import 'dart:convert';

import 'package:http/http.dart' as http;

import 'flash_sale_model.dart';

class FlashSaleApiException implements Exception {
  final String message;
  final int? statusCode;

  const FlashSaleApiException(
      this.message, {
        this.statusCode,
      });

  @override
  String toString() => message;
}

class ConsumerFlashSaleService {
  static const String activeSaleApiUrl =
      'https://hwy9tv2fca.execute-api.ap-south-1.amazonaws.com/default/getActiveFlashSale';

  static const String orderApiUrl =
      'https://twy2kldt11.execute-api.ap-south-1.amazonaws.com/default/createFlashSaleOrder';

  static const Duration _timeout =
  Duration(seconds: 20);

  // ============================================================
  // GET ACTIVE FLASH SALE
  // ============================================================

  static Future<ActiveFlashSaleResponse>
  getActiveSale() async {
    final response = await http
        .get(
      Uri.parse(activeSaleApiUrl),
      headers: const {
        'Accept': 'application/json',
      },
    )
        .timeout(_timeout);

    final json = _decodeResponse(
      response,
      fallbackError:
      'Could not load the Flash Sale.',
    );

    return ActiveFlashSaleResponse.fromJson(
      json,
    );
  }

  // ============================================================
  // VALIDATE ORDER
  // ============================================================

  static Future<FlashSaleValidationResponse>
  validateOrder({
    required String userID,
    required String flashSaleID,
    required int quantity,
  }) async {
    final response = await http
        .post(
      Uri.parse(orderApiUrl),
      headers: const {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'action': 'validate',
        'userID': userID.trim(),
        'flashSaleID': flashSaleID.trim(),
        'quantity': quantity,
      }),
    )
        .timeout(_timeout);

    final json = _decodeResponse(
      response,
      fallbackError:
      'Could not validate the Flash Sale order.',
    );

    return FlashSaleValidationResponse.fromJson(
      json,
    );
  }

  // ============================================================
  // CONFIRM ORDER
  // ============================================================

  static Future<FlashSaleOrderResponse>
  confirmOrder({
    required String userID,
    required String flashSaleID,
    required int quantity,
    required String requestId,
  }) async {
    final response = await http
        .post(
      Uri.parse(orderApiUrl),
      headers: const {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'action': 'confirm',
        'userID': userID.trim(),
        'flashSaleID': flashSaleID.trim(),
        'quantity': quantity,
        'requestId': requestId.trim(),
      }),
    )
        .timeout(_timeout);

    final json = _decodeResponse(
      response,
      fallbackError:
      'Could not confirm the Flash Sale order.',
    );

    return FlashSaleOrderResponse.fromJson(
      json,
    );
  }

  // ============================================================
  // COMMON RESPONSE DECODER
  // ============================================================

  static Map<String, dynamic> _decodeResponse(
      http.Response response, {
        required String fallbackError,
      }) {
    dynamic decoded;

    try {
      decoded = jsonDecode(response.body);
    } catch (_) {
      throw FlashSaleApiException(
        '$fallbackError Invalid server response.',
        statusCode: response.statusCode,
      );
    }

    // Supports API Gateway setups that expose the Lambda proxy
    // envelope instead of automatically unwrapping "body".
    if (decoded is Map &&
        decoded['body'] is String &&
        decoded['success'] == null) {
      final outerStatusCode = _toNullableInt(
        decoded['statusCode'],
      );

      try {
        decoded = jsonDecode(
          decoded['body'].toString(),
        );
      } catch (_) {
        throw FlashSaleApiException(
          '$fallbackError Invalid server response.',
          statusCode:
          outerStatusCode ?? response.statusCode,
        );
      }

      if (decoded is Map &&
          outerStatusCode != null &&
          outerStatusCode >= 400) {
        final inner =
        Map<String, dynamic>.from(decoded);

        throw FlashSaleApiException(
          _extractError(
            inner,
            fallbackError,
          ),
          statusCode: outerStatusCode,
        );
      }
    }

    if (decoded is! Map) {
      throw FlashSaleApiException(
        '$fallbackError Unexpected server response.',
        statusCode: response.statusCode,
      );
    }

    final json =
    Map<String, dynamic>.from(decoded);

    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        json['success'] != true) {
      throw FlashSaleApiException(
        _extractError(
          json,
          fallbackError,
        ),
        statusCode: response.statusCode,
      );
    }

    return json;
  }

  static String _extractError(
      Map<String, dynamic> json,
      String fallback,
      ) {
    final value =
        json['error'] ??
            json['message'];

    final text =
        value?.toString().trim() ?? '';

    return text.isEmpty
        ? fallback
        : text;
  }
}

int? _toNullableInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();

  return int.tryParse(value.toString());
}
