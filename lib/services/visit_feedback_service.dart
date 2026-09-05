import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class VisitFeedbackService {
  static const String _submitFeedbackUrl =
      'https://ngmua1eywa.execute-api.ap-south-1.amazonaws.com/default/submitVisitFeedback';

  Future<Map<String, dynamic>> submitFeedback({
    required String userId,
    required String dueDate,
    required int rating,
    required List<String> feedbackTags,
    required String feedbackText,
  }) async {
    if (_submitFeedbackUrl.startsWith('PASTE_') ||
        _submitFeedbackUrl.trim().isEmpty) {
      throw Exception(
        'submitVisitFeedback API URL is not configured',
      );
    }

    final payload = {
      'userID': userId.trim(),
      'dueDate': dueDate.trim(),
      'rating': rating,
      'feedbackTags': feedbackTags,
      'feedbackText': feedbackText.trim(),
    };

    debugPrint(
      '[VisitFeedbackService] POST $_submitFeedbackUrl',
    );

    debugPrint(
      '[VisitFeedbackService] payload=${jsonEncode(payload)}',
    );

    final response = await http.post(
      Uri.parse(_submitFeedbackUrl),
      headers: const {
        'Content-Type': 'application/json',
      },
      body: jsonEncode(payload),
    );

    final decoded = _decode(
      response.body,
    );

    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        decoded['success'] != true) {
      throw Exception(
        decoded['message']?.toString() ??
            'Unable to submit feedback',
      );
    }

    return decoded;
  }

  Map<String, dynamic> _decode(
      String raw,
      ) {
    if (raw.trim().isEmpty) {
      return {};
    }

    final decoded = jsonDecode(raw);

    if (decoded is! Map) {
      return {};
    }

    final outer =
    Map<String, dynamic>.from(decoded);

    if (outer['body'] is String) {
      final nested =
      jsonDecode(outer['body']);

      if (nested is Map) {
        return Map<String, dynamic>.from(
          nested,
        );
      }
    }

    if (outer['body'] is Map) {
      return Map<String, dynamic>.from(
        outer['body'] as Map,
      );
    }

    return outer;
  }
}
