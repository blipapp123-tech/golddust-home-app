import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zoho_payments_flutter_sdk/zoho_payments_flutter_sdk.dart';
import 'subscription_details_screen.dart';
import '../app/app_constants.dart';
import '../services/booking_service.dart';
import 'add_products_for_next_visit_screen.dart';
import 'cart_screen.dart';
import 'reschedule_booking_screen.dart';
import 'view_products_for_booking_screen.dart';

class ZohoBookingScreen extends StatefulWidget {
  final String userId;
  final String userName;
  final String profilePhotoUrl;
  final List<Map<String, dynamic>>? bookings;

  const ZohoBookingScreen({
    super.key,
    required this.userId,
    required this.userName,
    required this.profilePhotoUrl,
    this.bookings,
  });

  @override
  State<ZohoBookingScreen> createState() => _ZohoBookingScreenState();
}

class _ZohoBookingScreenState extends State<ZohoBookingScreen> {
  late List<Map<String, dynamic>> _bookings;

  bool _isSubmitting = false;
  bool _isSubmittingReschedule = false;
  bool _isLoadingBookings = true;

  final List<Map<String, dynamic>> _cart = [];
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _cartKey = GlobalKey();

  late Timer _countdownTimer;
  String _timeRemaining = '';
  bool _isWithinCutoff = true;

  bool _isOrderingAllowed = false;
  String _nextEligibleBookingDate = '';
  String _nextFutureDate = '';

  final Map<String, int> _selectedDateIndexMap = {};

  final ZohoPaymentsFlutterSdk _zohoSdk = ZohoPaymentsFlutterSdk();
  String? _currentPaymentSessionId;
  Map<String, dynamic>? _currentBooking;

  static const String _zohoCreatePaymentSessionUrl =
      'https://vztxhparhd.execute-api.ap-south-1.amazonaws.com/zohoPaymentSessionCreation';

  static const String _zohoVerifyPaymentUrl =
      'https://zus3h9i198.execute-api.ap-south-1.amazonaws.com/zohoPaymentVerify';

  static const String _zohoMarkRenewalPaidUrl =
      'https://ajq2lycd22.execute-api.ap-south-1.amazonaws.com/markRenewalPendinFalse';

  static const String _fetchZohoBookingsUrl =
      'https://u53ghj7ip8.execute-api.ap-south-1.amazonaws.com/zohoBookingsWithUserId';

  static const String _fetchBookingCatalogUrl =
      'https://lhz6z20eg6.execute-api.ap-south-1.amazonaws.com/default/fetchInventoryForBookingCatalog';

  bool get _hasPendingRenewalPayment {
    return _bookings.any((b) => _isRenewalPaymentPending(b));
  }

  Map<String, dynamic>? get _firstPendingRenewalBooking {
    try {
      return _bookings.firstWhere((b) => _isRenewalPaymentPending(b));
    } catch (_) {
      return null;
    }
  }

  bool get _shouldShowSubscriptionExpiredOnly {
    if (_bookings.isEmpty) return false;
    if (_hasPendingRenewalPayment) return false;
    return _bookings.every((b) => _isSubscriptionExpired(b));
  }

  @override
  void initState() {
    super.initState();
    _bookings = widget.bookings ?? [];
    _loadCart();
    _initZohoPayments();
    _startCountdownTimer();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchZohoBookings();
    });
  }

  @override
  void dispose() {
    _countdownTimer.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initZohoPayments() async {
    try {
      await _zohoSdk.initialize(
        apiKey: BookingService.zohoPaymentsApiKey,
        accountId: BookingService.zohoPaymentsAccountId,
      );
    } catch (_) {}
  }

  bool _isRenewalPaymentPending(Map<String, dynamic> booking) {
    final value = booking['renewalPaymentPending'];

    if (value is bool) return value;

    if (value is String) {
      final v = value.trim().toLowerCase();
      return v == 'true' || v == 'yes' || v == '1' || v == 'pending';
    }

    if (value is num) return value == 1;

    return false;
  }

  Future<void> _markRenewalPaymentPendingFalse() async {
    final response = await http.post(
      Uri.parse(_zohoMarkRenewalPaidUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'userID': widget.userId,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to update renewalPaymentPending: ${response.body}',
      );
    }
  }

  Future<Map<String, dynamic>> _createZohoPaymentSession({
    required String userId,
    required double amount,
    required String currency,
    required String description,
    required String customerName,
    required String customerPhone,
    required String customerEmail,
    Map<String, dynamic>? metadata,
  }) async {
    final response = await http.post(
      Uri.parse(_zohoCreatePaymentSessionUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'userId': userId,
        'amount': amount,
        'currency': currency,
        'description': description,
        'customerName': customerName,
        'customerPhone': customerPhone,
        'customerEmail': customerEmail,
        'metadata': metadata ?? {},
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to create Zoho payment session: ${response.body}');
  }

  Future<Map<String, dynamic>> _verifyZohoPayment({
    required String paymentId,
    required String paymentSessionId,
    required String signature,
  }) async {
    final response = await http.post(
      Uri.parse(_zohoVerifyPaymentUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'paymentId': paymentId,
        'paymentSessionId': paymentSessionId,
        'signature': signature,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to verify Zoho payment: ${response.body}');
  }

  Future<void> _handleZohoPayment(Map<String, dynamic> booking) async {
    final amount = (booking['bookingAmount'] ?? 0).toDouble();
    final mobile = (booking['Mobile'] ?? '').toString().trim();

    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid renewal amount. Please contact support.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      _currentBooking = booking;

      final sessionResponse = await _createZohoPaymentSession(
        userId: widget.userId,
        amount: amount,
        currency: 'INR',
        description: 'Pending Renewal Payment - ${booking['planName'] ?? 'Plan'}',
        customerName: widget.userName,
        customerPhone: mobile,
        customerEmail: '',
        metadata: {
          'userId': widget.userId,
          'bookingId': booking['bookingID'] ?? '',
          'planName': booking['planName'] ?? '',
          'flow': 'pending_renewal_payment',
        },
      );

      final paymentSessionId =
          sessionResponse['payment_session_id']?.toString() ??
              sessionResponse['paymentSessionId']?.toString();

      if (paymentSessionId == null || paymentSessionId.isEmpty) {
        throw Exception('payment_session_id missing from backend response');
      }

      _currentPaymentSessionId = paymentSessionId;

      final options = ZohoPaymentsCheckoutOptions(
        paymentSessionId: paymentSessionId,
        description: 'Pending Renewal Payment - ${booking['planName'] ?? 'Plan'}',
        invoiceNumber: 'REN-${DateTime.now().millisecondsSinceEpoch}',
        referenceNumber: widget.userId,
        name: widget.userName,
        email: '',
        phone: mobile,
      );

      final result = await _zohoSdk.showCheckout(
        options,
        domain: ZohoPaymentsDomain.india,
        environment: ZohoPaymentsEnvironment.live,
      )
          .timeout(
        const Duration(seconds: 25),
        onTimeout: () {
          throw Exception(
            'Payment page did not open. Please check internet and try again.',
          );
        },
      );

      switch (result) {
        case ZohoPaymentsSuccess():
          await _handleZohoPaymentSuccess(
            paymentId: result.paymentId,
            signature: result.signature,
          );
          break;
        case ZohoPaymentsFailure():
          _handleZohoPaymentFailure(
            code: result.code,
            message: result.message,
          );
          break;
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error initiating payment: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _handleZohoPaymentSuccess({
    required String paymentId,
    required String signature,
  }) async {
    try {
      final verifyResponse = await _verifyZohoPayment(
        paymentId: paymentId,
        paymentSessionId: _currentPaymentSessionId ?? '',
        signature: signature,
      );

      final status = verifyResponse['status']?.toString().toLowerCase() ?? '';

      final verified = verifyResponse['verified'] == true ||
          status == 'success' ||
          status == 'succeeded' ||
          status == 'paid' ||
          status == 'captured' ||
          status == 'completed';

      if (!verified) {
        throw Exception('Payment could not be verified');
      }

      await _markRenewalPaymentPendingFalse();
      await _fetchZohoBookings();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment completed successfully.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Payment received, but verification failed. Please contact support.',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _handleZohoPaymentFailure({
    required String code,
    required String message,
  }) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message.isNotEmpty
              ? message
              : 'Payment failed or cancelled. Please try again.',
        ),
        backgroundColor: Colors.red,
      ),
    );
  }

  Future<void> _fetchZohoBookings() async {
    setState(() => _isLoadingBookings = true);

    try {
      final res = await http.post(
        Uri.parse(_fetchZohoBookingsUrl),
        body: jsonEncode({'userID': widget.userId}),
        headers: {'Content-Type': 'application/json'},
      );

      if (res.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(res.body);
        final transformedBookings = _transformZohoBookings(data);

        final activeBookingsOnly = transformedBookings.where((booking) {
          final dealStatus =
          (booking['dealStatus'] ?? '').toString().trim().toLowerCase();
          return dealStatus == 'active';
        }).toList();

        setState(() {
          _bookings = activeBookingsOnly;
          _isLoadingBookings = false;
        });

        _updateOrderingEligibility();
      } else {
        setState(() => _isLoadingBookings = false);
      }
    } catch (_) {
      setState(() => _isLoadingBookings = false);
    }
  }

  List<Map<String, dynamic>> _transformZohoBookings(
      Map<String, dynamic> response,
      ) {
    final List<Map<String, dynamic>> transformedBookings = [];

    if (response.containsKey('bookings') && response['bookings'] is List) {
      final bookingsList = response['bookings'] as List;

      for (final raw in bookingsList) {
        if (raw is! Map) continue;

        final booking = Map<String, dynamic>.from(raw);

        final dueDate = (booking['dueDate'] ?? '').toString().trim();
        final visitTimeSlot =
        (booking['visitTimeSlot1'] ?? booking['timeSlot'] ?? '').toString();

        final status = (booking['status'] ?? '').toString().trim();
        final normalizedStatus = status.toLowerCase();

        final isDone = normalizedStatus == 'done' ||
            normalizedStatus == 'completed' ||
            normalizedStatus == 'complete' ||
            normalizedStatus == 'closed' ||
            normalizedStatus == 'finished' ||
            normalizedStatus == 'visit completed' ||
            normalizedStatus == 'service completed';

        transformedBookings.add({
          ...booking,

          'bookingID': booking['taskID'] ??
              booking['bookingID'] ??
              booking['visitID'] ??
              '',
          'taskID': booking['taskID'] ?? '',
          'dealID': booking['dealID'] ?? '',
          'bookingType': 'monthlySubscription',
          'planName': booking['planName'] ?? 'Standard Plan',
          'bookingAmount':
          int.tryParse((booking['monthlyAmount'] ?? '0').toString()) ?? 0,
          'maaliNo': booking['assignedMaliId'] ?? booking['maaliNo'] ?? '',
          'assignedMali': booking['assignedMali'] ?? '',
          'subscriptionStatus': booking['subscriptionStatus'] ?? 'Active',
          'startDate': booking['startDate'] ?? '',
          'dueDate': dueDate,
          'date': dueDate,
          'timeSlot': visitTimeSlot,
          'visitTimeSlot1': visitTimeSlot,
          'status': status,
          'isDone': isDone,
          'dealStatus': booking['dealStatus'] ?? '',
          'renewalPaymentPending': booking['renewalPaymentPending'] ?? '',
          'bookedDates': dueDate.isNotEmpty ? [dueDate] : <String>[],
          'dayTimeSlots': [
            {
              'day': booking['visitDay1'] ?? '',
              'timeSlot': visitTimeSlot,
            }
          ],
        });
      }
    }

    return transformedBookings;
  }

  List<String> _generateBookedDatesFromDueDates(Map<String, dynamic> booking) {
    final List<String> dates = [];

    if (booking.containsKey('dueDate')) {
      final dueDate = booking['dueDate'] as String;
      try {
        final parts = dueDate.split('-');
        if (parts.length == 3) {
          final year = int.parse(parts[2]) + 2000;
          final month = int.parse(parts[1]);
          final day = int.parse(parts[0]);
          dates.add(
            '${day.toString().padLeft(2, '0')}-${month.toString().padLeft(2, '0')}-$year',
          );
        }
      } catch (_) {}
    }

    if (dates.isEmpty && booking.containsKey('startDate')) {
      final startDate = booking['startDate'] as String;
      try {
        final parts = startDate.split('-');
        if (parts.length == 3) {
          final year = int.parse(parts[0]);
          final month = int.parse(parts[1]);
          final day = int.parse(parts[2]);

          dates.add(
            '${day.toString().padLeft(2, '0')}-${month.toString().padLeft(2, '0')}-$year',
          );

          if (booking.containsKey('visitDay1')) {
            DateTime currentDate = DateTime(year, month, day);
            for (int i = 1; i <= 3; i++) {
              currentDate = currentDate.add(const Duration(days: 7));
              dates.add(
                '${currentDate.day.toString().padLeft(2, '0')}-${currentDate.month.toString().padLeft(2, '0')}-${currentDate.year}',
              );
            }
          }
        }
      } catch (_) {}
    }

    return dates;
  }

  bool _isSubscriptionExpired(Map<String, dynamic> booking) {
    try {
      if (booking['bookingType'] == 'monthlySubscription') {
        final bookedDates = (booking['bookedDates'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .where((e) => e.trim().isNotEmpty)
            .toList() ??
            [];

        if (bookedDates.isEmpty) return true;

        bookedDates.sort((a, b) {
          final aParts = a.split('-');
          final bParts = b.split('-');

          final aDate = DateTime(
            int.parse(aParts[2]),
            int.parse(aParts[1]),
            int.parse(aParts[0]),
          );

          final bDate = DateTime(
            int.parse(bParts[2]),
            int.parse(bParts[1]),
            int.parse(bParts[0]),
          );

          return aDate.compareTo(bDate);
        });

        final lastDateStr = bookedDates.last;
        final parts = lastDateStr.split('-');

        final lastVisitEnd = DateTime(
          int.parse(parts[2]),
          int.parse(parts[1]),
          int.parse(parts[0]),
          23,
          59,
          59,
        );

        return DateTime.now().isAfter(lastVisitEnd);
      }

      if (booking['bookingType'] == 'oneTime') {
        final dateStr = (booking['date'] ?? '').toString().trim();
        if (dateStr.isEmpty) return true;

        final parts = dateStr.split('-');
        int year = int.parse(parts[2]);
        if (year < 100) year += 2000;

        final visitEnd = DateTime(
          year,
          int.parse(parts[1]),
          int.parse(parts[0]),
          23,
          59,
          59,
        );

        return DateTime.now().isAfter(visitEnd);
      }
    } catch (_) {}

    return false;
  }

  void _updateTimeRemaining() {
    final now = DateTime.now();
    final targetDateStr = _nextEligibleBookingDate.isNotEmpty
        ? _nextEligibleBookingDate
        : _nextFutureDate;

    if (targetDateStr.isEmpty) {
      setState(() {
        _timeRemaining = '00:00:00';
        _isWithinCutoff = false;
      });
      return;
    }

    try {
      final parts = targetDateStr.split('-');
      final bookingDate = DateTime(
        int.parse(parts[2]),
        int.parse(parts[1]),
        int.parse(parts[0]),
      );

      final cutoffDate = bookingDate.subtract(const Duration(days: 1));
      final cutoffTime =
      DateTime(cutoffDate.year, cutoffDate.month, cutoffDate.day, 15, 0);

      if (now.isBefore(cutoffTime)) {
        final difference = cutoffTime.difference(now);
        final hours = difference.inHours;
        final minutes = difference.inMinutes % 60;
        final seconds = difference.inSeconds % 60;

        setState(() {
          _timeRemaining =
          '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
          _isWithinCutoff = true;
        });
      } else {
        setState(() {
          _timeRemaining = '00:00:00';
          _isWithinCutoff = false;
        });
      }
    } catch (_) {
      setState(() {
        _timeRemaining = '00:00:00';
        _isWithinCutoff = false;
      });
    }

    _updateOrderingEligibility();
  }

  void _startCountdownTimer() {
    _updateTimeRemaining();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) _updateTimeRemaining();
    });
  }

  void _updateOrderingEligibility() {
    if (_bookings.isEmpty) {
      setState(() {
        _isOrderingAllowed = false;
        _nextEligibleBookingDate = '';
        _nextFutureDate = '';
      });
      return;
    }

    final activeBookings =
    _bookings.where((b) => !_isSubscriptionExpired(b)).toList();

    if (activeBookings.isEmpty) {
      setState(() {
        _isOrderingAllowed = false;
        _nextEligibleBookingDate = '';
        _nextFutureDate = '';
      });
      return;
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final List<Map<String, dynamic>> allEligibleDates = [];
    String overallFutureDate = '';

    for (final activeBooking in activeBookings) {
      try {
        if (activeBooking['bookingType'] == 'monthlySubscription') {
          final rawDates = activeBooking['bookedDates'] as List<dynamic>? ?? [];
          final cleanedDates = rawDates
              .map((e) => e.toString())
              .where((s) => s.trim().isNotEmpty)
              .toList();

          cleanedDates.sort((a, b) {
            final aParts = a.split('-');
            final bParts = b.split('-');
            final aDate = DateTime(
              int.parse(aParts[2]),
              int.parse(aParts[1]),
              int.parse(aParts[0]),
            );
            final bDate = DateTime(
              int.parse(bParts[2]),
              int.parse(bParts[1]),
              int.parse(bParts[0]),
            );
            return aDate.compareTo(bDate);
          });

          for (final dateStr in cleanedDates) {
            final parts = dateStr.split('-');
            final bookingDate = DateTime(
              int.parse(parts[2]),
              int.parse(parts[1]),
              int.parse(parts[0]),
            );

            if (bookingDate.isAfter(today) ||
                bookingDate.isAtSameMomentAs(today)) {
              if (overallFutureDate.isEmpty ||
                  bookingDate.isBefore(
                    DateTime(
                      int.parse(overallFutureDate.split('-')[2]),
                      int.parse(overallFutureDate.split('-')[1]),
                      int.parse(overallFutureDate.split('-')[0]),
                    ),
                  )) {
                overallFutureDate = dateStr;
              }
              break;
            }
          }

          for (final dateStr in cleanedDates) {
            final parts = dateStr.split('-');
            final bookingDate = DateTime(
              int.parse(parts[2]),
              int.parse(parts[1]),
              int.parse(parts[0]),
            );
            final cutoffDate = bookingDate.subtract(const Duration(days: 1));
            final cutoffTime = DateTime(
              cutoffDate.year,
              cutoffDate.month,
              cutoffDate.day,
              15,
              0,
            );

            if (now.isBefore(cutoffTime)) {
              allEligibleDates.add({
                'date': dateStr,
                'bookingDate': bookingDate,
                'cutoffTime': cutoffTime,
              });
            }
          }
        }
      } catch (_) {}
    }

    allEligibleDates.sort(
          (a, b) => a['cutoffTime'].compareTo(b['cutoffTime']),
    );

    setState(() {
      _isOrderingAllowed = allEligibleDates.isNotEmpty;
      _nextEligibleBookingDate =
      allEligibleDates.isNotEmpty ? allEligibleDates.first['date'] : '';
      _nextFutureDate = overallFutureDate;
    });
  }

  bool _canModifyVisit(String dateStr) {
    try {
      final parts = dateStr.split('-');
      if (parts.length != 3) return false;

      final day = int.parse(parts[0]);
      final month = int.parse(parts[1]);

      int year = int.parse(parts[2]);
      if (year < 100) year += 2000;

      final bookingDate = DateTime(year, month, day);
      final cutoffDate = bookingDate.subtract(const Duration(days: 1));

      final cutoffTime = DateTime(
        cutoffDate.year,
        cutoffDate.month,
        cutoffDate.day,
        23,
        59,
      );

      return DateTime.now().isBefore(cutoffTime);
    } catch (_) {
      return false;
    }
  }

  String _getVisitModificationCutoffText(String dateStr) {
    try {
      final parts = dateStr.split('-');
      if (parts.length != 3) return '11:59 PM one day before';

      final day = int.parse(parts[0]);
      final month = int.parse(parts[1]);

      int year = int.parse(parts[2]);
      if (year < 100) year += 2000;

      final bookingDate = DateTime(year, month, day);
      final cutoffDate = bookingDate.subtract(const Duration(days: 1));

      return '${cutoffDate.day.toString().padLeft(2, '0')}-'
          '${cutoffDate.month.toString().padLeft(2, '0')}-'
          '${cutoffDate.year} at 11:59 PM';
    } catch (_) {
      return '11:59 PM one day before';
    }
  }

  bool _isWithinCutoffForDate(String dateStr) {
    try {
      final parts = dateStr.split('-');
      final bookingDate = DateTime(
        int.parse(parts[2]),
        int.parse(parts[1]),
        int.parse(parts[0]),
      );
      final now = DateTime.now();
      final cutoffDate = bookingDate.subtract(const Duration(days: 1));
      final cutoffTime =
      DateTime(cutoffDate.year, cutoffDate.month, cutoffDate.day, 15, 0);
      return now.isBefore(cutoffTime);
    } catch (_) {
      return false;
    }
  }

  String _getCutoffDateString(String bookingDate) {
    try {
      final parts = bookingDate.split('-');
      final date = DateTime(
        int.parse(parts[2]),
        int.parse(parts[1]),
        int.parse(parts[0]),
      );
      final cutoffDate = date.subtract(const Duration(days: 1));
      return '${cutoffDate.day.toString().padLeft(2, '0')}-${cutoffDate.month.toString().padLeft(2, '0')}-${cutoffDate.year}';
    } catch (_) {
      return 'the day before';
    }
  }

  Future<void> _saveCart() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('mali_cart', jsonEncode(_cart));
  }

  Future<void> _loadCart() async {
    final prefs = await SharedPreferences.getInstance();
    final cartJson = prefs.getString('mali_cart');
    if (cartJson != null) {
      final decoded = List<Map<String, dynamic>>.from(jsonDecode(cartJson));
      setState(() {
        _cart
          ..clear()
          ..addAll(decoded);
      });
    }
  }

  Future<void> _skipWeekForBooking({
    required Map<String, dynamic> booking,
    required String dueDate,
  }) async {
    setState(() => _isSubmittingReschedule = true);

    try {
      final res = await http.post(
        Uri.parse(
          'https://6q24qsrxu4.execute-api.ap-south-1.amazonaws.com/bookingsSkipCompletely',
        ),
        body: jsonEncode({
          'userID': widget.userId,
          'dueDate': dueDate,
        }),
        headers: {'Content-Type': 'application/json'},
      );

      if (res.statusCode == 200) {
        final Map<String, dynamic> response = jsonDecode(res.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['message'] ?? 'Week skipped successfully'),
            backgroundColor: Colors.green,
          ),
        );
        await _fetchZohoBookings();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to skip week. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Network error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmittingReschedule = false);
    }
  }

  void _showSkipWeekDialog(
      BuildContext context,
      Map<String, dynamic> booking,
      String selectedDate,
      ) {
    final canModify = _canModifyVisit(selectedDate);

    if (!canModify) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Skipping visit for $selectedDate is allowed only until ${_getVisitModificationCutoffText(selectedDate)}.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Skip Week',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Are you sure you want to skip this week\'s visit?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);

              String dueDate = selectedDate;
              final parts = selectedDate.split('-');
              if (parts.length == 3 && parts[2].length == 4) {
                dueDate = '${parts[0]}-${parts[1]}-${parts[2].substring(2)}';
              }

              await _skipWeekForBooking(
                booking: booking,
                dueDate: dueDate,
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text(
              'Skip Week',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _showRescheduleDialog(
      BuildContext context,
      Map<String, dynamic> booking,
      String selectedDate,
      String assignedMali,
      ) {
    final canModify = _canModifyVisit(selectedDate);

    if (!canModify) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Rescheduling for $selectedDate is allowed only until ${_getVisitModificationCutoffText(selectedDate)}.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final parts = selectedDate.split('-');

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RescheduleBookingScreen(
          userId: widget.userId,
          userName: widget.userName,
          booking: booking,
          oldDate: '${parts[0]}-${parts[1]}-${parts[2].substring(2)}',
          assignedMaliId: booking['maaliNo'] ?? '',
        ),
      ),
    ).then((val) {
      if (val == true) _fetchZohoBookings();
    });
  }

  Future<void> _proceedToCartWithDate(
      String bookingDate,
      Map<String, dynamic> activeBooking,
      ) async {
    final bookingID = activeBooking['bookingID'] ?? '';

    final confirmed = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CartScreen(
          cartItems: _cart,
          onCartUpdated: (updatedCart) {
            setState(() {
              _cart
                ..clear()
                ..addAll(updatedCart);
            });
            _saveCart();
          },
          bookingID: bookingID,
          userID: widget.userId,
          date: bookingDate,
        ),
      ),
    );

    if (confirmed == true) {
      setState(() => _cart.clear());
      _saveCart();
    }
  }

  Map<String, dynamic> _buildSubscriptionDetailsBookingFromZohoRows() {
    final sortedBookings = List<Map<String, dynamic>>.from(_bookings);

    sortedBookings.sort((a, b) {
      final aDate = _parseBookingDate((a['dueDate'] ?? a['date'] ?? '').toString());
      final bDate = _parseBookingDate((b['dueDate'] ?? b['date'] ?? '').toString());

      if (aDate == null && bDate == null) return 0;
      if (aDate == null) return 1;
      if (bDate == null) return -1;

      return aDate.compareTo(bDate);
    });

    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);

    Map<String, dynamic>? nearestUpcomingBooking;

    for (final booking in sortedBookings) {
      final dateStr = (booking['dueDate'] ?? booking['date'] ?? '').toString();
      final parsed = _parseBookingDate(dateStr);
      if (parsed == null) continue;

      final dateOnly = DateTime(parsed.year, parsed.month, parsed.day);

      if (!dateOnly.isBefore(todayOnly)) {
        nearestUpcomingBooking = booking;
        break;
      }
    }

    nearestUpcomingBooking ??=
    sortedBookings.isNotEmpty ? sortedBookings.last : <String, dynamic>{};

    final allBookedDates = <String>[];
    final allScheduledVisits = <Map<String, dynamic>>[];

    for (final booking in sortedBookings) {
      final date = (booking['dueDate'] ?? booking['date'] ?? '').toString().trim();
      if (date.isEmpty) continue;

      final parsed = _parseBookingDate(date);
      if (parsed == null) continue;

      final dateOnly = DateTime(parsed.year, parsed.month, parsed.day);

      final status = (booking['status'] ?? '').toString().trim();
      final normalizedStatus = status.toLowerCase();

      final isDone = normalizedStatus == 'done' ||
          normalizedStatus == 'completed' ||
          normalizedStatus == 'complete' ||
          normalizedStatus == 'closed' ||
          normalizedStatus == 'finished' ||
          normalizedStatus == 'visit completed' ||
          normalizedStatus == 'service completed';

      if (!allBookedDates.contains(date)) {
        allBookedDates.add(date);
      }

      allScheduledVisits.add({
        'date': date,
        'dueDate': date,
        'mali': booking['assignedMali'] ?? booking['maaliName'] ?? 'Not assigned',
        'assignedMali': booking['assignedMali'] ?? booking['maaliName'] ?? 'Not assigned',
        'assignedMaliId': booking['assignedMaliId'] ?? booking['maaliNo'] ?? '',
        'maaliNo': booking['assignedMaliId'] ?? booking['maaliNo'] ?? '',
        'timeSlot': booking['visitTimeSlot1'] ?? booking['timeSlot'] ?? 'N/A',
        'bookingID': booking['bookingID'] ?? '',
        'taskID': booking['taskID'] ?? '',
        'dealID': booking['dealID'] ?? '',
        'planName': booking['planName'] ?? '',
        'status': status,
        'visitStatus': status,
        'isDone': isDone,
        'booking': Map<String, dynamic>.from(booking),
        'isPast': dateOnly.isBefore(todayOnly),
        'isToday': dateOnly.isAtSameMomentAs(todayOnly),
        'isFuture': dateOnly.isAfter(todayOnly),
      });
    }

    allBookedDates.sort((a, b) {
      final aDate = _parseBookingDate(a) ?? DateTime(2100);
      final bDate = _parseBookingDate(b) ?? DateTime(2100);
      return aDate.compareTo(bDate);
    });

    allScheduledVisits.sort((a, b) {
      final aDate = _parseBookingDate(a['date'].toString()) ?? DateTime(2100);
      final bDate = _parseBookingDate(b['date'].toString()) ?? DateTime(2100);
      return aDate.compareTo(bDate);
    });

    final merged = Map<String, dynamic>.from(nearestUpcomingBooking);

    merged['bookingType'] = 'monthlySubscription';
    merged['bookedDates'] = allBookedDates;
    merged['allScheduledVisits'] = allScheduledVisits;
    merged['rawZohoBookings'] = sortedBookings;

    merged['dueDate'] =
        (nearestUpcomingBooking['dueDate'] ?? nearestUpcomingBooking['date'] ?? '')
            .toString();

    merged['date'] = merged['dueDate'];

    merged['visitTimeSlot1'] =
        (nearestUpcomingBooking['visitTimeSlot1'] ??
            nearestUpcomingBooking['timeSlot'] ??
            '')
            .toString();

    merged['timeSlot'] = merged['visitTimeSlot1'];

    merged['planName'] = nearestUpcomingBooking['planName'] ?? 'Current Plan';
    merged['assignedMali'] =
        nearestUpcomingBooking['assignedMali'] ?? 'Not assigned';
    merged['maaliNo'] =
        nearestUpcomingBooking['assignedMaliId'] ??
            nearestUpcomingBooking['maaliNo'] ??
            '';
    merged['subscriptionStatus'] =
        nearestUpcomingBooking['subscriptionStatus'] ?? 'Active';
    merged['dealStatus'] = nearestUpcomingBooking['dealStatus'] ?? 'Active';

    debugPrint('✅ SubscriptionDetails merged booking visits: ${allScheduledVisits.length}');
    debugPrint('✅ SubscriptionDetails merged booking: $merged');

    return merged;
  }

  DateTime? _parseBookingDate(String value) {
    try {
      final clean = value.trim();
      if (clean.isEmpty) return null;

      final parts = clean.split('-');
      if (parts.length != 3) return null;

      final day = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final rawYear = int.parse(parts[2]);
      final year = parts[2].length == 2 ? 2000 + rawYear : rawYear;

      return DateTime(year, month, day);
    } catch (_) {
      return null;
    }
  }

  void _openSubscriptionDetailsScreen() {
    debugPrint('OPEN SUBSCRIPTION DETAILS SCREEN');

    if (_bookings.isEmpty) return;

    final booking = _buildSubscriptionDetailsBookingFromZohoRows();

    debugPrint('🧾 Passing allScheduledVisits count: '
        '${booking['allScheduledVisits'] is List ? booking['allScheduledVisits'].length : 0}');

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SubscriptionDetailsScreen(
          booking: booking,
          userId: widget.userId,
          userName: widget.userName,
          profilePhotoUrl: widget.profilePhotoUrl,
          cartItems: _cart,
          nextEligibleBookingDate: _nextEligibleBookingDate,
          nextFutureDate: _nextFutureDate,
          timeRemaining: _timeRemaining,
          isWithinCutoff: _isWithinCutoff,
          fetchCatalogUrl: _fetchBookingCatalogUrl,
          onCartUpdated: (updatedCart) {
            setState(() {
              _cart
                ..clear()
                ..addAll(updatedCart);
            });
            _saveCart();
          },
          onRefreshRequested: _fetchZohoBookings,
          onSkipWeek: _skipWeekForBooking,
          canModifyVisit: _canModifyVisit,
          getVisitModificationCutoffText: _getVisitModificationCutoffText,
          getCutoffDateString: _getCutoffDateString,
        ),
      ),
    );
  }

  Widget _buildAddProductsEntryCard(String nextBookingDate) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () async {
        final activeBooking = _bookings.firstWhere(
              (booking) => !_isSubscriptionExpired(booking),
          orElse: () => _bookings.first,
        );

        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AddProductsForNextVisitScreen(
              userID: widget.userId,
              bookingID: activeBooking['bookingID'] ?? '',
              visitDate: nextBookingDate,
              cartItems: _cart,
              fetchCatalogUrl: _fetchBookingCatalogUrl,
              onCartUpdated: (updatedCart) {
                setState(() {
                  _cart
                    ..clear()
                    ..addAll(updatedCart);
                });
                _saveCart();
              },
            ),
          ),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.primaryColor.withOpacity(0.08),
              Colors.green.shade50,
            ],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: AppColors.primaryColor.withOpacity(0.18),
          ),
        ),
        child: Row(
          children: [
            Container(
              height: 54,
              width: 54,
              decoration: BoxDecoration(
                color: AppColors.primaryColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.add_shopping_cart_rounded,
                color: AppColors.primaryColor,
              ),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Add products for next visit',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Browse plants, planters, grow bags, seeds and more',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 18,
              color: AppColors.primaryColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.calendar_month_outlined,
              size: 72,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 14),
            const Text(
              'No active plan found',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your active subscription visits will appear here once your plan is created.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanOverviewCard() {
    final booking = _bookings.first;
    final planName = (booking['planName'] ?? 'Plan').toString();
    final amount = (booking['bookingAmount'] ?? 0).toString();
    final assignedMali = (booking['assignedMali'] ?? 'Not assigned').toString();
    final status = (booking['subscriptionStatus'] ?? 'Active').toString();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () {
          debugPrint('PLAN CARD TAPPED');
          _openSubscriptionDetailsScreen();
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      planName,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryColor,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 16,
                    color: AppColors.primaryColor,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildInfoPill(
                      icon: Icons.currency_rupee,
                      title: 'Monthly Amount',
                      value: '₹$amount',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildInfoPill(
                      icon: Icons.person_outline,
                      title: 'Assigned Mali',
                      value: assignedMali,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.green.withOpacity(0.25)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.verified_outlined,
                      color: Colors.green,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Subscription Status: $status',
                        style: const TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoPill({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primaryColor.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primaryColor),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showRenewalDialog(Map<String, dynamic> booking) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Subscription Expired',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Your subscription has expired. Please contact support to restart services.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingCard() {
    if (_bookings.isEmpty) return const SizedBox.shrink();
    if (_shouldShowSubscriptionExpiredOnly) return const SizedBox.shrink();

    final List<Map<String, dynamic>> allScheduledVisits = [];

    for (final booking in _bookings) {
      if (booking['bookingType'] == 'monthlySubscription') {
        final bookedDates = (booking['bookedDates'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
            [];
        final dayTimeSlots = (booking['dayTimeSlots'] as List<dynamic>?) ?? [];
        final assignedMali = booking['assignedMali'] ?? 'Not assigned';
        final timeSlot =
        dayTimeSlots.isNotEmpty ? dayTimeSlots.first['timeSlot'] ?? 'N/A' : 'N/A';
        final isExpired = _isSubscriptionExpired(booking);
        final today = DateTime(
          DateTime.now().year,
          DateTime.now().month,
          DateTime.now().day,
        );

        for (final date in bookedDates) {
          try {
            final parts = date.split('-');
            final visitDate = DateTime(
              int.parse(parts[2]),
              int.parse(parts[1]),
              int.parse(parts[0]),
            );

            allScheduledVisits.add({
              'date': date,
              'mali': assignedMali,
              'timeSlot': timeSlot,
              'bookingID': booking['bookingID'],
              'planName': booking['planName'],
              'booking': booking,
              'isPast': visitDate.isBefore(today),
              'isToday': visitDate.isAtSameMomentAs(today),
              'isFuture': visitDate.isAfter(today),
              'isExpired': isExpired,
            });
          } catch (_) {}
        }
      }
    }

    allScheduledVisits.sort((a, b) {
      final aParts = a['date'].split('-');
      final bParts = b['date'].split('-');

      return DateTime(
        int.parse(aParts[2]),
        int.parse(aParts[1]),
        int.parse(aParts[0]),
      ).compareTo(
        DateTime(
          int.parse(bParts[2]),
          int.parse(bParts[1]),
          int.parse(bParts[0]),
        ),
      );
    });

    final selectedDateIndex = _selectedDateIndexMap['global'] ?? -1;

    bool isSelectedDatePast = false;
    bool isSelectedDateToday = false;
    bool isSelectedDateFuture = false;
    bool isSelectedDateExpired = false;

    if (selectedDateIndex != -1 &&
        selectedDateIndex < allScheduledVisits.length) {
      final selectedVisit = allScheduledVisits[selectedDateIndex];
      isSelectedDatePast = selectedVisit['isPast'] ?? false;
      isSelectedDateToday = selectedVisit['isToday'] ?? false;
      isSelectedDateFuture = selectedVisit['isFuture'] ?? false;
      isSelectedDateExpired = selectedVisit['isExpired'] ?? false;
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Scheduled Visits',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 18,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${allScheduledVisits.length} visits in this cycle',
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          if (allScheduledVisits.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'No scheduled visits',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            )
          else
            SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: allScheduledVisits.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final visit = allScheduledVisits[index];
                  final dateStr = visit['date'];
                  final isPast = visit['isPast'] ?? false;
                  final isToday = visit['isToday'] ?? false;
                  final isExpired = visit['isExpired'] ?? false;
                  final isEligible =
                      !isPast && !isExpired && dateStr == _nextEligibleBookingDate;
                  final isSelected = selectedDateIndex == index;

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedDateIndexMap['global'] =
                        (selectedDateIndex == index) ? -1 : index;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primaryColor
                            : (isPast || isExpired
                            ? Colors.grey.shade200
                            : (isEligible
                            ? AppColors.primaryColor.withOpacity(0.12)
                            : (isToday
                            ? Colors.red.shade50
                            : Colors.white))),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primaryColor
                              : (isPast || isExpired
                              ? Colors.grey.shade400
                              : (isEligible
                              ? AppColors.primaryColor
                              : (isToday
                              ? Colors.red.shade300
                              : Colors.grey.shade300))),
                        ),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Center(
                        child: Text(
                          dateStr,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected || isEligible || isToday
                                ? FontWeight.w700
                                : FontWeight.normal,
                            color: isSelected
                                ? Colors.white
                                : (isPast || isExpired
                                ? Colors.grey.shade600
                                : (isEligible
                                ? AppColors.primaryColor
                                : (isToday
                                ? Colors.red.shade700
                                : Colors.black87))),
                            decoration: (isPast || isExpired)
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 14),
          if (selectedDateIndex != -1 &&
              selectedDateIndex < allScheduledVisits.length)
            Builder(
              builder: (_) {
                final selectedVisit = allScheduledVisits[selectedDateIndex];
                final selectedDateStr = selectedVisit['date']?.toString() ?? '';
                final canModifySelectedVisit = _canModifyVisit(selectedDateStr);

                return Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: (isSelectedDatePast || isSelectedDateExpired)
                          ? Colors.grey.shade300
                          : AppColors.primaryColor.withOpacity(0.15),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _detailMiniCard(
                              icon: Icons.person_outline,
                              title: 'Mali',
                              value: selectedVisit['mali']?.toString() ?? 'N/A',
                              bg: Colors.orange.shade50,
                              iconColor: Colors.orange.shade700,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _detailMiniCard(
                              icon: Icons.access_time,
                              title: 'Time',
                              value:
                              selectedVisit['timeSlot']?.toString() ?? 'N/A',
                              bg: Colors.green.shade50,
                              iconColor: Colors.green.shade700,
                            ),
                          ),
                        ],
                      ),
                      if (isSelectedDateFuture &&
                          !isSelectedDateExpired &&
                          !canModifySelectedVisit) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.orange.shade200),
                          ),
                          child: Text(
                            'Visit changes are allowed only until ${_getVisitModificationCutoffText(selectedDateStr)}',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.orange.shade900,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      if (isSelectedDateFuture && !isSelectedDateExpired)
                        if (canModifySelectedVisit)
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    _showRescheduleDialog(
                                      context,
                                      selectedVisit['booking'],
                                      selectedVisit['date'],
                                      selectedVisit['mali'],
                                    );
                                  },
                                  icon: const Icon(Icons.edit_calendar_rounded),
                                  label: const Text('Reschedule'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primaryColor,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    _showSkipWeekDialog(
                                      context,
                                      selectedVisit['booking'],
                                      selectedVisit['date'],
                                    );
                                  },
                                  icon: const Icon(Icons.skip_next_rounded),
                                  label: const Text('Skip Week'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.orange,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          )
                        else
                          const SizedBox.shrink()
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: isSelectedDatePast
                                ? Colors.green.shade50
                                : (isSelectedDateExpired
                                ? Colors.grey.shade100
                                : Colors.red.shade50),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelectedDatePast
                                  ? Colors.green.shade200
                                  : (isSelectedDateExpired
                                  ? Colors.grey.shade300
                                  : Colors.red.shade200),
                            ),
                          ),
                          child: Text(
                            isSelectedDatePast
                                ? 'Completed'
                                : (isSelectedDateExpired ? 'Expired' : 'Today'),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isSelectedDatePast
                                  ? Colors.green.shade700
                                  : (isSelectedDateExpired
                                  ? Colors.grey.shade600
                                  : Colors.red.shade700),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _detailMiniCard({
    required IconData icon,
    required String title,
    required String value,
    required Color bg,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddProductsSection() {
    if (_shouldShowSubscriptionExpiredOnly) {
      return const SizedBox.shrink();
    }

    final hasActiveBooking = _bookings.any((b) => !_isSubscriptionExpired(b));
    if (!hasActiveBooking) return const SizedBox.shrink();

    _updateOrderingEligibility();

    final nextBookingDate = _nextEligibleBookingDate;
    final nextFutureDate = _nextFutureDate;

    if (nextBookingDate.isEmpty && nextFutureDate.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Add Products for Next Visit',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              if (nextBookingDate.isNotEmpty)
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Text(
                    nextBookingDate,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade800,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (_isWithinCutoff && nextBookingDate.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.timer, size: 18, color: Colors.blue),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Order before 3:00 PM on ${_getCutoffDateString(nextBookingDate)} (Ends in $_timeRemaining)',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          _buildAddProductsEntryCard(nextBookingDate),
        ],
      ),
    );
  }

  Widget _buildRenewalPrompt() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: const Column(
        children: [
          Icon(Icons.warning_amber, size: 50, color: Colors.red),
          SizedBox(height: 16),
          Text(
            'Your subscription has expired. Please contact support to restart services.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingPaymentBanner() {
    final pendingBooking = _firstPendingRenewalBooking;
    if (pendingBooking == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange.shade800),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Renewal payment pending',
                  style: TextStyle(
                    color: Colors.orange.shade900,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Your renewal payment is pending. Please complete the payment to continue our services.',
            style: TextStyle(
              color: Colors.orange.shade900,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                _currentBooking = pendingBooking;
                _handleZohoPayment(pendingBooking);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Pay Now',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: AppColors.secondaryColor,
          appBar: AppBar(
            backgroundColor: AppColors.secondaryColor,
            elevation: 0,
            foregroundColor: AppColors.textPrimary,
            title: const Text(
              'My Plan',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            actions: [
              IconButton(
                tooltip: 'Refresh',
                onPressed: _fetchZohoBookings,
                icon: const Icon(Icons.refresh),
              ),
              if (_bookings.isNotEmpty)
                IconButton(
                  tooltip: 'View Orders',
                  icon: const Icon(Icons.receipt_long_outlined),
                  onPressed: _openSubscriptionDetailsScreen,
                ),
              if (_bookings.any((booking) => !_isSubscriptionExpired(booking)))
                Padding(
                  key: _cartKey,
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: () async {
                      if (_cart.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Your cart is empty.')),
                        );
                        return;
                      }

                      _updateOrderingEligibility();

                      final activeBooking = _bookings.firstWhere(
                            (booking) => !_isSubscriptionExpired(booking),
                        orElse: () => _bookings.first,
                      );

                      if (_bookings.every(
                            (booking) => _isSubscriptionExpired(booking),
                      )) {
                        _showRenewalDialog(_bookings.first);
                        return;
                      }

                      if (!_isOrderingAllowed) {
                        if (_nextFutureDate.isNotEmpty) {
                          if (_isWithinCutoffForDate(_nextFutureDate)) {
                            setState(() {
                              _isOrderingAllowed = true;
                              _nextEligibleBookingDate = _nextFutureDate;
                            });
                            _proceedToCartWithDate(
                              _nextFutureDate,
                              activeBooking,
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Orders for $_nextFutureDate can only be placed 24 hours before the visit.',
                                ),
                                backgroundColor: Colors.orange,
                              ),
                            );
                          }
                          return;
                        }
                        _showRenewalDialog(_bookings.first);
                        return;
                      }

                      _proceedToCartWithDate(
                        _nextEligibleBookingDate,
                        activeBooking,
                      );
                    },
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          child: Icon(
                            Icons.shopping_cart_outlined,
                            size: 28,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (_cart.isNotEmpty)
                          Positioned(
                            right: 4,
                            top: 4,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                _cart.length.toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          body: SafeArea(
            child: _isLoadingBookings
                ? const Center(
              child: CircularProgressIndicator(
                color: AppColors.primaryColor,
              ),
            )
                : _bookings.isEmpty
                ? _buildEmptyState()
                : _shouldShowSubscriptionExpiredOnly
                ? ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildRenewalPrompt(),
                const SizedBox(height: 30),
              ],
            )
                : RefreshIndicator(
              onRefresh: _fetchZohoBookings,
              color: AppColors.primaryColor,
              child: ListView(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                children: [
                  if (_hasPendingRenewalPayment)
                    _buildPendingPaymentBanner(),
                  _buildPlanOverviewCard(),
                  const SizedBox(height: 14),
                  _buildBookingCard(),
                  const SizedBox(height: 18),
                  _buildAddProductsSection(),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ),
        if (_isSubmitting)
          Container(
            color: Colors.white.withOpacity(0.85),
            child: Center(
              child: Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                decoration: BoxDecoration(
                  color: const Color(0xfff3f9f4),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.shade100.withOpacity(0.5),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.primaryColor,
                      ),
                      strokeWidth: 3,
                    ),
                    SizedBox(height: 20),
                    Text(
                      "Renewal in progress. Don't close the app",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.primaryColor,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}