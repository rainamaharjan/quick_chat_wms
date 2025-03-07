import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:quick_chat_wms/preference_manager.dart';
import 'package:quick_chat_wms/quick_chat_widget.dart';
import 'package:http/http.dart' as http;

class NotificationHandler {
  static Future<void> initialize(BuildContext context) async {
    requestPermission();
    try {
      await Firebase.initializeApp();
    } catch (e) {
      print(
          "Quick Chat -------- Firebase not initialized. Make sure to add google-services.json in your app.");
    }
      getFcmConfigure(context);
      initLocalNotifications(context);

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _handleNotificationClick(message.data, context);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleNotificationClick(message.data, context);
    });
  }

  static Future<void> updateFirebaseToken(
      String fcmToken, String uniqueId, String fcmServerKey) async {
    final url = Uri.parse(
        // 'https://app.quickconnect.biz/api/api/v1/store-firebase-token');
        'https://wms-uat.worldlink.com.np/api/api/v1/store-firebase-token');

    final body = {
      'fcm_server_key': fcmServerKey,
      'firebase_token': fcmToken,
      'client_unique_id': uniqueId,
    };

    try {
      final response = await http.post(url, body: body);

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

  static void getFcmConfigure(BuildContext context) async {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint(
          "FCM NOTIFICATION ---Foreground message received: ${jsonEncode(message.toMap())}");
      showLocalNotification(message);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint(
          "FCM NOTIFICATION ---User tapped the notification: ${jsonEncode(message.toMap())}");
      _handleNotificationClick(message.data, context);
    });

    FirebaseMessaging.instance
        .getInitialMessage()
        .then((RemoteMessage? message) {
      if (message != null) {
        debugPrint(
            "FCM NOTIFICATION ---App opened from terminated state via notification: ${jsonEncode(message.toMap())}");
        _handleNotificationClick(message.data, context);
      }
    });
  }

  static void _handleNotificationClick(
      Map<String, dynamic> data, BuildContext context) async {
    PreferencesManager preferencesManager = PreferencesManager();

    Map<String, dynamic> prefs = await preferencesManager.getPreferences();
    String widgetCode = prefs['widgetCode'];
    String fcmServerKey = prefs['fcmServerKey'];
    Color backgroundColor = prefs['backgroundColor'];
    String appBarTitle = prefs['appBarTitle'];
    Color appBarBackgroundColor = prefs['appBarBackgroundColor'];
    Color appBarTitleColor = prefs['appBarTitleColor'];
    Color appBarBackButtonColor = prefs['appBarBackButtonColor'];

      QuickChat.init(context,
          widgetCode: widgetCode,
          fcmServerKey: fcmServerKey,
          appBarTitle: appBarTitle,
          appBarBackgroundColor: appBarBackgroundColor,
          appBarTitleColor: appBarTitleColor,
          appBarBackButtonColor: appBarBackButtonColor,
          backgroundColor: backgroundColor);
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

  static void initLocalNotifications(BuildContext context) async {
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
          _handleNotificationClick(data, context);
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
