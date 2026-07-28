import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:quick_chat_wms/services/api_config.dart';

class ClientService {
  /// Asks the server for the `client_unique_id` already issued to [userName].
  ///
  /// Returns `null` when the user has no chat history yet (the API answers with
  /// `client_unique_id: null`), when we have nothing to identify the user with,
  /// or when the call fails — every one of those cases means "start a new
  /// chat", so the caller never has to distinguish them.
  static Future<String?> fetchClientUniqueId({
    required String widgetCode,
    required String userName,
  }) async {
    if (widgetCode.isEmpty || userName.isEmpty) {
      // Debug-only: kDebugMode so the payload (which carries the token) never
      // reaches release logs.
      if (kDebugMode) {
        debugPrint(
          'QUICKCHAT_GET_UNIQUE_ID skipped: widgetCode.isEmpty='
          '${widgetCode.isEmpty}, userName.isEmpty=${userName.isEmpty}',
        );
      }
      return null;
    }

    final url = Uri.parse('$quickChatBaseUrl/api/api/v1/get-unique-id');
    final payload = jsonEncode({
      'token': quickChatStaticToken,
      'user_name': userName,
    });
    if (kDebugMode) {
      debugPrint('QUICKCHAT_GET_UNIQUE_ID POST $url');
      debugPrint('QUICKCHAT_GET_UNIQUE_ID payload: $payload');
    }
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: payload,
      );

      if (kDebugMode) {
        debugPrint(
          'QUICKCHAT_GET_UNIQUE_ID response ${response.statusCode}: '
          '${response.body}',
        );
      }

      if (response.statusCode != 200) {
        debugPrint(
          'get-unique-id failed: ${response.statusCode} ${response.body}',
        );
        return null;
      }

      final decoded = jsonDecode(response.body);
      // Response shape: { "data": "...", "message": { "client_unique_id": ... } }
      final message = (decoded is Map) ? decoded['message'] : null;
      final id = (message is Map) ? message['client_unique_id'] : null;
      final resolved = id?.toString().trim() ?? '';
      if (kDebugMode) {
        debugPrint(
          'QUICKCHAT_GET_UNIQUE_ID resolved client_unique_id for '
          '"$userName": ${resolved.isEmpty ? '<null/empty → fresh chat>' : resolved}',
        );
      }
      return resolved.isEmpty ? null : resolved;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('QUICKCHAT_GET_UNIQUE_ID error for "$userName": $e');
      }
      return null;
    }
  }
}
