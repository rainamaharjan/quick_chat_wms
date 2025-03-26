import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:quick_chat_wms/quick_chat_widget.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> initNotifications(BuildContext context) async {
  const initializationSettings = InitializationSettings(
    android: AndroidInitializationSettings('@mipmap/ic_launcher'),
  );

  await flutterLocalNotificationsPlugin.initialize(initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
    QuickChat.handleNotificationOnClick(context);
  });
}
Future<ByteArrayAndroidBitmap> _getImageFromUrl(String imageUrl) async {
  final response = await http.get(Uri.parse(imageUrl));
  if (response.statusCode == 200) {
    return ByteArrayAndroidBitmap(response.bodyBytes);
  } else {
    throw Exception('Failed to load image');
  }
}

Future<void> showQuickChatNotification(RemoteMessage message) async {
  final body = message.data['body'] ?? '';
  if (isUrl(body)) {
    final imageExt = extractImageExtension(body);
    if (imageExt != null) {
      final largeIcon = await _getImageFromUrl(body);
      await flutterLocalNotificationsPlugin.show(
        0,
        message.data['title'],
        null,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'channel_id',
            'channel_name',
            importance: Importance.max,
            priority: Priority.high,
            largeIcon: largeIcon,
            styleInformation: BigPictureStyleInformation(largeIcon),
          ),
        ),
      );
      return;
    }
  }

  await showLocalNotification(message);
}

List<String> messages = [];

Future<void> showLocalNotification(RemoteMessage message) async {
  final body = message.data['body'] ?? '';
  String content = '';

  // If it's a file, extract the file name (excluding images)
  if (isUrl(body)) {
    String fileName = extractFileName(body);
    content = fileName;
  } else {
    content = body;
    messages.add(content);
  }

  await flutterLocalNotificationsPlugin.show(
    0,
    message.data['title'] ?? '',
    content,
    NotificationDetails(
      android: AndroidNotificationDetails(
        'chat_channel',
        'Chat Notifications',
        importance: Importance.high,
        playSound: true,
        priority: Priority.high,
        styleInformation: InboxStyleInformation(
          messages,
          contentTitle: message.data['title'] ?? '',
          summaryText: "Tap to open chat",
        ),
        onlyAlertOnce: true,
        setAsGroupSummary: true,
        groupKey: 'notification_group_key',
      ),
    ),
  );
}

bool isUrl(String text) {
  final urlPattern = RegExp(
      r'^(https?:\/\/)?(www\.)?[\da-z\.-]+\.[a-z\.]{2,6}([\/\w\.-]*)*\/?(\?[=&\w\.-]*)?(#[\w-]*)?$',
      caseSensitive: false);
  return urlPattern.hasMatch(text);
}

String? extractImageExtension(String url) {
  final regExp = RegExp(r'\.(jpg|jpeg|png)$', caseSensitive: false);
  return regExp.firstMatch(url)?.group(1)?.toLowerCase();
}

String extractFileName(String url) {
  final regExp = RegExp(r'\/([^/]+\.(?!jpg|jpeg|png)[a-zA-Z0-9]+)$');
  final match = regExp.firstMatch(url);
  return match?.group(1) ?? 'Unknown file';
}
