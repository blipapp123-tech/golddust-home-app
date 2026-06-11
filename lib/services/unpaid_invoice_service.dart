import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/unpaid_invoice_model.dart';

class UnpaidInvoiceService {
  static const String baseUrl =
      'https://wdr48h16e8.execute-api.ap-south-1.amazonaws.com/default';

  static Future<List<UnpaidInvoice>> fetchUnpaidInvoices({
    required String userID,
  }) async {
    final uri = Uri.parse('$baseUrl/fetchCustomerUnpaidInvoices').replace(
      queryParameters: {
        'userID': userID,
      },
    );

    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch unpaid invoices');
    }

    final Map<String, dynamic> outerData = jsonDecode(response.body);

    final Map<String, dynamic> data =
    outerData['body'] is String ? jsonDecode(outerData['body']) : outerData;

    if (data['success'] != true) {
      throw Exception(data['message'] ?? 'Unable to fetch unpaid invoices');
    }

    final List invoicesJson = data['invoices'] ?? [];

    return invoicesJson
        .map((item) => UnpaidInvoice.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }
}