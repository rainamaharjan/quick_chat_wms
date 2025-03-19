import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:quick_chat_wms/preference_manager.dart';
import 'package:quick_chat_wms/url_launcher_helper.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart'
as webview_flutter_android;
import 'handler.dart';

WebViewController? _controller;

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

class QuickChatWidgetState extends State<QuickChatWidget> with WidgetsBindingObserver {
  String url = '';
  bool isLoading = true;
  bool isFilePicking = false;
  bool isWebViewActive = false;
  @override
  void initState() {
    super.initState();
    url =
    "https://wms-uat.worldlink.com.np/chat-sdk-script/mobileChat.html?widgetId=${widget.widgetCode}";
    _initializeController();
    WidgetsBinding.instance.addObserver(this);
  }

  void _initializeController() async {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..enableZoom(false)
      ..addJavaScriptChannel(
        'FlutterWebView',
        onMessageReceived: (JavaScriptMessage message) {
          String uniqueId = message.message;
          debugPrint("Received Unique ID: $uniqueId");
          if (uniqueId != null || uniqueId.isNotEmpty) {
            postTokenToApi(uniqueId);
          } else {
            uniqueId = generateUniqueId();
            postTokenToApi(uniqueId);
          }
        },
      )
      ..setNavigationDelegate(_createNavigationDelegate())
      ..loadRequest(Uri.parse(url));
    await _configureFilePicker();
  }

  String generateUniqueId() {
    DateTime now = DateTime.now();
    return "${now.year}${now.month.toString().padLeft(2, '0')}"
        "${now.day.toString().padLeft(2, '0')}${now.hour.toString().padLeft(2, '0')}"
        "${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}"
        "${now.millisecond.toString().padLeft(3, '0')}";
  }

  static Future<void> postTokenToApi(String uniqueId) async {
    Handler.updateFirebaseToken(uniqueId);
  }

  NavigationDelegate _createNavigationDelegate() {
    return NavigationDelegate(
      onPageStarted: _onPageStarted,
      onNavigationRequest: _handleNavigationRequest,
      onPageFinished: _onPageFinished,
    );
  }

  Future<NavigationDecision> _handleNavigationRequest(
      NavigationRequest request) async {
    if (request.url.contains('google.com')) {
      print('Navigating externally to: ${request.url}');
      return NavigationDecision.prevent; // Prevent in-app navigation
    }

    if (!request.url.contains(url)) {
      _showExternalWebView(request.url);
      return NavigationDecision.prevent;
    }
    return NavigationDecision.navigate;
  }

  Future<void> _onPageStarted(String url) async {
    if (mounted) {
      setState(() {
        isLoading = true;
        isWebViewActive = true;
      });
    }
  }

  Future<void> _onPageFinished(String url) async {
    _controller?.runJavaScript("console.log('JavaScript injected');"
        "if(document.querySelector('meta[name=\"viewport\"]')) { "
        "document.querySelector('meta[name=\"viewport\"]').setAttribute('content', 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no');"
        "} else { "
        "var meta = document.createElement('meta');"
        "meta.name = 'viewport';"
        "meta.content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no';"
        "document.head.appendChild(meta);"
        "}"
        "if(window.localStorage) {"
        "  var uniqueId = localStorage.getItem('uniqueId');"
        "  if (uniqueId) {"
        "    FlutterWebView.postMessage(uniqueId);"
        "  }"
        "}");

    if (mounted) {
      setState(() {
        isLoading = false;
        isWebViewActive = false;
      });
    }
  }

  Future<void> _configureFilePicker() async {
    if (Platform.isAndroid) {
      final androidController = _controller?.platform
      as webview_flutter_android.AndroidWebViewController;
      await androidController.setOnShowFileSelector(_androidFilePicker);
    }
  }

  Future<List<String>> _androidFilePicker(
      webview_flutter_android.FileSelectorParams params) async {
    try {
      await Handler.requestStoragePermission();
      setState(() {
        isFilePicking = true;
      });

      final fileType = _determineFileType(params.acceptTypes);
      final allowedExtensions = _extractAllowedExtensions(params.acceptTypes);

      var result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: fileType,
        allowedExtensions: allowedExtensions?.isNotEmpty == true
            ? allowedExtensions?.toSet().toList()
            : null, // Prevents empty extension list crash
      );

      if (result != null && result.files.isNotEmpty) {
        return result.files
            .map((file) => Uri.file(file.path!).toString()) // Ensures non-null path
            .toList();
      }
      setState(() {
        isFilePicking = false;
      });
    } catch (e) {
      setState(() {
        isFilePicking = false;
      });
      debugPrint('Quick Chat -------- Error picking file: $e');
    }

    return [];
  }

  FileType _determineFileType(List<String> acceptTypes) {
    if (acceptTypes.contains('image/*')) return FileType.image;
    if (acceptTypes.contains('application/pdf')) return FileType.custom;
    return FileType.any;
  }

  List<String>? _extractAllowedExtensions(List<String> acceptTypes) {
    final extensions = <String>[];
    for (var accept in acceptTypes) {
      for (var mime in accept.split(',')) {
        switch (mime.trim()) {
          case 'image/*':
            extensions.addAll(['jpg', 'jpeg', 'png', 'gif']);
            break;
          case 'application/pdf':
            extensions.add('pdf');
            break;
          case 'application/msword':
          case 'application/vnd.openxmlformats-officedocument.wordprocessingml.document':
            extensions.addAll(['doc', 'docx']);
            break;
          default:
            break;
        }
      }
    }

    return extensions.isNotEmpty ? extensions : null;
  }

  void _showExternalWebView(String url) {
    Uri uri = Uri.parse(url);
    if (uri.scheme != 'https' && uri.scheme != 'http') {
      return;
    }
    URLLauncherHelper.launchURL(url);
  }

  Future<bool> _onBackPressed(BuildContext context) async {
    if (isFilePicking) {
      setState(() {
        isFilePicking = false;
      });
      return false;
    } else if (await _controller!.canGoBack()) {
      _controller?.goBack();
      return false;
    } else {
      Navigator.pop(context);
      return false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (!isFilePicking) {
        _controller?.reload();
      }
      isFilePicking = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.clearCache();
    _controller = null; // Reset controller to avoid using disposed instance
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        return await _onBackPressed(context);
      },
      child: Scaffold(
        backgroundColor: widget.backgroundColor,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(50), // Increased height
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
        body: Stack(
          children: [
            WebViewWidget(controller: _controller!),
            if (isLoading)
              Center(
                child: CircularProgressIndicator(
                  color: widget.appBarBackgroundColor,
                ),
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
        Color backgroundColor = Colors.white, // Default background color
        String appBarTitle = 'Chat With Us', // Default app bar title
        Color appBarBackgroundColor = Colors.blueAccent, // Default background color
        Color appBarTitleColor = Colors.white, // Default title color
        Color appBarBackButtonColor = Colors.white, // Default back button color
      }) async {
    print("Quick chat ---------- start chat");
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

  static void handleNotificationOnClick(BuildContext context) {
    Handler.handleNotificationClick(context);
  }

  static void setFcmToken(String? fcmToken) async {
    PreferencesManager preferencesManager = PreferencesManager();
    await preferencesManager.saveFcmToken(fcmToken: fcmToken ?? '');
  }

  static bool isQuickChatNotification(Map<String, dynamic> data) {
    String clickAction = data['click_action'];
    if (clickAction == 'QUICK_CHAT_NOTIFICATION') {
      return true;
    } else {
      return false;
    }
  }

  static Future<void> resetUser() async {
    print("Quick chat ----------reset user");
    PreferencesManager preferencesManager = PreferencesManager();
    await Handler.updateFirebaseToken('');
    await preferencesManager.saveFcmToken(fcmToken: '');
    await preferencesManager.savePreferences(
        widgetCode: '',
        backgroundColor: Colors.blue,
        appBarTitle: 'appBarTitle',
        appBarBackgroundColor: Colors.blue,
        appBarTitleColor: Colors.white,
        appBarBackButtonColor: Colors.white);
    try {
      if (_controller != null) {
        await _controller!.runJavaScript("localStorage.clear();");
        await _controller!.reload();
      }
    } catch (e) {
      debugPrint("-------no local storage --------");
    }
  }
}