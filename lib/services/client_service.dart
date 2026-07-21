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
    if (widgetCode.isEmpty || userName.isEmpty) return null;

    final url = Uri.parse('$quickChatBaseUrl/api/api/v1/get-unique-id');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'token': widgetCode, 'user_name': userName}),
      );

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
      return resolved.isEmpty ? null : resolved;
    } catch (e) {
      debugPrint('Error fetching client unique id: $e');
      return null;
    }
  }
}
