import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:quick_chat_wms/services/notification_service.dart';
import 'package:quick_chat_wms/services/permission_service.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';

/// Details of a failed chat load, surfaced to the host so it can show a retry
/// UI instead of the raw server (nginx) error page, and log what actually went
/// wrong on the device. Carries no user/PII content.
class QuickChatLoadError {
  const QuickChatLoadError({
    required this.description,
    this.statusCode,
    this.url,
    this.isHttpStatus = false,
  });

  /// HTTP status when the server answered with an error (e.g. 502, 403, 421).
  /// Null for transport-level failures (DNS, TLS, connection reset).
  final int? statusCode;

  /// Human-readable description of the failure.
  final String description;

  /// The URL that failed.
  final String? url;

  /// True when this came from an HTTP error response, false for a
  /// [WebResourceError] (transport/render level).
  final bool isHttpStatus;

  @override
  String toString() =>
      'QuickChatLoadError(status: $statusCode, http: $isHttpStatus, '
      'desc: $description, url: $url)';
}

typedef QuickChatLoadErrorCallback = void Function(QuickChatLoadError error);

class QuickChatWebViewService {
  late final WebViewController controller;

  /// Times each phase of the open so a slow chat can be attributed to the phase
  /// that actually costs the time (grep logcat for QUICKCHAT_TIMING).
  final Stopwatch _openWatch = Stopwatch();

  void _mark(String phase) {
    if (!kDebugMode) return;
    debugPrint('QUICKCHAT_TIMING $phase: ${_openWatch.elapsedMilliseconds}ms');
  }

  /// Resolves to the server-known client id for the logged-in user, which is
  /// seeded into the page's localStorage so the chat loads their existing
  /// history (see [_seedUniqueId]).
  ///
  /// A FUTURE rather than a value: the lookup runs while the bootstrap document
  /// is already being fetched, so the API call costs no wall-clock of its own.
  Future<String?>? _uniqueIdFuture;

  /// The id once [_uniqueIdFuture] has resolved and been sanitized.
  String? _preloadUniqueId;

  /// Set once [_preloadUniqueId] is actually in the page's localStorage.
  bool _uniqueIdSeeded = false;

  /// Guards the reload fallback below, so a page that refuses to store the id
  /// can never put us in a reload loop.
  bool _reloadedForSeed = false;

  /// Origin of the chat URL. A BLANK same-origin document is rendered from it
  /// BEFORE the chat, purely so the id can be written to localStorage (which is
  /// per-origin) while nothing is on screen. Without it the chat had to boot
  /// once with the wrong id, get the id, and reload — which the user saw as
  /// chat → loading → chat.
  ///
  /// This used to navigate to `<origin>/robots.txt`, but that path 404s and the
  /// raw nginx error page could flash on screen for the ~1s the id lookup takes
  /// — visible on newer Android WebView, which paints the native view over the
  /// Flutter skeleton meant to hide it. A blank in-memory page cannot 404.
  String? _bootstrapOrigin;

  /// Blank, invisible document used only to reach the chat origin's
  /// localStorage. Rendered via [WebViewController.loadHtmlString] with
  /// [_bootstrapOrigin] as the base URL so its localStorage is that origin's.
  static const String _blankBootstrapHtml =
      '<!doctype html><html><head><meta charset="utf-8"></head>'
      '<body style="margin:0;background:transparent"></body></html>';

  /// True while that bootstrap document is the thing being loaded.
  bool _awaitingBootstrap = false;

  /// Called once the history id is in localStorage, so the SDK can remember
  /// this user is restored and skip the whole lookup next time.
  VoidCallback? _onHistoryRestored;

  /// The real chat document URL (mobileChat.html). Kept so load-error handling
  /// can tell a fatal chat failure apart from the throwaway bootstrap probe and
  /// from subresource (analytics/asset/XHR) errors inside the loaded page.
  String? _chatUrl;

  /// Invoked when the MAIN chat document fails to load — an HTTP 4xx/5xx from
  /// the server (the raw nginx page users used to see) or a transport-level
  /// web-resource error. Lets the host show a retry UI and log the status.
  QuickChatLoadErrorCallback? _onLoadError;

  /// One-shot guard so a single failed load (which can fire both onHttpError
  /// and onWebResourceError) is reported once. Reset by [retryLoad].
  bool _loadErrorReported = false;

  /// Context used to present the iOS upload sheet and its permission dialogs.
  /// Captured in [init] because the gate fires from a JavaScript channel, which
  /// has no BuildContext of its own.
  BuildContext? _gateContext;

  /// Host hook signalling that a picker is on screen. Held as a field so the
  /// iOS gate can raise it from the JavaScript channel, the same way the
  /// Android selector does from its own callback.
  Function(bool)? _onFileSelectorToggled;

  void init({
    required String url,
    required String userName,
    required String email,
    required String fcmToken,
    required BuildContext context,
    required VoidCallback onPageLoaded,
    required Function(bool) onFileSelectorToggled,
    Function(String uniqueId)? onUniqueIdResolved,
    Future<String?>? uniqueIdFuture,
    VoidCallback? onHistoryRestored,
    QuickChatLoadErrorCallback? onLoadError,
  }) {
    _chatUrl = url;
    _onLoadError = onLoadError;
    _loadErrorReported = false;
    _gateContext = context;
    _onFileSelectorToggled = onFileSelectorToggled;
    _openWatch
      ..reset()
      ..start();
    _mark(uniqueIdFuture != null ? 'init (restore path)' : 'init (direct)');
    _uniqueIdFuture = uniqueIdFuture;
    _onHistoryRestored = onHistoryRestored;
    if (uniqueIdFuture != null) {
      // Seed the chat origin's localStorage from a blank same-origin page (see
      // _blankBootstrapHtml) before the chat boots — no network, no 404.
      _bootstrapOrigin = Uri.parse(url).origin;
      _awaitingBootstrap = true;
    }
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'FlutterWebView',
        onMessageReceived: (JavaScriptMessage message) {
          String uniqueId = message.message;
          if (uniqueId.isEmpty) {
            uniqueId = _generateUniqueId();
          }
          // Surface the resolved client uniqueId so the SDK can persist it and
          // later re-register the FCM token (store-firebase-token) directly —
          // without needing the chat WebView to be open (e.g. token refresh).
          onUniqueIdResolved?.call(uniqueId);
          _postTokenToApi(userName, email, fcmToken, uniqueId);
        },
      )
      // iOS only. Android never posts here — its uploads go through
      // `setOnShowFileSelector` / `_androidFilePicker`, which already presents
      // our own sheet and is untouched by this gate.
      ..addJavaScriptChannel(
        'QuickChatUpload',
        onMessageReceived: (JavaScriptMessage message) {
          _handleUploadRequest();
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (NavigationRequest request) {
            final String reqUrl = request.url;
            final bool isChat = reqUrl.contains(url);
            // The blank bootstrap document (about:/data:) and any same-origin
            // navigation stay in the WebView; only genuine off-site links open
            // in the external browser.
            final bool isInApp = reqUrl.startsWith('about:') ||
                reqUrl.startsWith('data:') ||
                (_bootstrapOrigin != null && reqUrl.startsWith(_bootstrapOrigin!));
            if (!isChat && !isInApp) {
              _launchURL(reqUrl);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
          onPageFinished: (String pageUrl) async {
            if (_awaitingBootstrap) {
              // Nothing user-visible has loaded yet: write the restored id, then
              // load the chat ONCE, already carrying its history. The lookup was
              // running while this document loaded, so it's usually done by now.
              _awaitingBootstrap = false;
              _bootstrapWatchdog?.cancel();
              _mark('bootstrap loaded');
              // The id lookup must NEVER decide whether the chat loads.
              //
              // This await is on a network call. If it threw or hung, the
              // exception escaped this async callback and `loadRequest` below
              // never ran — leaving the WebView parked on _blankBootstrapHtml,
              // which is an genuinely blank white document. No error UI appeared
              // either, because the bootstrap page itself had loaded fine (200),
              // so _reportLoadError was never reached. That is the "chat opens
              // to a white screen" report.
              //
              // Worst case is exactly when it is most likely: opening from a
              // push tap after the app was backgrounded. The pause handler tears
              // the WebView down, so this runs a FRESH bootstrap while the
              // device has just woken and the radio is still reconnecting.
              //
              // Losing history restoration is a far better outcome than a chat
              // that never appears, so failures fall through to a plain load.
              try {
                _preloadUniqueId = _sanitizeUniqueId(
                  await _uniqueIdFuture?.timeout(const Duration(seconds: 8)),
                );
                _mark('get-unique-id resolved');
                if (_preloadUniqueId != null) {
                  _uniqueIdSeeded = await _seedUniqueId();
                  if (_uniqueIdSeeded) _onHistoryRestored?.call();
                }
              } catch (e) {
                debugPrint(
                  'QUICKCHAT bootstrap id lookup failed, '
                  'loading chat without restored history: $e',
                );
              }
              _mark('id seeded → loading chat');
              await controller.loadRequest(Uri.parse(url));
              return;
            }
            // Fallback: the bootstrap document couldn't store the id (blocked
            // storage, request failed). The chat script reads localStorage while
            // it boots, so seeding now only takes effect after a reload.
            if (_preloadUniqueId != null &&
                !_uniqueIdSeeded &&
                !_reloadedForSeed) {
              _reloadedForSeed = true;
              if (await _seedUniqueId()) {
                _uniqueIdSeeded = true;
                await controller.reload();
                return; // onPageFinished fires again after the reload.
              }
            }
            _mark('chat document loaded');
            await _injectViewportAndFetchId();
            await _installUploadGate();
            _mark('skeleton out');
            onPageLoaded();
          },
          // The server (nginx) answered the chat document with an error status
          // — this is the raw error page users saw before. Report it instead of
          // rendering it. Subresource and bootstrap failures are non-fatal.
          onHttpError: (HttpResponseError error) {
            // WebResourceRequest exposes no main-frame flag here, so failures
            // are filtered by URL: a subresource (analytics/asset/XHR) won't
            // match the chat document's path, nor will the bootstrap probe.
            final String? failedUrl =
                (error.request?.uri ?? error.response?.uri)?.toString();
            if (_isBootstrap(failedUrl)) return;
            if (!_isChatDocument(failedUrl)) return;
            final int? status = error.response?.statusCode;
            _mark('chat HTTP error $status');
            _reportLoadError(
              QuickChatLoadError(
                statusCode: status,
                description: 'Server returned HTTP $status',
                url: failedUrl,
                isHttpStatus: true,
              ),
            );
          },
          // Transport / render-level failure of the main chat document (DNS,
          // TLS, connection reset). Subresource failures don't break the shell.
          onWebResourceError: (WebResourceError error) {
            if (error.isForMainFrame == false) return;
            if (_isBootstrap(error.url)) return;
            // A main-frame transport error may carry no URL on some platforms;
            // a null URL is treated as the chat document, a set one is matched.
            if (error.url != null && !_isChatDocument(error.url)) return;
            _mark('chat resource error ${error.errorCode}');
            _reportLoadError(
              QuickChatLoadError(
                statusCode: null,
                description: error.description,
                url: error.url,
                isHttpStatus: false,
              ),
            );
          },
        ),
      );

    // iOS has no logcat equivalent for WKWebView, so page-side diagnostics
    // (`QC_CAM_GATE:`, `QC_UNIQUEID:`) were being written to a console nobody
    // could read. Forward them into the Dart log in debug builds.
    if (kDebugMode) {
      controller.setOnConsoleMessage((JavaScriptConsoleMessage message) {
        debugPrint('QUICKCHAT webview console: ${message.message}');
      });
    }

    if (Platform.isAndroid) {
      final androidController = controller.platform as AndroidWebViewController;
      androidController.setOnShowFileSelector(
        (params) => _androidFilePicker(params, context, onFileSelectorToggled),
      );
    }

    if (_awaitingBootstrap) {
      // Blank, invisible, same-origin — just to reach this origin's
      // localStorage before the real chat document loads.
      controller.loadHtmlString(_blankBootstrapHtml, baseUrl: _bootstrapOrigin);
      _armBootstrapWatchdog(url);
    } else {
      controller.loadRequest(Uri.parse(url));
    }
  }

  Timer? _bootstrapWatchdog;

  /// Last-resort escape from the blank bootstrap document.
  ///
  /// The bootstrap page is a literal blank white document, and the chat only
  /// replaces it from `onPageFinished`. If that callback never arrives — the
  /// in-memory load silently failing on a just-woken device, for instance —
  /// nothing else would ever move us off it, and the user stares at white with
  /// no error to report because no request actually failed.
  ///
  /// Only fires while [_awaitingBootstrap] is still set, i.e. the handover
  /// provably never happened. Once the chat is loading, this is a no-op.
  void _armBootstrapWatchdog(String url) {
    _bootstrapWatchdog?.cancel();
    _bootstrapWatchdog = Timer(const Duration(seconds: 12), () {
      if (!_awaitingBootstrap) return;
      _awaitingBootstrap = false;
      _mark('bootstrap watchdog fired → loading chat directly');
      debugPrint(
        'QUICKCHAT bootstrap never completed; loading chat without '
        'restored history',
      );
      controller.loadRequest(Uri.parse(url));
    });
  }

  /// Stop the watchdog. Call when the chat is torn down.
  void dispose() {
    _bootstrapWatchdog?.cancel();
    _bootstrapWatchdog = null;
  }

  /// The blank in-memory bootstrap document (about:blank / data:). Any load
  /// error on it is not a chat failure and must not be surfaced.
  bool _isBootstrap(String? url) {
    if (url == null) return false;
    return url.startsWith('about:') || url.startsWith('data:');
  }

  /// Whether [url] is the actual chat document, compared on origin + path so a
  /// differing query string (widgetId) or trailing slash doesn't matter.
  bool _isChatDocument(String? url) {
    if (url == null || _chatUrl == null) return false;
    final Uri? a = Uri.tryParse(url);
    final Uri? b = Uri.tryParse(_chatUrl!);
    if (a == null || b == null) return url == _chatUrl;
    return a.origin == b.origin && a.path == b.path;
  }

  /// Reports a failed chat load once per load attempt (both onHttpError and
  /// onWebResourceError can fire for the same failure).
  void _reportLoadError(QuickChatLoadError error) {
    if (_loadErrorReported) return;
    _loadErrorReported = true;
    debugPrint('QUICKCHAT_LOAD_ERROR $error');
    _onLoadError?.call(error);
  }

  /// Re-requests the current document after a failed load, re-arming the
  /// one-shot error guard so a repeat failure is reported again.
  Future<void> retryLoad() async {
    _loadErrorReported = false;
    await controller.reload();
  }

  /// Whether the page's renderer is still alive and able to run JavaScript.
  ///
  /// iOS runs WKWebView's page in a separate **WebContent** process. While the
  /// app is backgrounded, iOS reclaims memory by jetsamming that process; the
  /// `WKWebView` itself survives, so the widget tree is unchanged and Flutter
  /// has no idea anything happened — the view just renders blank white on
  /// resume. WebKit's `webViewWebContentProcessDidTerminate:` (which the plugin
  /// forwards as an `onWebResourceError` with `WKErrorCode
  /// .webContentProcessTerminated`) is not delivered when the app was suspended
  /// at the time, which is why the retry UI never appeared for it either.
  ///
  /// Probing with JavaScript is the reliable signal: with a dead WebContent
  /// process the evaluation errors out (or never answers), whereas a healthy
  /// page returns its `document.readyState` immediately.
  ///
  /// Retried once, because a resume can briefly land while the renderer is
  /// still waking up and a false negative here costs the user a visible reload.
  Future<bool> isWebContentAlive() async {
    for (int attempt = 0; attempt < 2; attempt++) {
      try {
        final Object result = await controller
            .runJavaScriptReturningResult('document.readyState')
            .timeout(const Duration(seconds: 2));
        final String state = result.toString().replaceAll('"', '');
        if (state.isNotEmpty && state != 'null') return true;
      } catch (_) {
        // Dead renderer, or the channel timed out — fall through and retry.
      }
      if (attempt == 0) {
        await Future<void>.delayed(const Duration(milliseconds: 300));
      }
    }
    return false;
  }

  /// The document the WebView believes it is showing, or null if it cannot say.
  ///
  /// Diagnostic only. A blank-but-alive page and a dead renderer look identical
  /// on screen, but differ here: a live page still reports its chat URL.
  Future<String?> currentUrlSafe() async {
    try {
      return await controller
          .currentUrl()
          .timeout(const Duration(seconds: 2));
    } catch (_) {
      return null;
    }
  }

  /// Reloads the chat, re-arming the one-shot load-error guard.
  ///
  /// The chat's history lives in the page's localStorage (see [_seedUniqueId]),
  /// so this restores the conversation rather than starting a new one.
  Future<void> recoveryReload() async {
    _mark('recovery reload');
    _loadErrorReported = false;
    await controller.reload();
  }

  /// Writes [_preloadUniqueId] into the current document's localStorage.
  ///
  /// Returns true once the id is in place — including when it was already the
  /// stored value, since the caller's only question is "does the chat now have
  /// the right id?".
  Future<bool> _seedUniqueId() async {
    final String? id = _preloadUniqueId;
    if (id == null) return false;

    try {
      final result = await controller.runJavaScriptReturningResult("""
        (function() {
          try {
            if (!window.localStorage) return 'false';
            localStorage.setItem('uniqueId', '$id');
            return localStorage.getItem('uniqueId') === '$id' ? 'true' : 'false';
          } catch (e) {
            return 'false';
          }
        })();
      """);
      return result.toString().contains('true');
    } catch (e) {
      debugPrint('Failed to seed uniqueId into localStorage: $e');
      return false;
    }
  }

  /// Ids come from the network and are interpolated into a JS string literal,
  /// so anything outside the server's `20250620100400360` shape is dropped.
  String? _sanitizeUniqueId(String? id) {
    final String value = id?.trim() ?? '';
    if (value.isEmpty) return null;
    if (!RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(value)) {
      debugPrint('Ignoring unexpected client_unique_id: $value');
      return null;
    }
    return value;
  }

  /// iOS: replace WKWebView's own upload sheet with ours.
  ///
  /// Android hands us `setOnShowFileSelector`, so [_androidFilePicker] gets to
  /// present the choices and ask for exactly the permission each one needs.
  /// iOS has no equivalent hook anywhere in webview_flutter_wkwebview: WKWebView
  /// puts up its OWN native sheet (Photo Library / Take Photo or Video / Choose
  /// File) and performs the capture itself. Nothing in Dart or JS can see which
  /// row was tapped, so the camera permission could not be tied to the camera
  /// row — and with the permission denied iOS still opens the capture UI, with
  /// a dead feed and a shutter that does nothing.
  ///
  /// So the tap is intercepted and the sheet is rebuilt here, which puts the
  /// permission back where it belongs: asked only when the user actually
  /// chooses Take Photo, and asked again on every later attempt while it is
  /// still missing. Gallery and Choose File never touch it.
  ///
  /// Video capture is deliberately absent on iOS. Returning a file to the page
  /// means injecting its bytes into the input (see [_injectPickedFile]), which
  /// is comfortable for a compressed photo and not for a phone video.
  Future<void> _installUploadGate() async {
    if (!Platform.isIOS) {
      return;
    }
    await controller.runJavaScript(r"""
      (function() {
        if (window.__qcUploadGateInstalled) return;
        window.__qcUploadGateInstalled = true;

        function qcIsFileInput(n) {
          return n && n.tagName === 'INPUT' &&
                 (n.getAttribute('type') || '').toLowerCase() === 'file';
        }

        // The chat UI is a Lit custom element (<chat-bot>), so its file input
        // lives inside a shadow root. Events crossing a shadow boundary are
        // RETARGETED: by the time one reaches this document listener, e.target
        // is the <chat-bot> host, not the input — and parentNode cannot walk
        // back in. composedPath() is the only view that still contains the real
        // input, which is why matching on e.target found nothing at all.
        function qcFindFileInput(e) {
          if (typeof e.composedPath === 'function') {
            var path = e.composedPath();
            for (var i = 0; i < path.length; i++) {
              if (qcIsFileInput(path[i])) return path[i];
            }
          }
          var el = e.target;
          while (el && el !== document) {
            if (qcIsFileInput(el)) return el;
            el = el.parentNode || el.host;
          }
          return null;
        }

        // Fallback for injection: the stashed input is lost if the page
        // re-renders while our sheet is up. Walks open shadow roots, since a
        // plain document.querySelector cannot see into them either.
        function qcAnyFileInput() {
          var stack = [document];
          while (stack.length) {
            var root = stack.pop();
            if (root.querySelector) {
              var hit = root.querySelector('input[type=file]');
              if (hit) return hit;
            }
            var all = root.querySelectorAll ? root.querySelectorAll('*') : [];
            for (var i = 0; i < all.length; i++) {
              if (all[i].shadowRoot) stack.push(all[i].shadowRoot);
            }
          }
          return null;
        }

        // Capture phase, so this runs before the page's own handlers and before
        // WKWebView opens its native sheet.
        document.addEventListener('click', function(e) {
          var input = qcFindFileInput(e);
          if (!input) return;
          e.preventDefault();
          e.stopPropagation();
          window.__qcPendingInput = input;
          console.log('QC_UPLOAD: intercepted file input tap');
          QuickChatUpload.postMessage('pick');
        }, true);

        // Bytes arrive in chunks so a multi-megabyte base64 string never has to
        // be a single JavaScript literal.
        window.__qcChunks = [];
        window.__qcAppendChunk = function(chunk) { window.__qcChunks.push(chunk); };
        window.__qcInjectFile = function(name, mime) {
          try {
            var b64 = window.__qcChunks.join('');
            window.__qcChunks = [];
            var input = window.__qcPendingInput || qcAnyFileInput();
            if (!input) return 'no-input';
            var bin = atob(b64);
            var bytes = new Uint8Array(bin.length);
            for (var i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i);
            var file = new File([bytes], name, { type: mime });
            var dt = new DataTransfer();
            dt.items.add(file);
            input.files = dt.files;
            input.dispatchEvent(new Event('change', { bubbles: true }));
            return 'ok';
          } catch (err) {
            return 'err:' + err;
          }
        };
        console.log('QC_UPLOAD: gate installed');
      })();
    """);
  }

  /// Presents the iOS upload sheet after the gate above swallowed a tap.
  Future<void> _handleUploadRequest() async {
    final BuildContext? context = _gateContext;
    if (context == null || !context.mounted) {
      return;
    }

    // Mirrors the Android path: tells the host a picker is up, so the chat is
    // not treated as idle while the user is off in the photo library.
    _onFileSelectorToggled?.call(true);
    try {
      final String? choice = await showModalBottomSheet<String>(
        context: context,
        useRootNavigator: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16.0)),
        ),
        builder: (BuildContext sheetContext) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 8.0,
                    ),
                    child: Text(
                      'Upload File',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.photo_library),
                    title: const Text('Gallery'),
                    onTap: () => Navigator.of(sheetContext).pop('gallery'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.camera_alt),
                    title: const Text('Take Photo'),
                    onTap: () => Navigator.of(sheetContext).pop('camera'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.attach_file),
                    title: const Text('Choose File'),
                    onTap: () => Navigator.of(sheetContext).pop('file'),
                  ),
                ],
              ),
            ),
          );
        },
      );

      // The sheet is an async gap: the chat can be torn down underneath it (an
      // iOS pause drops the WebView outright), so the context must be rechecked
      // before it is used to raise a dialog.
      if (choice == null || !context.mounted) {
        return;
      }

      if (choice == 'camera') {
        // The whole point of the gate: the permission is requested HERE, on the
        // camera row, and re-requested on every later attempt while it is
        // missing — never for a gallery or file upload.
        if (!await _ensureCameraPermission(context)) {
          return;
        }
        final XFile? photo = await ImagePicker().pickImage(
          source: ImageSource.camera,
          imageQuality: 70,
          maxWidth: 1920,
          maxHeight: 1080,
        );
        if (photo != null) {
          await _injectPickedFile(File(photo.path), photo.name);
        }
      } else if (choice == 'gallery') {
        // No permission call: on iOS 14+ image_picker uses PHPicker, which
        // hands back the chosen item without the app holding library access.
        final XFile? photo = await ImagePicker().pickImage(
          source: ImageSource.gallery,
          imageQuality: 70,
          maxWidth: 1920,
          maxHeight: 1080,
        );
        if (photo != null) {
          await _injectPickedFile(File(photo.path), photo.name);
        }
      } else if (choice == 'file') {
        final FilePickerResult? result = await FilePicker.platform.pickFiles(
          allowMultiple: false,
          type: FileType.any,
        );
        final PlatformFile? picked =
            (result != null && result.files.isNotEmpty)
                ? result.files.first
                : null;
        final String? path = picked?.path;
        if (path != null) {
          await _injectPickedFile(File(path), picked!.name);
        }
      }
    } catch (e) {
      debugPrint('QUICKCHAT iOS upload failed: $e');
    } finally {
      _onFileSelectorToggled?.call(false);
    }
  }

  /// True when the camera may be used right now.
  ///
  /// Asks every time it is missing, rather than remembering a refusal: an
  /// undecided permission gets the system dialog, and one already denied gets
  /// the Settings route, because iOS will not present its dialog a second time.
  Future<bool> _ensureCameraPermission(BuildContext context) async {
    final PermissionService permissions = PermissionService();
    if (await permissions.isCameraGranted()) {
      return true;
    }
    if (await permissions.isCameraUndecided() &&
        await permissions.requestCameraPermission()) {
      return true;
    }
    if (!context.mounted) {
      return false;
    }
    final bool? goToSettings = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: const Text('Camera permission required'),
          content: const Text(
            'Camera access is turned off for this app, so photos cannot be '
            'captured. Enable Camera in Settings to take a photo, or attach an '
            'existing photo or file instead.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Open Settings'),
            ),
          ],
        );
      },
    );
    if (goToSettings == true) {
      await permissions.openSettings();
    }
    return false;
  }

  /// Largest file we will hand to the page. Injection materialises the bytes as
  /// base64 inside JavaScript, so this is a memory ceiling, not a server limit.
  static const int _maxInjectBytes = 20 * 1024 * 1024;

  /// Hands a picked file to the chat's `<input type="file">`.
  ///
  /// iOS gives us no callback to return a file through — the Android selector
  /// just returns URIs and the engine reads them — so the bytes are shipped
  /// into the page and reassembled into a `File` there, then announced with a
  /// `change` event exactly as a real pick would be.
  Future<void> _injectPickedFile(File file, String name) async {
    try {
      final int length = await file.length();
      if (length > _maxInjectBytes) {
        final BuildContext? context = _gateContext;
        if (context != null && context.mounted) {
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
            const SnackBar(content: Text('That file is too large to attach.')),
          );
        }
        return;
      }

      final String b64 = base64Encode(await file.readAsBytes());
      await controller.runJavaScript('window.__qcChunks = [];');
      const int chunkSize = 64 * 1024;
      for (int i = 0; i < b64.length; i += chunkSize) {
        final int end =
            (i + chunkSize < b64.length) ? i + chunkSize : b64.length;
        // Base64's alphabet contains no quote or backslash, so a chunk is safe
        // to drop straight into a single-quoted JavaScript literal.
        await controller.runJavaScript(
          "window.__qcAppendChunk('${b64.substring(i, end)}');",
        );
      }
      final Object result = await controller.runJavaScriptReturningResult(
        'window.__qcInjectFile(${jsonEncode(name)}, '
        '${jsonEncode(_mimeFor(name))})',
      );
      debugPrint('QUICKCHAT inject ($name, $length bytes) -> $result');
    } catch (e) {
      debugPrint('QUICKCHAT inject failed: $e');
    }
  }

  String _mimeFor(String name) {
    final int dot = name.lastIndexOf('.');
    final String ext = dot == -1 ? '' : name.substring(dot + 1).toLowerCase();
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'heic':
        return 'image/heic';
      case 'pdf':
        return 'application/pdf';
      case 'txt':
        return 'text/plain';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument'
            '.wordprocessingml.document';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument'
            '.spreadsheetml.sheet';
      default:
        return 'application/octet-stream';
    }
  }


  Future<void> _injectViewportAndFetchId() async {
    // No settle delay: `onPageFinished` already means the DOM is ready, and the
    // half-second that used to be waited here was pure added latency on every
    // chat open. Anything the page writes late is still caught by the poll below.
    await controller.runJavaScript("""
      (function() {
        if(document.querySelector('meta[name="viewport"]')) {
          document.querySelector('meta[name="viewport"]').setAttribute('content', 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no');
        } else {
          var meta = document.createElement('meta');
          meta.name = 'viewport';
          meta.content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no';
          document.head.appendChild(meta);
        }

        // The chat page may write the client id to localStorage asynchronously
        // (after the conversation is established), so poll for it instead of
        // reading once. Also log every key so we can confirm the real key name.
        function qcTryPostId() {
          try {
            if (!window.localStorage) return false;
            console.log('QC_LS_KEYS: ' + Object.keys(localStorage).join('|'));
            var id = localStorage.getItem('uniqueId');
            console.log('QC_UNIQUEID: ' + id);
            if (id) {
              FlutterWebView.postMessage(id);
              return true;
            }
          } catch (e) {
            console.log('QC_LS_ERR: ' + e);
          }
          return false;
        }
        if (!qcTryPostId()) {
          var qcTries = 0;
          var qcTimer = setInterval(function() {
            qcTries++;
            if (qcTryPostId() || qcTries > 20) clearInterval(qcTimer);
          }, 1000);
        }
      })();
    """);
  }

  Future<List<String>> _androidFilePicker(
    FileSelectorParams params,
    BuildContext context,
    Function(bool) onFileSelectorToggled,
  ) async {
    onFileSelectorToggled(true);

    try {
      // Show the upload options first so the user always sees Camera / Gallery /
      // Video. Permission is requested per-choice below — only when needed and
      // only after the user taps the file-upload button in the web view.
      final String? choice = await showModalBottomSheet<String>(
        context: context,
        useRootNavigator: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16.0)),
        ),
        builder: (BuildContext context) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 8.0,
                    ),
                    child: Text(
                      'Upload File',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.photo_library),
                    title: const Text('Gallery / Files'),
                    onTap: () => Navigator.of(context).pop('gallery'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.camera_alt),
                    title: const Text('Take Photo'),
                    onTap: () => Navigator.of(context).pop('camera'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.videocam),
                    title: const Text('Record Video'),
                    onTap: () => Navigator.of(context).pop('video'),
                  ),
                ],
              ),
            ),
          );
        },
      );

      // Camera capture needs the camera permission, requested only when the
      // user picks a camera option. Gallery / Files goes through the system
      // file picker (SAF), which needs no runtime permission.
      if (choice == 'camera' || choice == 'video') {
        final permissionService = PermissionService();
        final cameraGranted = await permissionService.requestCameraPermission();
        if (!cameraGranted) {
          // When it's permanently denied the OS won't prompt anymore, so ask
          // the user (via a dialog) whether to open app settings to enable it.
          if (await permissionService.isCameraPermanentlyDenied() &&
              context.mounted) {
            final goToSettings = await _showCameraSettingsDialog(context);
            if (goToSettings == true) {
              await permissionService.openSettings();
            }
          }
          return [];
        }
      }

      if (choice == 'camera') {
        final photo = await ImagePicker().pickImage(
          source: ImageSource.camera,
          imageQuality: 70,
          maxWidth: 1920,
          maxHeight: 1080,
        );
        if (photo != null) return [Uri.file(photo.path).toString()];
      } else if (choice == 'video') {
        final video = await ImagePicker().pickVideo(source: ImageSource.camera);
        if (video != null) return [Uri.file(video.path).toString()];
      } else if (choice == 'gallery') {
        final result = await FilePicker.platform.pickFiles(
          allowMultiple: false,
          type: FileType.any,
        );
        if (result != null && result.files.isNotEmpty) {
          return result.files
              .where((file) => file.path != null)
              .map((file) => Uri.file(file.path!).toString())
              .toList();
        }
      }
    } catch (e) {
      debugPrint('Error picking file: $e');
    } finally {
      onFileSelectorToggled(false);
    }

    return [];
  }

  /// Asks the user whether to open app settings to enable the camera permission
  /// (shown only when the permission is permanently denied). Returns true if the
  /// user chose to open settings.
  Future<bool?> _showCameraSettingsDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Camera permission required'),
          content: const Text(
            'Camera access is turned off for this app. To take a photo, enable '
            'the Camera permission in Settings.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Open Settings'),
            ),
          ],
        );
      },
    );
  }

  void _launchURL(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      debugPrint("❌ Could not launch $url");
    }
  }

  Future<void> _postTokenToApi(
    String username,
    String email,
    String fcmToken,
    String uniqueId,
  ) async {
    await NotificationHandlerService.updateFirebaseToken(
      username,
      email,
      fcmToken,
      uniqueId,
    );
  }

  String _generateUniqueId() {
    DateTime now = DateTime.now();
    return "${now.year}${now.month.toString().padLeft(2, '0')}"
        "${now.day.toString().padLeft(2, '0')}${now.hour.toString().padLeft(2, '0')}"
        "${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}"
        "${now.millisecond.toString().padLeft(3, '0')}";
  }
}
