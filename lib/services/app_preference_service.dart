import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:quick_chat_wms/models/prefrence_model.dart';
import 'package:quick_chat_wms/services/secure_storage_service.dart';

class AppPreferencesService {
  final SecureStorageService _secureStorageService;

  static const String _keyAppPreferences = 'app_preferences_secure_data';

  /// In-memory copy of what's in secure storage.
  ///
  /// Every read here goes through the Android keystore, which cost ~670ms on
  /// the first call — paid again on every widget remount, and again inside each
  /// [updatePreferences] (setUserName/setEmail/setFcmToken each did a read AND
  /// a write). Static so the SDK's service and the widget's own instance share
  /// one cache; all writes funnel through this class, so it can't go stale.
  static AppPreferences? _cache;

  /// Dedupes concurrent first reads — several callers race at app start, and
  /// without this they'd each pay the full keystore cost.
  static Future<AppPreferences>? _pendingRead;

  AppPreferencesService({required SecureStorageService secureStorageService})
    : _secureStorageService = secureStorageService;

  /// Retrieves the entire preferences model.
  /// Returns default values if empty or on error.
  Future<AppPreferences> getPreferences() async {
    final AppPreferences? cached = _cache;
    if (cached != null) return cached;

    return _pendingRead ??= _readFromStorage()
      ..whenComplete(() => _pendingRead = null);
  }

  Future<AppPreferences> _readFromStorage() async {
    try {
      final jsonString = await _secureStorageService.read(
        key: _keyAppPreferences,
      );

      if (jsonString != null && jsonString.isNotEmpty) {
        final Map<String, dynamic> jsonMap = jsonDecode(jsonString);
        return _cache = AppPreferences.fromJson(jsonMap);
      }
    } catch (e) {
      debugPrint('Data parsing error in AppPreferencesService: $e');
    }
    return _cache = const AppPreferences(); // Falls back to @Default values
  }

  /// Updates only the provided fields using Freezed's copyWith,
  /// keeping the rest of the existing data intact.p
  Future<void> updatePreferences({
    required AppPreferences Function(AppPreferences currentData) data,
  }) async {
    // 1. Get current preferences
    final AppPreferences currentPrefs = await getPreferences();

    final AppPreferences updatedPrefs = data(currentPrefs);

    // Cache first: readers get the new value immediately, without waiting on
    // the keystore write below.
    _cache = updatedPrefs;

    // 3. Save back to secure storage
    final jsonString = jsonEncode(updatedPrefs.toJson());
    await _secureStorageService.write(
      key: _keyAppPreferences,
      value: jsonString,
    );
  }

  /// Clears the app preferences data completely
  Future<void> clearAllPreferences() async {
    _cache = null;
    await _secureStorageService.delete(key: _keyAppPreferences);
  }
}
