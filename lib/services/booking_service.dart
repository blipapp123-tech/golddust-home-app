import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
class BookingService {
  BookingService._();

  // =========================
  // API ENDPOINTS
  // =========================
  static const String _baseUrl =
      'https://xjf4mnwijc.execute-api.ap-south-1.amazonaws.com';

  static const String _expertVisitsUrl =
      'https://p8iwiengoa.execute-api.ap-south-1.amazonaws.com/expertVisits';

  static const String _fetchVisitsUrl =
      'https://wdjk4ojdbf.execute-api.ap-south-1.amazonaws.com/fetchExpertVisitsWithUserid';

  static const String _cancelVisitUrl =
      'https://v0m2gst194.execute-api.ap-south-1.amazonaws.com/ExpertVisitsWithUseridStatusChange';

  static const String _rescheduleVisitUrl =
      'https://e2k8r3zscd.execute-api.ap-south-1.amazonaws.com/ExpertVisitsWithUserideditDateTimeChange';

  static const String _expertRecommendationsUrl =
      'https://802duvpsg0.execute-api.ap-south-1.amazonaws.com/getExpertRecommendationUserId';

  static const String _zohoDealUrl =
      'https://ivkeovrinj.execute-api.ap-south-1.amazonaws.com/fast_zoho_contactNdeal_creation';

  static const String _zohoCreatePaymentSessionUrl =
      'https://vztxhparhd.execute-api.ap-south-1.amazonaws.com//zohoPaymentSessionCreation';

  static const String _zohoVerifyPaymentUrl =
      'https://zus3h9i198.execute-api.ap-south-1.amazonaws.com/zohoPaymentVerify';

  // ✅ REAL SUBSCRIPTION / ZOHO BOOKINGS FETCH API
  static const String _fetchZohoBookingsUrl =
      'https://u53ghj7ip8.execute-api.ap-south-1.amazonaws.com/zohoBookingsWithUserId';

  static const String zohoPaymentsApiKey =
      '1003.6df21b1cd78f2356636629a11492d057.302c0220f162f7868dd0a02411b42c68';

  static const String zohoPaymentsAccountId = '60066642528';

  static const Map<String, String> _headers = {
    'Content-Type': 'application/json',
  };

  // =========================
  // INTERNAL HELPERS
  // =========================
  static dynamic _decodeBody(http.Response response) {
    if (response.body.isEmpty) return null;
    return jsonDecode(response.body);
  }

  static Exception _buildException(
      String action,
      http.Response response,
      ) {
    return Exception(
      '$action failed (${response.statusCode}): ${response.body}',
    );
  }

  static Future<dynamic> _get(String url) async {
    final response = await http.get(
      Uri.parse(url),
      headers: _headers,
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return _decodeBody(response);
    }

    throw _buildException('GET request', response);
  }

  static Future<dynamic> _post(
      String url,
      Map<String, dynamic> body,
      ) async {
    final response = await http.post(
      Uri.parse(url),
      headers: _headers,
      body: jsonEncode(body),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return _decodeBody(response);
    }

    throw _buildException('POST request', response);
  }

  // =========================
  // FETCH EXPERT AVAILABILITY
  // =========================
  static Future<Map<String, dynamic>> fetchExpertAvailability() async {
    try {
      final data = await _get('$_baseUrl/expertAvailabilityfetch');

      if (data is Map<String, dynamic>) {
        return data;
      }

      throw Exception('Invalid availability response format');
    } catch (e) {
      throw Exception('Error fetching expert availability: $e');
    }
  }

  // =========================
  // SIMPLE SLOT BOOK API
  // =========================
  static Future<bool> bookExpertSlot({
    required String date,
    required String time,
    String service = 'maali',
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/expertBooking'),
        headers: _headers,
        body: jsonEncode({
          'date': date,
          'time': time,
          'service': service,
        }),
      );

      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      throw Exception('Booking slot failed: $e');
    }
  }

  // =========================
  // CREATE / BOOK EXPERT VISIT
  // =========================
  static Future<Map<String, dynamic>> bookExpertVisit(
      Map<String, dynamic> visitData,
      ) async {
    try {
      final data = await _post(_expertVisitsUrl, visitData);

      if (data is Map<String, dynamic>) {
        return data;
      }

      return {
        'success': true,
        'message': 'Expert visit created successfully',
        'data': data,
      };
    } catch (e) {
      throw Exception('Booking expert visit failed: $e');
    }
  }

  // =========================
  // FETCH EXPERT VISITS BY USER ID
  // This reads expertVisits table through Lambda.
  // Used for expert visit status / recommendation journey.
  // =========================
  static Future<List<dynamic>> fetchExpertVisits(String userId) async {
    try {
      final data = await _post(_fetchVisitsUrl, {
        'userID': userId,
      });

      if (data is List) {
        return data;
      }

      throw Exception('Invalid visits response format');
    } catch (e) {
      throw Exception('Error fetching expert visits: $e');
    }
  }

  // =========================
  // FETCH REAL ZOHO BOOKINGS BY USER ID
  // This reads zohoBookings table through Lambda.
  // Use this after expertVisits says "Subscription booked".
  // =========================
  static Future<List<Map<String, dynamic>>> fetchZohoBookings(
      String userId,
      ) async {
    try {
      final data = await _post(_fetchZohoBookingsUrl, {
        'userID': userId,
      });

      if (data is Map<String, dynamic>) {
        return _transformZohoBookings(data);
      }

      throw Exception('Invalid Zoho bookings response format');
    } catch (e) {
      throw Exception('Error fetching Zoho bookings: $e');
    }
  }

  static List<Map<String, dynamic>> _transformZohoBookings(
      Map<String, dynamic> response,
      ) {
    final List<Map<String, dynamic>> transformedBookings = [];

    if (!response.containsKey('bookings') || response['bookings'] is! List) {
      return transformedBookings;
    }

    final bookingsList = response['bookings'] as List;

    for (final rawBooking in bookingsList) {
      if (rawBooking is! Map) continue;

      final booking = Map<String, dynamic>.from(rawBooking);

      final hasMonthlyVisitFields =
          booking.containsKey('visitDay1') ||
              booking.containsKey('visitTimeSlot1') ||
              booking.containsKey('visitDate1');

      if (hasMonthlyVisitFields) {
        transformedBookings.add({
          'bookingID': booking['taskID'] ?? booking['dealID'] ?? '',
          'taskID': booking['taskID'] ?? '',
          'dealID': booking['dealID'] ?? '',
          'contactID': booking['contactID'] ?? '',

          'Mobile': booking['Mobile'] ?? booking['mobile'] ?? '',
          'bookingType': 'monthlySubscription',

          'planName': booking['planName'] ?? 'Standard Plan',
          'bookingAmount':
          int.tryParse((booking['monthlyAmount'] ?? '0').toString()) ?? 0,
          'monthlyAmount': booking['monthlyAmount'] ?? '0',

          'maaliNo': booking['assignedMaliId'] ?? '',
          'assignedMali': booking['assignedMali'] ?? '',
          'assignedMaliId': booking['assignedMaliId'] ?? '',

          'supervisorName': booking['supervisorName'] ?? '',
          'Supervisor_Assigned_ID': booking['Supervisor_Assigned_ID'] ?? '',

          'subscriptionStatus': booking['subscriptionStatus'] ?? 'Active',
          'dealStatus': booking['dealStatus'] ?? '',
          'taskStatus': booking['taskStatus'] ?? '',

          'startDate': booking['startDate'] ?? '',
          'Current_Cycle_Subscription_Start_Date':
          booking['Current_Cycle_Subscription_Start_Date'] ?? '',

          'serviceFrequency': booking['serviceFrequency'] ?? '',
          'subscriptionMonthTenure': booking['subscriptionMonthTenure'] ?? '',

          'dayTimeSlots': [
            {
              'day': booking['visitDay1'] ?? '',
              'timeSlot': booking['visitTimeSlot1'] ?? '',
            }
          ],

          'bookedDates': _generateBookedDatesFromDueDates(booking),

          'dueDate': _normalizeDueDateToFullYear(booking['dueDate'] ?? ''),
          'date': _normalizeDueDateToFullYear(booking['dueDate'] ?? ''),
          'visitTimeSlot1': booking['visitTimeSlot1'] ?? '',

          'Full_Name': booking['Full_Name'] ??
              booking['fullName'] ??
              booking['customerName'] ??
              '',
          'address': booking['address'] ?? '',

          'renewalPaymentPending': booking['renewalPaymentPending'] ?? '',

          // Keep original raw object also for debugging / future use.
          'rawZohoBooking': booking,
        });
      } else {
        transformedBookings.add({
          'bookingID': booking['taskID'] ?? booking['dealID'] ?? '',
          'taskID': booking['taskID'] ?? '',
          'dealID': booking['dealID'] ?? '',
          'contactID': booking['contactID'] ?? '',

          'bookingType': 'oneTime',

          'planName': booking['planName'] ?? 'One Time Service',
          'bookingAmount':
          int.tryParse((booking['monthlyAmount'] ?? '0').toString()) ?? 0,
          'monthlyAmount': booking['monthlyAmount'] ?? '0',

          'maaliNo': booking['assignedMaliId'] ?? '',
          'assignedMali': booking['assignedMali'] ?? '',
          'assignedMaliId': booking['assignedMaliId'] ?? '',

          'date': _normalizeDueDateToFullYear(booking['dueDate'] ?? ''),
          'dueDate': _normalizeDueDateToFullYear(booking['dueDate'] ?? ''),
          'timeSlot': booking['visitTimeSlot1'] ?? '',
          'visitTimeSlot1': booking['visitTimeSlot1'] ?? '',

          'subscriptionStatus': booking['subscriptionStatus'] ?? '',
          'dealStatus': booking['dealStatus'] ?? '',
          'taskStatus': booking['taskStatus'] ?? '',

          'renewalPaymentPending': booking['renewalPaymentPending'] ?? '',

          'Full_Name': booking['Full_Name'] ??
              booking['fullName'] ??
              booking['customerName'] ??
              '',
          'address': booking['address'] ?? '',

          'rawZohoBooking': booking,
        });
      }
    }

    return transformedBookings;
  }

  static List<String> _generateBookedDatesFromDueDates(
      Map<String, dynamic> booking,
      ) {
    final List<String> dates = [];

    final dueDate = (booking['dueDate'] ?? '').toString().trim();

    if (dueDate.isNotEmpty) {
      final normalized = _normalizeDueDateToFullYear(dueDate);
      if (normalized.isNotEmpty) {
        dates.add(normalized);
      }
    }

    if (dates.isEmpty) {
      final visitDate1 = (booking['visitDate1'] ?? '').toString().trim();

      if (visitDate1.isNotEmpty) {
        final normalized = _normalizeIsoDateToDisplayDate(visitDate1);
        if (normalized.isNotEmpty) {
          dates.add(normalized);
        }
      }
    }

    if (dates.isEmpty) {
      final startDate = (booking['startDate'] ?? '').toString().trim();

      if (startDate.isNotEmpty) {
        final normalized = _normalizeIsoDateToDisplayDate(startDate);
        if (normalized.isNotEmpty) {
          dates.add(normalized);
        }
      }
    }

    return dates;
  }

  static String _normalizeDueDateToFullYear(dynamic rawDate) {
    final value = (rawDate ?? '').toString().trim();

    if (value.isEmpty) return '';

    try {
      final parts = value.split('-');

      if (parts.length != 3) return value;

      final day = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final rawYear = int.parse(parts[2]);
      final year = parts[2].length == 2 ? 2000 + rawYear : rawYear;

      return '${day.toString().padLeft(2, '0')}-'
          '${month.toString().padLeft(2, '0')}-$year';
    } catch (_) {
      return value;
    }
  }

  static String _normalizeIsoDateToDisplayDate(dynamic rawDate) {
    final value = (rawDate ?? '').toString().trim();

    if (value.isEmpty) return '';

    try {
      final parts = value.split('-');

      if (parts.length != 3) return value;

      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final day = int.parse(parts[2]);

      return '${day.toString().padLeft(2, '0')}-'
          '${month.toString().padLeft(2, '0')}-$year';
    } catch (_) {
      return value;
    }
  }

  // =========================
  // CANCEL VISIT
  // =========================
  static Future<Map<String, dynamic>> cancelExpertVisit({
    required String userId,
    required String visitId,
  }) async {
    try {
      final data = await _post(_cancelVisitUrl, {
        'userID': userId,
        'visitID': visitId,
        'status': 'Cancelled',
      });

      if (data is Map<String, dynamic>) {
        return data;
      }

      return {
        'success': true,
        'message': 'Visit cancelled successfully',
        'data': data,
      };
    } catch (e) {
      throw Exception('Error cancelling expert visit: $e');
    }
  }

  // =========================
  // RESCHEDULE VISIT
  // =========================
  static Future<Map<String, dynamic>> rescheduleExpertVisit({
    required String userId,
    required String visitId,
    required String dateOfVisit,
    required String timeOfVisit,
  }) async {
    try {
      final data = await _post(_rescheduleVisitUrl, {
        'userID': userId,
        'visitID': visitId,
        'dateOfVisit': dateOfVisit,
        'timeOfVisit': timeOfVisit,
      });

      if (data is Map<String, dynamic>) {
        return data;
      }

      return {
        'success': true,
        'message': 'Visit rescheduled successfully',
        'data': data,
      };
    } catch (e) {
      throw Exception('Error rescheduling expert visit: $e');
    }
  }

  // =========================
  // FETCH EXPERT RECOMMENDATIONS
  // =========================
  static Future<List<dynamic>> fetchExpertRecommendations(
      String userId,
      ) async {
    try {
      final data = await _post(_expertRecommendationsUrl, {
        'userID': userId,
      });

      debugPrint('Expert recommendation raw response: $data');

      if (data is List) {
        return data;
      }

      if (data is Map<String, dynamic>) {
        if (data['recommendations'] is List) {
          return data['recommendations'] as List;
        }

        if (data['items'] is List) {
          return data['items'] as List;
        }

        if (data['data'] is List) {
          return data['data'] as List;
        }

        if (data['recommendation'] is Map) {
          return [data['recommendation']];
        }

        if (data['item'] is Map) {
          return [data['item']];
        }
      }

      throw Exception('Invalid recommendations response format: $data');
    } catch (e) {
      throw Exception('Error fetching expert recommendations: $e');
    }
  }

  // =========================
  // CREATE ZOHO DEAL
  // =========================
  static Future<dynamic> postZohoDeal(
      Map<String, dynamic> body,
      ) async {
    try {
      return await _post(_zohoDealUrl, body);
    } catch (e) {
      throw Exception('Failed to create Zoho deal: $e');
    }
  }

  // =========================
  // CREATE ZOHO PAYMENT SESSION
  // =========================
  static Future<Map<String, dynamic>> createZohoPaymentSession({
    required String userId,
    required double amount,
    required String currency,
    required String description,
    required String customerName,
    required String customerPhone,
    required String customerEmail,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final data = await _post(_zohoCreatePaymentSessionUrl, {
        'userId': userId,
        'amount': amount,
        'currency': currency,
        'description': description,
        'customerName': customerName,
        'customerPhone': customerPhone,
        'customerEmail': customerEmail,
        'metadata': metadata ?? {},
      });

      if (data is Map<String, dynamic>) {
        return data;
      }

      throw Exception('Invalid Zoho payment session response');
    } catch (e) {
      throw Exception('Failed to create Zoho payment session: $e');
    }
  }

  // =========================
  // VERIFY ZOHO PAYMENT
  // =========================
  static Future<Map<String, dynamic>> verifyZohoPayment({
    required String paymentId,
    required String paymentSessionId,
    required String signature,
  }) async {
    try {
      final data = await _post(_zohoVerifyPaymentUrl, {
        'paymentId': paymentId,
        'paymentSessionId': paymentSessionId,
        'signature': signature,
      });

      if (data is Map<String, dynamic>) {
        return data;
      }

      throw Exception('Invalid Zoho payment verify response');
    } catch (e) {
      throw Exception('Failed to verify Zoho payment: $e');
    }
  }
}