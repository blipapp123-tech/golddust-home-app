import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app/app_constants.dart';
import '../app/app_text_styles.dart';
import '../app/routes.dart';
import '../widgets/liquid_glass_instruction_card.dart';
import 'booking_details_view.dart';
import '../services/booking_service.dart';

class ScheduleBookingView extends StatefulWidget {
  final String? userId;
  final String? userName;
  final String? profilePhotoUrl;
  final String? serviceLocation;
  final String? serviceTitle;
  final String? serviceSubtitle;
  final String? initialPhone;
  final String? initialFlatNumber;
  final String? initialTowerNumber;
  final String? initialSocietyName;
  final String? initialSectorLocality;

  const ScheduleBookingView({
    super.key,
    this.userId,
    this.userName,
    this.profilePhotoUrl,
    this.serviceLocation,
    this.serviceTitle,
    this.serviceSubtitle,
    this.initialPhone,
    this.initialFlatNumber,
    this.initialTowerNumber,
    this.initialSocietyName,
    this.initialSectorLocality,
  });

  @override
  State<ScheduleBookingView> createState() => _ScheduleBookingViewState();
}

class _ScheduleBookingViewState extends State<ScheduleBookingView> {
  bool _isLoading = true;
  bool _isCheckingExistingBooking = false;
  String? _errorMessage;

  String _resolvedUserId = '';

  Map<String, dynamic> _availabilityData = {};
  List<DateTime> _availableDates = [];
  int _selectedExpertIndex = 0;
  String? _selectedDate;
  String? _selectedSlot;

  static const Color _darkGreen = Color(0xFF063F20);
  static const Color _cardGreen = Color(0xFF174F2D);
  static const Color _gold = Color(0xFFFFB72B);
  static const Color _softBg = Colors.white;

  @override
  void initState() {
    super.initState();
    _initializeScreen();
  }

  Future<void> _initializeScreen() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final resolvedUserId = await _resolveUserId();
      _resolvedUserId = resolvedUserId;

      final hasActiveBooking = await _hasOpenBooking(resolvedUserId);

      if (!mounted) return;

      if (hasActiveBooking) {
        Get.offNamed(
          AppRoutes.bookings,
          arguments: resolvedUserId.isNotEmpty ? resolvedUserId : widget.userId,
        );
        return;
      }

      await _fetchAvailability();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  String _formatDateKey(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}';
  }

  String _weekdayShort(DateTime date) {
    const shortWeekdays = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    return shortWeekdays[date.weekday - 1];
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

  String _dateTabTitle(DateTime date) {
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

  String _shortDayLabel(DateTime date) {
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    final tomorrowOnly = todayOnly.add(const Duration(days: 1));
    final dateOnly = DateTime(date.year, date.month, date.day);

    if (dateOnly.isAtSameMomentAs(todayOnly)) return 'Today';
    if (dateOnly.isAtSameMomentAs(tomorrowOnly)) return 'Tomorrow';

    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];

    return days[date.weekday - 1];
  }

  String _expertPhotoUrl(String expertName) {
    final name = expertName.trim().toLowerCase();

    final photos = {
      'sameet':
      'https://supervisormaalitask.s3.ap-south-1.amazonaws.com/employee-docs/KLHE00002/Sameet_Mugshot.png',

      'keshav':
      'https://supervisormaalitask.s3.ap-south-1.amazonaws.com/employee-docs/KLHE00004/Keshav_Mugshot.png',

      'sajan': 'https://supervisormaalitask.s3.ap-south-1.amazonaws.com/employee-docs/KLHE00001/Sajan_MugShot.png',
      'vinay': 'https://supervisormaalitask.s3.ap-south-1.amazonaws.com/employee-docs/KLS00003/Vinay_MugShot.png',
      'basant': 'https://supervisormaalitask.s3.ap-south-1.amazonaws.com/employee-docs/KLS00002/Basant_MugShot.png',
    };

    return photos[name] ?? '';
  }

  bool _isTomorrow(DateTime date) {
    final today = DateTime.now().toLocal();
    final tomorrow = DateTime(today.year, today.month, today.day + 1);
    final normalized = DateTime(date.year, date.month, date.day);

    return normalized.isAtSameMomentAs(tomorrow);
  }

  bool _isDateSelectable(DateTime date) {
    final today = DateTime.now().toLocal();
    final tomorrow = DateTime(today.year, today.month, today.day + 1);
    final normalized = DateTime(date.year, date.month, date.day);

    return normalized.isAfter(tomorrow) ||
        normalized.isAtSameMomentAs(tomorrow);
  }

  List<DateTime> _extractAvailableDates(Map<String, dynamic> data) {
    final List<DateTime> dates = [];

    for (final entry in data.entries) {
      try {
        final parts = entry.key.split('-');
        if (parts.length != 3) continue;

        final day = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        final year = int.parse(parts[2]);

        final parsedDate = DateTime(year, month, day);
        final slots = entry.value;
        final hasSlots = slots is List && slots.isNotEmpty;

        if (_isDateSelectable(parsedDate) && hasSlots) {
          dates.add(parsedDate);
        }
      } catch (_) {}
    }

    dates.sort((a, b) => a.compareTo(b));

    // Shows only next 7 available expert visit dates.
    return dates.take(7).toList();
  }

  List<String> get _selectedDateSlots {
    if (_selectedDate == null) return [];

    final raw = _availabilityData[_selectedDate];

    if (raw is List) {
      return raw.map((e) => e.toString()).toList();
    }

    return [];
  }

  Future<void> _fetchAvailability() async {
    try {
      final data = await BookingService.fetchExpertAvailability();
      final dates = _extractAvailableDates(data);

      if (!mounted) return;

      setState(() {
        _availabilityData = data;
        _availableDates = dates;
        _isLoading = false;

        if (_availableDates.isNotEmpty) {
          _selectedDate = _formatDateKey(_availableDates.first);

          final slots = _availabilityData[_selectedDate];
          if (slots is List && slots.isNotEmpty) {
            _selectedSlot = slots.first.toString();
          }
        }
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<String> _resolveUserId() async {
    if ((widget.userId ?? '').trim().isNotEmpty) {
      return widget.userId!.trim();
    }

    final prefs = await SharedPreferences.getInstance();

    final savedUserId = prefs.getString('userId')?.trim() ?? '';
    if (savedUserId.isNotEmpty) return savedUserId;

    final savedUserID = prefs.getString('userID')?.trim() ?? '';
    if (savedUserID.isNotEmpty) return savedUserID;

    final savedPhone = prefs.getString('bookingPhone')?.trim() ?? '';
    if (savedPhone.isNotEmpty) return 'otp$savedPhone';

    return '';
  }

  bool _isOpenStatus(String status) {
    final normalized = status.trim().toLowerCase();

    return normalized == 'pending' ||
        normalized == 'rescheduled' ||
        normalized == 'subscription booked' ||
        normalized == 'active' ||
        normalized == 'active cycle' ||
        normalized == 'renewal due' ||
        normalized == 'scheduled' ||
        normalized == 'confirmed';
  }

  Future<bool> _hasOpenBooking(String resolvedUserId) async {
    if (resolvedUserId.trim().isEmpty) return false;

    final visits = await BookingService.fetchExpertVisits(resolvedUserId);

    for (final visit in visits) {
      final status = (visit['status'] ?? '').toString();
      if (_isOpenStatus(status)) {
        return true;
      }
    }

    return false;
  }

  void _selectDate(String date) {
    final rawSlots = _availabilityData[date];
    final slots = rawSlots is List ? rawSlots : [];

    setState(() {
      _selectedDate = date;
      _selectedSlot = slots.isNotEmpty ? slots.first.toString() : null;
    });
  }

  void _selectSlot(String slot) {
    setState(() {
      _selectedSlot = slot;
    });
  }

  Future<void> _goToNextPage() async {
    if (_selectedDate == null || _selectedSlot == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a date and slot to continue'),
        ),
      );
      return;
    }

    setState(() {
      _isCheckingExistingBooking = true;
    });

    try {
      final resolvedUserId =
      _resolvedUserId.isNotEmpty ? _resolvedUserId : await _resolveUserId();

      final hasOpenBooking = await _hasOpenBooking(resolvedUserId);

      if (!mounted) return;

      setState(() {
        _isCheckingExistingBooking = false;
      });

      if (hasOpenBooking) {
        Get.offNamed(
          AppRoutes.bookings,
          arguments: resolvedUserId.isNotEmpty ? resolvedUserId : widget.userId,
        );
        return;
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BookingDetailsView(
            selectedDate: _selectedDate!,
            selectedSlot: _selectedSlot!,
            userId: resolvedUserId.isNotEmpty ? resolvedUserId : widget.userId,
            userName: widget.userName,
            profilePhotoUrl: widget.profilePhotoUrl,
            initialPhone: widget.initialPhone,
            initialFlatNumber: widget.initialFlatNumber,
            initialTowerNumber: widget.initialTowerNumber,
            initialSocietyName: widget.initialSocietyName,
            initialSectorLocality: widget.initialSectorLocality,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isCheckingExistingBooking = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to verify existing bookings: $e'),
          backgroundColor: Colors.red,
        ),
      );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _softBg,
      appBar: AppBar(
        backgroundColor: _softBg,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        title: Text(
          'Book Expert Visit',
          style: AppTextStyles.cardTitle.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? _buildLoadingState()
            : _errorMessage != null
            ? _buildErrorState()
            : _buildBookingContent(),
      ),
      bottomNavigationBar: _isLoading || _errorMessage != null
          ? null
          : _buildBottomConfirmButton(),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(
        color: AppColors.primaryColor,
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: LiquidGlassInstructionCard(
          radius: 28,
          minHeight: 0,
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 42,
                color: Colors.red,
              ),
              const SizedBox(height: 14),
              Text(
                'Unable to load booking slots',
                textAlign: TextAlign.center,
                style: AppTextStyles.cardTitle.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage ?? 'Something went wrong.',
                textAlign: TextAlign.center,
                style: AppTextStyles.body.copyWith(
                  height: 1.4,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 18),
              ElevatedButton(
                onPressed: _initializeScreen,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _darkGreen,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22),
                  ),
                ),
                child: Text(
                  'Retry',
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBookingContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTopBookingCard(),
          const SizedBox(height: 24),
          Text(
            'Select Date',
            style: AppTextStyles.sectionTitle.copyWith(
              fontWeight: FontWeight.w500,
              color: _darkGreen,
            ),
          ),
          const SizedBox(height: 14),
          _buildDateSelector(),
          const SizedBox(height: 24),
          Text(
            'Available Slots',
            style: AppTextStyles.sectionTitle.copyWith(
              fontWeight: FontWeight.w500,
              color: _darkGreen,
            ),
          ),
          const SizedBox(height: 14),
          _buildSlotSelector(),
          const SizedBox(height: 24),
          _buildExpertAssuranceCard(),
          const SizedBox(height: 110),
        ],
      ),
    );
  }

  Widget _buildTopBookingCard() {
    final selectedDateText = _selectedDate ?? 'Choose date';
    final selectedSlotText = _selectedSlot ?? 'Choose slot';

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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.20),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  'Available Now',
                  style: AppTextStyles.chip.copyWith(
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            widget.serviceTitle?.trim().isNotEmpty == true
                ? widget.serviceTitle!.trim()
                : 'Book your Gold Dust expert visit',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.heroTitle.copyWith(
              fontSize: 21,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.serviceSubtitle?.trim().isNotEmpty == true
                ? widget.serviceSubtitle!.trim()
                : 'Choose a convenient date and time slot for your home garden consultation.',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.caption.copyWith(
              height: 1.35,
              fontWeight: FontWeight.w500,
              color: const Color(0xFFD7E7D9),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _miniInfoPill(
                  icon: Icons.event_available_rounded,
                  label: 'DATE',
                  value: selectedDateText,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _miniInfoPill(
                  icon: Icons.access_time_rounded,
                  label: 'SLOT',
                  value: selectedSlotText,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniInfoPill({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withOpacity(0.10),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 17, color: _gold),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyles.tiny.copyWith(
                    fontSize: 8.5,
                    letterSpacing: 1,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFFD7E7D9),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.chip.copyWith(
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateSelector() {
    if (_availableDates.isEmpty) {
      return _buildEmptyCard('No available dates found right now.');
    }

    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 2),
        itemCount: _availableDates.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final date = _availableDates[index];
          final dateKey = _formatDateKey(date);
          final isSelected = _selectedDate == dateKey;

          return GestureDetector(
            onTap: () => _selectDate(dateKey),
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
                      _dateTabTitle(date),
                      maxLines: 1,
                      style: AppTextStyles.bodyLarge.copyWith(
                        fontWeight: FontWeight.w900,
                        color: isSelected ? _gold : AppColors.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _shortDayLabel(date),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption.copyWith(
                        fontWeight: FontWeight.w800,
                        color: isSelected ? _gold : AppColors.textSecondary,
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

  Widget _buildSlotSelector() {
    final slots = _selectedDateSlots;

    if (slots.isEmpty) {
      return _buildEmptyCard('No slots available for this date.');
    }

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: slots.map((slot) {
        final isSelected = _selectedSlot == slot;

        return GestureDetector(
          onTap: () => _selectSlot(slot),
          child: SizedBox(
            width: 108,
            child: LiquidGlassInstructionCard(
              radius: 20,
              minHeight: 74,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    slot,
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.body.copyWith(
                      color: isSelected ? _gold : AppColors.primaryColor,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Available',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.tiny.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildEmptyCard(String message) {
    return LiquidGlassInstructionCard(
      radius: 22,
      minHeight: 0,
      padding: const EdgeInsets.all(16),
      child: Text(
        message,
        style: AppTextStyles.body.copyWith(
          height: 1.4,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _buildExpertAssuranceCard() {
    final experts = [
      {
        'name': 'Keshav',
        'subtitle': 'Plant-care Consultant',
      },
      {
        'name': 'Sameet',
        'subtitle': 'Plant-care Consultant',
      },
      {
        'name': 'Sajan',
        'subtitle': 'Plant-care Consultant',
      },
      {
        'name': 'Vinay',
        'subtitle': 'Plant-care Consultant',
      },
      {
        'name': 'Basant',
        'subtitle': 'Plant-care Consultant',
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Our Experts',
          style: AppTextStyles.sectionTitle.copyWith(
            fontWeight: FontWeight.w600,
            color: _darkGreen,
          ),
        ),
        const SizedBox(height: 12),

        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: experts.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.78,
          ),
          itemBuilder: (context, index) {
            final expert = experts[index];
            final isSelected = _selectedExpertIndex == index;
            final name = expert['name']!;
            final photoUrl = _expertPhotoUrl(name);

            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedExpertIndex = index;
                });
              },
              child: LiquidGlassInstructionCard(
                radius: 24,
                minHeight: 184,
                padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
                child: Column(
                  children: [
                    Stack(
                      children: [
                        Container(
                          width: 68,
                          height: 68,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEAF8EF),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected
                                  ? _gold.withOpacity(0.75)
                                  : Colors.white.withOpacity(0.8),
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: photoUrl.trim().isNotEmpty
                              ? Image.network(
                            photoUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.person_rounded,
                              size: 38,
                              color: _darkGreen,
                            ),
                          )
                              : const Icon(
                            Icons.person_rounded,
                            size: 38,
                            color: _darkGreen,
                          ),
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 22,
                            height: 22,
                            decoration: const BoxDecoration(
                              color: _gold,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.verified_rounded,
                              size: 14,
                              color: _darkGreen,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodyLarge.copyWith(
                        fontWeight: FontWeight.w900,
                        color: isSelected ? _gold : _darkGreen,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Our Expert',
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.caption.copyWith(
                        height: 1.2,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      expert['subtitle']!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.tiny.copyWith(
                        height: 1.25,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildBottomConfirmButton() {
    return Container(
      color: _softBg,
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: ElevatedButton(
            onPressed: _isCheckingExistingBooking ? null : _goToNextPage,
            style: ElevatedButton.styleFrom(
              backgroundColor: _darkGreen,
              foregroundColor: Colors.white,
              disabledBackgroundColor: _darkGreen.withOpacity(0.45),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(32),
              ),
            ),
            child: _isCheckingExistingBooking
                ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2.4,
              ),
            )
                : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Confirm Booking',
                  style: AppTextStyles.bodyLarge.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 14),
                const Icon(
                  Icons.arrow_forward_rounded,
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}