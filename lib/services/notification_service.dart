import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:quick_chat_wms/quick_chat_wms.dart';
import 'package:quick_chat_wms/services/api_config.dart';
import 'package:quick_chat_wms/services/app_preference_service.dart';
import 'package:quick_chat_wms/services/secure_storage_service.dart';

class NotificationHandlerService {
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  final AppPreferencesService _prefsService;

  // Encapsulated state rather than static global variables
  final List<String> _messages = [];

  /// Inject the AppPreferencesService to fetch configurations on click
  NotificationHandlerService({required AppPreferencesService prefsService})
    : _prefsService = prefsService;

  /// Initialize the notification plugin
  Future<void> initNotification(BuildContext context) async {
    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );

    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        await handleNotificationClick(context);
      },
    );
  }

  /// Handles the tap action on the notification
  Future<void> handleNotificationClick(BuildContext context) async {
    _messages.clear();

    // Fetch the preferences using the new Freezed model
    final prefs = await _prefsService.getPreferences();

    // Use the strongly-typed properties from your Freezed class
    QuickChatWms.init(
      context,
      widgetCode: prefs.widgetCode,
      backgroundColor: prefs.backgroundColor,
      appBarTitle: prefs.appBarTitle,
      appBarBackgroundColor: prefs.appBarBackgroundColor,
      appBarTitleColor: prefs.appBarTitleColor,
      appBarBackButtonColor: prefs.appBarBackButtonColor,
    );
  }

  /// Displays the quick chat notification using InboxStyle
  Future<void> showQuickChatNotification(Map<String, dynamic> data) async {
    final title = data['title']?.toString() ?? '';
    final body = data['body']?.toString() ?? '';

    // Cancel existing notification with ID 0 to update it
    await _flutterLocalNotificationsPlugin.cancel(0);

    // Prevent duplicate messages in the inbox style
    if (!_messages.contains(body)) {
      _messages.add(body);
    }

    final inboxStyle = InboxStyleInformation(
      _messages,
      contentTitle: title,
      summaryText: "Tap to open chat",
    );

    final androidDetails = AndroidNotificationDetails(
      'chat_channel',
      'Chat Notifications',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      styleInformation: inboxStyle,
      onlyAlertOnce: true,
      setAsGroupSummary: true,
      groupKey: 'notification_group_key',
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: const DarwinNotificationDetails(),
    );

    await _flutterLocalNotificationsPlugin.show(
      0,
      title,
      body,
      notificationDetails,
    );
  }

  /// Optional: Helper to clear message history manually if needed
  void clearMessages() {
    _messages.clear();
  }

  /// What the last successful `store-firebase-token` registered (user, email,
  /// FCM token, client id, mobile), so a logged-in user is registered once per
  /// login / account switch / token rotation instead of on every app start and
  /// every chat open. Cleared by the logout deregistration.
  static const String _registeredKey = 'qc_fcm_registered';

  /// POSTs `store-firebase-token`.
  ///
  /// With [skipIfRegistered] the call is dropped when these exact values were
  /// already registered. The bearer token (`mobile_token`) is deliberately not
  /// part of that comparison: it is refreshed on its own schedule, and a new
  /// bearer token for the same user and device is not a new registration.
  ///
  /// An all-empty call is the logout deregistration: always sent, and it
  /// forgets the registration so the next login sends again.
  static Future<void> updateFirebaseToken(
    String username,
    String email,
    String fcmToken,
    String uniqueId, {
    bool skipIfRegistered = false,
  }) async {
    final bool isDeregistration = username.isEmpty && fcmToken.isEmpty;
    final String signature = jsonEncode(
      [username, email, fcmToken, uniqueId, QuickChatWms.userMobile],
    );
    final SecureStorageService storage = SecureStorageService();
    if (skipIfRegistered && !isDeregistration) {
      final String? registered = await storage.read(key: _registeredKey);
      if (registered == signature) {
        if (kDebugMode) {
          debugPrint(
            'QUICKCHAT_STORE_FCM_TOKEN skipped: already registered for '
            '"$username"',
          );
        }
        return;
      }
    }
    final url = Uri.parse('$quickChatBaseUrl/api/api/v1/store-firebase-token');
    final body = {
      'token': quickChatStaticToken,
      'user_name': username,
      'email': email,
      'firebase_token': fcmToken,
      'client_unique_id': uniqueId,
      // The user's bearer token from the host app (QuickChatWms.setUserToken).
      // Only ever logged under kDebugMode, below.
      'mobile_token': QuickChatWms.userToken,
      'mobile': QuickChatWms.userMobile,
    };
    final headers = {'X-Auth-Token': quickChatAuthHeaderToken};
    // Debug-only: kDebugMode so the headers and body (which carry the tokens)
    // never reach release logs.
    if (kDebugMode) {
      debugPrint('QUICKCHAT_STORE_FCM_TOKEN POST $url');
      debugPrint('QUICKCHAT_STORE_FCM_TOKEN headers: ${jsonEncode(headers)}');
      debugPrint('QUICKCHAT_STORE_FCM_TOKEN body: ${jsonEncode(body)}');
    }
    try {
      final response = await http.post(url, headers: headers, body: body);
      if (kDebugMode) {
        debugPrint(
          'QUICKCHAT_STORE_FCM_TOKEN response ${response.statusCode}: '
          '${response.body}',
        );
      }
      if (response.statusCode == 200) {
        if (isDeregistration) {
          await storage.delete(key: _registeredKey);
        } else {
          await storage.write(key: _registeredKey, value: signature);
        }
        debugPrint('FCM Token updated successfully');
      } else {
        debugPrint(
          'Failed to update FCM Token: ${response.statusCode} ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('Error updating FCM Token: $e');
    }
  }
}
