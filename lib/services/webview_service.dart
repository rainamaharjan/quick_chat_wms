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
              _mark('bootstrap loaded');
              _preloadUniqueId = _sanitizeUniqueId(await _uniqueIdFuture);
              _mark('get-unique-id resolved');
              if (_preloadUniqueId != null) {
                _uniqueIdSeeded = await _seedUniqueId();
                if (_uniqueIdSeeded) _onHistoryRestored?.call();
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
    } else {
      controller.loadRequest(Uri.parse(url));
    }
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
