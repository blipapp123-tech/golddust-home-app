import 'dart:convert';

import 'package:http/http.dart' as http;

class AccountDeletionResult {
  final bool success;
  final bool alreadyExists;
  final String message;
  final String? requestId;
  final String? status;
  final String? requestedAt;
  final String? deletionDeadline;

  AccountDeletionResult({
    required this.success,
    required this.alreadyExists,
    required this.message,
    this.requestId,
    this.status,
    this.requestedAt,
    this.deletionDeadline,
  });

  factory AccountDeletionResult.fromJson(Map<String, dynamic> json) {
    return AccountDeletionResult(
      success: json['success'] == true,
      alreadyExists: json['alreadyExists'] == true,
      message: (json['message'] ?? '').toString(),
      requestId: json['requestId']?.toString(),
      status: json['status']?.toString(),
      requestedAt: json['requestedAt']?.toString(),
      deletionDeadline: json['deletionDeadline']?.toString(),
    );
  }
}

class AccountDeletionService {
  static const String _endpoint =
      'https://mw7xssrnv3.execute-api.ap-south-1.amazonaws.com/default/accountDeletionRequest';

  static Future<AccountDeletionResult> submitDeletionRequest({
    required String userId,
    required String phoneNumber,
    required String reason,
    required String platform,
    String appVersion = '',
  }) async {
    final uri = Uri.parse(_endpoint);

    print('🗑️ Delete account API URL: $uri');

    final response = await http
        .post(
      uri,
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'userId': userId,
        'phoneNumber': phoneNumber,
        'reason': reason,
        'platform': platform,
        'appVersion': appVersion,
      }),
    )
        .timeout(const Duration(seconds: 20));

    print('🗑️ Delete account status: ${response.statusCode}');
    print('🗑️ Delete account body: ${response.body}');

    Map<String, dynamic> decoded = {};

    try {
      decoded = Map<String, dynamic>.from(jsonDecode(response.body));
    } catch (_) {
      decoded = {
        'success': false,
        'message': response.body,
      };
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return AccountDeletionResult.fromJson(decoded);
    }

    throw Exception(
      decoded['message']?.toString().isNotEmpty == true
          ? decoded['message'].toString()
          : 'Unable to submit deletion request.',
    );
  }
}