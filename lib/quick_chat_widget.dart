import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:quick_chat_wms/preference_manager.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart'
    as webview_flutter_android;
import 'notification_handler.dart';

late WebViewController _controller;

class QuickChatWidget extends StatefulWidget {
  final String widgetCode;
  final String fcmServerKey;
  final String appBarTitle;
  final Color appBarTitleColor;
  final Color appBarBackgroundColor;
  final Color backgroundColor;
  final Color appBarBackButtonColor;

  const QuickChatWidget({
    super.key,
    required this.widgetCode,
    required this.fcmServerKey,
    required this.appBarTitle,
    required this.appBarTitleColor,
    required this.backgroundColor,
    required this.appBarBackgroundColor,
    required this.appBarBackButtonColor,
  });

  @override
  State<QuickChatWidget> createState() => QuickChatWidgetState();
}

class QuickChatWidgetState extends State<QuickChatWidget> {
  WebViewController? _externalController;
  String url = '';
  bool isLoading = true;
  static String fcmServerKey = '';

  @override
  void initState() {
    super.initState();
    url =
        "http://wms-srm-m02.wlink.com.np:3013/mobileChat.html?widgetId=${widget.widgetCode}";
    fcmServerKey = widget.fcmServerKey;
    _initializeController();
  }

  void _initializeController() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..enableZoom(false)
      ..addJavaScriptChannel(
        'FlutterWebView',
        onMessageReceived: (JavaScriptMessage message) {
          String uniqueId = message.message;
          debugPrint("Received Unique ID: $uniqueId");
          if (uniqueId.isNotEmpty) {
            postTokenToApi(uniqueId);
          } else {
            uniqueId = generateUniqueId();
            postTokenToApi(uniqueId);
          }
          if (message.message == "pickFile") {
            pickFile();
          }
        },
      )
      ..setNavigationDelegate(_createNavigationDelegate())
      ..loadRequest(Uri.parse(url));
    _configureFilePicker(_controller);
  }

  String generateUniqueId() {
    DateTime now = DateTime.now();
    return "${now.year}${now.month.toString().padLeft(2, '0')}"
        "${now.day.toString().padLeft(2, '0')}${now.hour.toString().padLeft(2, '0')}"
        "${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}"
        "${now.millisecond.toString().padLeft(3, '0')}";
  }

  static Future<void> postTokenToApi(String uniqueId) async {
    await FirebaseMessaging.instance.getToken().then((token) async {
      await NotificationHandler.updateFirebaseToken(
          token ?? '', uniqueId, fcmServerKey);
    });
  }

  Future<void> pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    if (result != null) {
      File file = File(result.files.single.path!);
      debugPrint('Quick Chat -------- File picked: ${file.path}');
    } else {
      debugPrint("Quick Chat -------- File pick cancelled");
    }
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
    if (!request.url.contains(url)) {
      _showExternalWebView(request.url);
      return NavigationDecision.prevent;
    }
    return NavigationDecision.navigate;
  }

  Future<void> _onPageStarted(String url) async {
    setState(() {
      isLoading = true; // Show loading spinner when page starts loading
    });
  }

  Future<void> _onPageFinished(String url) async {
    _controller.runJavaScript("console.log('JavaScript injected');"
        "if(document.querySelector('meta[name=\"viewport\"]')) { "
        "document.querySelector('meta[name=\"viewport\"]').setAttribute('content', 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no');"
        "} else { "
        "var meta = document.createElement('meta');"
        "meta.name = 'viewport';"
        "meta.content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no';"
        "document.head.appendChild(meta);"
        "}"

        // Inject JavaScript to capture unique ID
        "if(window.localStorage) {"
        "  var uniqueId = localStorage.getItem('uniqueId');"
        "  if (uniqueId) {"
        "    FlutterWebView.postMessage(uniqueId);"
        "  }"
        "}");

    setState(() {
      isLoading = false; // Hide loading spinner when page finishes loading
    });
  }

  Future<void> _configureFilePicker(WebViewController controller) async {
    if (Platform.isAndroid) {
      final androidController = controller.platform
          as webview_flutter_android.AndroidWebViewController;
      await androidController.setOnShowFileSelector(_androidFilePicker);
    }
  }

  Future<List<String>> _androidFilePicker(
      webview_flutter_android.FileSelectorParams params) async {
    final fileType = _determineFileType(params.acceptTypes);
    final allowedExtensions = _extractAllowedExtensions(params.acceptTypes);

    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: fileType,
        allowedExtensions: allowedExtensions?.toSet().toList(),
      );

      if (result != null && result.paths.isNotEmpty) {
        return result.paths
            .whereType<String>()
            .map((path) => Uri.file(path).toString())
            .toList();
      }
    } catch (e) {
      debugPrint('Quick Chat -------- Error picking file: $e');
    }

    return [];
  }

  FileType _determineFileType(List<String> acceptTypes) {
    for (var accept in acceptTypes) {
      if (accept.contains('*')) return FileType.custom;
    }
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

    _externalController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(Uri.parse(url));

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog.fullscreen(
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(),
              Expanded(child: WebViewWidget(controller: _externalController!)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      color: Colors.grey[100],
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
          WebViewWidget(controller: _controller),
          if (isLoading)
            const Center(
              child: CircularProgressIndicator(
                color: Colors.blueGrey,
              ),
            ),
        ],
      ),
    );
  }
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

String? activeChatContactId; // Stores the current chat's contact ID

class QuickChat {
  static void init(
    BuildContext context, {
    String widgetCode = '',
    String fcmServerKey = '',
    Color backgroundColor = Colors.white, // Default background color
    String appBarTitle = 'Chat With Us', // Default app bar title
    Color appBarBackgroundColor = Colors.blueAccent, // Default background color
    Color appBarTitleColor = Colors.white, // Default title color
    Color appBarBackButtonColor = Colors.white, // Default back button color
  }) async {
    NotificationHandler.initialize(context);
    PreferencesManager preferencesManager = PreferencesManager();

    await preferencesManager.savePreferences(
      widgetCode: widgetCode,
      fcmServerKey: fcmServerKey,
      backgroundColor: backgroundColor,
      appBarTitle: appBarTitle,
      appBarBackgroundColor: appBarBackgroundColor,
      appBarTitleColor: appBarTitleColor,
      appBarBackButtonColor: appBarBackgroundColor,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => QuickChatWidget(
              widgetCode: widgetCode,
              fcmServerKey: fcmServerKey,
              appBarTitle: appBarTitle,
              appBarBackgroundColor: appBarBackgroundColor,
              appBarTitleColor: appBarTitleColor,
              appBarBackButtonColor: appBarBackButtonColor,
              backgroundColor: backgroundColor),
        ),
      );
    });
  }

  static Future<void> resetUser() async {
    await NotificationHandler.updateFirebaseToken('', '', '');
    await _controller.runJavaScript("""
      localStorage.clear();
      console.log('LocalStorage cleared');
    """);
    await _controller.reload();
    debugPrint("-------storage cleared--------");
  }
}
