import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:quick_chat_wms/quick_chat_wms.dart';
import 'package:quick_chat_wms/services/api_config.dart';
import 'package:quick_chat_wms/services/app_preference_service.dart';

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

  static Future<void> updateFirebaseToken(
    String username,
    String email,
    String fcmToken,
    String uniqueId,
  ) async {
    final url = Uri.parse('$quickChatBaseUrl/api/api/v1/store-firebase-token');
    final body = {
      'token': quickChatStaticToken,
      'user_name': username,
      'email': email,
      'firebase_token': fcmToken,
      'client_unique_id': uniqueId,
    };
    try {
      final response = await http.post(url, body: body);
      if (response.statusCode == 200) {
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
