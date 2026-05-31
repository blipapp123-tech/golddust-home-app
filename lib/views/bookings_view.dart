import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../app/app_constants.dart';
import '../services/booking_service.dart';
import 'subscription_details_screen.dart';

class BookingsView extends StatefulWidget {
  final String userId;
  final String? userName;
  final String? profilePhotoUrl;

  const BookingsView({
    super.key,
    required this.userId,
    this.userName,
    this.profilePhotoUrl,
  });

  @override
  State<BookingsView> createState() => _BookingsViewState();
}

class _BookingsViewState extends State<BookingsView> {
  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _errorMessage;
  List<dynamic> _bookings = [];
  Timer? _autoRefreshTimer;
  String _resolvedUserId = '';

  @override
  void initState() {
    super.initState();
    _fetchBookings();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  void _startAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) {
        _fetchBookings(isAutoRefresh: true);
      }
    });
  }

  Future<String> _resolveUserId() async {
    if (widget.userId.trim().isNotEmpty) {
      return widget.userId.trim();
    }

    final prefs = await SharedPreferences.getInstance();

    final savedUserId = prefs.getString('userId')?.trim() ?? '';
    if (savedUserId.isNotEmpty) {
      return savedUserId;
    }

    final savedUserID = prefs.getString('userID')?.trim() ?? '';
    if (savedUserID.isNotEmpty) {
      return savedUserID;
    }

    final savedPhone = prefs.getString('bookingPhone')?.trim() ?? '';
    if (savedPhone.isNotEmpty) {
      return 'otp$savedPhone';
    }

    return '';
  }

  Future<void> _fetchBookings({bool isAutoRefresh = false}) async {
    if (!isAutoRefresh) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    } else {
      _isRefreshing = true;
    }

    try {
      final resolvedUserId = await _resolveUserId();

      if (resolvedUserId.isEmpty) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _isRefreshing = false;
          _errorMessage =
          'No booking identity found yet. Please create an expert visit first using your phone number.';
        });
        return;
      }

      final data = await BookingService.fetchExpertVisits(resolvedUserId);

      if (!mounted) return;
      setState(() {
        _resolvedUserId = resolvedUserId;
        _bookings = data;
        _sortBookings();
        _isLoading = false;
        _isRefreshing = false;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
        _isRefreshing = false;
      });
    }
  }

  void _sortBookings() {
    _bookings.sort((a, b) {
      final aDate = _parseDate(a['dateOfVisit']?.toString() ?? '');
      final bDate = _parseDate(b['dateOfVisit']?.toString() ?? '');

      if (aDate == null && bDate == null) return 0;
      if (aDate == null) return 1;
      if (bDate == null) return -1;

      return bDate.compareTo(aDate);
    });
  }

  DateTime? _parseDate(String value) {
    try {
      return DateFormat('dd-MM-yyyy').parse(value);
    } catch (_) {
      return null;
    }
  }

  String _formatDate(String value) {
    try {
      final date = DateFormat('dd-MM-yyyy').parse(value);
      return DateFormat('EEEE, dd MMM yyyy').format(date);
    } catch (_) {
      return value;
    }
  }

  String _capitalizeStatus(String status) {
    if (status.isEmpty) return 'Pending';
    final lower = status.toLowerCase();
    if (lower == 'subscription booked') return 'Subscription Booked';
    if (lower == 'rescheduled') return 'Rescheduled';
    if (lower == 'cancelled') return 'Cancelled';
    if (lower == 'completed') return 'Completed';
    if (lower == 'pending') return 'Pending';
    return status[0].toUpperCase() + status.substring(1);
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      case 'rescheduled':
        return Colors.purple;
      case 'subscription booked':
        return Colors.blue;
      case 'pending':
      default:
        return Colors.orange;
    }
  }

  IconData _statusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Icons.check_circle;
      case 'cancelled':
        return Icons.cancel;
      case 'rescheduled':
        return Icons.update;
      case 'subscription booked':
        return Icons.verified;
      case 'pending':
      default:
        return Icons.schedule;
    }
  }

  String _buildAddress(Map<String, dynamic> booking) {
    final flatNo = (booking['flatNo'] ?? '').toString().trim();
    final towerNo = (booking['towerNo'] ?? '').toString().trim();
    final society = (booking['society'] ?? '').toString().trim();
    final sector = (booking['sector'] ?? '').toString().trim();

    final parts = <String>[];

    if (flatNo.isNotEmpty) parts.add(flatNo);
    if (towerNo.isNotEmpty) parts.add('Tower $towerNo');
    if (society.isNotEmpty) parts.add(society);
    if (sector.isNotEmpty) parts.add(sector);

    return parts.isEmpty ? 'Address not available' : parts.join(', ');
  }

  bool _isCompletedBooking(Map<String, dynamic> booking) {
    final status = (booking['status'] ?? '').toString().trim().toLowerCase();
    return status == 'completed';
  }

  Future<void> _openSubscriptionDetails(Map<String, dynamic> booking) async {
    final bookingMap = Map<String, dynamic>.from(booking);

    final bookedDate = (bookingMap['dateOfVisit'] ?? '').toString().trim();
    final bookedTime = (bookingMap['timeOfVisit'] ?? '').toString().trim();

    final subscriptionBooking = <String, dynamic>{
      'bookingID': bookingMap['visitID'] ??
          bookingMap['bookingID'] ??
          bookingMap['taskID'] ??
          '',
      'bookingType': 'monthlySubscription',
      'planName': bookingMap['planName'] ?? 'Subscription Plan',
      'bookingAmount': bookingMap['bookingAmount'] ?? bookingMap['monthlyAmount'] ?? 0,
      'assignedMali': bookingMap['assignedMali'] ?? bookingMap['maaliName'] ?? '',
      'maaliNo': bookingMap['assignedMaliId'] ?? bookingMap['maaliNo'] ?? '',
      'subscriptionStatus': bookingMap['status'] ?? 'Subscription Booked',
      'bookedDates': bookedDate.isNotEmpty ? [bookedDate] : <String>[],
      'dayTimeSlots': [
        {
          'day': bookedDate.isNotEmpty ? bookedDate : '',
          'timeSlot': bookedTime,
        }
      ],
      'Mobile': bookingMap['phoneNo'] ?? '',
      'dueDate': bookedDate,
      'dealStatus': 'active',
      'renewalPaymentPending': bookingMap['renewalPaymentPending'] ?? false,
      'fullName': bookingMap['fullName'] ?? '',
      'flatNo': bookingMap['flatNo'] ?? '',
      'towerNo': bookingMap['towerNo'] ?? '',
      'society': bookingMap['society'] ?? '',
      'sector': bookingMap['sector'] ?? '',
    };

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SubscriptionDetailsScreen(
          booking: subscriptionBooking,
          userId: _resolvedUserId.isNotEmpty ? _resolvedUserId : widget.userId,
          userName: widget.userName ?? '',
          profilePhotoUrl: widget.profilePhotoUrl ?? '',
          cartItems: const [],
          nextEligibleBookingDate: bookedDate,
          nextFutureDate: bookedDate,
          timeRemaining: '',
          isWithinCutoff: false,
          fetchCatalogUrl:
          'https://lhz6z20eg6.execute-api.ap-south-1.amazonaws.com/default/fetchInventoryForBookingCatalog',
          onCartUpdated: (_) {},
          onRefreshRequested: () async {
            await _fetchBookings();
          },
          onSkipWeek: ({
            required Map<String, dynamic> booking,
            required String dueDate,
          }) async {},
          canModifyVisit: (_) => true,
          getVisitModificationCutoffText: (_) => '3:00 PM one day before',
          getCutoffDateString: (date) => date,
        ),
      ),
    );

    if (result == true) {
      _fetchBookings();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.secondaryColor,
      appBar: AppBar(
        backgroundColor: AppColors.secondaryColor,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        title: const Text(
          'My Bookings',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          if (_isRefreshing)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            IconButton(
              onPressed: () => _fetchBookings(),
              icon: const Icon(Icons.refresh),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
        child: CircularProgressIndicator(
          color: AppColors.primaryColor,
        ),
      )
          : _errorMessage != null
          ? _buildErrorState()
          : _bookings.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
        onRefresh: _fetchBookings,
        color: AppColors.primaryColor,
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: _bookings.length,
          separatorBuilder: (_, __) => const SizedBox(height: 14),
          itemBuilder: (context, index) {
            final booking =
            Map<String, dynamic>.from(_bookings[index]);
            return _buildBookingCard(booking);
          },
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 68, color: Colors.red.shade300),
            const SizedBox(height: 14),
            const Text(
              'Unable to load bookings',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Something went wrong',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _fetchBookings,
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
            const SizedBox(height: 16),
            const Text(
              'No bookings yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your expert visits will appear here once you create a booking.',
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

  Widget _buildBookingCard(Map<String, dynamic> booking) {
    final status = (booking['status'] ?? 'Pending').toString();
    final statusColor = _statusColor(status);
    final statusIcon = _statusIcon(status);

    final dateOfVisit = (booking['dateOfVisit'] ?? '').toString();
    final timeOfVisit = (booking['timeOfVisit'] ?? '').toString();
    final fullName = (booking['fullName'] ?? '').toString().trim();
    final phoneNo = (booking['phoneNo'] ?? '').toString().trim();
    final address = _buildAddress(booking);
    final isCompleted = _isCompletedBooking(booking);

    return GestureDetector(
      onTap: () => _openSubscriptionDetails(booking),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isCompleted ? Colors.green.shade200 : AppColors.border,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 14, color: statusColor),
                      const SizedBox(width: 6),
                      Text(
                        _capitalizeStatus(status),
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                const Icon(
                  Icons.calendar_today_outlined,
                  size: 18,
                  color: AppColors.primaryColor,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              dateOfVisit.isNotEmpty
                  ? _formatDate(dateOfVisit)
                  : 'Date unavailable',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              timeOfVisit.isNotEmpty ? timeOfVisit : 'Time unavailable',
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 14),
            if (fullName.isNotEmpty) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.person_outline,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      fullName,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
            if (phoneNo.isNotEmpty) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.phone_outlined,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      phoneNo,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    address,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
            if (isCompleted) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.green.withOpacity(0.18)),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.visibility_outlined,
                      size: 18,
                      color: Colors.green,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'View subscription plan and make payment',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.green,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 14,
                      color: Colors.green,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}