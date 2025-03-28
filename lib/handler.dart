import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:quick_chat_wms/preference_manager.dart';
import 'package:quick_chat_wms/quick_chat_widget.dart';
import 'package:http/http.dart' as http;

class Handler {
  static Future<void> updateFirebaseToken(
      String fcmToken, String uniqueId) async {
    final url = Uri.parse(
        'https://app.quickconnect.biz/api/api/v1/store-firebase-token');
    final body = {
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

  static Future<void> requestStoragePermission() async {
    if (Platform.isAndroid) {
      final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
      final AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
      int sdkVersion = androidInfo.version.sdkInt;
      if (sdkVersion >= 33) {
        // Android 13+ (API 33+): Request separate media permissions
        await Permission.photos.request();
        await Permission.videos.request();
        await Permission.audio.request();

        if (await Permission.photos.isGranted ||
            await Permission.videos.isGranted ||
            await Permission.audio.isGranted) {
          debugPrint("✅ Storage permissions granted.");
        } else {
          debugPrint("❌ Storage permissions denied.");
        }
      } else {
        var status = await Permission.storage.status;

        if (status.isGranted) {
          debugPrint("✅ Storage permission already granted.");
          return;
        }

        if (status.isDenied) {
          debugPrint("🚀 Requesting storage permission...");
          status = await Permission.storage.request();
        }

        if (status.isPermanentlyDenied) {
          debugPrint(
              "❌ Storage permission permanently denied. Redirecting to settings.");
          openAppSettings(); // Open settings for manual permission
        } else if (status.isDenied) {
          debugPrint("❌ Storage permission denied.");
        } else {
          debugPrint("✅ Storage permission granted.");
        }
      }
    } else {
      debugPrint("⚠️ handle ios permission request");
    }
  }

  static void handleNotificationClick(BuildContext context) async {
    messages.clear();
    PreferencesManager preferencesManager = PreferencesManager();
    Map<String, dynamic> prefs = await preferencesManager.getPreferences();
    String widgetCode = prefs['widgetCode'];
    Color backgroundColor = prefs['backgroundColor'];
    String appBarTitle = prefs['appBarTitle'];
    Color appBarBackgroundColor = prefs['appBarBackgroundColor'];
    Color appBarTitleColor = prefs['appBarTitleColor'];
    Color appBarBackButtonColor = prefs['appBarBackButtonColor'];

    QuickChat.init(context,
        widgetCode: widgetCode,
        appBarTitle: appBarTitle,
        appBarBackgroundColor: appBarBackgroundColor,
        appBarTitleColor: appBarTitleColor,
        appBarBackButtonColor: appBarBackButtonColor,
        backgroundColor: backgroundColor);
  }

  static Future<void> initNotification(BuildContext context) async {
    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );

    await flutterLocalNotificationsPlugin.initialize(initializationSettings,
        onDidReceiveNotificationResponse:
            (NotificationResponse response) async {
          QuickChat.handleNotificationOnClick(context);
        });
  }

  static Future<ByteArrayAndroidBitmap> _getImageFromUrl(
      String imageUrl) async {
    final response = await http.get(Uri.parse(imageUrl));
    if (response.statusCode == 200) {
      return ByteArrayAndroidBitmap(response.bodyBytes);
    } else {
      throw Exception('Failed to load image');
    }
  }

  static Future<void> showQuickChatNotification(
      Map<String, dynamic> data) async {
    final body = data['body'] ?? '';
    if (isUrl(body)) {
      final imageExt = extractImageExtension(body);
      if (imageExt != null) {
        final largeIcon = await _getImageFromUrl(body);
        await flutterLocalNotificationsPlugin.show(
          0,
          data['title'],
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
    await showLocalNotification(data);
  }

  static List<String> messages = [];

  static Future<void> showLocalNotification(Map<String, dynamic> data) async {
    final body = data['body'] ?? '';
    String content = '';

    await flutterLocalNotificationsPlugin.cancel(0);

    if (isUrl(body)) {
      String fileName = extractFileName(body);
      content = "📂 $fileName";
    } else {
      content = body;
    }
    if (!messages.contains(content)) {
      messages.add(content);
    }

    await flutterLocalNotificationsPlugin.show(
        0,
        data['title'] ?? '',
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
              contentTitle: data['title'] ?? '',
              summaryText: "Tap to open chat",
            ),
            onlyAlertOnce: true,
            setAsGroupSummary: true,
            groupKey: 'notification_group_key',
          ),
        ));
  }

  static final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

  static bool isUrl(String text) {
    final urlPattern = RegExp(
        r'^(https?:\/\/)?(www\.)?[\da-z\.-]+\.[a-z\.]{2,6}([\/\w\.-]*)*\/?(\?[=&\w\.-]*)?(#[\w-]*)?$',
        caseSensitive: false);
    return urlPattern.hasMatch(text);
  }

  static String? extractImageExtension(String url) {
    final regExp = RegExp(r'\.(jpg|jpeg|png)$', caseSensitive: false);
    return regExp.firstMatch(url)?.group(1)?.toLowerCase();
  }

  static String extractFileName(String url) {
    final regExp = RegExp(r'\/([^/]+\.(?!jpg|jpeg|png)[a-zA-Z0-9]+)$');
    final match = regExp.firstMatch(url);
    return match?.group(1) ?? 'Unknown file';
  }
}