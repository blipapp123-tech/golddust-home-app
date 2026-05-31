import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../widgets/liquid_glass_instruction_card.dart';
import '../app/app_constants.dart';
import '../app/app_text_styles.dart';
import 'add_products_for_next_visit_screen.dart';
import 'reschedule_booking_screen.dart';
import 'view_products_for_booking_screen.dart';

class SubscriptionDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> booking;
  final String userId;
  final String userName;
  final String profilePhotoUrl;
  final List<Map<String, dynamic>> cartItems;
  final String nextEligibleBookingDate;
  final String nextFutureDate;
  final String timeRemaining;
  final bool isWithinCutoff;
  final String fetchCatalogUrl;
  final ValueChanged<List<Map<String, dynamic>>> onCartUpdated;
  final Future<void> Function() onRefreshRequested;
  final Future<void> Function({
  required Map<String, dynamic> booking,
  required String dueDate,
  }) onSkipWeek;
  final bool Function(String dateStr) canModifyVisit;
  final String Function(String dateStr) getVisitModificationCutoffText;
  final String Function(String bookingDate) getCutoffDateString;

  const SubscriptionDetailsScreen({
    super.key,
    required this.booking,
    required this.userId,
    required this.userName,
    required this.profilePhotoUrl,
    required this.cartItems,
    required this.nextEligibleBookingDate,
    required this.nextFutureDate,
    required this.timeRemaining,
    required this.isWithinCutoff,
    required this.fetchCatalogUrl,
    required this.onCartUpdated,
    required this.onRefreshRequested,
    required this.onSkipWeek,
    required this.canModifyVisit,
    required this.getVisitModificationCutoffText,
    required this.getCutoffDateString,
  });

  @override
  State<SubscriptionDetailsScreen> createState() =>
      _SubscriptionDetailsScreenState();
}

class _SubscriptionDetailsScreenState extends State<SubscriptionDetailsScreen> {
  int _selectedDateIndex = -1;
  //bool _isSkipping = false;
  bool _isCancellingPlan = false;

  late List<Map<String, dynamic>> _cart;

  Timer? _countdownTimer;
  DateTime _now = DateTime.now();

  static const String _cancelPlanApiUrl = 'YOUR_CANCEL_PLAN_API_URL';

  static const Color _darkGreen = Color(0xFF063F20);
  static const Color _cardGreen = Color(0xFF174F2D);
  static const Color _gold = Color(0xFFFFB72B);
  static const Color _softBg = Colors.white;

  @override
  void initState() {
    super.initState();
    _cart = List<Map<String, dynamic>>.from(widget.cartItems);

    _countdownTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  bool _isDoneStatus(String status) {
    final s = status.trim().toLowerCase();
    return s == 'done' ||
        s == 'completed' ||
        s == 'complete' ||
        s == 'closed' ||
        s == 'finished' ||
        s == 'visit completed' ||
        s == 'service completed';
  }

  List<Map<String, dynamic>> _buildScheduledVisits() {
    final List<Map<String, dynamic>> visits = [];

    final today = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );

    final rawScheduledVisits = widget.booking['allScheduledVisits'];

    if (rawScheduledVisits is List && rawScheduledVisits.isNotEmpty) {
      for (final rawVisit in rawScheduledVisits) {
        if (rawVisit is! Map) continue;

        final visit = Map<String, dynamic>.from(rawVisit);
        final date = (visit['date'] ?? '').toString().trim();
        if (date.isEmpty) continue;

        final visitDate = _parseVisitDate(date);
        if (visitDate == null) continue;

        final visitStatus = (visit['status'] ?? '').toString().trim();
        final isDone = visit['isDone'] == true || _isDoneStatus(visitStatus);

        visits.add({
          'date': date,
          'mali': (visit['mali'] ?? visit['assignedMali'] ?? 'Not assigned')
              .toString(),
          'timeSlot': (visit['timeSlot'] ?? visit['visitTimeSlot1'] ?? 'N/A')
              .toString(),
          'status': visitStatus,
          'isDone': isDone,
          'booking': visit['booking'] is Map
              ? Map<String, dynamic>.from(visit['booking'] as Map)
              : widget.booking,
          'isPast': visitDate.isBefore(today),
          'isToday': visitDate.isAtSameMomentAs(today),
          'isFuture': visitDate.isAfter(today),
          'visitDate': visitDate,
        });
      }

      visits.sort((a, b) =>
          (a['visitDate'] as DateTime).compareTo(b['visitDate'] as DateTime));
      return visits;
    }

    final bookedDates = (widget.booking['bookedDates'] as List<dynamic>?)
        ?.map((e) => e.toString())
        .toList() ??
        [];

    final dayTimeSlots =
        (widget.booking['dayTimeSlots'] as List<dynamic>?) ?? [];

    final assignedMali = widget.booking['assignedMali'] ?? 'Not assigned';

    String timeSlot = 'N/A';
    if (dayTimeSlots.isNotEmpty && dayTimeSlots.first is Map) {
      final firstSlot = Map<String, dynamic>.from(dayTimeSlots.first as Map);
      timeSlot = (firstSlot['timeSlot'] ?? 'N/A').toString();
    }

    for (final date in bookedDates) {
      final visitDate = _parseVisitDate(date);
      if (visitDate == null) continue;

      final visitStatus = (widget.booking['status'] ?? '').toString().trim();
      final isDone = _isDoneStatus(visitStatus);

      visits.add({
        'date': date,
        'mali': assignedMali,
        'timeSlot': timeSlot,
        'status': visitStatus,
        'isDone': isDone,
        'booking': widget.booking,
        'isPast': visitDate.isBefore(today),
        'isToday': visitDate.isAtSameMomentAs(today),
        'isFuture': visitDate.isAfter(today),
        'visitDate': visitDate,
      });
    }

    visits.sort((a, b) =>
        (a['visitDate'] as DateTime).compareTo(b['visitDate'] as DateTime));

    return visits;
  }

  DateTime? _parseVisitDate(String dateStr) {
    try {
      final parts = dateStr.split('-');
      if (parts.length != 3) return null;

      final day = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final yearRaw = int.parse(parts[2]);
      final year = parts[2].length == 2 ? 2000 + yearRaw : yearRaw;

      return DateTime(year, month, day);
    } catch (_) {
      return null;
    }
  }

  String _weekdayShort(DateTime date) {
    const days = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    return days[date.weekday - 1];
  }

  String _monthShort(DateTime date) {
    const months = [
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC',
    ];
    return months[date.month - 1];
  }

  String _getUpcomingVisitLabel(Map<String, dynamic>? visit) {
    if (visit == null) return 'Not scheduled';

    final dateStr = visit['date']?.toString() ?? '';
    final timeSlot = visit['timeSlot']?.toString() ?? '';

    if (dateStr.isEmpty && timeSlot.isEmpty) return 'Not scheduled';
    if (dateStr.isEmpty) return timeSlot;

    final date = _parseVisitDate(dateStr);
    if (date == null) return '$dateStr, $timeSlot';

    final month = _monthShort(date);
    final formatted =
        '${month.substring(0, 1)}${month.substring(1).toLowerCase()} ${date.day.toString().padLeft(2, '0')}';

    if (timeSlot.isEmpty || timeSlot == 'N/A') return formatted;
    return '$formatted, $timeSlot';
  }

  int _defaultSelectedIndex(List<Map<String, dynamic>> visits) {
    if (_selectedDateIndex >= 0 && _selectedDateIndex < visits.length) {
      return _selectedDateIndex;
    }

    final nextIndex = visits.indexWhere((visit) {
      return visit['isToday'] == true || visit['isFuture'] == true;
    });

    if (nextIndex >= 0) return nextIndex;
    return visits.isNotEmpty ? 0 : -1;
  }

  Map<String, dynamic>? _getSelectedVisit(List<Map<String, dynamic>> visits) {
    final index = _defaultSelectedIndex(visits);
    if (index < 0 || index >= visits.length) return null;
    return visits[index];
  }

  int _getDaysLeftForPlan(List<Map<String, dynamic>> visits) {
    DateTime? lastFutureDate;

    for (final visit in visits) {
      final date = visit['visitDate'];
      if (date is DateTime) {
        if (lastFutureDate == null || date.isAfter(lastFutureDate)) {
          lastFutureDate = date;
        }
      }
    }

    if (lastFutureDate == null) return 0;

    final today = DateTime(_now.year, _now.month, _now.day);
    return lastFutureDate.difference(today).inDays.clamp(0, 999);
  }

  bool _isPlanExpired(List<Map<String, dynamic>> visits) {
    if (visits.isEmpty) return false;

    final dates = visits
        .map((visit) => visit['visitDate'])
        .whereType<DateTime>()
        .toList();

    if (dates.isEmpty) return false;

    dates.sort((a, b) => b.compareTo(a));

    final lastVisitDate = DateTime(
      dates.first.year,
      dates.first.month,
      dates.first.day,
    );

    final today = DateTime(_now.year, _now.month, _now.day);

    return lastVisitDate.isBefore(today);
  }

  DateTime? _getLastVisitDate(List<Map<String, dynamic>> visits) {
    final dates = visits
        .map((visit) => visit['visitDate'])
        .whereType<DateTime>()
        .toList();

    if (dates.isEmpty) return null;

    dates.sort((a, b) => b.compareTo(a));
    return dates.first;
  }

  List<DateTime> _buildNextRenewalDates(List<Map<String, dynamic>> visits) {
    final lastVisitDate = _getLastVisitDate(visits);
    final baseDate = lastVisitDate ?? DateTime.now();

    final List<DateTime> dates = [];
    DateTime nextDate = baseDate.add(const Duration(days: 7));

    final today = DateTime(_now.year, _now.month, _now.day);

    while (DateTime(nextDate.year, nextDate.month, nextDate.day)
        .isBefore(today)) {
      nextDate = nextDate.add(const Duration(days: 7));
    }

    for (int i = 0; i < 4; i++) {
      dates.add(nextDate.add(Duration(days: i * 7)));
    }

    return dates;
  }

  String _formatDateForDb(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}';
  }

  String _formatReadableDate(DateTime date) {
    return '${_weekdayShort(date)}, ${date.day.toString().padLeft(2, '0')} ${_monthShort(date)}';
  }

  String _getBookingDateForProducts() {
    if (widget.nextEligibleBookingDate.isNotEmpty) {
      return widget.nextEligibleBookingDate;
    }

    if (widget.nextFutureDate.isNotEmpty) {
      return widget.nextFutureDate;
    }

    final visits = _buildScheduledVisits();
    final selectedVisit = _getSelectedVisit(visits);

    return selectedVisit?['date']?.toString() ?? '';
  }

  DateTime? _getProductOrderingCutoff(String bookingDate) {
    final visitDate = _parseVisitDate(bookingDate);
    if (visitDate == null) return null;

    final previousDay = visitDate.subtract(const Duration(days: 1));

    return DateTime(
      previousDay.year,
      previousDay.month,
      previousDay.day,
      15,
      30,
    );
  }

  bool _isProductOrderingOpen(String bookingDate) {
    final cutoff = _getProductOrderingCutoff(bookingDate);
    if (cutoff == null) return false;
    return _now.isBefore(cutoff);
  }

  String _getProductOrderingCountdown(String bookingDate) {
    final cutoff = _getProductOrderingCutoff(bookingDate);
    if (cutoff == null) return 'Ordering date unavailable';

    final diff = cutoff.difference(_now);

    if (diff.isNegative || diff.inSeconds <= 0) {
      return 'Ordering closed';
    }

    final hours = diff.inHours;
    final minutes = diff.inMinutes.remainder(60);

    if (hours <= 0) {
      return 'Ordering closes in $minutes mins';
    }

    return 'Ordering closes in $hours hrs $minutes mins';
  }

  String _getCutoffDisplayText(String bookingDate) {
    final cutoff = _getProductOrderingCutoff(bookingDate);
    if (cutoff == null) return '';

    final day = cutoff.day.toString().padLeft(2, '0');
    final month = cutoff.month.toString().padLeft(2, '0');
    final year = cutoff.year.toString();

    return '$day-$month-$year, 3:30 PM';
  }

  void _openOrdersScreen() {
    String bookingDate = '';

    if (widget.booking['bookingType'] == 'monthlySubscription') {
      final rawDates = widget.booking['bookedDates'] as List<dynamic>? ?? [];
      final cleanedDates = rawDates.map((e) => e.toString()).toList();

      cleanedDates.sort((a, b) {
        final aDate = _parseVisitDate(a) ?? DateTime(2100);
        final bDate = _parseVisitDate(b) ?? DateTime(2100);
        return aDate.compareTo(bDate);
      });

      for (final dateStr in cleanedDates) {
        final date = _parseVisitDate(dateStr);
        if (date == null) continue;

        final today = DateTime(_now.year, _now.month, _now.day);
        if (!date.isBefore(today)) {
          bookingDate = dateStr;
          break;
        }
      }

      if (bookingDate.isEmpty && cleanedDates.isNotEmpty) {
        bookingDate = cleanedDates.last;
      }
    } else {
      bookingDate = widget.booking['date']?.toString() ?? '';
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ViewProductsForBookingScreen(
          bookingID: widget.booking['bookingID'],
          date: bookingDate,
          userID: widget.userId,
        ),
      ),
    );
  }

  /*void _showSkipWeekDialog(String selectedDate) {
    final canModify = widget.canModifyVisit(selectedDate);

    if (!canModify) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Skipping visit for $selectedDate is allowed only until ${widget.getVisitModificationCutoffText(selectedDate)}.',
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
        title: const Text('Skip Week', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to skip this week\'s visit?'),
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

              setState(() => _isSkipping = true);

              try {
                await widget.onSkipWeek(
                  booking: widget.booking,
                  dueDate: dueDate,
                );

                if (mounted) {
                  await widget.onRefreshRequested();
                }
              } finally {
                if (mounted) setState(() => _isSkipping = false);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Skip Week', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }*/

  bool _canRescheduleVisit(String dateStr) {
    try {
      final parts = dateStr.split('-');
      if (parts.length != 3) return false;

      final day = int.parse(parts[0]);
      final month = int.parse(parts[1]);

      int year = int.parse(parts[2]);
      if (year < 100) year += 2000;

      final visitDate = DateTime(year, month, day);
      final cutoffDate = visitDate.subtract(const Duration(days: 1));

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

  String _getRescheduleCutoffText(String dateStr) {
    try {
      final parts = dateStr.split('-');
      if (parts.length != 3) return '11:59 PM one day before';

      final day = int.parse(parts[0]);
      final month = int.parse(parts[1]);

      int year = int.parse(parts[2]);
      if (year < 100) year += 2000;

      final visitDate = DateTime(year, month, day);
      final cutoffDate = visitDate.subtract(const Duration(days: 1));

      return '${cutoffDate.day.toString().padLeft(2, '0')}-'
          '${cutoffDate.month.toString().padLeft(2, '0')}-'
          '${cutoffDate.year} at 11:59 PM';
    } catch (_) {
      return '11:59 PM one day before';
    }
  }




  void _openRescheduleScreen(String selectedDate) {
    final canModify = _canRescheduleVisit(selectedDate);

    if (!canModify) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Rescheduling for $selectedDate is allowed only until ${_getRescheduleCutoffText(selectedDate)}.',
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
          booking: widget.booking,
          oldDate: '${parts[0]}-${parts[1]}-${parts[2].substring(2)}',
          assignedMaliId: widget.booking['maaliNo'] ?? '',
        ),
      ),
    ).then((val) async {
      if (val == true) {
        await Future.delayed(const Duration(milliseconds: 800));
        await widget.onRefreshRequested();

        if (!mounted) return;

        Navigator.pop(context, true);
      }
    });
  }

  void _openAddProducts() async {
    final bookingDate = _getBookingDateForProducts();

    if (bookingDate.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No upcoming visit found for adding products.')),
      );
      return;
    }

    if (!_isProductOrderingOpen(bookingDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Ordering for this visit is closed. Cutoff was ${_getCutoffDisplayText(bookingDate)}.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddProductsForNextVisitScreen(
          userID: widget.userId,
          bookingID: widget.booking['bookingID'] ?? '',
          visitDate: bookingDate,
          cartItems: _cart,
          fetchCatalogUrl: widget.fetchCatalogUrl,
          assignedMali: widget.booking['assignedMali']?.toString() ?? '',
          onCartUpdated: (updatedCart) {
            setState(() {
              _cart = List<Map<String, dynamic>>.from(updatedCart);
            });
            widget.onCartUpdated(updatedCart);
          },
        ),
      ),
    );
  }

  Future<void> _cancelPlan() async {
    final bookingID = (widget.booking['bookingID'] ??
        widget.booking['bookingId'] ??
        widget.booking['id'] ??
        '')
        .toString();

    final dueDate = (widget.booking['dueDate'] ??
        widget.booking['date'] ??
        widget.booking['nextFutureDate'] ??
        '')
        .toString();

    final userID = widget.userId;

    if (_cancelPlanApiUrl == 'YOUR_CANCEL_PLAN_API_URL') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please connect cancel plan API URL first.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (userID.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to cancel plan. User details missing.')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Cancel Plan?', style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text(
          'This will mark your subscription as inactive. This plan will no longer appear as an active plan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Cancel Plan'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isCancellingPlan = true);

    try {
      final response = await http.post(
        Uri.parse(_cancelPlanApiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userID': userID,
          'userId': userID,
          'bookingID': bookingID,
          'bookingId': bookingID,
          'dueDate': dueDate,
          'status': 'Inactive',
          'subscriptionStatus': 'Inactive',
        }),
      );

      dynamic body;
      try {
        body = jsonDecode(response.body);
      } catch (_) {
        body = {'success': false, 'message': response.body};
      }

      final isSuccess = response.statusCode >= 200 &&
          response.statusCode < 300 &&
          (body['success'] == true || body['status'] == 'success');

      if (!isSuccess) {
        throw Exception(body['message'] ?? 'Unable to cancel plan');
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Plan cancelled successfully.')),
      );

      await widget.onRefreshRequested();

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cancel failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isCancellingPlan = false);
    }
  }

  void _startRenewalPayment(List<DateTime> renewalDates) {
    final formattedDates = renewalDates.map(_formatDateForDb).toList();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Payment flow will start for renewal dates: ${formattedDates.join(', ')}',
        ),
      ),
    );
  }

  Widget _softCard({
    required Widget child,
    EdgeInsets padding = const EdgeInsets.all(16),
    double radius = 24,
    Color color = Colors.white,
  }) {
    return LiquidGlassInstructionCard(
      radius: radius,
      minHeight: 0,
      padding: padding,
      child: child,
    );
  }



  Widget _currentPlanCard({
    required String planName,
    required String status,
    required Map<String, dynamic>? upcomingVisit,
    required int daysLeft,
    required bool isExpired,
  }) {
    final upcomingText =
    isExpired ? 'Cycle completed' : _getUpcomingVisitLabel(upcomingVisit);

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
                  'CURRENT PLAN',
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w800,
                    color: _gold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: isExpired
                      ? Colors.orange.withOpacity(0.25)
                      : Colors.white.withOpacity(0.20),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  isExpired ? 'Renewal Due' : (status.isEmpty ? 'Active' : status),
                  style: AppTextStyles.chip.copyWith(
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            planName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.heroTitle.copyWith(fontSize: 21),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Text(
                'Renewal Status',
                style: AppTextStyles.chip.copyWith(
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFFD7E7D9),
                ),
              ),
              const Spacer(),
              Text(
                isExpired ? 'Cycle completed' : '$daysLeft Days left',
                style: AppTextStyles.chip.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: isExpired ? 1 : (daysLeft <= 0 ? 0.08 : 0.68),
              minHeight: 5,
              backgroundColor: Colors.white.withOpacity(0.20),
              valueColor: AlwaysStoppedAnimation<Color>(
                isExpired ? Colors.orange : _gold,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              color: _cardGreen,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(
                  isExpired
                      ? Icons.restart_alt_rounded
                      : Icons.event_available_rounded,
                  color: _gold,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isExpired ? 'NEXT ACTION' : 'NEXT VISIT',
                        style: AppTextStyles.tiny.copyWith(
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFFD7E7D9),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        upcomingText,
                        style: AppTextStyles.body.copyWith(
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _dateTabTitleForVisit(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return '${date.day} ${months[date.month - 1]}';
  }

  Widget _upcomingVisitsSection(List<Map<String, dynamic>> visits) {
    if (visits.isEmpty) {
      return _softCard(
        child: Text(
          'No scheduled visits found.',
          style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
        ),
      );
    }

    final selectedIndex = _defaultSelectedIndex(visits);

    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 2),
        itemCount: visits.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final visit = visits[index];
          final date = visit['visitDate'] as DateTime;

          final isSelected = selectedIndex == index;
          final isToday = visit['isToday'] == true;
          final isDone = visit['isDone'] == true;

          String topLabel;

          if (isDone) {
            topLabel = 'Done';
          } else if (isToday) {
            topLabel = 'Today';
          } else {
            topLabel = _dateTabTitleForVisit(date);
          }

          final bottomLabel = isDone
              ? _dateTabTitleForVisit(date)
              : isToday
              ? _weekdayShort(date)
              : _weekdayShort(date);

          final highlightColor = isDone
              ? Colors.red.shade600
              : isSelected || isToday
              ? _gold
              : AppColors.primaryColor;

          final subTextColor = isDone
              ? Colors.red.shade400
              : isSelected || isToday
              ? _gold
              : AppColors.textSecondary;

          return GestureDetector(
            onTap: () => setState(() => _selectedDateIndex = index),
            child: SizedBox(
              width: 82,
              child: LiquidGlassInstructionCard(
                radius: 24,
                minHeight: 88,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      topLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodyLarge.copyWith(
                        fontWeight: FontWeight.w900,
                        color: highlightColor,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      bottomLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.caption.copyWith(
                        fontWeight: FontWeight.w800,
                        color: subTextColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showContactSupportForWateringDialog() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.28),
      builder: (_) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 22),
          child: LiquidGlassInstructionCard(
            radius: 30,
            minHeight: 0,
            padding: EdgeInsets.zero,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: 18,
                  sigmaY: 18,
                ),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.82),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.65),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFB72B).withOpacity(0.18),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(
                          Icons.support_agent_rounded,
                          color: _darkGreen,
                          size: 32,
                        ),
                      ),

                      const SizedBox(height: 18),

                      Text(
                        'Contact Support',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.cardTitle.copyWith(
                          color: _darkGreen,
                          fontWeight: FontWeight.w900,
                        ),
                      ),

                      const SizedBox(height: 10),

                      Text(
                        'Please contact our support team to book watering visits for your plants.',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.body.copyWith(
                          height: 1.45,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),

                      const SizedBox(height: 20),

                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 46,
                              child: OutlinedButton(
                                onPressed: () => Navigator.pop(context),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: _darkGreen,
                                  side: BorderSide(
                                    color: _darkGreen.withOpacity(0.18),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(23),
                                  ),
                                ),
                                child: const Text(
                                  'Okay',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(width: 10),

                          Expanded(
                            child: SizedBox(
                              height: 46,
                              child: ElevatedButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                  // Optional: call WhatsApp/support flow here later.
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _gold,
                                  foregroundColor: Colors.black,
                                  elevation: 0,
                                  shadowColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(23),
                                  ),
                                ),
                                child: const Text(
                                  'Contact Support',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900,
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
              ),
            ),
          ),
        );
      },
    );
  }

  void _showWateringAddOnSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.28),
      builder: (_) {
        return DraggableScrollableSheet(
          initialChildSize: 0.72,
          minChildSize: 0.45,
          maxChildSize: 0.88,
          expand: false,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
              child: LiquidGlassInstructionCard(
                radius: 30,
                minHeight: 0,
                padding: EdgeInsets.zero,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                    ),
                    child: Column(
                      children: [
                        const SizedBox(height: 10),
                        Container(
                          width: 42,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.16),
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        Expanded(
                          child: ListView(
                            controller: scrollController,
                            padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 52,
                                    height: 52,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEAF8EF),
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                    child: const Icon(
                                      Icons.water_drop_rounded,
                                      color: _darkGreen,
                                      size: 28,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '+Watering Add-On',
                                          style: AppTextStyles.bodyLarge.copyWith(
                                            fontSize: 17,
                                            fontWeight: FontWeight.w900,
                                            color: _darkGreen,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Optional watering visit service',
                                          style: AppTextStyles.caption.copyWith(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 18),

                              Text(
                                'Plant Care Advisory',
                                style: AppTextStyles.bodyLarge.copyWith(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: _darkGreen,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'To support customers requiring regular watering assistance, Gold Dust has introduced an optional plant watering visit service.',
                                style: AppTextStyles.caption.copyWith(
                                  fontSize: 12,
                                  height: 1.45,
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),

                              const SizedBox(height: 18),

                              _wateringDetailTile(
                                icon: Icons.local_florist_rounded,
                                title: 'Service Type',
                                value: 'Watering-only visit by maali',
                              ),
                              const SizedBox(height: 10),
                              _wateringDetailTile(
                                icon: Icons.timer_rounded,
                                title: 'Duration',
                                value: '30 minutes',
                              ),
                              const SizedBox(height: 10),
                              _wateringDetailTile(
                                icon: Icons.currency_rupee_rounded,
                                title: 'Charge',
                                value: '₹39 per visit',
                              ),
                              const SizedBox(height: 10),
                              _wateringDetailTile(
                                icon: Icons.receipt_long_rounded,
                                title: 'Billing',
                                value: 'Monthly billing applicable',
                              ),

                              const SizedBox(height: 18),

                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEAF8EF),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: _darkGreen.withOpacity(0.10),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Example',
                                      style: AppTextStyles.bodyLarge.copyWith(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w900,
                                        color: _darkGreen,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      '15 visits in a month = ₹585',
                                      style: AppTextStyles.title.copyWith(
                                        fontWeight: FontWeight.w900,
                                        color: _darkGreen,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 18),

                              _wateringNote(
                                icon: Icons.access_time_filled_rounded,
                                text:
                                'Watering visits will only be available in the 4:00 PM to 5:00 PM slot.',
                              ),
                              const SizedBox(height: 10),
                              _wateringNote(
                                icon: Icons.groups_rounded,
                                text:
                                'Same maali may or may not be allocated, as watering can be done by any of our trained maalis.',
                              ),
                              const SizedBox(height: 10),
                              _wateringNote(
                                icon: Icons.event_busy_rounded,
                                text:
                                'Rescheduling is not allowed for watering visits.',
                              ),

                              const SizedBox(height: 24),

                              SizedBox(
                                width: double.infinity,
                                height: 52,
                                child: ElevatedButton(
                                  onPressed: () {
                                    Navigator.pop(context);

                                    Future.delayed(const Duration(milliseconds: 180), () {
                                      if (!mounted) return;
                                      _showContactSupportForWateringDialog();
                                    });
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _gold,
                                    foregroundColor: Colors.black,
                                    elevation: 0,
                                    shadowColor: Colors.transparent,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(26),
                                    ),
                                  ),
                                  child: const Text(
                                    'Book Watering Service',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w900,
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
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _wateringDetailTile({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return LiquidGlassInstructionCard(
      radius: 20,
      minHeight: 0,
      padding: const EdgeInsets.all(13),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFFFB72B).withOpacity(0.16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              color: _gold,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.toUpperCase(),
                  style: AppTextStyles.tiny.copyWith(
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: _darkGreen,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _wateringNote({
    required IconData icon,
    required String text,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 18,
          color: _gold,
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            text,
            style: AppTextStyles.caption.copyWith(
              fontSize: 11,
              height: 1.35,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _actionButtons(Map<String, dynamic>? selectedVisit) {
    final selectedDate = selectedVisit?['date']?.toString() ?? '';

    return SizedBox(
      height: 79,
      child: Row(
        children: [
          _smallActionButton(
            icon: Icons.calendar_month_rounded,
            title: 'Reschedule',
            onTap: selectedDate.isEmpty
                ? null
                : () => _openRescheduleScreen(selectedDate),
          ),

          const Spacer(),

          _smallActionButton(
            icon: Icons.water_drop_rounded,
            title: '+Watering',
            onTap: _showWateringAddOnSheet,
          ),

          const Spacer(),

          _smallActionButton(
            icon: Icons.receipt_long_rounded,
            title: 'View Order',
            onTap: _openOrdersScreen,
          ),
        ],
      ),
    );
  }

  Widget _smallActionButton({
    required IconData icon,
    required String title,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: SizedBox(
        width: 96,
        height: 75,
        child: LiquidGlassInstructionCard(
          radius: 24,
          minHeight: 75,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 21,
                color: onTap == null ? Colors.grey : _gold,
              ),
              const SizedBox(height: 8),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: AppTextStyles.tiny.copyWith(
                  fontWeight: FontWeight.w800,
                  color: onTap == null ? Colors.grey : _darkGreen,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _normalizeMaaliId(String value) {
    final raw = value.trim().toUpperCase();

    if (raw.isEmpty) return '';

    final match = RegExp(r'^KLM0*(\d+)$').firstMatch(raw);

    if (match == null) return raw;

    final number = int.tryParse(match.group(1) ?? '');

    if (number == null) return raw;

    return 'KLM${number.toString().padLeft(5, '0')}';
  }

  String _getMaaliPhotoUrl(String maaliId, String maaliName) {
    final id = _normalizeMaaliId(maaliId);
    final name = maaliName.trim().toLowerCase();

    final Map<String, String> maaliPhotosById = {
      'KLM00017': 'https://supervisormaalitask.s3.amazonaws.com/employee-docs/KLM00017/e5f1fb444bec4081aa1b01dd4a668029.jpg',
      'KLM00030': 'https://supervisormaalitask.s3.amazonaws.com/employee-docs/KLM00017/e5f1fb444bec4081aa1b01dd4a668029.jpg',
      'KLM00029': 'https://supervisormaalitask.s3.amazonaws.com/employee-docs/KLM00017/e5f1fb444bec4081aa1b01dd4a668029.jpg',
      'KLM00022': 'https://supervisormaalitask.s3.amazonaws.com/employee-docs/KLM00022/88c00393155c4acd96f8d7385a8597c1.jpg',
      'KLM00005': 'https://supervisormaalitask.s3.amazonaws.com/employee-docs/KLM00005/cfdeead0f57e4516a8fc104a966c6784.jpg',
      'KLM00026': 'https://supervisormaalitask.s3.amazonaws.com/employee-docs/KLM00026/46277e4a398c4b2498926ca78bb42514.jpg',
      'KLM00024': 'https://supervisormaalitask.s3.amazonaws.com/employee-docs/KLM00024/cf1e534a9df5448dbc5472a51500ef0e.jpg',
      'KLM00009': 'https://supervisormaalitask.s3.amazonaws.com/employee-docs/KLM00009/b0d95ed61339491090733cc23de05273.jpg',
      'KLM00025': 'https://supervisormaalitask.s3.amazonaws.com/employee-docs/KLM00025/18fb7ee819954e56b538384cbf7cf820.jpg',
      'KLM00001': 'https://supervisormaalitask.s3.amazonaws.com/employee-docs/KLM00001/089174d561494caba78a7c02bc70869c.jpg',
      'KLM00016': 'https://supervisormaalitask.s3.amazonaws.com/employee-docs/KLM00016/02641b7761ce4f9691012d8f6ac2588a.jpg',
      'KLM00032': 'https://supervisormaalitask.s3.amazonaws.com/employee-docs/KLM00017/e5f1fb444bec4081aa1b01dd4a668029.jpg',
      'KLM00027': 'https://supervisormaalitask.s3.amazonaws.com/employee-docs/KLM00027/1a7226c3d0fd4d23bf75fa576c299c73.jpg',
      'KLM00019': 'https://supervisormaalitask.s3.amazonaws.com/employee-docs/KLM00019/abf58c94419b4fbea6dc936298819450.jpg',
      'KLM00015': 'https://supervisormaalitask.s3.amazonaws.com/employee-docs/KLM00015/5bd3c47cb06a4c308d98c3355081197c.jpg',
    };

    final Map<String, String> maaliPhotosByName = {
      'aakash': maaliPhotosById['KLM00017']!,
      'dharmend': maaliPhotosById['KLM00030']!,
      'gobind': maaliPhotosById['KLM00029']!,
      'indrakesh': maaliPhotosById['KLM00022']!,
      'keshav': maaliPhotosById['KLM00005']!,
      'lavkush': maaliPhotosById['KLM00026']!,
      'pankaj': maaliPhotosById['KLM00024']!,
      'ravi': maaliPhotosById['KLM00009']!,
      'ritesh': maaliPhotosById['KLM00025']!,
      'sachin': maaliPhotosById['KLM00001']!,
      'samar': maaliPhotosById['KLM00016']!,
      'vijay': maaliPhotosById['KLM00032']!,
      'vikas': maaliPhotosById['KLM00027']!,
      'vineet': maaliPhotosById['KLM00019']!,
      'yogender': maaliPhotosById['KLM00015']!,
    };

    debugPrint('🧑‍🌾 Maali photo lookup => rawId=$maaliId, normalizedId=$id, name=$name');

    if (maaliPhotosById.containsKey(id)) {
      debugPrint('✅ Maali photo found by ID: ${maaliPhotosById[id]}');
      return maaliPhotosById[id]!;
    }

    if (maaliPhotosByName.containsKey(name)) {
      debugPrint('✅ Maali photo found by name: ${maaliPhotosByName[name]}');
      return maaliPhotosByName[name]!;
    }

    debugPrint('❌ No maali photo found for id=$id name=$name');

    return '';
  }


  Widget _assignedExpertCard(String assignedMali) {
    final societyCount = (widget.booking['societyCount'] ??
        widget.booking['societies'] ??
        widget.booking['assignedSocieties'] ??
        '121')
        .toString();

    final maaliId = (widget.booking['maaliNo'] ??
        widget.booking['maaliID'] ??
        widget.booking['maliNo'] ??
        widget.booking['maliID'] ??
        widget.booking['assignedMaliId'] ??
        widget.booking['assignedMaliID'] ??
        widget.booking['assignedMaaliId'] ??
        widget.booking['assignedMaaliID'] ??
        widget.booking['maaliId'] ??
        widget.booking['maaliID'] ??
        '')
        .toString();

    debugPrint('🧑‍🌾 Assigned maali name: $assignedMali');
    debugPrint('🧑‍🌾 Booking maali raw fields: ${widget.booking}');
    debugPrint('🧑‍🌾 Extracted maaliId: $maaliId');

    final maaliPhotoUrl = _getMaaliPhotoUrl(maaliId, assignedMali);

    return LiquidGlassInstructionCard(
      radius: 24,
      minHeight: 92,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: 58,
                  height: 64,
                  color: const Color(0xFFEAF8EF),
                  child: maaliPhotoUrl.trim().isNotEmpty
                      ? Image.network(
                    maaliPhotoUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.person_rounded,
                      size: 34,
                      color: _darkGreen,
                    ),
                  )
                      : const Icon(
                    Icons.person_rounded,
                    size: 34,
                    color: _darkGreen,
                  ),
                ),
              ),
              Positioned(
                right: -1,
                bottom: -1,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: const BoxDecoration(
                    color: _gold,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.verified_rounded,
                    size: 13,
                    color: _darkGreen,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'ASSIGNED EXPERT (MAALI)',
                  style: AppTextStyles.tiny.copyWith(
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  assignedMali,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyLarge.copyWith(
                    fontWeight: FontWeight.w800,
                    color: _darkGreen,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  maaliId.isNotEmpty ? maaliId : '$societyCount Sessions',
                  style: AppTextStyles.chip.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.star_rounded, size: 18, color: _gold),
          const SizedBox(width: 3),
          const Text(
            '5.0',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: _darkGreen,
            ),
          ),
        ],
      ),
    );
  }

  Widget _enhanceNextVisitHeader(String bookingDate) {
    final countdownText =
    bookingDate.isEmpty ? 'No upcoming visit found' : _getProductOrderingCountdown(bookingDate);

    final isOpen = bookingDate.isNotEmpty && _isProductOrderingOpen(bookingDate);

    return InkWell(
      onTap: isOpen ? _openAddProducts : null,
      borderRadius: BorderRadius.circular(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Enhance Your Next Visit',
                  style: AppTextStyles.sectionTitle.copyWith(
                    fontWeight: FontWeight.w500,
                    color: _darkGreen,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      isOpen ? Icons.timer_outlined : Icons.lock_clock_rounded,
                      size: 13,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        countdownText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFFFE3E3),
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Text(
              'SHOP NOW',
              style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w900,
                color: Color(0xFFC93535),
              ),
            ),
          ),
          const SizedBox(width: 8),
          const Padding(
            padding: EdgeInsets.only(top: 3),
            child: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: _darkGreen),
          ),
        ],
      ),
    );
  }

  Widget _recommendedProductsPreview() {
    final products = [
      {
        'title': 'Sikotiya Palm - 10 inch',
        'subtitle': 'Dense Indoor Plant',
        'price': '₹359.00',
        'image': 'assets/images/sikotiya_palm.png',
      },
      {
        'title': 'Metal Rectangular Railing Planter - White',
        'subtitle': 'Outdoor Planter',
        'price': '₹310.00',
        'image': 'assets/images/railing_planter.png',
      },
      {
        'title': 'Ixora - 6 inch',
        'subtitle': 'Outdoor Flowering Plant',
        'price': '₹129.00',
        'image': 'assets/images/ixora.png',
      },
    ];

    return Column(
      children: [
        _largeRecommendedProduct(products[0]),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _smallRecommendedProduct(products[1])),
            const SizedBox(width: 14),
            Expanded(child: _smallRecommendedProduct(products[2])),
          ],
        ),
      ],
    );
  }

  Widget _largeRecommendedProduct(Map<String, dynamic> product) {
    return InkWell(
      onTap: _openAddProducts,
      borderRadius: BorderRadius.circular(24),
      child: SizedBox(
        width: double.infinity,
        height: 118,
        child: LiquidGlassInstructionCard(
          radius: 24,
          minHeight: 118,
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.asset(
                  product['image'].toString(),
                  width: 86,
                  height: 86,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 86,
                    height: 86,
                    color: const Color(0xFFEAF8EF),
                    child: const Icon(Icons.image_outlined, color: _darkGreen),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product['title'].toString(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodyLarge.copyWith(
                        fontWeight: FontWeight.w700,
                        color: _darkGreen,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      product['subtitle'].toString(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      product['price'].toString(),
                      style: AppTextStyles.cardTitle.copyWith(
                        fontWeight: FontWeight.w900,
                        color: _darkGreen,
                      ),
                    ),
                  ],
                ),
              ),
              _orangePlusButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _smallRecommendedProduct(Map<String, dynamic> product) {
    return InkWell(
      onTap: _openAddProducts,
      borderRadius: BorderRadius.circular(24),
      child: SizedBox(
        height: 218,
        child: LiquidGlassInstructionCard(
          radius: 24,
          minHeight: 218,
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.asset(
                  product['image'].toString(),
                  height: 96,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 96,
                    width: double.infinity,
                    color: const Color(0xFFEAF8EF),
                    child: const Icon(Icons.image_outlined, color: _darkGreen),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                product['title'].toString(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.body.copyWith(
                  fontWeight: FontWeight.w700,
                  color: _darkGreen,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                product['subtitle'].toString(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.chip.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      product['price'].toString(),
                      style: AppTextStyles.title.copyWith(
                        fontWeight: FontWeight.w900,
                        color: _darkGreen,
                      ),
                    ),
                  ),
                  _orangePlusButton(size: 34, iconSize: 20),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _orangePlusButton({double size = 42, double iconSize = 24}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _gold,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: _gold.withOpacity(0.45),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Icon(Icons.add, color: Colors.black, size: iconSize),
    );
  }

  Widget _expiredPlanActionsCard(List<Map<String, dynamic>> visits) {
    final renewalDates = _buildNextRenewalDates(visits);
    final amount =
    (widget.booking['bookingAmount'] ?? widget.booking['monthlyAmount'] ?? '')
        .toString();

    final planName = (widget.booking['planName'] ?? 'Current Plan').toString();

    return _softCard(
      radius: 22,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your subscription cycle is complete',
            style: AppTextStyles.cardTitle.copyWith(color: _darkGreen),
          ),
          const SizedBox(height: 8),
          Text(
            'Renew your plan to continue weekly garden care, or cancel this plan to stop showing it as active.',
            style: AppTextStyles.body.copyWith(
              height: 1.45,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFEAF8EF),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _darkGreen.withOpacity(0.10)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Renew $planName',
                  style: AppTextStyles.title.copyWith(color: _darkGreen),
                ),
                const SizedBox(height: 6),
                Text(
                  amount.isEmpty
                      ? 'Next 4 visits'
                      : 'Amount: ₹$amount • Next 4 visits',
                  style: AppTextStyles.small.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                Column(
                  children: renewalDates.map((date) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          const Icon(Icons.event_available_rounded, size: 17, color: _darkGreen),
                          const SizedBox(width: 8),
                          Text(
                            _formatReadableDate(date),
                            style: AppTextStyles.body.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () => _startRenewalPayment(renewalDates),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _darkGreen,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    child: Text(
                      'Make Payment & Renew',
                      style: AppTextStyles.bodyLarge.copyWith(
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: OutlinedButton(
              onPressed: _isCancellingPlan ? null : _cancelPlan,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(23),
                ),
              ),
              child: _isCancellingPlan
                  ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.red,
                ),
              )
                  : Text(
                'Cancel Plan',
                style: AppTextStyles.bodyLarge.copyWith(
                  fontWeight: FontWeight.w800,
                  color: Colors.red,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

 /* Widget _viewOrdersButton() {
    return TextButton.icon(
      onPressed: _openOrdersScreen,
      icon: const Icon(Icons.receipt_long_outlined, size: 18),
      label: const Text('View Product Orders'),
      style: TextButton.styleFrom(
        foregroundColor: _darkGreen,
        textStyle: AppTextStyles.body.copyWith(fontWeight: FontWeight.w800),
      ),
    );
  }*/

  @override
  Widget build(BuildContext context) {
    final visits = _buildScheduledVisits();
    final selectedVisit = _getSelectedVisit(visits);

    final planName = (widget.booking['planName'] ?? 'Plan').toString();
    final assignedMali =
    (widget.booking['assignedMali'] ?? 'Not assigned').toString();
    final status = (widget.booking['subscriptionStatus'] ?? 'Active').toString();

    final bookingDate = _getBookingDateForProducts();

    final daysLeft = _getDaysLeftForPlan(visits);
    final isPlanExpired = _isPlanExpired(visits);

    return Scaffold(
      backgroundColor: _softBg,
      appBar: AppBar(
        backgroundColor: _softBg,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        title: Text(
          'Subscription Details',
          style: AppTextStyles.cardTitle.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: widget.onRefreshRequested,
        color: AppColors.primaryColor,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
          children: [
            _currentPlanCard(
              planName: planName,
              status: status,
              upcomingVisit: selectedVisit,
              daysLeft: daysLeft,
              isExpired: isPlanExpired,
            ),
            const SizedBox(height: 24),
            Text(
              isPlanExpired ? 'Completed Visits' : 'Upcoming Visit',
              style: AppTextStyles.sectionTitle.copyWith(
                fontWeight: FontWeight.w500,
                color: _darkGreen,
              ),
            ),
            const SizedBox(height: 14),
            _upcomingVisitsSection(visits),
            const SizedBox(height: 18),
            if (!isPlanExpired) ...[
              _actionButtons(selectedVisit),
              const SizedBox(height: 18),
            ],
            _assignedExpertCard(assignedMali),
            const SizedBox(height: 22),
            if (isPlanExpired) ...[
              _expiredPlanActionsCard(visits),
            ] else ...[
              _enhanceNextVisitHeader(bookingDate),
              const SizedBox(height: 16),
              _recommendedProductsPreview(),
              const SizedBox(height: 8),
              /*Align(
                alignment: Alignment.centerLeft,
                child: _viewOrdersButton(),
              ),*/
              /*const SizedBox(height: 18),
              if (selectedVisit != null &&
                  selectedVisit['isFuture'] == true &&
                  selectedVisit['date'] != null)
                OutlinedButton.icon(
                  onPressed: _isSkipping
                      ? null
                      : () => _showSkipWeekDialog(
                    selectedVisit['date'].toString(),
                  ),
                  icon: const Icon(Icons.skip_next_rounded),
                  label: Text(_isSkipping ? 'Skipping...' : 'Skip This Week'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.orange.shade700,
                    side: BorderSide(color: Colors.orange.shade300),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),*/
            ],
            const SizedBox(height: 18),
          ],
        ),
      ),
    );
  }
}