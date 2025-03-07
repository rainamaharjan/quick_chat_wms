import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PreferencesManager {
  Future<void> savePreferences({
    required String widgetCode,
    required String fcmServerKey,
    required Color backgroundColor,
    required String appBarTitle,
    required Color appBarBackgroundColor,
    required Color appBarTitleColor,
    required Color appBarBackButtonColor,
  }) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    await prefs.setString('widgetCode', widgetCode);
    await prefs.setString('fcmServerKey', fcmServerKey);
    await prefs.setString('backgroundColor', backgroundColor.value.toString());
    await prefs.setString('appBarTitle', appBarTitle);
    await prefs.setString('appBarBackgroundColor', appBarBackgroundColor.value.toString());
    await prefs.setString('appBarTitleColor', appBarTitleColor.value.toString());
    await prefs.setString('appBarBackButtonColor', appBarBackButtonColor.value.toString());
  }

  Future<Map<String, dynamic>> getPreferences() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    String widgetCode = prefs.getString('widgetCode') ?? '';
    String fcmServerKey = prefs.getString('fcmServerKey') ?? '';
    Color backgroundColor = Color(int.parse(prefs.getString('backgroundColor') ?? '0xFFFFFFFF'));
    String appBarTitle = prefs.getString('appBarTitle') ?? 'Chat With Us';
    Color appBarBackgroundColor = Color(int.parse(prefs.getString('appBarBackgroundColor') ?? '0xFF0000FF'));
    Color appBarTitleColor = Color(int.parse(prefs.getString('appBarTitleColor') ?? '0xFFFFFFFF'));
    Color appBarBackButtonColor = Color(int.parse(prefs.getString('appBarBackButtonColor') ?? '0xFFFFFFFF'));

    return {
      'widgetCode': widgetCode,
      'fcmServerKey': fcmServerKey,
      'backgroundColor': backgroundColor,
      'appBarTitle': appBarTitle,
      'appBarBackgroundColor': appBarBackgroundColor,
      'appBarTitleColor': appBarTitleColor,
      'appBarBackButtonColor': appBarBackButtonColor,
    };
  }
}
