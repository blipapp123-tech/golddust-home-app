import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zoho_payments_flutter_sdk/zoho_payments_flutter_sdk.dart';

import '../app/app_constants.dart';
import '../app/app_text_styles.dart';
import '../services/booking_service.dart';
import '../widgets/liquid_glass_instruction_card.dart';

class ExpertVisitDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> booking;
  final String userId;
  final Future<void> Function()? onRefreshRequested;

  const ExpertVisitDetailsScreen({
    super.key,
    required this.booking,
    required this.userId,
    this.onRefreshRequested,
  });

  @override
  State<ExpertVisitDetailsScreen> createState() =>
      _ExpertVisitDetailsScreenState();
}

class _ExpertVisitDetailsScreenState extends State<ExpertVisitDetailsScreen> {
  bool _isSaving = false;

  bool _isLoadingRecommendations = false;
  String? _recommendationError;
  List<dynamic> _recommendations = [];

  bool _isZohoSdkReady = false;
  bool _isCheckoutOpening = false;
  bool _isPostPaymentProcessing = false;
  String _processingMessage = '';

  String? _currentPaymentSessionId;
  int? _currentPaymentIndex;
  List<dynamic>? _currentSelectedSlots;
  Map<String, dynamic>? _currentRecommendation;

  final ZohoPaymentsFlutterSdk _zohoSdk = ZohoPaymentsFlutterSdk();

  final Map<int, Set<int>> _selectedSlotIndices = {};
  final Map<int, bool> _isPaying = {};

  late Map<String, dynamic> _booking;

  static const Color _darkGreen = Color(0xFF063F20);
  static const Color _cardGreen = Color(0xFF174F2D);
  static const Color _gold = Color(0xFFFFB72B);
  static const Color _softBg = Colors.white;

  @override
  void initState() {
    super.initState();
    _booking = Map<String, dynamic>.from(widget.booking);
    _initZohoPayments();
    _fetchRecommendations();
  }

  String _text(dynamic value, {String fallback = ''}) {
    final text = (value ?? '').toString().trim();
    return text.isEmpty ? fallback : text;
  }

  String get _visitId {
    return _text(
      _booking['visitID'] ??
          _booking['visitId'] ??
          _booking['bookingID'] ??
          _booking['bookingId'] ??
          _booking['id'],
    );
  }

  String get _customerName {
    return _text(
      _booking['Full_Name'] ??
          _booking['fullName'] ??
          _booking['customerName'] ??
          _booking['userName'],
      fallback: 'Customer',
    );
  }

  String get _phone {
    return _text(
      _booking['Phone_No'] ??
          _booking['phoneNo'] ??
          _booking['mobile'] ??
          _booking['phone'],
    );
  }

  String get _dateOfVisit {
    return _text(
      _booking['dateOfVisit'] ?? _booking['dueDate'] ?? _booking['date'],
      fallback: 'Not scheduled',
    );
  }

  String get _timeOfVisit {
    return _text(
      _booking['timeOfVisit'] ??
          _booking['visitTimeSlot1'] ??
          _booking['timeSlot'],
      fallback: 'Not available',
    );
  }

  String get _status {
    return _text(_booking['status'], fallback: 'Booked');
  }

  String get _address {
    final flatNo = _text(_booking['flatNo'] ?? _booking['Flat_No']);
    final towerNo = _text(_booking['towerNo'] ?? _booking['Tower_No']);
    final society = _text(_booking['society'] ?? _booking['Society']);
    final sector = _text(_booking['sector'] ?? _booking['Sector']);
    final city = _text(_booking['city'] ?? _booking['City']);

    final parts = [
      flatNo,
      towerNo,
      society,
      sector,
      city,
    ].where((e) => e.trim().isNotEmpty).toList();

    if (parts.isEmpty) return 'Address not available';

    return parts.join(', ');
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

  DateTime? _parseDate(String value) {
    final clean = value.trim();
    if (clean.isEmpty) return null;

    try {
      if (clean.contains('-')) {
        final parts = clean.split('-');
        if (parts.length == 3) {
          if (parts[0].length == 4) {
            return DateTime(
              int.parse(parts[0]),
              int.parse(parts[1]),
              int.parse(parts[2]),
            );
          }

          final day = int.parse(parts[0]);
          final month = int.parse(parts[1]);
          final rawYear = int.parse(parts[2]);
          final year = parts[2].length == 2 ? 2000 + rawYear : rawYear;

          return DateTime(year, month, day);
        }
      }

      return DateTime.tryParse(clean);
    } catch (_) {
      return null;
    }
  }

  DateTime _parseSlotDate(String rawDate) {
    try {
      return DateFormat('dd-MM-yy').parseStrict(rawDate);
    } catch (_) {
      try {
        return DateFormat('dd-MM-yyyy').parseStrict(rawDate);
      } catch (_) {
        try {
          return DateTime.parse(rawDate);
        } catch (_) {
          return DateTime.now();
        }
      }
    }
  }

  DateTime _parseSlotDateTime(Map<String, dynamic> slot) {
    final date = _parseSlotDate(slot['date']?.toString() ?? '');
    final rawTime = slot['time']?.toString().trim() ?? '8:00 AM';

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

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.year}';
  }

  String _formatDateToYMD(String rawDate) {
    final date = _parseSlotDate(rawDate);
    return DateFormat('yyyy-MM-dd').format(date);
  }

  String _formatDisplayDate(String rawDate) {
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

      debugPrint('✅ Zoho Payments SDK initialized');
    } catch (e, stack) {
      debugPrint('❌ Zoho Payments init error: $e');
      debugPrint('$stack');

      if (!mounted) return;

      setState(() {
        _isZohoSdkReady = false;
      });
    }
  }

  Future<void> _fetchRecommendations() async {
    if (!mounted) return;

    setState(() {
      _isLoadingRecommendations = true;
      _recommendationError = null;
    });

    try {
      final data = await BookingService.fetchExpertRecommendations(
        widget.userId,
      );

      if (!mounted) return;

      setState(() {
        _recommendations = data;

        for (int i = 0; i < _recommendations.length; i++) {
          _selectedSlotIndices[i] = <int>{};
          _isPaying[i] = false;
        }

        _isLoadingRecommendations = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _recommendationError = e.toString();
        _isLoadingRecommendations = false;
      });
    }
  }

  bool _isSameDayAlreadySelected(int recommendationIndex, int slotIndex) {
    final recommendation = _recommendations[recommendationIndex];
    final slots = recommendation['slots'] as List? ?? [];
    final selectedSlots = _selectedSlotIndices[recommendationIndex] ?? {};

    if (slotIndex >= slots.length) return false;

    final currentDay =
    (slots[slotIndex]['day'] ?? '').toString().trim().toLowerCase();

    for (final selectedIndex in selectedSlots) {
      if (selectedIndex == slotIndex) continue;

      final selectedDay =
      (slots[selectedIndex]['day'] ?? '').toString().trim().toLowerCase();

      if (selectedDay == currentDay) {
        return true;
      }
    }

    return false;
  }

  bool _isSlotDisabled(int recommendationIndex, int slotIndex) {
    final recommendation = _recommendations[recommendationIndex];
    final frequency =
        int.tryParse(recommendation['frequency']?.toString() ?? '1') ?? 1;

    final selectedSlots = _selectedSlotIndices[recommendationIndex] ?? {};

    if (selectedSlots.contains(slotIndex)) return false;
    if (selectedSlots.length >= frequency) return true;
    if (_isSameDayAlreadySelected(recommendationIndex, slotIndex)) return true;

    return false;
  }

  bool _isSlotSelected(int recommendationIndex, int slotIndex) {
    return _selectedSlotIndices[recommendationIndex]?.contains(slotIndex) ??
        false;
  }

  int _getSelectedSlotsCount(int recommendationIndex) {
    return _selectedSlotIndices[recommendationIndex]?.length ?? 0;
  }

  void _toggleSlotSelection(int recommendationIndex, int slotIndex) {
    setState(() {
      final recommendation = _recommendations[recommendationIndex];
      final frequency =
          int.tryParse(recommendation['frequency']?.toString() ?? '1') ?? 1;
      final selectedSlots = _selectedSlotIndices[recommendationIndex]!;
      final slots = recommendation['slots'] as List? ?? [];

      if (selectedSlots.contains(slotIndex)) {
        selectedSlots.remove(slotIndex);
        return;
      }

      if (selectedSlots.length >= frequency) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('You can only select $frequency slot(s) for this plan'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final tappedSlot = slots[slotIndex];
      final tappedDay =
      (tappedSlot['day'] ?? '').toString().trim().toLowerCase();

      final alreadySelectedSameDay = selectedSlots.any((selectedIndex) {
        final selectedSlot = slots[selectedIndex];
        final selectedDay =
        (selectedSlot['day'] ?? '').toString().trim().toLowerCase();

        return selectedDay == tappedDay;
      });

      if (alreadySelectedSameDay) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You cannot select multiple slots for the same day'),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }

      selectedSlots.add(slotIndex);
    });
  }

  Future<bool> _createZohoDeal() async {
    try {
      debugPrint('\n================ ZOHO DEAL START ================\n');

      final recommendation = _currentRecommendation;
      final currentSlots = _currentSelectedSlots;

      if (recommendation == null) {
        throw Exception('Recommendation missing');
      }

      if (currentSlots == null || currentSlots.isEmpty) {
        throw Exception('No slots selected');
      }

      final selectedSlots = List<Map<String, dynamic>>.from(currentSlots);

      selectedSlots.sort((a, b) {
        final aDate = _parseSlotDateTime(a);
        final bDate = _parseSlotDateTime(b);

        return aDate.compareTo(bDate);
      });

      final fullName =
      recommendation['fullName']?.toString().trim().isNotEmpty == true
          ? recommendation['fullName'].toString().trim()
          : _customerName;

      final nameParts = fullName.split(RegExp(r'\s+'));

      final firstName = nameParts.isNotEmpty ? nameParts.first : 'User';
      final lastName =
      nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';

      final firstVisitDate =
      _parseSlotDate(selectedSlots.first['date']?.toString() ?? '');

      final frequency =
          int.tryParse(recommendation['frequency']?.toString() ?? '1') ?? 1;

      final serviceFrequency = frequency.toString();

      final sectorValue =
      recommendation['sector']?.toString().trim().isNotEmpty == true
          ? recommendation['sector'].toString().trim()
          : _text(_booking['sector'] ?? _booking['Sector']);

      final rawSociety =
      recommendation['society']?.toString().trim().isNotEmpty == true
          ? recommendation['society'].toString().trim()
          : _text(_booking['society'] ?? _booking['Society']);

      final societyValue = rawSociety.isNotEmpty ? rawSociety : sectorValue;

      final Map<String, dynamic> body = {
        'firstName': firstName,
        'lastName': lastName,
        'mobile': recommendation['mobile']?.toString() ??
            recommendation['phoneNo']?.toString() ??
            _phone,
        'leadSource':
        recommendation['leadSource']?.toString() ?? 'External Reference',
        'planName': recommendation['planName']?.toString() ?? '',
        'monthlyAmount': recommendation['monthlyAmount']?.toString() ?? '0',
        'startDate': DateFormat('yyyy-MM-dd').format(firstVisitDate),
        'currentCycleStartDate':
        DateFormat('yyyy-MM-dd').format(firstVisitDate),
        'flatNo': recommendation['flatNo']?.toString() ??
            _text(_booking['flatNo'] ?? _booking['Flat_No']),
        'towerNo': recommendation['towerNo']?.toString() ??
            _text(_booking['towerNo'] ?? _booking['Tower_No']),
        'society': societyValue,
        'sector': sectorValue,
        'mailingCity': 'Noida',
        'mailingState': 'Uttar Pradesh',
        'mailingCountry': 'India',
        'oneTime': recommendation['oneTime']?.toString() ?? 'n',
        'frequency': recommendation['frequency']?.toString() ?? '1',
        'serviceFrequency': serviceFrequency,
        'remarks': recommendation['remarks']?.toString() ??
            _text(_booking['remarks'] ?? _booking['Remark']),
        'userID': recommendation['userID']?.toString() ?? widget.userId,
        'assignedMali': selectedSlots.first['maaliName']?.toString() ?? '',
        'assignedMaliId': selectedSlots.first['maaliId']?.toString() ?? '',
        'secondVisitGap': 0,
        'subscriptionMonthTenure': 1,
        'sourceVisitID': _visitId,
      };

      for (int i = 0; i < selectedSlots.length; i++) {
        final slot = selectedSlots[i];
        final visitNumber = i + 1;

        final visitDate = _formatDateToYMD(slot['date']?.toString() ?? '');

        body['visitDay$visitNumber'] = slot['day']?.toString() ?? '';
        body['visitTimeSlot$visitNumber'] = slot['time']?.toString() ?? '';
        body['visitDate$visitNumber'] = visitDate;

        body['assignedMali$visitNumber'] =
            slot['maaliName']?.toString() ?? '';
        body['assignedMaliId$visitNumber'] =
            slot['maaliId']?.toString() ?? '';
      }

      final firstVisitDateObj =
      _parseSlotDate(selectedSlots.first['date']?.toString() ?? '');

      if (selectedSlots.length >= 2) {
        final secondVisitDate =
        _parseSlotDate(selectedSlots[1]['date']?.toString() ?? '');

        body['secondVisitGap'] =
            secondVisitDate.difference(firstVisitDateObj).inDays;
      }

      if (selectedSlots.length >= 3) {
        final thirdVisitDate =
        _parseSlotDate(selectedSlots[2]['date']?.toString() ?? '');

        body['thirdVisitGap'] =
            thirdVisitDate.difference(firstVisitDateObj).inDays;
      }

      debugPrint('📦 FINAL ZOHO PAYLOAD: $body');

      final response = await BookingService.postZohoDeal(body);

      debugPrint('✅ Zoho Response: $response');
      debugPrint('\n================ ZOHO DEAL END ================\n');

      return true;
    } catch (e, stack) {
      debugPrint('❌ Zoho API Error: $e');
      debugPrint('$stack');
      debugPrint('\n================ ZOHO DEAL FAILED ================\n');

      return false;
    }
  }

  Future<void> _handlePayment(int recommendationIndex) async {
    if (_isCheckoutOpening || _isPostPaymentProcessing) return;

    final recommendation = _recommendations[recommendationIndex];

    final selectedSlots = _selectedSlotIndices[recommendationIndex]!;
    final frequency =
        int.tryParse(recommendation['frequency']?.toString() ?? '1') ?? 1;

    if (selectedSlots.length != frequency) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select $frequency slot(s)'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (!_isZohoSdkReady) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Payment system is still loading. Please try again in a moment.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isPaying[recommendationIndex] = true;
      _isCheckoutOpening = true;
    });

    try {
      final slots = recommendation['slots'] as List? ?? [];
      final selectedSlotDetails = selectedSlots.map((i) => slots[i]).toList();

      _currentPaymentIndex = recommendationIndex;
      _currentSelectedSlots = selectedSlotDetails;
      _currentRecommendation = Map<String, dynamic>.from(recommendation);

      final amount =
          double.tryParse(recommendation['monthlyAmount'].toString()) ?? 0;

      final customerPhone = _normalizeIndianPhone(
        recommendation['mobile']?.toString().isNotEmpty == true
            ? recommendation['mobile'].toString()
            : _phone,
      );

      final customerName =
      recommendation['fullName']?.toString().trim().isNotEmpty == true
          ? recommendation['fullName'].toString().trim()
          : _customerName;

      if (amount <= 0) {
        throw Exception('Invalid payment amount');
      }

      if (customerPhone.length != 10) {
        throw Exception('Invalid customer mobile number');
      }

      final sessionResponse = await BookingService.createZohoPaymentSession(
        userId: widget.userId,
        amount: amount,
        currency: 'INR',
        description: recommendation['planName'] ?? 'Expert Plan',
        customerName: customerName,
        customerPhone: customerPhone,
        customerEmail: recommendation['email']?.toString() ?? '',
        metadata: {
          'userId': widget.userId,
          'visitId': _visitId,
          'planName': recommendation['planName'] ?? '',
          'recommendationIndex': recommendationIndex.toString(),
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
        description: recommendation['planName'] ?? 'Expert Plan',
        invoiceNumber: 'GD-${DateTime.now().millisecondsSinceEpoch}',
        referenceNumber: widget.userId,
        name: customerName,
        email: recommendation['email']?.toString() ?? '',
        phone: customerPhone,
      );

      await Future.delayed(const Duration(milliseconds: 150));

      if (!mounted) return;

      debugPrint('🟡 Calling Zoho showCheckout...');
      debugPrint('🟡 paymentSessionId: $paymentSessionId');
      debugPrint('🟡 customerPhone: $customerPhone');

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

      debugPrint('🟢 Zoho checkout returned');
      debugPrint('🟢 result runtimeType: ${result.runtimeType}');
      debugPrint('🟢 result: $result');

      if (!mounted) return;

      setState(() {
        _isCheckoutOpening = false;
      });

      if (result is ZohoPaymentsSuccess) {
        await _handleZohoPaymentSuccess(
          paymentId: result.paymentId,
          signature: result.signature,
        );
      } else if (result is ZohoPaymentsFailure) {
        _handleZohoPaymentFailure(
          code: result.code,
          message: result.message,
        );
      } else {
        _handleZohoPaymentFailure(
          code: 'UNKNOWN',
          message: 'Payment failed or cancelled. Please try again.',
        );
      }
    } catch (e, stack) {
      debugPrint('❌ Payment initiation error: $e');
      debugPrint('$stack');

      if (!mounted) return;

      setState(() {
        _isPaying[recommendationIndex] = false;
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
    debugPrint('✅ Zoho Payment Success: $paymentId');

    if (!mounted) return;

    setState(() {
      _isPostPaymentProcessing = true;
      _processingMessage =
      'Payment received. Please do not close the app while we confirm your booking.';
    });

    try {
      final verifyResponse = await BookingService.verifyZohoPayment(
        paymentId: paymentId,
        paymentSessionId: _currentPaymentSessionId ?? '',
        signature: signature,
      );

      final verified = verifyResponse['verified'] == true ||
          verifyResponse['status']?.toString().toLowerCase() == 'success';

      if (!verified) {
        throw Exception('Payment could not be verified');
      }

      if (!mounted) return;

      setState(() {
        _processingMessage =
        'Payment verified. Finalizing your subscription. Please do not close the app.';
      });

      final isZohoSuccess = await _createZohoDeal();

      if (!mounted) return;

      if (isZohoSuccess) {
        setState(() {
          _isPostPaymentProcessing = false;
          _processingMessage = '';
          if (_currentPaymentIndex != null) {
            _isPaying[_currentPaymentIndex!] = false;
          }
          _booking['status'] = 'Subscription booked';
        });

        if (widget.onRefreshRequested != null) {
          await widget.onRefreshRequested!();
        }

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment successful. Your subscription is activated.'),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.pop(context, true);
      } else {
        setState(() {
          _isPostPaymentProcessing = false;
          _processingMessage = '';
          if (_currentPaymentIndex != null) {
            _isPaying[_currentPaymentIndex!] = false;
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Payment succeeded but subscription creation failed. Please contact support.',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e, stack) {
      debugPrint('❌ Payment success handling error: $e');
      debugPrint('$stack');

      if (!mounted) return;

      setState(() {
        _isPostPaymentProcessing = false;
        _processingMessage = '';
        if (_currentPaymentIndex != null) {
          _isPaying[_currentPaymentIndex!] = false;
        }
      });

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
    debugPrint('❌ Zoho Payment Failed: $code - $message');

    if (!mounted) return;

    setState(() {
      _isCheckoutOpening = false;
      _isPostPaymentProcessing = false;
      _processingMessage = '';
      if (_currentPaymentIndex != null) {
        _isPaying[_currentPaymentIndex!] = false;
      }
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

  Future<void> _openWhatsAppSupport() async {
    const phoneNumber = '919217206273';
    final message = Uri.encodeComponent(
      'Hi GoldDust Gardening, I need help with my expert visit scheduled on $_dateOfVisit at $_timeOfVisit.',
    );

    final whatsappUri = Uri.parse(
      'whatsapp://send?phone=$phoneNumber&text=$message',
    );

    final webWhatsappUri = Uri.parse(
      'https://wa.me/$phoneNumber?text=$message',
    );

    try {
      final opened = await launchUrl(
        whatsappUri,
        mode: LaunchMode.externalApplication,
      );

      if (!opened) {
        await launchUrl(
          webWhatsappUri,
          mode: LaunchMode.externalApplication,
        );
      }
    } catch (_) {
      final openedWeb = await launchUrl(
        webWhatsappUri,
        mode: LaunchMode.externalApplication,
      );

      if (!openedWeb && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to open WhatsApp right now.'),
          ),
        );
      }
    }
  }

  Future<void> _pickTimeAndReschedule(DateTime selectedDate) async {
    final timeController = TextEditingController(
      text: _timeOfVisit == 'Not available' ? '' : _timeOfVisit,
    );

    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.25),
      builder: (_) {
        return Padding(
          padding: EdgeInsets.only(
            left: 18,
            right: 18,
            bottom: MediaQuery.of(context).viewInsets.bottom + 18,
          ),
          child: LiquidGlassInstructionCard(
            radius: 28,
            minHeight: 0,
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 46,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.16),
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                const SizedBox(height: 18),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Select Visit Time',
                    style: AppTextStyles.cardTitle.copyWith(
                      fontWeight: FontWeight.w900,
                      color: _darkGreen,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: timeController,
                  cursorColor: _darkGreen,
                  decoration: InputDecoration(
                    hintText: 'Example: 10:00 AM',
                    labelText: 'Time of visit',
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.88),
                    prefixIcon: const Icon(
                      Icons.access_time_rounded,
                      color: _gold,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                      borderSide: BorderSide(
                        color: _darkGreen.withOpacity(0.10),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                      borderSide: BorderSide(
                        color: _darkGreen.withOpacity(0.10),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                      borderSide: const BorderSide(
                        color: _gold,
                        width: 1.4,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () {
                      final value = timeController.text.trim();

                      if (value.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please enter visit time.'),
                          ),
                        );
                        return;
                      }

                      Navigator.pop(context, value);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _darkGreen,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(26),
                      ),
                    ),
                    child: Text(
                      'Continue',
                      style: AppTextStyles.body.copyWith(
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (result == null || result.trim().isEmpty) return;

    await _rescheduleVisit(
      newDate: _formatDate(selectedDate),
      newTime: result.trim(),
    );
  }

  Future<void> _openRescheduleFlow() async {
    if (_visitId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Visit ID not found. Cannot reschedule this visit.'),
        ),
      );
      return;
    }

    final currentDate = _parseDate(_dateOfVisit);
    final now = DateTime.now();

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: currentDate ?? now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 90)),
      helpText: 'Select new visit date',
      confirmText: 'Next',
      cancelText: 'Cancel',
    );

    if (pickedDate == null) return;

    await _pickTimeAndReschedule(pickedDate);
  }

  Future<void> _rescheduleVisit({
    required String newDate,
    required String newTime,
  }) async {
    if (_isSaving) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final result = await BookingService.rescheduleExpertVisit(
        userId: widget.userId,
        visitId: _visitId,
        dateOfVisit: newDate,
        timeOfVisit: newTime,
      );

      setState(() {
        _booking['dateOfVisit'] = newDate;
        _booking['dueDate'] = newDate;
        _booking['date'] = newDate;
        _booking['timeOfVisit'] = newTime;
        _booking['visitTimeSlot1'] = newTime;
        _booking['status'] = 'Rescheduled';
      });

      if (widget.onRefreshRequested != null) {
        await widget.onRefreshRequested!();
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _text(
              result['message'],
              fallback: 'Expert visit rescheduled successfully.',
            ),
          ),
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to reschedule visit: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _cancelVisit() async {
    if (_visitId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Visit ID not found. Cannot cancel this visit.'),
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.35),
      builder: (_) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: LiquidGlassInstructionCard(
            radius: 28,
            minHeight: 0,
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.10),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.cancel_outlined,
                    color: Colors.red,
                    size: 30,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Cancel Expert Visit?',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.cardTitle.copyWith(
                    fontWeight: FontWeight.w900,
                    color: _darkGreen,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Are you sure you want to cancel this expert visit?',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.body.copyWith(
                    height: 1.45,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context, false),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _darkGreen,
                            side: BorderSide(
                              color: _darkGreen.withOpacity(0.18),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                          child: Text(
                            'No',
                            style: AppTextStyles.body.copyWith(
                              fontWeight: FontWeight.w800,
                              color: _darkGreen,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                          child: Text(
                            'Cancel',
                            style: AppTextStyles.body.copyWith(
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (confirm != true) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final result = await BookingService.cancelExpertVisit(
        userId: widget.userId,
        visitId: _visitId,
      );

      if (widget.onRefreshRequested != null) {
        await widget.onRefreshRequested!();
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _text(
              result['message'],
              fallback: 'Expert visit cancelled successfully.',
            ),
          ),
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to cancel visit: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Widget _softCard({
    required Widget child,
    EdgeInsets padding = const EdgeInsets.all(16),
    double radius = 24,
    double minHeight = 0,
  }) {
    return LiquidGlassInstructionCard(
      radius: radius,
      minHeight: minHeight,
      padding: padding,
      child: child,
    );
  }

  Widget _buildHeroCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: _darkGreen,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: _darkGreen.withOpacity(0.26),
            blurRadius: 22,
            offset: const Offset(0, 10),
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
                  'EXPERT VISIT',
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w800,
                    color: _gold,
                  ),
                ),
              ),
              _statusChip(_status),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            'Visit booked for $_customerName',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.heroTitle.copyWith(
              fontSize: 21,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Our expert will visit your home and recommend the right garden care plan.',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.caption.copyWith(
              height: 1.35,
              fontWeight: FontWeight.w500,
              color: const Color(0xFFD7E7D9),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              color: _cardGreen,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.event_available_rounded,
                  color: _gold,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _heroInfoBlock(
                    label: 'VISIT DATE',
                    value: _dateOfVisit,
                  ),
                ),
                Container(
                  width: 1,
                  height: 34,
                  color: Colors.white.withOpacity(0.14),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _heroInfoBlock(
                    label: 'TIME SLOT',
                    value: _timeOfVisit,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroInfoBlock({
    required String label,
    required String value,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.tiny.copyWith(
            letterSpacing: 1.1,
            fontWeight: FontWeight.w800,
            color: const Color(0xFFD7E7D9),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.body.copyWith(
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _statusChip(String status) {
    final normalized = status.trim().toLowerCase();

    Color bg;
    Color textColor;
    String label;

    if (normalized.contains('cancel')) {
      bg = Colors.red.withOpacity(0.16);
      textColor = Colors.red;
      label = 'Cancelled';
    } else if (normalized.contains('subscription')) {
      bg = _gold.withOpacity(0.22);
      textColor = _gold;
      label = 'Subscription Booked';
    } else if (normalized.contains('reschedule')) {
      bg = Colors.orange.withOpacity(0.20);
      textColor = Colors.orange;
      label = 'Rescheduled';
    } else {
      bg = Colors.white.withOpacity(0.20);
      textColor = Colors.white;
      label = status.isEmpty ? 'Booked' : status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTextStyles.chip.copyWith(
          fontWeight: FontWeight.w800,
          color: textColor,
        ),
      ),
    );
  }

  Widget _infoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFFEAF8EF),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Icon(
            icon,
            color: _darkGreen,
            size: 21,
          ),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: AppTextStyles.tiny.copyWith(
                  letterSpacing: 1.1,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                value.trim().isEmpty ? 'Not available' : value,
                style: AppTextStyles.body.copyWith(
                  height: 1.35,
                  fontWeight: FontWeight.w800,
                  color: _darkGreen,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _divider() {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(vertical: 15),
      color: _darkGreen.withOpacity(0.08),
    );
  }

  Widget _buildVisitInfoCard() {
    return _softCard(
      radius: 24,
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          _infoRow(
            icon: Icons.location_on_rounded,
            label: 'Address',
            value: _address,
          ),
          if (_phone.isNotEmpty) ...[
            _divider(),
            _infoRow(
              icon: Icons.phone_rounded,
              label: 'Phone',
              value: _phone,
            ),
          ],
          _divider(),
          _infoRow(
            icon: Icons.eco_rounded,
            label: 'Visit Purpose',
            value:
            'Expert inspection, plant-care advice and subscription recommendation.',
          ),
        ],
      ),
    );
  }

  Widget _buildNextStepsCard() {
    final hasRecommendation = _recommendations.isNotEmpty;

    return _softCard(
      radius: 24,
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: const BoxDecoration(
              color: Color(0xFFEAF8EF),
              shape: BoxShape.circle,
            ),
            child: Icon(
              hasRecommendation
                  ? Icons.recommend_rounded
                  : Icons.tips_and_updates_rounded,
              color: _darkGreen,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasRecommendation
                      ? 'Expert recommendation is ready'
                      : 'What happens next?',
                  style: AppTextStyles.bodyLarge.copyWith(
                    fontWeight: FontWeight.w900,
                    color: _darkGreen,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  hasRecommendation
                      ? 'Select your preferred slots and make payment to activate your subscription.'
                      : 'Our expert will inspect your plants, understand the space, and recommend the right care plan.',
                  style: AppTextStyles.caption.copyWith(
                    height: 1.45,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationSection() {
    if (_isLoadingRecommendations) {
      return _softCard(
        radius: 24,
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: _darkGreen,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                'Checking expert recommendation...',
                style: AppTextStyles.body.copyWith(
                  fontWeight: FontWeight.w800,
                  color: _darkGreen,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_recommendationError != null) {
      return _softCard(
        radius: 24,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recommendation could not be loaded',
              style: AppTextStyles.bodyLarge.copyWith(
                fontWeight: FontWeight.w900,
                color: _darkGreen,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _recommendationError!,
              style: AppTextStyles.caption.copyWith(
                height: 1.4,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: _fetchRecommendations,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _darkGreen,
                side: BorderSide(color: _darkGreen.withOpacity(0.20)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_recommendations.isEmpty) {
      return _softCard(
        radius: 24,
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: const BoxDecoration(
                color: Color(0xFFEAF8EF),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.hourglass_empty_rounded,
                color: _darkGreen,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Recommendation not ready yet',
                    style: AppTextStyles.bodyLarge.copyWith(
                      fontWeight: FontWeight.w900,
                      color: _darkGreen,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Once our expert submits the recommendation, your plan and payment option will appear here.',
                    style: AppTextStyles.caption.copyWith(
                      height: 1.45,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: List.generate(
        _recommendations.length,
            (index) => _buildRecommendationCard(index),
      ),
    );
  }

  Widget _buildRecommendationCard(int index) {
    final recommendation = _recommendations[index];

    final frequency =
        int.tryParse(recommendation['frequency']?.toString() ?? '1') ?? 1;

    final slots = recommendation['slots'] as List? ?? [];
    final selectedCount = _getSelectedSlotsCount(index);

    final paymentStatus =
        recommendation['paymentStatus']?.toString().toLowerCase() ?? 'pending';

    final planName = recommendation['planName']?.toString() ?? 'Expert Plan';
    final amount = recommendation['monthlyAmount']?.toString() ?? '0';

    final isPaymentPending = paymentStatus == 'pending';

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: LiquidGlassInstructionCard(
        radius: 26,
        minHeight: 0,
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
              decoration: const BoxDecoration(
                color: _darkGreen,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(26),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      planName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.cardTitle.copyWith(
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: _gold,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Text(
                      '₹$amount/mo',
                      style: AppTextStyles.chip.copyWith(
                        color: _darkGreen,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildMiniInfoBox(
                          icon: Icons.calendar_month_rounded,
                          label: 'Frequency',
                          value: '$frequency visit/week',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildMiniInfoBox(
                          icon: Icons.payments_rounded,
                          label: 'Payment',
                          value: _capitalizeFirstLetter(paymentStatus),
                          valueColor: paymentStatus == 'pending'
                              ? Colors.orange
                              : paymentStatus == 'completed'
                              ? Colors.green
                              : _darkGreen,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF8EF).withOpacity(0.55),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _darkGreen.withOpacity(0.08),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Select $frequency slot(s)',
                          style: AppTextStyles.bodyLarge.copyWith(
                            fontWeight: FontWeight.w900,
                            color: _darkGreen,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'Choose the slots recommended by our expert to activate your subscription.',
                          style: AppTextStyles.caption.copyWith(
                            height: 1.4,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 14),
                        if (slots.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Center(
                              child: Text(
                                'No slots available',
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          )
                        else
                          Column(
                            children: List.generate(slots.length, (slotIndex) {
                              final slot = slots[slotIndex];
                              final isSelected =
                              _isSlotSelected(index, slotIndex);
                              final isDisabled =
                              _isSlotDisabled(index, slotIndex);

                              return GestureDetector(
                                onTap: isDisabled
                                    ? null
                                    : () => _toggleSlotSelection(
                                  index,
                                  slotIndex,
                                ),
                                child: Opacity(
                                  opacity: isDisabled ? 0.45 : 1,
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 10),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? _gold.withOpacity(0.10)
                                          : Colors.white.withOpacity(0.88),
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(
                                        color: isSelected
                                            ? _gold
                                            : _darkGreen.withOpacity(0.08),
                                        width: isSelected ? 1.5 : 1,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 26,
                                          height: 26,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: isSelected
                                                ? _gold
                                                : Colors.transparent,
                                            border: Border.all(
                                              color: isSelected
                                                  ? _gold
                                                  : _darkGreen.withOpacity(0.25),
                                              width: 2,
                                            ),
                                          ),
                                          child: isSelected
                                              ? const Icon(
                                            Icons.check,
                                            color: _darkGreen,
                                            size: 16,
                                          )
                                              : null,
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                slot['day']?.toString() ??
                                                    'N/A',
                                                style: AppTextStyles.body
                                                    .copyWith(
                                                  fontWeight: FontWeight.w900,
                                                  color: _darkGreen,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                _formatDisplayDate(
                                                  slot['date']?.toString() ??
                                                      '',
                                                ),
                                                style: AppTextStyles.caption
                                                    .copyWith(
                                                  fontWeight: FontWeight.w600,
                                                  color:
                                                  AppColors.textSecondary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 7,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _darkGreen.withOpacity(0.08),
                                            borderRadius:
                                            BorderRadius.circular(18),
                                          ),
                                          child: Text(
                                            slot['time']?.toString() ?? 'N/A',
                                            style: AppTextStyles.caption
                                                .copyWith(
                                              color: _darkGreen,
                                              fontWeight: FontWeight.w900,
                                            ),
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
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _isPaying[index] == true || !isPaymentPending
                          ? null
                          : () => _handlePayment(index),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                        isPaymentPending && selectedCount == frequency
                            ? _darkGreen
                            : Colors.grey,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey.shade400,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(27),
                        ),
                      ),
                      child: _isPaying[index] == true
                          ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Processing...',
                            style: AppTextStyles.body.copyWith(
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      )
                          : !isPaymentPending
                          ? Text(
                        'Payment ${_capitalizeFirstLetter(paymentStatus)}',
                        style: AppTextStyles.body.copyWith(
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      )
                          : Text(
                        selectedCount == frequency
                            ? 'Pay & Activate - ₹$amount'
                            : 'Select ${frequency - selectedCount} more slot(s)',
                        style: AppTextStyles.body.copyWith(
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniInfoBox({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return LiquidGlassInstructionCard(
      radius: 18,
      minHeight: 86,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 18,
            color: _gold,
          ),
          const SizedBox(height: 8),
          Text(
            label.toUpperCase(),
            style: AppTextStyles.tiny.copyWith(
              letterSpacing: 1,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.caption.copyWith(
              fontWeight: FontWeight.w900,
              color: valueColor ?? _darkGreen,
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButtons({required bool blockUi}) {
    return Row(
      children: [
        Expanded(
          child: _smallActionButton(
            icon: Icons.edit_calendar_rounded,
            title: 'Reschedule',
            onTap: _isSaving || blockUi ? null : _openRescheduleFlow,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _smallActionButton(
            icon: Icons.support_agent_rounded,
            title: 'Support',
            onTap: _isSaving || blockUi ? null : _openWhatsAppSupport,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _smallActionButton(
            icon: Icons.cancel_outlined,
            title: 'Cancel',
            danger: true,
            onTap: _isSaving || blockUi ? null : _cancelVisit,
          ),
        ),
      ],
    );
  }

  Widget _smallActionButton({
    required IconData icon,
    required String title,
    required VoidCallback? onTap,
    bool danger = false,
  }) {
    final color = danger ? Colors.red : _gold;
    final textColor = danger ? Colors.red : _darkGreen;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: SizedBox(
        height: 78,
        child: LiquidGlassInstructionCard(
          radius: 24,
          minHeight: 78,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 21,
                color: onTap == null ? Colors.grey : color,
              ),
              const SizedBox(height: 8),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: AppTextStyles.tiny.copyWith(
                  fontWeight: FontWeight.w800,
                  color: onTap == null ? Colors.grey : textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: AppTextStyles.sectionTitle.copyWith(
        fontWeight: FontWeight.w500,
        color: _darkGreen,
      ),
    );
  }

  Widget _buildSavingOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.18),
      child: Center(
        child: LiquidGlassInstructionCard(
          radius: 26,
          minHeight: 0,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: const CircularProgressIndicator(
            color: _darkGreen,
            strokeWidth: 3,
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.45),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: LiquidGlassInstructionCard(
              radius: 28,
              minHeight: 0,
              padding: const EdgeInsets.all(22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 30,
                    height: 30,
                    child: CircularProgressIndicator(
                      color: _darkGreen,
                      strokeWidth: 3,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _isCheckoutOpening
                        ? 'Opening payment page...'
                        : 'Processing payment...',
                    style: AppTextStyles.cardTitle.copyWith(
                      fontWeight: FontWeight.w900,
                      color: _darkGreen,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _isCheckoutOpening
                        ? 'Please wait while secure payment options load.'
                        : _processingMessage,
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.textSecondary,
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final blockUi = _isCheckoutOpening || _isPostPaymentProcessing;

    return PopScope(
      canPop: !blockUi,
      onPopInvoked: (didPop) {
        if (!didPop && blockUi) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Please wait. Do not close the app while payment is being processed.',
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
      },
      child: Scaffold(
        backgroundColor: _softBg,
        appBar: AppBar(
          backgroundColor: _softBg,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
          title: Text(
            'Expert Visit Details',
            style: AppTextStyles.cardTitle.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          actions: [
            IconButton(
              onPressed: blockUi ? null : _fetchRecommendations,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        body: Stack(
          children: [
            RefreshIndicator(
              onRefresh: _fetchRecommendations,
              color: _darkGreen,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
                children: [
                  _buildHeroCard(),
                  const SizedBox(height: 22),

                  _sectionTitle('Visit Information'),
                  const SizedBox(height: 14),
                  _buildVisitInfoCard(),

                  const SizedBox(height: 18),
                  _actionButtons(blockUi: blockUi),

                  const SizedBox(height: 22),
                  _buildNextStepsCard(),

                  const SizedBox(height: 22),
                  _sectionTitle('Recommended Plan'),
                  const SizedBox(height: 14),
                  _buildRecommendationSection(),

                  const SizedBox(height: 18),
                ],
              ),
            ),
            if (_isSaving) _buildSavingOverlay(),
            if (blockUi) _buildPaymentOverlay(),
          ],
        ),
      ),
    );
  }
}