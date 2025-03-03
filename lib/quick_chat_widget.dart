import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart'
    as webview_flutter_android;
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

late WebViewController _controller;

class QuickChatWidget extends StatefulWidget {
  final String id;

  const QuickChatWidget({super.key, required this.id});

  @override
  State<QuickChatWidget> createState() => QuickChatWidgetState();
}

class QuickChatWidgetState extends State<QuickChatWidget> {
  WebViewController? _externalController;
  String url = '';

  @override
  void initState() {
    super.initState();
    url = "https://app.quickconnect.biz/mobile-widget?widged_id=${widget.id}";
    NotificationHandler.initialize();
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
          //hit api with firebase token and unique id
          // saveUniqueId(uniqueId);
          if (message.message == "pickFile") {
            pickFile();
          }
        },
      )
      ..setNavigationDelegate(_createNavigationDelegate())
      ..loadRequest(Uri.parse(url ?? ''));
    _configureFilePicker(_controller);
  }

  Future<void> pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    if (result != null) {
      File file = File(result.files.single.path!);
      debugPrint('File picked: ${file.path}');
    } else {
      debugPrint("File pick cancelled");
    }
  }

  NavigationDelegate _createNavigationDelegate() {
    return NavigationDelegate(
      onNavigationRequest: _handleNavigationRequest,
      onPageFinished: _onPageFinished,
    );
  }

  Future<NavigationDecision> _handleNavigationRequest(
      NavigationRequest request) async {
    if (!request.url.contains(url ?? '')) {
      _showExternalWebView(request.url);
      return NavigationDecision.prevent;
    }
    return NavigationDecision.navigate;
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
      debugPrint('Error picking file: $e');
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
    return WebViewWidget(controller: _controller);
  }
}

class QuickChat {
  static Future<void> resetUser() async {
    await _controller.runJavaScript("""
      localStorage.clear();
      console.log('LocalStorage cleared');
    """);
    await _controller.reload();
    debugPrint("-------storage cleared--------");
  }
}

class NotificationHandler {
  static Future<void> initialize() async {
    requestPermission();

    await Firebase.initializeApp();
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null) {
        String title = message.notification?.title ?? '';
        String body = message.notification?.body ?? '';
        _sendNotificationToWebView(title, body);
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      if (message.notification != null) {
        String title = message.notification?.title ?? '';
        String body = message.notification?.body ?? '';
        _sendNotificationToWebView(title, body);
      }
    });
  }

  static void _sendNotificationToWebView(String title, String body) {
    if (_controller != null) {
      _controller.runJavaScript('handleNotification("$title", "$body");');
    }
  }
}

void requestPermission() async {
  FirebaseMessaging messaging = FirebaseMessaging.instance;
  NotificationSettings settings = await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  if (settings.authorizationStatus == AuthorizationStatus.authorized) {
    debugPrint("User granted permission");
  } else {
    debugPrint("User declined or has not accepted permission");
  }
}
