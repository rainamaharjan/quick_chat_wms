import 'package:flutter/material.dart';
import 'package:quick_chat_wms/services/app_preference_service.dart';
import 'package:quick_chat_wms/services/notification_service.dart';
import 'package:quick_chat_wms/services/secure_storage_service.dart';
import 'package:quick_chat_wms/widget/quick_chat_widget.dart';

bool isChatScreen = false;

class QuickChatWms {
  // Create a single static instance of the service to be used across all methods
  static final AppPreferencesService _prefsService = AppPreferencesService(
    secureStorageService: SecureStorageService(),
  );

  static final NotificationHandlerService _notificationService =
      NotificationHandlerService(prefsService: _prefsService);

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

    await _prefsService.updatePreferences(
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
    await _notificationService.handleNotificationClick(context);
  }

  static void initializeNotification(BuildContext context) async {
    await _notificationService.initNotification(context);
  }

  static void showQuickChatNotification(Map<String, dynamic> data) {
    debugPrint("Quick chat ---------- showQuickChatNotification ");
    if (isChatScreen) {
      return;
    }
    _notificationService.showQuickChatNotification(data);
  }

  static void setFcmToken(String? fcmToken) async {
    await _prefsService.updatePreferences(fcmToken: fcmToken ?? '');
  }

  static void setUserName(String? username) async {
    await _prefsService.updatePreferences(userName: username ?? '');
  }

  static void setEmail(String? email) async {
    await _prefsService.updatePreferences(email: email ?? '');
  }

  static bool isQuickChatNotification(Map<String, dynamic> data) {
    debugPrint("Quick chat ----------is quick chat notification");
    String? clickAction = data['click_action'];
    if (clickAction == null || clickAction.isEmpty) {
      return false;
    }

    return clickAction == 'QUICK_CHAT_NOTIFICATION';
  }

  static Future<void> resetUser() async {
    // 1. Clear everything from secure storage
    await _prefsService.clearAllPreferences();

    // 2. Setting the flag will automatically recreate the JSON string
    // with default Freezed values + the true flag.
    await _prefsService.updatePreferences(resetLocalStorage: true);

    await NotificationHandlerService.updateFirebaseToken('', '', '', '');
    debugPrint("Quick chat ----------reset user");
  }
}
