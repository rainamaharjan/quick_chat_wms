import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter/foundation.dart';

class WebViewService {
  static final WebViewService _instance = WebViewService._internal();

  factory WebViewService() => _instance;

  WebViewService._internal();

  WebViewController? _controller;

  set controller(WebViewController controller) {
    _controller ??= controller;
  }

  void clearController() {
    _controller = null;
  }

  Future<void> clearLocalStorage() async {
    try {
      await _controller!.runJavaScript("localStorage.clear();");
      await _controller!.reload();
      debugPrint("✅ localStorage cleared and WebView reloaded.");
    } catch (e) {
      debugPrint("❌ Error clearing localStorage: $e");
    }
  }

  Future<void> runJS(String js) async {
    if (_controller == null) return;
    try {
      await _controller!.runJavaScript(js);
    } catch (e) {
      debugPrint("❌ JS execution error: $e");
    }
  }

  WebViewController get controller {
    assert(_controller != null, 'WebViewController not initialized yet');
    return _controller!;
  }
}
