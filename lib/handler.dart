import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/cupertino.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:quick_chat_wms/preference_manager.dart';
import 'package:quick_chat_wms/quick_chat_widget.dart';
import 'package:http/http.dart' as http;


class Handler {
  static Future<void> updateFirebaseToken(String uniqueId) async {
    PreferencesManager preferencesManager = PreferencesManager();
    final url = Uri.parse(
      // 'https://app.quickconnect.biz/api/api/v1/store-firebase-token');
        'https://wms-uat.worldlink.com.np/api/api/v1/store-firebase-token');
    final body = {
      'firebase_token': await preferencesManager.getFcmToken(),
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
          print("✅ Storage permissions granted.");
        } else {
          print("❌ Storage permissions denied.");
        }
      } else {
        var status = await Permission.storage.status;

        if (status.isGranted) {
          print("✅ Storage permission already granted.");
          return;
        }

        if (status.isDenied) {
          print("🚀 Requesting storage permission...");
          status = await Permission.storage.request();
        }

        if (status.isPermanentlyDenied) {
          print(
              "❌ Storage permission permanently denied. Redirecting to settings.");
          openAppSettings(); // Open settings for manual permission
        } else if (status.isDenied) {
          print("❌ Storage permission denied.");
        } else {
          print("✅ Storage permission granted.");
        }
      }
    } else {
      print("⚠️ handle ios permission request");
    }
  }

  static void handleNotificationClick(BuildContext context) async {
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
}