import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:quick_chat_wms/models/prefrence_model.dart';
import 'package:quick_chat_wms/services/app_preference_service.dart';
import 'package:quick_chat_wms/services/permission_service.dart';
import 'package:quick_chat_wms/services/secure_storage_service.dart';
import 'package:quick_chat_wms/services/webview_service.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:permission_handler/permission_handler.dart';

// Assuming these are your paths based on our previous discussions
// import 'package:quick_chat_wms/services/app_preferences_service.dart';
// import 'package:quick_chat_wms/services/permission_service.dart';
// import 'package:quick_chat_wms/services/quick_chat_webview_service.dart';
// import 'package:quick_chat_wms/models/app_preferences.dart';

class QuickChatWidget extends StatefulWidget {
  const QuickChatWidget({super.key});

  @override
  State<QuickChatWidget> createState() => QuickChatWidgetState();
}

class QuickChatWidgetState extends State<QuickChatWidget>
    with WidgetsBindingObserver, AutomaticKeepAliveClientMixin {
  // Services
  final _permissionService = PermissionService();
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

  String _url = '';
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
    _prefs = await _prefsService.getPreferences();

    // Check reset flag logic
    if (_prefs.resetLocalStorage) {
      await _prefsService.clearAllPreferences();
      await _prefsService.updatePreferences(
        data: (currentData) => AppPreferences(),
      );
    }

    final hasPerms = await _permissionService.checkAndRequestPermissions();

    if (!mounted) return;

    setState(() {
      _hasPermissions = hasPerms;
      _isCheckingPermissions = false;

      _url =
          'https://app.quickconnect.biz/chat-sdk-script/mobileChat.html?widgetId=${_prefs.widgetCode}';
    });

    if (_hasPermissions) {
      _initializeWebView();
    }
  }

  void _initializeWebView() {
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
    );

    if (mounted) {
      setState(() => _isControllerInitialized = true);
    }
  }

  Future<void> _checkConnectivity() async {
    final result = await Connectivity().checkConnectivity();
    if (mounted) setState(() => _connectionStatus = result);
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

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_isCheckingPermissions) {
      return Scaffold(
        backgroundColor: _prefs.backgroundColor,
        body: Center(
          child: CircularProgressIndicator(color: _prefs.appBarBackgroundColor),
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
          ? Stack(
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
                if (_isLoading || !_isControllerInitialized)
                  Container(
                    color: _prefs.backgroundColor,
                    child: Center(
                      child: CircularProgressIndicator(
                        color: _prefs.appBarBackgroundColor,
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
