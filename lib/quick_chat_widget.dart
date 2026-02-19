import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:quick_chat_wms/preference_manager.dart';
import 'package:quick_chat_wms/webview_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'handler.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

bool isChatScreen = false;

class QuickChatWidget extends StatefulWidget {
  const QuickChatWidget({super.key});

  @override
  State<QuickChatWidget> createState() => QuickChatWidgetState();
}

class QuickChatWidgetState extends State<QuickChatWidget>
    with WidgetsBindingObserver, AutomaticKeepAliveClientMixin {
  String url = '';
  bool isLoading = true;
  bool _isPickerActive = false;
  bool _webViewReady = false;

  late StreamSubscription<ConnectivityResult> _subscription;
  ConnectivityResult _connectionStatus = ConnectivityResult.none;

  String fcmToken = '';
  String email = '';
  String userName = '';
  String widgetCode = '';
  String appBarTitle = '';
  Color? appBarTitleColor;
  Color? appBarBackgroundColor;
  Color? backgroundColor;
  Color? appBarBackButtonColor;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeController();

    isLoading = true;
    _checkConnectivity();

    _subscription = Connectivity()
        .onConnectivityChanged
        .listen((ConnectivityResult result) {
      if (_connectionStatus == ConnectivityResult.none &&
          result != ConnectivityResult.none &&
          WebViewService().isReady) {
        WebViewService().controller!.reload();
      }
      setState(() {
        _connectionStatus = result;
      });
    });

    isChatScreen = true;
  }

  Future<void> _checkConnectivity() async {
    final result = await Connectivity().checkConnectivity();
    setState(() {
      _connectionStatus = result;
    });
  }

  void _initializeController() async {
    PreferencesManager preferencesManager = PreferencesManager();

    fcmToken = await preferencesManager.getFcmToken();
    userName = await preferencesManager.getUserName();
    email = await preferencesManager.getEmail();

    final prefs = await preferencesManager.getPreferences();

    if (!mounted) return;

    setState(() {
      widgetCode = prefs['widget_code'] ?? '';
      appBarTitle = prefs['app_bar_title'] ?? 'Chat With Us';
      appBarTitleColor = prefs['app_bar_title_color'];
      appBarBackgroundColor = prefs['app_bar_background_color'];
      backgroundColor = prefs['background_color'];
      appBarBackButtonColor = prefs['app_bar_back_button_color'];
      url =
          'https://app.quickconnect.biz/chat-sdk-script/mobileChat.html?widgetId=$widgetCode';
    });
  }

  void checkAndResetLocalStorage() async {
    PreferencesManager preferencesManager = PreferencesManager();
    final shouldReset = await preferencesManager.getLocalStorageResetFlag();
    if (shouldReset && WebViewService().isReady && mounted) {
      await WebViewService().clearLocalStorage();
      await preferencesManager.setLocalStorageResetFlag(reset: false);
    }
  }

  String generateUniqueId() {
    DateTime now = DateTime.now();
    return "${now.year}${now.month.toString().padLeft(2, '0')}"
        "${now.day.toString().padLeft(2, '0')}${now.hour.toString().padLeft(2, '0')}"
        "${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}"
        "${now.millisecond.toString().padLeft(3, '0')}";
  }

  static Future<void> postTokenToApi(
      String username, String email, String fcmToken, String uniqueId) async {
    await Handler.updateFirebaseToken(username, email, fcmToken, uniqueId);
  }

  Future<void> _onPageFinished(String url) async {
    // Guard: skip if widget disposed or controller not ready
    if (!mounted || !WebViewService().isReady || !_webViewReady) return;

    await Future.delayed(const Duration(milliseconds: 500));

    // Guard again after delay
    if (!mounted || !WebViewService().isReady) return;

    await WebViewService().runJS("""
      (function() {
        if(document.querySelector('meta[name="viewport"]')) {
          document.querySelector('meta[name="viewport"]').setAttribute('content', 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no');
        } else {
          var meta = document.createElement('meta');
          meta.name = 'viewport';
          meta.content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no';
          document.head.appendChild(meta);
        }

        if(window.localStorage) {
          var uniqueId = localStorage.getItem('uniqueId');
          if (uniqueId) {
            window.flutter_inappwebview.callHandler('FlutterWebView', uniqueId);
          }
        }
      })();
    """);

    if (mounted) {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _launchURL(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      debugPrint("❌ Could not launch $url");
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.paused) {
      // App went to background — could be camera/file picker opening
      _isPickerActive = true;
    }

    if (state == AppLifecycleState.resumed) {
      final controller = WebViewService().controller;

      if (controller != null) {
        try {
          await controller.reload();
        } catch (e) {
          debugPrint("WebView reload failed: $e");
        }
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    isChatScreen = false;
    _webViewReady = false;
    _subscription.cancel();
    WebViewService().clear(); // clear stale controller reference
    super.dispose();
  }


  Future<void> _openCamera(String facing) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: facing == 'front'
            ? CameraDevice.front
            : CameraDevice.rear,
        imageQuality: 80,
      );

      if (image != null) {
        await _sendImageToWebView(image);
      }
    } catch (e) {
      webViewController?.evaluateJavascript(
        source: "receiveError('${e.toString().replaceAll("'", "\\'")}');",
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final isConnected = _connectionStatus != ConnectivityResult.none;

    if (url.isEmpty) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: backgroundColor ?? Colors.white,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(50),
        child: AppBar(
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_ios_outlined,
              size: 18,
              color: appBarBackButtonColor ?? Colors.blue,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            appBarTitle,
            style: TextStyle(
                color: appBarTitleColor ?? Colors.white, fontSize: 18),
          ),
          centerTitle: true,
          backgroundColor: appBarBackgroundColor ?? Colors.white,
        ),
      ),
      body: isConnected
          ? Stack(
              children: [
                InAppWebView(
                  initialUrlRequest:
                      URLRequest(url: WebUri.uri(Uri.parse(url))),
                  initialSettings: InAppWebViewSettings(
                    useOnLoadResource: true,
                    clearCache: true,
                    cacheEnabled: false,
                    cacheMode: CacheMode.LOAD_NO_CACHE,
                    // Camera & media fixes
                    mediaPlaybackRequiresUserGesture: false,
                    allowsInlineMediaPlayback: true,
                    allowFileAccessFromFileURLs: true,
                    allowUniversalAccessFromFileURLs: true,
                       useHybridComposition: true,
          javaScriptEnabled: true,
                  ),
                  // Grant camera/mic/storage permissions requested by the web page
                  onPermissionRequest: (controller, request) async {
                    return PermissionResponse(
                      resources: request.resources,
                      action: PermissionResponseAction.GRANT,
                    );
                  },
                  onJsAlert: (controller, jsAlertRequest) async {
                    return JsAlertResponse(handledByClient: true);
                  },
                  onWebViewCreated: (controller) {
                    WebViewService().controller = controller;
                    _webViewReady = true;

                    // Handle front/back camera
          controller.addJavaScriptHandler(
            handlerName: 'openCamera',
            callback: (args) async {
              final facing = args.isNotEmpty ? args[0].toString() : 'back';
              await _openCamera(facing);
            },
          );

                    controller.addJavaScriptHandler(
                      handlerName: 'FlutterWebView',
                      callback: (args) {
                        if (args.isEmpty) return;
                        String uniqueId = args.first;
                        if (uniqueId.isNotEmpty) {
                          postTokenToApi(userName, email, fcmToken, uniqueId);
                        } else {
                          uniqueId = generateUniqueId();
                          postTokenToApi(userName, email, fcmToken, uniqueId);
                        }
                      },
                    );
                  },
                  shouldOverrideUrlLoading:
                      (controller, navigationAction) async {
                    final uri = navigationAction.request.url;
                    if (uri != null && !uri.toString().contains(url)) {
                      _launchURL(uri.toString());
                      return NavigationActionPolicy.CANCEL;
                    }
                    return NavigationActionPolicy.ALLOW;
                  },
                  onLoadStop: (controller, url) async {
                    await _onPageFinished(url.toString());
                  },
                ),
                if (isLoading)
                  Container(
                    color: Colors.white,
                    child: Center(
                      child: CircularProgressIndicator(
                        color: appBarBackgroundColor ?? Colors.blue,
                      ),
                    ),
                  ),
              ],
            )
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

class QuickChat {
  static void init(
    BuildContext context, {
    String widgetCode = '',
    Color backgroundColor = Colors.white,
    String appBarTitle = 'Chat With Us',
    Color appBarBackgroundColor = Colors.blueAccent,
    Color appBarTitleColor = Colors.white,
    Color appBarBackButtonColor = Colors.white,
  }) async {
    debugPrint("Quick chat ---------- start chat");
    PreferencesManager preferencesManager = PreferencesManager();

    await preferencesManager.savePreferences(
      widgetCode: widgetCode,
      backgroundColor: backgroundColor,
      appBarTitle: appBarTitle,
      appBarBackgroundColor: appBarBackgroundColor,
      appBarTitleColor: appBarTitleColor,
      appBarBackButtonColor: appBarBackButtonColor,
    );
  }

  static Widget get screen => const QuickChatWidget();

  static void handleNotificationOnClick(BuildContext context) async {
    debugPrint("Quick chat ---------- handleNotificationOnClick ");
    Handler.handleNotificationClick(context);
  }

  static void initializeNotification(BuildContext context) async {
    await Handler.initNotification(context);
  }

  static void showQuickChatNotification(Map<String, dynamic> data) {
    debugPrint("Quick chat ---------- showQuickChatNotification ");
    if (isChatScreen) return;
    Handler.showQuickChatNotification(data);
  }

  static void setFcmToken(String? fcmToken) async {
    PreferencesManager preferencesManager = PreferencesManager();
    await preferencesManager.saveFcmToken(fcmToken: fcmToken ?? '');
  }

  static void setUserName(String? username) async {
    PreferencesManager preferencesManager = PreferencesManager();
    await preferencesManager.setUserName(username: username ?? '');
  }

  static void setEmail(String? email) async {
    PreferencesManager preferencesManager = PreferencesManager();
    await preferencesManager.setEmail(email: email ?? '');
  }

  static bool isQuickChatNotification(Map<String, dynamic> data) {
    debugPrint("Quick chat ----------is quick chat notification");
    final clickAction = data['click_action'];
    if (clickAction == null || clickAction.isEmpty) return false;
    return clickAction == 'QUICK_CHAT_NOTIFICATION';
  }

  static Future<void> resetUser() async {
    PreferencesManager preferencesManager = PreferencesManager();
    preferencesManager.clearAllPreferences();
    preferencesManager.setLocalStorageResetFlag(reset: true);
    await Handler.updateFirebaseToken('', '', '', '');
    debugPrint("Quick chat ----------reset user");
  }
}

class WebViewService {
  static final WebViewService _instance = WebViewService._internal();
  factory WebViewService() => _instance;
  WebViewService._internal();

  InAppWebViewController? _controller;

  /// Returns the controller. Use [isReady] before accessing.
  InAppWebViewController? get controller => _controller;

  set controller(InAppWebViewController? c) => _controller = c;

  /// True only when the WebView has been created and is ready.
  bool get isReady => _controller != null;

  /// Clears the controller reference (call on dispose).
  void clear() {
    _controller = null;
  }

  /// Safely runs JavaScript. Silently skips if controller is not ready.
  Future<void> runJS(String js) async {
    if (_controller == null) {
      debugPrint("⚠️ JS skipped: WebView controller not ready");
      return;
    }
    try {
      await _controller!.evaluateJavascript(source: js);
    } catch (e) {
      debugPrint("❌ JS execution error: $e");
    }
  }

  /// Safely clears localStorage inside the WebView.
  Future<void> clearLocalStorage() async {
    if (_controller == null) {
      debugPrint("⚠️ clearLocalStorage skipped: controller not ready");
      return;
    }
    try {
      await _controller!.evaluateJavascript(source: "localStorage.clear();");
    } catch (e) {
      debugPrint("❌ clearLocalStorage error: $e");
    }
  }
}
