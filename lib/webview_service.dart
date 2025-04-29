import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class WebViewService {
  static final WebViewService _instance = WebViewService._internal();

  factory WebViewService() => _instance;

  WebViewService._internal();

  InAppWebViewController? _controller;
  set controller(InAppWebViewController controller) {
    _controller ??= controller;
  }

  void clearController() {
    _controller = null;
  }

  Future<void> clearLocalStorage() async {
    try {
      await _controller?.evaluateJavascript(source: "localStorage.clear();");
      await _controller?.reload();
      debugPrint("✅ localStorage cleared and WebView reloaded.");
    } catch (e) {
      debugPrint("❌ Error clearing localStorage: $e");
    }
  }

  Future<void> runJS(String js) async {
    if (_controller == null) return;
    try {
      await _controller?.evaluateJavascript(source: js);
    } catch (e) {
      debugPrint("❌ JS execution error: $e");
    }
  }

  InAppWebViewController get controller {
    assert(_controller != null, 'WebViewController not initialized yet');
    return _controller!;
  }
}
