import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  /// {@macro secure_storage}
  SecureStorageService([FlutterSecureStorage? secureStorage])
    : _secureStorage =
          secureStorage ??
          // This now correctly calls the static method
          FlutterSecureStorage(aOptions: _getAndroidOptions());
  // Made this static so it can be used in the constructor initializer
  static AndroidOptions _getAndroidOptions() => const AndroidOptions();

  final FlutterSecureStorage _secureStorage;

  Future<String?> read({required String key}) async {
    try {
      debugPrint('Read: $key, name: Secure Storage Service');
      return await _secureStorage.read(key: key);
    } on Exception catch (e, s) {
      debugPrint('''❌ Failed to Read $key,\n
        error: $e, \n
        stackTrace: $s, \n
        name: 'Secure Storage Service''');
      Error.throwWithStackTrace(e, s);
    }
  }

  Future<void> write({required String key, required String value}) async {
    try {
      debugPrint('Wrote $key: $value, name: Secure Storage Service');
      await _secureStorage.write(key: key, value: value);
    } on Exception catch (e, s) {
      debugPrint('''❌ Failed to Write $key: $value,\n
        error: $e, \n
        stackTrace: $s, \n
        name: 'Secure Storage Service''');
      Error.throwWithStackTrace(e, s);
    }
  }

  Future<void> delete({required String key}) async {
    try {
      debugPrint('Deleted $key, name: Secure Storage Service');
      await _secureStorage.delete(key: key);
    } on Exception catch (e, s) {
      debugPrint('''❌ Failed to delete $key,\n
        error: $e, \n
        stackTrace: $s, \n
        name: 'Secure Storage Service''');
      Error.throwWithStackTrace(e, s);
    }
  }

  Future<void> clear() async {
    try {
      debugPrint('Cleared, name: Secure Storage Service');
      await _secureStorage.deleteAll();
    } on Exception catch (e, s) {
      debugPrint('''❌ Failed to clear,\n
        error: $e, \n
        stackTrace: $s, \n
        name: 'Secure Storage Service''');
      Error.throwWithStackTrace(e, s);
    }
  }
}
