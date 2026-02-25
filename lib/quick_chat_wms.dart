import 'package:flutter/material.dart';
import 'package:quick_chat_wms/models/prefrence_model.dart';
import 'package:quick_chat_wms/services/app_preference_service.dart';
import 'package:quick_chat_wms/services/notification_service.dart';
import 'package:quick_chat_wms/services/secure_storage_service.dart';
import 'package:quick_chat_wms/widget/quick_chat_widget.dart';

bool isChatScreen = false;

class QuickChatWms {
  static final AppPreferencesService _prefsService = AppPreferencesService(
    secureStorageService: SecureStorageService(),
  );

  static final NotificationHandlerService _notificationService =
      NotificationHandlerService(prefsService: _prefsService);

  // CHANGED: void -> Future<void>
  static Future<void> init(
    BuildContext context, {
    String widgetCode = '',
    Color backgroundColor = Colors.white,
    String appBarTitle = 'Chat With Us',
    Color appBarBackgroundColor = Colors.blueAccent,
    Color appBarTitleColor = Colors.white,
    Color appBarBackButtonColor = Colors.white,
  }) async {
    debugPrint("Quick chat ---------- start chat");

    await _prefsService.updatePreferences(
      data: (currentData) => currentData.copyWith(
        widgetCode: widgetCode,
        backgroundColor: backgroundColor,
        appBarTitle: appBarTitle,
        appBarBackgroundColor: appBarBackgroundColor,
        appBarTitleColor: appBarTitleColor,
        appBarBackButtonColor: appBarBackButtonColor,
      ),
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

  // CHANGED: void -> Future<void>
  static Future<void> setFcmToken(String? fcmToken) async {
    print('QUICKCHAT:::: FCM Update: $fcmToken');

    await _prefsService.updatePreferences(
      data: (current) => current.copyWith(fcmToken: fcmToken ?? ''),
    );
  }

  // CHANGED: void -> Future<void>
  static Future<void> setUserName(String? username) async {
    print('QUICKCHAT:::: UserName Update: $username');

    await _prefsService.updatePreferences(
      data: (currentData) => currentData.copyWith(userName: username ?? ''),
    );
  }

  // CHANGED: void -> Future<void>
  static Future<void> setEmail(String? email) async {
    print('QUICKCHAT:::: Email Update: $email');
    await _prefsService.updatePreferences(
      data: (currentData) => currentData.copyWith(email: email ?? ''),
    );
  }

  static bool isQuickChatNotification(Map<String, dynamic> data) {
    debugPrint("Quick chat ----------is quick chat notification");
    String? clickAction = data['click_action'];
    if (clickAction == null || clickAction.isEmpty) {
      return false;
    }

    return clickAction == 'QUICK_CHAT_NOTIFICATION';
  }

  // This was already Future<void>, which is correct!
  static Future<void> resetUser() async {


    await _prefsService.clearAllPreferences();
    await _prefsService.updatePreferences(
      data: (currentData) => AppPreferences(),
    );
    await NotificationHandlerService.updateFirebaseToken('', '', '', '');
    debugPrint("Quick chat ----------reset user");
  }
}
