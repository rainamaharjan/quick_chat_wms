import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:quick_chat_wms/quick_chat_widget.dart';
import 'package:http/http.dart' as http;

class NotificationHandler {
  static Future<void> initialize() async {
    requestPermission();
    await Firebase.initializeApp();
    getFcmConfigure();
    initLocalNotifications();

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _handleNotificationClick(message.data);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleNotificationClick(message.data);
    });
  }

  static Future<void> updateFirebaseToken(String fcmToken,String uniqueId) async {
    final url = Uri.parse(
        'https://app.quickconnect.biz/api/api/v1/users/update-firebase-token');
    final headers = {
      'Content-Type': 'application/json',
    };

    final body = jsonEncode({
      'mobile_firebase_token': fcmToken,
      'unique_id': uniqueId,
    });

    try {
      final response = await http.post(url, headers: headers, body: body);

      if (response.statusCode == 200) {
        debugPrint('FCM Token updated successfully');
      } else {
        debugPrint(
            'Failed to update FCM Token: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      debugPrint('Error updating FCM Token: $e');
    }
  }

  static FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static void getFcmConfigure() async {

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint(
          "FCM NOTIFICATION ---Foreground message received: ${jsonEncode(message.toMap())}");
      showLocalNotification(message);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint(
          "FCM NOTIFICATION ---User tapped the notification: ${jsonEncode(message.toMap())}");
      _handleNotificationClick(message.data);
    });

    FirebaseMessaging.instance
        .getInitialMessage()
        .then((RemoteMessage? message) {
      if (message != null) {
        debugPrint(
            "FCM NOTIFICATION ---App opened from terminated state via notification: ${jsonEncode(message.toMap())}");
        _handleNotificationClick(message.data);
      }
    });
  }

  static void _handleNotificationClick(Map<String, dynamic> data) {
    String? chatId = data['chat_id'];

    if (chatId != null) {
      // QuickChat.initQuickChat(chatId ?? '');
    }
  }

  static Future<void> showLocalNotification(RemoteMessage message) async {
    String fullName = message.data['full_name'];
    String mobile = message.data['mobile'];
    String? messageContactId = message.data['mobile_redirect_url']?.toString();
    String? identity =
        fullName.isNotEmpty ? fullName : (mobile.isNotEmpty ? mobile : "N/A");
    String messages = message.notification?.body ?? "You have a new message.";

    if (messageContactId == activeChatContactId) {
      debugPrint(
          "FCM NOTIFICATION ---🔕 No notification: User is already chatting with $activeChatContactId");
      return;
    }


    InboxStyleInformation inboxStyle = InboxStyleInformation(
      [message.notification?.body ?? ''],
      contentTitle: identity,
      summaryText: "Tap to open chat",
    );
    var androidDetails = AndroidNotificationDetails(
      'chat_channel',
      'Chat Notifications',
      importance: Importance.high,
      playSound: true,
      priority: Priority.high,
      styleInformation: inboxStyle,
      onlyAlertOnce: true,
    );

    var notificationDetails = NotificationDetails(android: androidDetails);
    debugPrint(
        "FCM NOTIFICATION ---NOTIFICATION DATA ----------> ${jsonEncode(message.toMap())}");

    await flutterLocalNotificationsPlugin.show(
      int.parse(messageContactId ?? "0"),
      identity,
      messages,
      notificationDetails,
      payload: message.data.isNotEmpty ? jsonEncode(message.data) : null,
    );
  }

  static void initLocalNotifications() async {
    var androidInitialize =
        const AndroidInitializationSettings('@mipmap/ic_launcher');
    var initializationSettings =
        InitializationSettings(android: androidInitialize);

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint(
            "FCM NOTIFICATION --- init local notification ${response.payload}");
        if (response.payload != null) {
          final Map<String, dynamic> data = jsonDecode(response.payload ?? '');
          _handleNotificationClick(data);
        }
      },
    );
  }
}

void requestPermission() async {
  FirebaseMessaging messaging = FirebaseMessaging.instance;
  if (Platform.isIOS) {
    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
  }
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
