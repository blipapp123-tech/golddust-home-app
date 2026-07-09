import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zoho_payments_flutter_sdk/zoho_payments_flutter_sdk.dart';

import '../app/app_constants.dart';
import '../services/booking_service.dart';
import 'zoho_booking_screen.dart';

class BookingSummaryView extends StatefulWidget {
  final String userId;
  final String userName;
  final String profilePhotoUrl;
  final Map<String, dynamic>? booking;

  const BookingSummaryView({
    super.key,
    required this.userId,
    required this.userName,
    required this.profilePhotoUrl,
    this.booking,
  });

  @override
  State<BookingSummaryView> createState() => _BookingSummaryViewState();
}

class _BookingSummaryViewState extends State<BookingSummaryView> {
  final ZohoPaymentsFlutterSdk _zohoSdk = ZohoPaymentsFlutterSdk();

  bool _isLoading = true;
  bool _isZohoSdkReady = false;
  bool _isCheckoutOpening = false;
  bool _isPostPaymentProcessing = false;
  bool _isPaying = false;

  String? _errorMessage;
  String _processingMessage = '';
  String? _currentPaymentSessionId;

  Map<String, dynamic>? _recommendation;
  final Set<int> _selectedSlotIndices = {};

  @override
  void initState() {
    super.initState();
    _loadPage();
  }

  Future<void> _loadPage() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _initZohoPayments();
      await _fetchRecommendation();

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _initZohoPayments() async {
    try {
      await _zohoSdk.initialize(
        apiKey: BookingService.zohoPaymentsApiKey,
        accountId: BookingService.zohoPaymentsAccountId,
      );

      if (!mounted) return;

      setState(() {
        _isZohoSdkReady = true;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isZohoSdkReady = false;
      });

      rethrow;
    }
  }

  Future<void> _fetchRecommendation() async {
    final data = await BookingService.fetchExpertRecommendations(widget.userId);

    if (data.isEmpty) {
      throw Exception('No subscription recommendation available yet');
    }

    final latest = Map<String, dynamic>.from(data.first as Map);

    if (!mounted) return;

    setState(() {
      _recommendation = latest;
      _selectedSlotIndices.clear();
    });
  }

  String _normalizeIndianPhone(String? raw) {
    if (raw == null) return '';

    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');

    if (digits.length == 10) return digits;

    if (digits.length == 12 && digits.startsWith('91')) {
      return digits.substring(2);
    }

    if (digits.length > 10) {
      return digits.substring(digits.length - 10);
    }

    return digits;
  }

  DateTime _parseSlotDate(String rawDate) {
    try {
      return DateFormat('dd-MM-yy').parseStrict(rawDate);
    } catch (_) {
      try {
        return DateFormat('dd-MM-yyyy').parseStrict(rawDate);
      } catch (_) {
        return DateTime.now();
      }
    }
  }

  DateTime _parseSlotDateTime(Map<String, dynamic> slot) {
    final date = _parseSlotDate((slot['date'] ?? '').toString());
    final rawTime = (slot['time'] ?? '8:00 AM').toString().trim();

    try {
      final time = DateFormat('h:mm a').parseStrict(rawTime);

      return DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    } catch (_) {
      return date;
    }
  }

  String _formatDateToYMD(String rawDate) {
    final date = _parseSlotDate(rawDate);
    return DateFormat('yyyy-MM-dd').format(date);
  }

  String _formatReadableDate(String rawDate) {
    try {
      final date = _parseSlotDate(rawDate);
      return DateFormat('dd MMM yyyy').format(date);
    } catch (_) {
      return rawDate;
    }
  }

  String _capitalizeFirstLetter(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }

  int get _frequency {
    return int.tryParse(_recommendation?['frequency']?.toString() ?? '1') ?? 1;
  }

  List<dynamic> get _slots {
    final raw = _recommendation?['slots'];

    if (raw is List) return raw;

    return [];
  }

  bool _isSameDayAlreadySelected(int slotIndex) {
    if (slotIndex >= _slots.length) return false;

    final currentDay =
    (_slots[slotIndex]['day'] ?? '').toString().trim().toLowerCase();

    for (final selectedIndex in _selectedSlotIndices) {
      if (selectedIndex == slotIndex) continue;

      final selectedDay = (_slots[selectedIndex]['day'] ?? '')
          .toString()
          .trim()
          .toLowerCase();

      if (selectedDay == currentDay) return true;
    }

    return false;
  }

  bool _isSlotDisabled(int slotIndex) {
    if (_selectedSlotIndices.contains(slotIndex)) return false;
    if (_selectedSlotIndices.length >= _frequency) return true;
    if (_isSameDayAlreadySelected(slotIndex)) return true;

    return false;
  }

  bool _isSlotSelected(int slotIndex) {
    return _selectedSlotIndices.contains(slotIndex);
  }

  void _toggleSlotSelection(int slotIndex) {
    setState(() {
      if (_selectedSlotIndices.contains(slotIndex)) {
        _selectedSlotIndices.remove(slotIndex);
        return;
      }

      if (_selectedSlotIndices.length >= _frequency) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('You can only select $_frequency slot(s)'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      if (_isSameDayAlreadySelected(slotIndex)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'You cannot select multiple slots for the same day',
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }

      _selectedSlotIndices.add(slotIndex);
    });
  }

  List<Map<String, dynamic>> _selectedSlotDetails() {
    final selected = _selectedSlotIndices.map((i) => _slots[i]).toList();

    return List<Map<String, dynamic>>.from(selected);
  }

  String _safePaymentVisitId(
      Map<String, dynamic> recommendation,
      double amount,
      ) {
    final candidates = [
      recommendation['visitId'],
      recommendation['VisitID'],
      recommendation['visitID'],
      widget.booking?['visitId'],
      widget.booking?['VisitID'],
      widget.booking?['visitID'],
    ];

    for (final value in candidates) {
      final text = value?.toString().trim() ?? '';

      if (text.isNotEmpty && text.toLowerCase() != 'null') {
        return text;
      }
    }

    final planName = recommendation['planName']?.toString().trim() ?? '';
    final slotsKey = _selectedSlotDetails()
        .map(
          (slot) =>
      '${slot['date']?.toString() ?? ''}_'
          '${slot['time']?.toString() ?? ''}_'
          '${slot['maaliId']?.toString() ?? ''}',
    )
        .join('|');

    return '${widget.userId}|$planName|${amount.toStringAsFixed(2)}|$slotsKey';
  }

  Future<void> _clearPendingPaymentLocally() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove('pendingPaymentVisitId');
    await prefs.remove('pendingPaymentSessionId');
    await prefs.remove('pendingPaymentUserId');
    await prefs.remove('pendingPaymentAmount');
    await prefs.remove('pendingPaymentCreatedAt');

    debugPrint('✅ Pending payment cleared locally');
  }

  void _showPaymentPendingDialog() {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        title: const Text(
          'Payment Confirmation Pending',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: const Text(
          'If your amount was deducted, please do not pay again. '
              'Your booking will be confirmed automatically within a few minutes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<bool> _tryRecoverPaymentNow() async {
    final paymentSessionId = _currentPaymentSessionId ?? '';

    if (paymentSessionId.isEmpty) {
      return false;
    }

    try {
      if (mounted) {
        setState(() {
          _isCheckoutOpening = false;
          _isPostPaymentProcessing = true;
          _processingMessage =
          'Checking your payment status. Please do not pay again.';
        });
      }

      final response = await BookingService.recoverOneZohoPaymentRecovery(
        paymentSessionId: paymentSessionId,
      );

      debugPrint('✅ recoverOne response: $response');

      final created = response['success'] == true &&
          (response['bookingStatus'] == 'BOOKING_CREATED' ||
              response['alreadyCreated'] == true);

      if (!mounted) return created;

      if (created) {
        await _clearPendingPaymentLocally();

        setState(() {
          _isCheckoutOpening = false;
          _isPostPaymentProcessing = false;
          _isPaying = false;
          _processingMessage = '';
        });

        await showDialog(
          context: context,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            title: const Text(
              'Plan Activated',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            content: const Text(
              'Your subscription plan has been activated successfully.',
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryColor,
                  foregroundColor: Colors.white,
                ),
                child: const Text('OK'),
              ),
            ],
          ),
        );

        if (!mounted) return true;

        _goToZohoBookings();
        return true;
      }

      setState(() {
        _isCheckoutOpening = false;
        _isPostPaymentProcessing = false;
        _isPaying = false;
        _processingMessage = '';
      });

      _showPaymentPendingDialog();
      return false;
    } catch (e) {
      debugPrint('❌ Immediate payment recovery check failed: $e');

      if (!mounted) return false;

      setState(() {
        _isCheckoutOpening = false;
        _isPostPaymentProcessing = false;
        _isPaying = false;
        _processingMessage = '';
      });

      _showPaymentPendingDialog();
      return false;
    }
  }

  Map<String, dynamic> _buildZohoDealPayload() {
    final recommendation = _recommendation!;
    final selectedSlots = _selectedSlotDetails();

    if (selectedSlots.isEmpty) {
      throw Exception('No slots selected');
    }

    selectedSlots.sort((a, b) {
      final aDate = _parseSlotDateTime(a);
      final bDate = _parseSlotDateTime(b);

      return aDate.compareTo(bDate);
    });

    final rawFullName =
    recommendation['fullName']?.toString().trim().isNotEmpty == true
        ? recommendation['fullName'].toString().trim()
        : '${recommendation['firstName'] ?? ''} ${recommendation['lastName'] ?? ''}'
        .trim();

    final nameParts = rawFullName.split(RegExp(r'\s+'));
    final firstName = nameParts.isNotEmpty ? nameParts.first : 'User';
    final lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';

    final firstVisitDate =
    _parseSlotDate((selectedSlots.first['date'] ?? '').toString());

    final sectorValue = recommendation['sector']?.toString().trim() ?? '';
    final rawSociety = recommendation['society']?.toString().trim() ?? '';
    final societyValue = rawSociety.isNotEmpty ? rawSociety : sectorValue;
    final sourceVisitId = (
        recommendation['visitId'] ??
            recommendation['VisitID'] ??
            recommendation['visitID'] ??
            widget.booking?['visitId'] ??
            widget.booking?['VisitID'] ??
            widget.booking?['visitID'] ??
            ''
    )
        .toString()
        .trim();

    final dealClosedLocation =
    recommendation['dealClosedLocation'] is Map
        ? Map<String, dynamic>.from(recommendation['dealClosedLocation'])
        : <String, dynamic>{};

    final dealClosedLatitude =
        recommendation['dealClosedLatitude'] ??
            dealClosedLocation['latitude'];

    final dealClosedLongitude =
        recommendation['dealClosedLongitude'] ??
            dealClosedLocation['longitude'];

    final dealClosedAccuracy =
        recommendation['dealClosedAccuracy'] ??
            dealClosedLocation['accuracy'];

    final dealClosedLocationCapturedAt =
        recommendation['dealClosedLocationCapturedAt'] ??
            dealClosedLocation['capturedAt'];

    final dealClosedLocationUrl =
        recommendation['dealClosedLocationUrl'] ??
            recommendation['dealClosedGoogleMapsUrl'] ??
            dealClosedLocation['googleMapsUrl'] ??
            dealClosedLocation['googleMapsLink'];

    final dealClosedLocationSource =
        recommendation['dealClosedLocationSource'] ??
            dealClosedLocation['source'] ??
            'expert_visit_deal_closed_location';

    final Map<String, dynamic> body = {
      'firstName': firstName,
      'lastName': lastName,
      'mobile': recommendation['mobile']?.toString() ?? '',
      'leadSource':
      recommendation['leadSource']?.toString() ?? 'External Reference',
      'planName': recommendation['planName']?.toString() ?? '',
      'monthlyAmount': recommendation['monthlyAmount']?.toString() ?? '0',
      'startDate': DateFormat('yyyy-MM-dd').format(firstVisitDate),
      'currentCycleStartDate': DateFormat('yyyy-MM-dd').format(firstVisitDate),
      'flatNo': recommendation['flatNo']?.toString() ?? '',
      'towerNo': recommendation['towerNo']?.toString() ?? '',
      'society': societyValue,
      'sector': sectorValue,
      'mailingCity': 'Noida',
      'mailingState': 'Uttar Pradesh',
      'mailingCountry': 'India',
      'oneTime': recommendation['oneTime']?.toString() ?? 'n',
      'frequency': recommendation['frequency']?.toString() ?? '1',
      'serviceFrequency': _frequency.toString(),
      'remarks': recommendation['remarks']?.toString() ?? '',
      'userID': recommendation['userID']?.toString() ?? widget.userId,
      'assignedMali': selectedSlots.first['maaliName']?.toString() ?? '',
      'assignedMaliId': selectedSlots.first['maaliId']?.toString() ?? '',
      'secondVisitGap': 0,
      'subscriptionMonthTenure': 1,
      'sourceVisitID': sourceVisitId,
      'paymentSessionId': _currentPaymentSessionId ?? '',

      // Expert visit captured location for Maali app navigation
      'dealClosedLocation': dealClosedLocation,
      'dealClosedLatitude': dealClosedLatitude,
      'dealClosedLongitude': dealClosedLongitude,
      'dealClosedAccuracy': dealClosedAccuracy,
      'dealClosedLocationCapturedAt': dealClosedLocationCapturedAt,
      'dealClosedLocationUrl': dealClosedLocationUrl,
      'dealClosedLocationSource': dealClosedLocationSource,

      // Clean navigation fields that booking Lambda should copy to zohoBookings
      'navigationLatitude': dealClosedLatitude,
      'navigationLongitude': dealClosedLongitude,
      'navigationLocationUrl': dealClosedLocationUrl,
      'navigationLocationSource': dealClosedLocationUrl != null &&
          dealClosedLocationUrl.toString().trim().isNotEmpty
          ? 'expert_visit_deal_closed_location'
          : '',
    };

    for (int i = 0; i < selectedSlots.length; i++) {
      final slot = selectedSlots[i];
      final visitNumber = i + 1;

      body['visitDay$visitNumber'] = slot['day']?.toString() ?? '';
      body['visitTimeSlot$visitNumber'] = slot['time']?.toString() ?? '';
      body['visitDate$visitNumber'] =
          _formatDateToYMD(slot['date']?.toString() ?? '');
      body['assignedMali$visitNumber'] = slot['maaliName']?.toString() ?? '';
      body['assignedMaliId$visitNumber'] = slot['maaliId']?.toString() ?? '';
    }

    final firstVisitDateObj =
    _parseSlotDate((selectedSlots.first['date'] ?? '').toString());

    if (selectedSlots.length >= 2) {
      final secondVisitDate =
      _parseSlotDate((selectedSlots[1]['date'] ?? '').toString());

      body['secondVisitGap'] =
          secondVisitDate.difference(firstVisitDateObj).inDays;
    }

    if (selectedSlots.length >= 3) {
      final thirdVisitDate =
      _parseSlotDate((selectedSlots[2]['date'] ?? '').toString());

      body['thirdVisitGap'] =
          thirdVisitDate.difference(firstVisitDateObj).inDays;
    }

    return body;
  }

  Future<bool> _createZohoDeal() async {
    try {
      final body = _buildZohoDealPayload();

      body['paymentSessionId'] = _currentPaymentSessionId ?? '';

      debugPrint('🟡 Creating Zoho deal / AWS booking...');
      debugPrint('🟡 Zoho deal payload: $body');

      final response = await BookingService.postZohoDeal(body);

      debugPrint('✅ Zoho deal / AWS booking created: $response');

      return true;
    } catch (e, stackTrace) {
      debugPrint('❌ Zoho deal / AWS booking creation failed: $e');
      debugPrint('❌ StackTrace: $stackTrace');

      return false;
    }
  }

  void _goToZohoBookings() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => ZohoBookingScreen(
          userId: widget.userId,
          userName: widget.userName,
          profilePhotoUrl: widget.profilePhotoUrl,
        ),
      ),
          (route) => false,
    );
  }

  Future<void> _handlePayment() async {
    if (_isCheckoutOpening || _isPostPaymentProcessing || _isPaying) return;
    if (_recommendation == null) return;

    if (_selectedSlotIndices.length != _frequency) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select $_frequency slot(s)'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (!_isZohoSdkReady) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Payment system is loading. Please try again in a moment.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isPaying = true;
      _isCheckoutOpening = true;
    });

    _currentPaymentSessionId = null;

    try {
      final recommendation = _recommendation!;
      final amount =
          double.tryParse(recommendation['monthlyAmount'].toString()) ?? 0;
      final customerPhone =
      _normalizeIndianPhone(recommendation['mobile']?.toString());
      final customerName =
      recommendation['fullName']?.toString().trim().isNotEmpty == true
          ? recommendation['fullName'].toString().trim()
          : widget.userName;

      if (amount <= 0) {
        throw Exception('Invalid payment amount');
      }

      if (customerPhone.length != 10) {
        throw Exception('Invalid customer mobile number');
      }

      final prefs = await SharedPreferences.getInstance();
      final paymentVisitId = _safePaymentVisitId(recommendation, amount);

      final pendingVisitId = prefs.getString('pendingPaymentVisitId') ?? '';
      final pendingSessionId = prefs.getString('pendingPaymentSessionId') ?? '';
      final pendingCreatedAt = prefs.getString('pendingPaymentCreatedAt') ?? '';

      bool hasFreshPendingSession = false;

      if (pendingVisitId == paymentVisitId &&
          pendingSessionId.isNotEmpty &&
          pendingCreatedAt.isNotEmpty) {
        final createdAt = DateTime.tryParse(pendingCreatedAt);

        if (createdAt != null) {
          final minutesOld = DateTime.now().difference(createdAt).inMinutes;
          hasFreshPendingSession = minutesOld < 15;
        }
      }

      if (hasFreshPendingSession) {
        debugPrint('⚠️ Existing pending payment session found.');
        debugPrint('⚠️ visitId: $pendingVisitId');
        debugPrint('⚠️ paymentSessionId: $pendingSessionId');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'A payment is already in progress. Please wait or contact support if amount was deducted.',
              ),
              backgroundColor: Colors.orange,
            ),
          );

          setState(() {
            _isPaying = false;
            _isCheckoutOpening = false;
            _isPostPaymentProcessing = false;
            _processingMessage = '';
          });
        }

        return;
      }

      final bookingPayload = _buildZohoDealPayload();

      debugPrint('🟡 Booking payload prepared before payment session: $bookingPayload');

      final sessionResponse = await BookingService.createZohoPaymentSession(
        userId: widget.userId,
        amount: amount,
        currency: 'INR',
        description: recommendation['planName'] ?? 'Recommended Plan',
        customerName: customerName,
        customerPhone: customerPhone,
        customerEmail: recommendation['email']?.toString() ?? '',
        metadata: {
          'userId': widget.userId,
          'planName': recommendation['planName'] ?? '',
          'flow': 'recommendation_plan_payment',
          'visitId': paymentVisitId,
        },
        bookingPayload: bookingPayload,
      ).timeout(
        const Duration(seconds: 25),
        onTimeout: () {
          throw Exception(
            'Payment session creation timed out. Please try again.',
          );
        },
      );

      debugPrint('✅ Payment session response received: $sessionResponse');

      final paymentSessionId =
          sessionResponse['payment_session_id']?.toString() ??
              sessionResponse['paymentSessionId']?.toString();

      if (paymentSessionId == null || paymentSessionId.isEmpty) {
        throw Exception('payment_session_id missing from backend response');
      }

      _currentPaymentSessionId = paymentSessionId;

      await prefs.setString('pendingPaymentVisitId', paymentVisitId);
      await prefs.setString('pendingPaymentSessionId', paymentSessionId);
      await prefs.setString('pendingPaymentUserId', widget.userId);
      await prefs.setString('pendingPaymentAmount', amount.toString());
      await prefs.setString(
        'pendingPaymentCreatedAt',
        DateTime.now().toIso8601String(),
      );

      debugPrint('✅ Pending payment saved locally');
      debugPrint('✅ visitId: $paymentVisitId');
      debugPrint('✅ paymentSessionId: $paymentSessionId');

      final options = ZohoPaymentsCheckoutOptions(
        paymentSessionId: paymentSessionId,
        description: recommendation['planName'] ?? 'Recommended Plan',
        invoiceNumber: 'GD-${DateTime.now().millisecondsSinceEpoch}',
        referenceNumber: widget.userId,
        name: customerName,
        email: recommendation['email']?.toString() ?? '',
        phone: customerPhone,
      );

      await Future.delayed(const Duration(milliseconds: 150));

      if (!mounted) {
        debugPrint('⚠️ Screen unmounted before checkout could open.');
        return;
      }

      debugPrint('🟡 Opening Zoho checkout');
      debugPrint('🟡 paymentSessionId: $paymentSessionId');
      debugPrint('🟡 userId: ${widget.userId}');
      debugPrint('🟡 amount: $amount');
      debugPrint('🟡 customerPhone: $customerPhone');

      final result = await _zohoSdk
          .showCheckout(
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

      debugPrint('🟢 Zoho checkout returned');
      debugPrint('🟢 Result runtimeType: ${result.runtimeType}');
      debugPrint('🟢 Result: $result');
      debugPrint('🟢 Current payment session id: $_currentPaymentSessionId');

      if (mounted) {
        setState(() {
          _isCheckoutOpening = false;
        });
      }

      switch (result) {
        case ZohoPaymentsSuccess():
          debugPrint('✅ ZohoPaymentsSuccess');
          debugPrint('✅ paymentId: ${result.paymentId}');
          debugPrint('✅ signature present: ${result.signature.isNotEmpty}');

          await _handleZohoPaymentSuccess(
            paymentId: result.paymentId,
            signature: result.signature,
          );
          break;

        case ZohoPaymentsFailure():
          debugPrint('❌ ZohoPaymentsFailure');
          debugPrint('❌ code: ${result.code}');
          debugPrint('❌ message: ${result.message}');

          _handleZohoPaymentFailure(
            code: result.code,
            message: result.message,
          );
          break;

        default:
          debugPrint('⚠️ Unknown Zoho payment result: $result');
          await _tryRecoverPaymentNow();
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error initiating payment: $e');
      debugPrint('❌ StackTrace: $stackTrace');
      if ((_currentPaymentSessionId ?? '').isNotEmpty) {
        await _tryRecoverPaymentNow();
        return;
      }

      if (!mounted) return;

      setState(() {
        _isPaying = false;
        _isCheckoutOpening = false;
        _isPostPaymentProcessing = false;
        _processingMessage = '';
      });

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
    if (mounted) {
      setState(() {
        _isPostPaymentProcessing = true;
        _processingMessage =
        'Payment received. Please do not close the app while we confirm your plan.';
      });
    }

    try {
      final verifyResponse = await BookingService.verifyZohoPayment(
        paymentId: paymentId,
        paymentSessionId: _currentPaymentSessionId ?? '',
        signature: signature,
      );

      debugPrint('✅ Zoho payment verify response: $verifyResponse');

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

      if (mounted) {
        setState(() {
          _processingMessage =
          'Payment verified. Finalizing your subscription booking.';
        });
      }

      debugPrint('✅ Payment verified. Calling zohoPaymentRecoveryFinalize now...');

      final finalizeResponse = await BookingService.finalizeZohoPaymentRecovery(
        paymentSessionId: _currentPaymentSessionId ?? '',
        paymentId: paymentId,
        signature: signature,
      );

      debugPrint('✅ zohoPaymentRecoveryFinalize response: $finalizeResponse');

      final isZohoSuccess = finalizeResponse['success'] == true ||
          finalizeResponse['bookingStatus'] == 'BOOKING_CREATED' ||
          finalizeResponse['alreadyCreated'] == true;

      debugPrint('✅ Final booking creation result: $isZohoSuccess');

      if (isZohoSuccess) {
        await _clearPendingPaymentLocally();
      }

      if (!mounted) {
        debugPrint('⚠️ Booking flow completed but screen was unmounted.');
        return;
      }

      if (isZohoSuccess) {
        setState(() {
          _isPostPaymentProcessing = false;
          _isCheckoutOpening = false;
          _isPaying = false;
          _processingMessage = '';
        });

        await showDialog(
          context: context,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            title: const Text(
              'Plan Activated',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            content: const Text(
              'Your subscription plan has been activated successfully.',
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryColor,
                  foregroundColor: Colors.white,
                ),
                child: const Text('OK'),
              ),
            ],
          ),
        );

        if (!mounted) return;

        _goToZohoBookings();
      } else {
        setState(() {
          _isPostPaymentProcessing = false;
          _isCheckoutOpening = false;
          _processingMessage = '';
          _isPaying = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Payment succeeded but plan activation failed. Please contact support.',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Payment verification/finalization failed: $e');
      debugPrint('❌ StackTrace: $stackTrace');

      if (!mounted) return;

      setState(() {
        _isPostPaymentProcessing = false;
        _isCheckoutOpening = false;
        _processingMessage = '';
        _isPaying = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment received, but verification failed: $e'),
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

    setState(() {
      _isCheckoutOpening = false;
      _isPostPaymentProcessing = false;
      _processingMessage = '';
      _isPaying = false;
    });

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

  String _bookingAddress() {
    final rec = _recommendation ?? {};

    final parts = [
      (rec['flatNo'] ?? '').toString().trim(),
      (rec['towerNo'] ?? '').toString().trim().isNotEmpty
          ? 'Tower ${(rec['towerNo'] ?? '').toString().trim()}'
          : '',
      (rec['society'] ?? '').toString().trim(),
      (rec['sector'] ?? '').toString().trim(),
    ].where((e) => e.isNotEmpty).toList();

    return parts.isEmpty ? 'Address not available' : parts.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final bool blockUi = _isCheckoutOpening || _isPostPaymentProcessing;

    return PopScope(
      canPop: !blockUi,
      child: Scaffold(
        backgroundColor: AppColors.secondaryColor,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: AppColors.secondaryColor,
          foregroundColor: AppColors.primaryColor,
          title: const Text(
            'Booking Summary',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        body: Stack(
          children: [
            _buildMainBody(),
            if (blockUi)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withOpacity(0.45),
                  child: Center(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 24),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(
                              color: AppColors.primaryColor,
                              strokeWidth: 3,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _isCheckoutOpening
                                ? 'Opening payment page...'
                                : 'Processing payment...',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _isCheckoutOpening
                                ? 'Please wait while secure payment options load.'
                                : _processingMessage,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                              height: 1.4,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryColor),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 72, color: Colors.red.shade300),
              const SizedBox(height: 16),
              const Text(
                'Unable to load plan',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black54,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _loadPage,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryColor,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    final recommendation = _recommendation!;
    final paymentStatus =
        recommendation['paymentStatus']?.toString().toLowerCase() ?? 'pending';
    final selectedCount = _selectedSlotIndices.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildVisitedBookingCard(),
          const SizedBox(height: 16),
          _buildPlanHeaderCard(recommendation, paymentStatus),
          const SizedBox(height: 16),
          _buildAddressCard(),
          const SizedBox(height: 16),
          _buildRemarksCard(recommendation),
          const SizedBox(height: 16),
          _buildSlotsCard(selectedCount),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 58,
            child: ElevatedButton(
              onPressed: _isPaying || paymentStatus != 'pending'
                  ? null
                  : () => _handlePayment(),
              style: ElevatedButton.styleFrom(
                backgroundColor: paymentStatus != 'pending'
                    ? Colors.grey
                    : selectedCount == _frequency
                    ? AppColors.primaryColor
                    : Colors.grey,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: _isPaying
                  ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.4,
                ),
              )
                  : paymentStatus != 'pending'
                  ? Text(
                'Payment ${_capitalizeFirstLetter(paymentStatus)}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              )
                  : Text(
                selectedCount == _frequency
                    ? 'Pay to Start Plan - ₹${recommendation['monthlyAmount']?.toString() ?? '0'}'
                    : 'Select ${_frequency - selectedCount} more slot(s)',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVisitedBookingCard() {
    final booking = widget.booking;

    if (booking == null) return const SizedBox.shrink();

    final status = (booking['status'] ?? '').toString();
    final dateOfVisit = (booking['dateOfVisit'] ?? '').toString();
    final timeOfVisit = (booking['timeOfVisit'] ?? '').toString();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F2EE),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Completed Visit',
            style: TextStyle(
              fontSize: 12,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w700,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            dateOfVisit.isNotEmpty ? dateOfVisit : 'Date unavailable',
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppColors.primaryColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            timeOfVisit.isNotEmpty ? timeOfVisit : 'Time unavailable',
            style: const TextStyle(
              fontSize: 15,
              color: Colors.black87,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (status.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.12),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Text(
                'Completed',
                style: TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPlanHeaderCard(
      Map<String, dynamic> recommendation,
      String paymentStatus,
      ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            recommendation['planName'] ?? 'Recommended Plan',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.primaryColor,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _infoPill(
                  icon: Icons.repeat,
                  title: 'Frequency',
                  value: '$_frequency visit/week',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _infoPill(
                  icon: Icons.currency_rupee,
                  title: 'Amount',
                  value:
                  '₹${recommendation['monthlyAmount']?.toString() ?? '0'}/mo',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _statusBanner(paymentStatus),
        ],
      ),
    );
  }

  Widget _buildAddressCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.location_on_outlined,
            color: AppColors.primaryColor,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _bookingAddress(),
              style: const TextStyle(
                fontSize: 14,
                height: 1.5,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRemarksCard(Map<String, dynamic> recommendation) {
    final remarks = (recommendation['remarks'] ?? '').toString().trim();

    if (remarks.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.note_alt_outlined,
            color: AppColors.primaryColor,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              remarks,
              style: const TextStyle(
                fontSize: 14,
                height: 1.5,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlotsCard(int selectedCount) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select $_frequency slot(s)',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$selectedCount selected',
            style: const TextStyle(
              fontSize: 13,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 14),
          if (_slots.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Text(
                'No slots available',
                style: TextStyle(fontSize: 14, color: Colors.black54),
              ),
            )
          else
            Column(
              children: List.generate(_slots.length, (index) {
                final slot = Map<String, dynamic>.from(_slots[index] as Map);
                final isSelected = _isSlotSelected(index);
                final isDisabled = _isSlotDisabled(index);

                return GestureDetector(
                  onTap: isDisabled ? null : () => _toggleSlotSelection(index),
                  child: Opacity(
                    opacity: isDisabled ? 0.45 : 1,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primaryColor.withOpacity(0.08)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primaryColor
                              : Colors.grey.shade300,
                          width: isSelected ? 1.8 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isSelected
                                  ? AppColors.primaryColor
                                  : Colors.transparent,
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.primaryColor
                                    : Colors.grey.shade400,
                                width: 2,
                              ),
                            ),
                            child: isSelected
                                ? const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 14,
                            )
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  (slot['day'] ?? 'N/A').toString(),
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: isDisabled
                                        ? Colors.grey
                                        : AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${_formatReadableDate((slot['date'] ?? '').toString())} • ${(slot['time'] ?? 'N/A').toString()}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDisabled
                                        ? Colors.grey.shade600
                                        : Colors.black54,
                                  ),
                                ),
                                if ((slot['maaliName'] ?? '')
                                    .toString()
                                    .trim()
                                    .isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'Mali: ${(slot['maaliName'] ?? '').toString()}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.black45,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
        ],
      ),
    );
  }

  Widget _infoPill({
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
                    color: Colors.black54,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
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

  Widget _statusBanner(String paymentStatus) {
    final isCompleted = paymentStatus == 'completed';
    final color = isCompleted ? Colors.green : Colors.orange;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Icon(
            isCompleted ? Icons.check_circle : Icons.info_outline,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isCompleted
                  ? 'Payment completed successfully'
                  : 'Payment pending. Complete payment to start your plan.',
              style: TextStyle(
                fontSize: 13,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}