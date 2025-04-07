import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PreferencesManager {
  static const _keyWidgetCode = 'widget_code';
  static const _keyBackgroundColor = 'background_color';
  static const _keyAppBarTitle = 'app_bar_title';
  static const _keyAppBarBackgroundColor = 'app_bar_background_color';
  static const _keyAppBarTitleColor = 'app_bar_title_color';
  static const _keyAppBarBackButtonColor = 'app_bar_back_button_color';
  static const _keyFcmToken = 'fcm_token';
  static const _keyUserName = 'user_name';
  static const _keyEmail = 'email';
  static const _keyResetLocalStorage = 'reset_local_storage';

  Future<void> savePreferences({
    required String widgetCode,
    required Color backgroundColor,
    required String appBarTitle,
    required Color appBarBackgroundColor,
    required Color appBarTitleColor,
    required Color appBarBackButtonColor,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(_keyWidgetCode, widgetCode);
    await prefs.setInt(_keyBackgroundColor, backgroundColor.value);
    await prefs.setString(_keyAppBarTitle, appBarTitle);
    await prefs.setInt(_keyAppBarBackgroundColor, appBarBackgroundColor.value);
    await prefs.setInt(_keyAppBarTitleColor, appBarTitleColor.value);
    await prefs.setInt(_keyAppBarBackButtonColor, appBarBackButtonColor.value);
  }

  Future<Map<String, dynamic>> getPreferences() async {
    final prefs = await SharedPreferences.getInstance();

    return {
      'widget_code': prefs.getString(_keyWidgetCode) ?? '',
      'background_color':
          Color(prefs.getInt(_keyBackgroundColor) ?? 0xFFFFFFFF),
      'app_bar_title': prefs.getString(_keyAppBarTitle) ?? 'Chat With Us',
      'app_bar_background_color':
          Color(prefs.getInt(_keyAppBarBackgroundColor) ?? 0xFF0000FF),
      'app_bar_title_color':
          Color(prefs.getInt(_keyAppBarTitleColor) ?? 0xFFFFFFFF),
      'app_bar_back_button_color':
          Color(prefs.getInt(_keyAppBarBackButtonColor) ?? 0xFFFFFFFF),
    };
  }

  Future<void> saveFcmToken({required String fcmToken}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyFcmToken, fcmToken);
  }

  Future<String> getFcmToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyFcmToken) ?? '';
  }

  Future<void> setUserName({required String username}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUserName, username);
  }

  Future<String> getUserName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserName) ?? '';
  }

  Future<void> setEmail({required String email}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyEmail, email);
  }

  Future<String> getEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyEmail) ?? '';
  }

  Future<bool> setLocalStorageResetFlag({required bool reset}) async {
    final prefs = await SharedPreferences.getInstance();
    return await prefs.setBool(_keyResetLocalStorage, reset);
  }

  Future<bool> getLocalStorageResetFlag() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyResetLocalStorage) ?? false;
  }

  Future<void> clearAllPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyWidgetCode, '');
    await prefs.setInt(_keyBackgroundColor, 0);
    await prefs.setString(_keyAppBarTitle, '');
    await prefs.setInt(_keyAppBarBackgroundColor, 0);
    await prefs.setInt(_keyAppBarTitleColor, 0);
    await prefs.setInt(_keyAppBarBackButtonColor, 0);
    await prefs.setString(_keyFcmToken, '');
    await prefs.setString(_keyUserName, '');
    await prefs.setString(_keyEmail, '');
  }
}
