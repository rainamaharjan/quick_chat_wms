import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:quick_chat_wms/quick_chat_wms.dart';

FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('Handling a background message ${message.messageId}');
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  void initState() {
    super.initState();
    initialize();
  }

  initialize() async {
    requestPermission();
    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    } catch (e) {
      print(
          "Quick Chat -------- Firebase not initialized. Make sure to add google-services.json in your app.");
    }
    getFcmConfigure(context);
    initLocalNotifications(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('DEMO CHAT APP'),
        backgroundColor: Colors.blueAccent,
      ),
      body: InkWell(
        onTap: () {
          QuickChat.init(context,
              widgetCode: 'YOUR-WIDGET-KEY',
              appBarBackgroundColor: const Color(0XFF0066B3));
        },
        child: const Center(child: Text('CLICK HERE')),
      ),
    );
  }

  FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  void getFcmConfigure(BuildContext context) async {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint(
          "FCM NOTIFICATION ---Foreground message received: ${jsonEncode(message.toMap())}");
      showLocalNotification(message);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint(
          "FCM NOTIFICATION ---User tapped the notification: ${jsonEncode(message.toMap())}");
      QuickChat.handleNotificationOnClick(context);
    });

    FirebaseMessaging.instance
        .getInitialMessage()
        .then((RemoteMessage? message) {
      if (message != null) {
        debugPrint(
            "FCM NOTIFICATION ---App opened from terminated state via notification: ${jsonEncode(message.toMap())}");
        QuickChat.handleNotificationOnClick(context);
      }
    });
  }

  List<String> messages = [];

  Future<void> showLocalNotification(RemoteMessage message) async {
    String title = message.notification?.title ?? '';
    String body = message.notification?.body ?? '';
    messages.add(body);
    InboxStyleInformation inboxStyle = InboxStyleInformation(
      messages,
      contentTitle: title,
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
      0,
      title,
      body,
      notificationDetails,
    );
  }

  void initLocalNotifications(BuildContext context) async {
    var androidInitialize =
        const AndroidInitializationSettings('@mipmap/ic_launcher');
    var initializationSettings =
        InitializationSettings(android: androidInitialize);

    await flutterLocalNotificationsPlugin.initialize(initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
      QuickChat.handleNotificationOnClick(context);
    });
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