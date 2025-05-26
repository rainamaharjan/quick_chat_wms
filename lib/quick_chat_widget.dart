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
  final String widgetCode;
  final String appBarTitle;
  final Color appBarTitleColor;
  final Color appBarBackgroundColor;
  final Color backgroundColor;
  final Color appBarBackButtonColor;

  const QuickChatWidget({
    super.key,
    required this.widgetCode,
    required this.appBarTitle,
    required this.appBarTitleColor,
    required this.backgroundColor,
    required this.appBarBackgroundColor,
    required this.appBarBackButtonColor,
  });

  @override
  State<QuickChatWidget> createState() => QuickChatWidgetState();
}

class QuickChatWidgetState extends State<QuickChatWidget>
    with WidgetsBindingObserver, AutomaticKeepAliveClientMixin {
  String url = '';
  bool isLoading = true;
  late StreamSubscription<ConnectivityResult> _subscription;
  ConnectivityResult _connectionStatus = ConnectivityResult.none;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    isLoading = true;
    _checkConnectivity();
    _subscription = Connectivity()
        .onConnectivityChanged
        .listen((ConnectivityResult result) {
      if (_connectionStatus == ConnectivityResult.none &&
          result != ConnectivityResult.none) {
        WebViewService().controller.reload();
      }
      setState(() {
        _connectionStatus = result;
      });
    });

    isChatScreen = true;
    url =
        'https://app.quickconnect.biz/chat-sdk-script/mobileChat.html?widgetId=${widget.widgetCode}';
    _initializeController();
  }

  String fcmToken = '';
  String email = '';
  String userName = '';

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
  }

  void checkAndResetLocalStorage() async {
    PreferencesManager preferencesManager = PreferencesManager();
    final shouldReset = await preferencesManager.getLocalStorageResetFlag();
    if (shouldReset) {
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
    await Future.delayed(const Duration(milliseconds: 500));
    WebViewService().runJS("""
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
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
        WebViewService().controller.reload();
      }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    isChatScreen = false;
    _subscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    bool isConnected = _connectionStatus != ConnectivityResult.none;
    return Scaffold(
      backgroundColor: widget.backgroundColor,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(50),
        child: AppBar(
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_ios_outlined,
              size: 18,
              color: widget.appBarBackButtonColor,
            ),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
          title: Text(
            widget.appBarTitle,
            style: TextStyle(color: widget.appBarTitleColor, fontSize: 18),
          ),
          centerTitle: true,
          backgroundColor: widget.appBarBackgroundColor,
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
                    useHybridComposition: true,
                    clearCache: true,
                    cacheEnabled: false,
                    cacheMode: CacheMode.LOAD_NO_CACHE,
                  ),
                  onWebViewCreated: (controller) {
                    WebViewService().controller = controller;
                    controller.addJavaScriptHandler(
                      handlerName: 'FlutterWebView',
                      callback: (args) {
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
                      color: widget.backgroundColor,
                    )),
                  ),
              ],
            )
          : Center(
              child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    "No internet connection"),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: _checkConnectivity,
                  child: const Text("Retry"),
                )
              ],
            )),
    );
  }
}

class QuickChat {
  static void init(
    BuildContext context, {
    String widgetCode = '',
    Color backgroundColor = Colors.white, // Default background color
    String appBarTitle = 'Chat With Us', // Default app bar title
    Color appBarBackgroundColor = Colors.blueAccent, // Default background color
    Color appBarTitleColor = Colors.white, // Default title color
    Color appBarBackButtonColor = Colors.white, // Default back button color
  }) async {
    debugPrint("Quick chat ---------- start chat");
    PreferencesManager preferencesManager = PreferencesManager();

    await preferencesManager.savePreferences(
      widgetCode: widgetCode,
      backgroundColor: backgroundColor,
      appBarTitle: appBarTitle,
      appBarBackgroundColor: appBarBackgroundColor,
      appBarTitleColor: appBarTitleColor,
      appBarBackButtonColor: appBarBackgroundColor,
    );
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => QuickChatWidget(
            widgetCode: widgetCode,
            appBarTitle: appBarTitle,
            appBarBackgroundColor: appBarBackgroundColor,
            appBarTitleColor: appBarTitleColor,
            appBarBackButtonColor: appBarBackButtonColor,
            backgroundColor: backgroundColor),
      ),
    );
  }

  static void handleNotificationOnClick(BuildContext context) async {
    debugPrint("Quick chat ---------- handleNotificationOnClick ");
    Handler.handleNotificationClick(context);
  }

  static void initializeNotification(BuildContext context) async {
    await Handler.initNotification(context);
  }

  static void showQuickChatNotification(Map<String, dynamic> data) {
    debugPrint("Quick chat ---------- showQuickChatNotification ");
    if (isChatScreen) {
      return;
    }
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
    String clickAction = data['click_action'];
    if(clickAction == null){
      return false;
    }
    if (clickAction == 'QUICK_CHAT_NOTIFICATION') {
      return true;
    } else {
      return false;
    }
  }

  static Future<void> resetUser() async {
    PreferencesManager preferencesManager = PreferencesManager();
    preferencesManager.clearAllPreferences();
    preferencesManager.setLocalStorageResetFlag(reset: true);
    await Handler.updateFirebaseToken('', '', '', '');
    debugPrint("Quick chat ----------reset user");
  }
}
