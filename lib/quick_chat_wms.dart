import 'package:flutter/material.dart';
import 'package:quick_chat_wms/models/prefrence_model.dart';
import 'package:quick_chat_wms/services/app_preference_service.dart';
import 'package:quick_chat_wms/services/notification_service.dart';
import 'package:quick_chat_wms/services/secure_storage_service.dart';
import 'package:quick_chat_wms/services/webview_service.dart';
import 'package:quick_chat_wms/widget/quick_chat_widget.dart';

bool isChatScreen = false;

class QuickChatWms {
  static final AppPreferencesService _prefsService = AppPreferencesService(
    secureStorageService: SecureStorageService(),
  );

  /// Optional hook fired when the chat WebView fails to load its page (server
  /// error status or transport failure). Set it during app init to forward the
  /// failure — status code and url, no user content — to crash/analytics
  /// logging, so failures on customer devices are diagnosable in the field.
  static QuickChatLoadErrorCallback? onChatLoadError;

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

    // Re-register the token with `store-firebase-token` directly. Previously
    // this ONLY happened from inside the chat WebView (on load), so a refreshed
    // token was never sent unless the user reopened the chat. If we already
    // know this client's uniqueId (captured on a prior chat open), push the new
    // token now — including from the dashboard / on token refresh.
    final String token = fcmToken ?? '';
    if (token.isEmpty) return;
    final String uniqueId =
        await SecureStorageService().read(key: 'qc_client_unique_id') ?? '';
    if (uniqueId.isEmpty) return;
    final prefs = await _prefsService.getPreferences();
    await NotificationHandlerService.updateFirebaseToken(
      prefs.userName,
      prefs.email,
      token,
      uniqueId,
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

  /// Ends the logged-in user's chat session while KEEPING the widget
  /// configuration, so the chat still works for an anonymous (logged-out) user.
  ///
  /// Use this on logout instead of [resetUser]: that one wipes everything —
  /// including the widget code — which leaves the WebView loading a blank
  /// `widgetId=`. That's fine when a fresh [init] follows immediately (a user
  /// switch), but wrong on logout, where the floating chat must keep working.
  ///
  /// The identity is dropped and the WebView's stored client id is marked for
  /// deletion, so the next chat starts as a brand-new conversation with a new
  /// `client_unique_id` — the logged-out user cannot see the previous user's
  /// history. Logging back in re-fetches the real id via `get-unique-id` and
  /// restores that conversation.
  static Future<void> logout() async {
    debugPrint("Quick chat ---------- logout");

    // Deregister push for the user who just logged out.
    await NotificationHandlerService.updateFirebaseToken('', '', '', '');

    await SecureStorageService().delete(key: 'qc_client_unique_id');
    // Force the next login to re-fetch its history instead of trusting the
    // localStorage we're about to wipe.
    await SecureStorageService().delete(key: kRestoredUserKey);
    await _prefsService.updatePreferences(
      data: (current) => current.copyWith(
        userName: '',
        email: '',
        // Consumed by QuickChatWidget on its next mount: wipes the WebView's
        // localStorage so the page mints a fresh client_unique_id.
        resetLocalStorage: true,
      ),
    );
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
