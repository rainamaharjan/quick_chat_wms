import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:quick_chat_wms/models/prefrence_model.dart';
import 'package:quick_chat_wms/services/api_config.dart';
import 'package:quick_chat_wms/services/app_preference_service.dart';
import 'package:quick_chat_wms/services/client_service.dart';
import 'package:quick_chat_wms/services/secure_storage_service.dart';
import 'package:quick_chat_wms/services/webview_service.dart';
import 'package:quick_chat_wms/quick_chat_wms.dart';
import 'package:quick_chat_wms/widget/chat_skeleton.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart';

// Assuming these are your paths based on our previous discussions
// import 'package:quick_chat_wms/services/app_preferences_service.dart';
// import 'package:quick_chat_wms/services/permission_service.dart';
// import 'package:quick_chat_wms/services/quick_chat_webview_service.dart';
// import 'package:quick_chat_wms/models/app_preferences.dart';

/// Secure-storage key holding the username whose conversation is already in the
/// WebView's localStorage. Its presence is what lets a repeat open skip the
/// `get-unique-id` lookup entirely. Cleared by [QuickChatWms.logout] and
/// whenever that storage is wiped.
const String kRestoredUserKey = 'qc_restored_user';

class QuickChatWidget extends StatefulWidget {
  const QuickChatWidget({super.key});

  @override
  State<QuickChatWidget> createState() => QuickChatWidgetState();
}

class QuickChatWidgetState extends State<QuickChatWidget>
    with WidgetsBindingObserver, AutomaticKeepAliveClientMixin {
  // Services
  final _webViewService = QuickChatWebViewService();
  // Ensure you initialize this or pass it via dependency injection
  late final AppPreferencesService _prefsService;
  AppPreferences _prefs = AppPreferences();

  // State Variables
  bool _isCheckingPermissions = true;
  bool _hasPermissions = false;
  bool _isControllerInitialized = false;
  bool _isLoading = true;
  bool _isFileSelectorActive = false;

  /// Skeleton visibility is tracked separately from [_isLoading] so it can fade
  /// out: [_showSkeleton] drives the opacity, [_skeletonRemoved] drops it from
  /// the tree once the fade has finished.
  bool get _showSkeleton => _isLoading || !_isControllerInitialized;
  bool _skeletonRemoved = false;

  String _url = '';

  /// Set when the chat document itself fails to load (server/nginx error or a
  /// transport failure). Drives the retry UI that replaced the raw error page.
  QuickChatLoadError? _loadError;

  ConnectivityResult _connectionStatus = ConnectivityResult.none;
  late StreamSubscription<ConnectivityResult> _subscription;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Initialize your preferences service here (or via get_it/provider)
    _prefsService = AppPreferencesService(
      secureStorageService: SecureStorageService(),
    );

    _checkConnectivity();
    _listenToConnectivity();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Everything here runs BEFORE the WebView exists, so it is dead time on
    // screen — worth seeing in the timing log alongside the load phases.
    final Stopwatch watch = Stopwatch()..start();
    _prefs = await _prefsService.getPreferences();
    if (kDebugMode) {
      debugPrint('QUICKCHAT_TIMING prefs read: ${watch.elapsedMilliseconds}ms');
    }

    // Set by QuickChatWms.logout(): drop the previous conversation so this
    // mount starts fresh. Only the WebView's storage is wiped — the widget code
    // and branding must survive, otherwise a logged-out user gets a blank chat.
    if (_prefs.resetLocalStorage) {
      await _clearWebStorage();
      // The stored conversation is gone, so the "already restored" marker must
      // go with it or the next login would skip the lookup it now needs.
      await SecureStorageService().delete(key: kRestoredUserKey);
      await _prefsService.updatePreferences(
        data: (currentData) => currentData.copyWith(resetLocalStorage: false),
      );
      _prefs = await _prefsService.getPreferences();
    }

    // Permissions are NOT requested here anymore. Camera/gallery/file access is
    // requested only when the user taps the file-upload button inside the web
    // view (see WebViewService._androidFilePicker), so opening the chat no
    // longer triggers an up-front permission prompt.
    // A logged-in user may already have a conversation on the server. Look up
    // their client id so the chat can be restored instead of started fresh.
    //
    // Only on the FIRST open for that user, though: once the id is in the
    // WebView's localStorage it stays there, so every later open would pay for
    // an API call and an extra page load to write a value that's already
    // correct. Anonymous users have nothing to look up at all.
    //
    // Deliberately NOT awaited — the future is handed to the WebView, which
    // resolves it while the bootstrap document is already in flight.
    final String userName = _prefs.userName.trim();
    Future<String?>? uniqueIdFuture;
    if (userName.isNotEmpty && await _needsHistoryRestore(userName)) {
      uniqueIdFuture = ClientService.fetchClientUniqueId(
        widgetCode: _prefs.widgetCode,
        userName: userName,
      );
    }

    if (kDebugMode) {
      debugPrint(
        'QUICKCHAT_TIMING pre-webview total: ${watch.elapsedMilliseconds}ms '
        '(restore lookup: ${uniqueIdFuture != null})',
      );
    }

    if (!mounted) return;

    setState(() {
      _hasPermissions = true;
      _isCheckingPermissions = false;

      _url =
          '$quickChatBaseUrl/chat-sdk-script/mobileChat.html?widgetId=${_prefs.widgetCode}';
    });

    _initializeWebView(uniqueIdFuture: uniqueIdFuture, userName: userName);
  }

  /// Whether this user's history still has to be pulled from the server. False
  /// once [kRestoredUserKey] says we already seeded it into localStorage.
  Future<bool> _needsHistoryRestore(String userName) async {
    try {
      final String restoredFor =
          await SecureStorageService().read(key: kRestoredUserKey) ?? '';
      return restoredFor != userName;
    } catch (e) {
      debugPrint('Could not read restore marker: $e');
      return true;
    }
  }

  void _initializeWebView({
    Future<String?>? uniqueIdFuture,
    String userName = '',
  }) {
    _webViewService.init(
      url: _url,
      userName: _prefs.userName,
      email: _prefs.email,
      fcmToken: _prefs.fcmToken,
      context: context,
      onPageLoaded: () {
        if (mounted) setState(() => _isLoading = false);
      },
      onFileSelectorToggled: (isActive) {
        if (mounted) setState(() => _isFileSelectorActive = isActive);
      },
      onLoadError: (error) {
        // Forward to the host app so field failures on customer devices are
        // diagnosable (status code, url) via its crash/analytics logging.
        QuickChatWms.onChatLoadError?.call(error);
        if (mounted) {
          setState(() {
            _loadError = error;
            _isLoading = false;
          });
        }
      },
      uniqueIdFuture: uniqueIdFuture,
      onHistoryRestored: () {
        // Their conversation is now in localStorage and stays there, so skip
        // the lookup (and the extra page load) on every subsequent open.
        SecureStorageService().write(key: kRestoredUserKey, value: userName);
      },
      onUniqueIdResolved: (id) {
        // Persist so QuickChatWms.setFcmToken can re-register the token later
        // without the chat being open (see quick_chat_wms.dart).
        if (id.isNotEmpty) {
          SecureStorageService().write(
            key: 'qc_client_unique_id',
            value: id,
          );
        }
      },
    );

    if (mounted) {
      setState(() => _isControllerInitialized = true);
    }
  }

  /// Wipes the WebView's localStorage (where the chat page keeps `uniqueId`)
  /// so the next load mints a new conversation. Best-effort — a failure here
  /// must not stop the chat from opening.
  Future<void> _clearWebStorage() async {
    try {
      await WebViewController().clearLocalStorage();
    } catch (e) {
      debugPrint('Failed to clear chat local storage: $e');
    }
  }

  Future<void> _checkConnectivity() async {
    final result = await Connectivity().checkConnectivity();
    if (mounted) setState(() => _connectionStatus = result);
  }

  /// Re-requests the chat document after a load failure and shows the skeleton
  /// again while it reloads.
  void _retryLoad() {
    setState(() {
      _loadError = null;
      _isLoading = true;
      _skeletonRemoved = false;
    });
    _webViewService.retryLoad();
  }

  void _listenToConnectivity() {
    _subscription = Connectivity().onConnectivityChanged.listen((result) {
      if (_connectionStatus == ConnectivityResult.none &&
          result != ConnectivityResult.none) {
        if (_isControllerInitialized) {
          _webViewService.controller.reload();
        }
      }
      if (mounted) setState(() => _connectionStatus = result);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _subscription.cancel();
    super.dispose();
  }

  /// Friendly retry screen shown when the chat document fails to load, in place
  /// of the raw server (nginx) error page. Shows a compact technical hint (the
  /// status code) so a field report is actionable.
  Widget _buildLoadErrorView() {
    final int? status = _loadError?.statusCode;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            const Text(
              "We couldn't load the chat",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            const Text(
              "Something went wrong on our side. Please try again in a moment.",
              style: TextStyle(fontSize: 13, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              status != null ? "Error code: $status" : "Connection error",
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _retryLoad,
              child: const Text("Retry"),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_isCheckingPermissions) {
      return Scaffold(
        backgroundColor: _prefs.backgroundColor,
        body: ChatSkeleton(
          backgroundColor: _prefs.backgroundColor,
          accentColor: _prefs.appBarBackgroundColor,
        ),
      );
    }

    if (!_hasPermissions) {
      return Scaffold(
        backgroundColor: _prefs.backgroundColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Storage, Image, and Notification permissions are required.',
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => openAppSettings(),
                child: const Text('Open App Settings'),
              ),
            ],
          ),
        ),
      );
    }

    bool isConnected = _connectionStatus != ConnectivityResult.none;

    return Scaffold(
      backgroundColor: _prefs.backgroundColor,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(50),
        child: AppBar(
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_ios_outlined,
              size: 18,
              color: _prefs.appBarBackButtonColor,
            ),
            onPressed: () {
                if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                } else {
                  if (Platform.isAndroid) {
                    SystemNavigator.pop();
                  } else {
                    exit(0);
                  }
                }
              }
          ),
          title: Text(
            _prefs.appBarTitle,
            style: TextStyle(color: _prefs.appBarTitleColor, fontSize: 18),
          ),
          centerTitle: true,
          backgroundColor: _prefs.appBarBackgroundColor,
        ),
      ),
      body: isConnected
          ? (_loadError != null
              ? _buildLoadErrorView()
              : Stack(
              children: [
                if (_isControllerInitialized)
                  (Platform.isAndroid)
                      ? WebViewWidget.fromPlatformCreationParams(
                          params: AndroidWebViewWidgetCreationParams(
                            controller: _webViewService.controller.platform,
                            displayWithHybridComposition: true,
                          ),
                        )
                      : WebViewWidget(controller: _webViewService.controller),
                // Kept in the tree until the fade-out finishes, so the skeleton
                // dissolves into the conversation instead of cutting to it.
                if (!_skeletonRemoved)
                  IgnorePointer(
                    child: AnimatedOpacity(
                      opacity: _showSkeleton ? 1 : 0,
                      duration: const Duration(milliseconds: 280),
                      onEnd: () {
                        if (!_showSkeleton && mounted) {
                          setState(() => _skeletonRemoved = true);
                        }
                      },
                      child: ChatSkeleton(
                        backgroundColor: _prefs.backgroundColor,
                        accentColor: _prefs.appBarBackgroundColor,
                      ),
                    ),
                  ),
              ],
            ))
          : Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "No internet connection",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _checkConnectivity,
                    child: const Text("Retry"),
                  ),
                ],
              ),
            ),
    );
  }
}
