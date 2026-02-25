import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:quick_chat_wms/models/prefrence_model.dart';
import 'package:quick_chat_wms/services/secure_storage_service.dart';

class AppPreferencesService {
  final SecureStorageService _secureStorageService;

  static const String _keyAppPreferences = 'app_preferences_secure_data';

  AppPreferencesService({required SecureStorageService secureStorageService})
    : _secureStorageService = secureStorageService;

  /// Retrieves the entire preferences model.
  /// Returns default values if empty or on error.
  Future<AppPreferences> getPreferences() async {
    try {
      final jsonString = await _secureStorageService.read(
        key: _keyAppPreferences,
      );

      if (jsonString != null && jsonString.isNotEmpty) {
        final Map<String, dynamic> jsonMap = jsonDecode(jsonString);
        return AppPreferences.fromJson(jsonMap);
      }
    } catch (e) {
      debugPrint('Data parsing error in AppPreferencesService: $e');
    }
    return const AppPreferences(); // Falls back to @Default values
  }

  /// Updates only the provided fields using Freezed's copyWith,
  /// keeping the rest of the existing data intact.
  Future<void> updatePreferences({
    String? widgetCode,
    Color? backgroundColor,
    String? appBarTitle,
    Color? appBarBackgroundColor,
    Color? appBarTitleColor,
    Color? appBarBackButtonColor,
    String? fcmToken,
    String? userName,
    String? email,
    bool? resetLocalStorage,
  }) async {
    // 1. Get current preferences
    final currentPrefs = await getPreferences();

    // 2. Apply updates only to the fields passed in
    final updatedPrefs = currentPrefs.copyWith(
      widgetCode: widgetCode ?? currentPrefs.widgetCode,
      backgroundColor: backgroundColor ?? currentPrefs.backgroundColor,
      appBarTitle: appBarTitle ?? currentPrefs.appBarTitle,
      appBarBackgroundColor:
          appBarBackgroundColor ?? currentPrefs.appBarBackgroundColor,
      appBarTitleColor: appBarTitleColor ?? currentPrefs.appBarTitleColor,
      appBarBackButtonColor:
          appBarBackButtonColor ?? currentPrefs.appBarBackButtonColor,
      fcmToken: fcmToken ?? currentPrefs.fcmToken,
      userName: userName ?? currentPrefs.userName,
      email: email ?? currentPrefs.email,
      resetLocalStorage: resetLocalStorage ?? currentPrefs.resetLocalStorage,
    );

    // 3. Save back to secure storage
    final jsonString = jsonEncode(updatedPrefs.toJson());
    await _secureStorageService.write(
      key: _keyAppPreferences,
      value: jsonString,
    );
  }

  /// Clears the app preferences data completely
  Future<void> clearAllPreferences() async {
    await _secureStorageService.delete(key: _keyAppPreferences);
  }
}
