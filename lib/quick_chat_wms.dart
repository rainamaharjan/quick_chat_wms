library quick_chat_wms;

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart'
as webview_flutter_android;

class QuickChat extends StatefulWidget {
  final String? url;

  QuickChat({
    super.key,
    this.url,
  });

  @override
  State<QuickChat> createState() => QuickChatState();
}

class QuickChatState extends State<QuickChat> {
  late final WebViewController _controller;
  WebViewController? _externalController;

  @override
  void initState() {
    super.initState();
    _initializeController();
  }

  /// Initializes the WebViewController with initial configurations
  void _initializeController() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..enableZoom(false)
      ..addJavaScriptChannel(
        'FlutterWebView',
        onMessageReceived: (JavaScriptMessage message) {
          if (message.message == "pickFile") {
            pickFile();
          }
        },
      )
      ..setNavigationDelegate(_createNavigationDelegate())
      ..loadRequest(Uri.parse(widget.url ?? ''));

    _configureFilePicker(_controller);
  }

  Future<void> pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    if (result != null) {
      File file = File(result.files.single.path!);
    }
  }

  /// Creates a NavigationDelegate for the WebView
  NavigationDelegate _createNavigationDelegate() {
    return NavigationDelegate(
      onNavigationRequest: _handleNavigationRequest,
      onPageFinished: _onPageFinished,
    );
  }

  /// Handles navigation requests within the WebView
  Future<NavigationDecision> _handleNavigationRequest(
      NavigationRequest request) async {
    if (!request.url.contains(widget.url ?? '')) {
      _showExternalWebView(request.url);
      return NavigationDecision.prevent;
    }
    return NavigationDecision.navigate;
  }

  /// Called when the page has finished loading
  Future<void> _onPageFinished(String url) async {
    _controller.runJavaScript("console.log('JavaScript injected');"
        "if(document.querySelector('meta[name=\"viewport\"]')) { "
        "document.querySelector('meta[name=\"viewport\"]').setAttribute('content', 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no');"
        "} else { "
        "var meta = document.createElement('meta');"
        "meta.name = 'viewport';"
        "meta.content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no';"
        "document.head.appendChild(meta);"
        "}");
  }

  /// Configures the file picker for Android
  Future<void> _configureFilePicker(WebViewController controller) async {
    if (Platform.isAndroid) {
      final androidController = controller.platform
      as webview_flutter_android.AndroidWebViewController;
      await androidController.setOnShowFileSelector(_androidFilePicker);
    }
  }

  /// Handles file selection on Android
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
      print('Error picking file: $e');
    }

    return [];
  }

  /// Determines the file type based on MIME types
  FileType _determineFileType(List<String> acceptTypes) {
    for (var accept in acceptTypes) {
      if (accept.contains('*')) return FileType.custom;
    }
    return FileType.any;
  }

  /// Extracts allowed file extensions based on MIME types
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

  /// Displays an external WebView when the URL is outside the widgetUrl
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

  /// Builds the AppBar for the external WebView
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