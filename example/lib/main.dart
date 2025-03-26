import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:quick_chat_wms/quick_chat_wms.dart';

import 'notification_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  if (QuickChat.isQuickChatNotification(message.data)) {
    QuickChat.handleQuickChatBackgroundNotification(message.data);
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
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
    requestPermission();
    getFcmConfigure(context);
    initNotifications(context);
    QuickChat.initializeNotification(context);
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
        child: Container(
            //YOUR-CONTAINER
            ),
      ),
    );
  }

  void getFcmConfigure(BuildContext context) async {
    FirebaseMessaging.instance.getToken().then((token) {
      QuickChat.setFcmToken(token);
    });

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (QuickChat.isQuickChatNotification(message.data)) {
        QuickChat.showQuickChatNotification(message.data);
        return;
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      if (QuickChat.isQuickChatNotification(message.data)) {
        QuickChat.handleNotificationOnClick(context);
        return;
      }
    });

    FirebaseMessaging.instance
        .getInitialMessage()
        .then((RemoteMessage? message) {
      if (message != null) {
        if (QuickChat.isQuickChatNotification(message.data)) {
          QuickChat.handleNotificationOnClick(context);
          return;
        }
      }
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