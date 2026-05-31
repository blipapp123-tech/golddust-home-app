import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_view.dart';
import '../app/app_constants.dart';
import '../app/app_text_styles.dart';
import '../services/booking_service.dart';
import '../widgets/liquid_glass_instruction_card.dart';

class BookingDetailsView extends StatefulWidget {
  final String selectedDate;
  final String selectedSlot;

  final String? userId;
  final String? userName;
  final String? profilePhotoUrl;
  final String? initialPhone;
  final String? initialFlatNumber;
  final String? initialTowerNumber;
  final String? initialSocietyName;
  final String? initialSectorLocality;

  const BookingDetailsView({
    super.key,
    required this.selectedDate,
    required this.selectedSlot,
    this.userId,
    this.userName,
    this.profilePhotoUrl,
    this.initialPhone,
    this.initialFlatNumber,
    this.initialTowerNumber,
    this.initialSocietyName,
    this.initialSectorLocality,
  });

  @override
  State<BookingDetailsView> createState() => _BookingDetailsViewState();
}

class _BookingDetailsViewState extends State<BookingDetailsView> {
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;
  bool _isPrefilling = true;

  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController flatNumberController = TextEditingController();
  final TextEditingController towerNumberController = TextEditingController();
  final TextEditingController societyNameController = TextEditingController();
  final TextEditingController sectorLocalityController =
  TextEditingController();

  static const Color _darkGreen = Color(0xFF063F20);
  static const Color _cardGreen = Color(0xFF174F2D);
  static const Color _gold = Color(0xFFFFB72B);
  static const Color _softBg = Colors.white;

  @override
  void initState() {
    super.initState();
    _prefillData();
  }

  Future<void> _prefillData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final userName = widget.userName?.trim() ?? '';

      if (userName.isNotEmpty) {
        final parts = userName.split(RegExp(r'\s+'));
        if (parts.isNotEmpty) {
          firstNameController.text = parts.first;
          if (parts.length > 1) {
            lastNameController.text = parts.sublist(1).join(' ');
          }
        }
      }

      final phoneFromLogin = _extractPhoneNumber(
        prefs.getString('phoneNumber') ??
            prefs.getString('bookingPhone') ??
            prefs.getString('userPhone') ??
            prefs.getString('maaliUserId') ??
            prefs.getString('userId') ??
            prefs.getString('userID') ??
            widget.initialPhone ??
            widget.userId ??
            '',
      );

      phoneController.text = phoneFromLogin;

      flatNumberController.text = widget.initialFlatNumber ?? '';
      towerNumberController.text = widget.initialTowerNumber ?? '';
      societyNameController.text = widget.initialSocietyName ?? '';
      sectorLocalityController.text = widget.initialSectorLocality ?? '';
    } catch (e) {
      debugPrint('❌ Booking details prefill error: $e');

      phoneController.text = _extractPhoneNumber(
        widget.initialPhone ?? widget.userId ?? '',
      );
    }

    if (!mounted) return;

    setState(() {
      _isPrefilling = false;
    });
  }

  String _extractPhoneNumber(String raw) {
    final clean = raw.trim();

    if (clean.startsWith('otp')) {
      final otpPhone = clean.replaceFirst('otp', '');
      return _extractPhoneNumber(otpPhone);
    }

    final digitsOnly = clean.replaceAll(RegExp(r'[^0-9]'), '');

    if (digitsOnly.length >= 10) {
      return digitsOnly.substring(digitsOnly.length - 10);
    }

    return digitsOnly;
  }

  @override
  void dispose() {
    firstNameController.dispose();
    lastNameController.dispose();
    phoneController.dispose();
    flatNumberController.dispose();
    towerNumberController.dispose();
    societyNameController.dispose();
    sectorLocalityController.dispose();
    super.dispose();
  }

  String? _requiredValidator(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter $fieldName';
    }
    return null;
  }

  String? _phoneValidator(String? value) {
    final phone = value?.trim() ?? '';

    if (phone.isEmpty) {
      return 'Phone number not found. Please login again.';
    }

    if (!RegExp(r'^[0-9]{10}$').hasMatch(phone)) {
      return 'Invalid login phone number';
    }

    return null;
  }

  String _buildFullName() {
    final first = firstNameController.text.trim();
    final last = lastNameController.text.trim();
    return '$first $last'.trim();
  }

  String _normalizeUserId() {
    final passedUserId = widget.userId?.trim() ?? '';

    if (passedUserId.isNotEmpty) {
      return passedUserId;
    }

    return 'otp${phoneController.text.trim()}';
  }

  String _generateVisitId() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final phone = phoneController.text.trim();
    final suffix = phone.length >= 4 ? phone.substring(phone.length - 4) : phone;
    return 'visit_${suffix}_$now';
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

  Future<bool> _hasOpenBooking() async {
    final resolvedUserId = _normalizeUserId();
    if (resolvedUserId.isEmpty) return false;

    final visits = await BookingService.fetchExpertVisits(resolvedUserId);

    for (final visit in visits) {
      final status = (visit['status'] ?? '').toString();
      if (_isOpenStatus(status)) {
        return true;
      }
    }

    return false;
  }

  Map<String, dynamic> _buildVisitPayload() {
    final generatedVisitId = _generateVisitId();

    final firstName = firstNameController.text.trim();
    final lastName = lastNameController.text.trim();
    final fullName = '$firstName $lastName'.trim();

    return {
      'VisitID': generatedVisitId,
      'visitID': generatedVisitId,

      'userID': _normalizeUserId(),

      // Add these separate fields
      'firstName': firstName,
      'lastName': lastName,

      // Keep these also for compatibility with existing DB/Lambda
      'fullName': fullName,
      'Full_Name': fullName,
      'customerName': fullName,

      'phoneNo': phoneController.text.trim(),
      'phoneNumber': phoneController.text.trim(),

      'dateOfVisit': widget.selectedDate,
      'timeOfVisit': widget.selectedSlot,

      'flatNo': flatNumberController.text.trim(),
      'towerNo': towerNumberController.text.trim(),
      'society': societyNameController.text.trim(),
      'sector': sectorLocalityController.text.trim(),

      'status': 'Pending',

      if ((widget.profilePhotoUrl ?? '').trim().isNotEmpty)
        'profilePhotoUrl': widget.profilePhotoUrl!.trim(),
    };
  }

  Future<void> _saveBookingIdentityLocally() async {
    final prefs = await SharedPreferences.getInstance();

    final resolvedUserId = _normalizeUserId();
    final phone = phoneController.text.trim();
    final firstName = firstNameController.text.trim();
    final lastName = lastNameController.text.trim();
    final fullName = '$firstName $lastName'.trim();

    await prefs.setString('userID', resolvedUserId);
    await prefs.setString('userId', resolvedUserId);
    await prefs.setString('bookingPhone', phone);
    await prefs.setString('phoneNumber', phone);

    await prefs.setString('firstName', firstName);
    await prefs.setString('lastName', lastName);
    await prefs.setString('userName', fullName);
    await prefs.setString('bookingName', fullName);
  }

  Future<void> _confirmBooking() async {
    if (!_formKey.currentState!.validate()) return;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.35),
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 22),
        child: LiquidGlassInstructionCard(
          radius: 28,
          minHeight: 0,
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: const BoxDecoration(
                      color: _gold,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.event_available_rounded,
                      color: _darkGreen,
                      size: 23,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Confirm Booking',
                      style: AppTextStyles.cardTitle.copyWith(
                        fontWeight: FontWeight.w900,
                        color: _darkGreen,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _dialogSummaryBlock(),
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
                          'Edit',
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
                          backgroundColor: _darkGreen,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                        child: Text(
                          'Confirm',
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
      ),
    );

    if (confirmed == true) {
      _submitBooking();
    }
  }

  Widget _dialogSummaryBlock() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF6FBF7),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _darkGreen.withOpacity(0.08),
        ),
      ),
      child: Column(
        children: [
          _summaryRow('Date', widget.selectedDate),
          _summaryRow('Time', widget.selectedSlot),
          const Divider(height: 18),
          _summaryRow('Name', _buildFullName()),
          _summaryRow('Phone', phoneController.text.trim()),
          const Divider(height: 18),
          _summaryRow('Flat No.', flatNumberController.text.trim()),
          _summaryRow('Tower No.', towerNumberController.text.trim()),
          _summaryRow('Society', societyNameController.text.trim()),
          _summaryRow('Sector/Locality', sectorLocalityController.text.trim()),
        ],
      ),
    );
  }

  Future<void> _submitBooking() async {
    if (_isSubmitting) return;

    setState(() => _isSubmitting = true);

    try {
      final hasOpenBooking = await _hasOpenBooking();

      if (hasOpenBooking) {
        if (!mounted) return;

        setState(() => _isSubmitting = false);

        await _showInfoDialog(
          title: 'Booking Already Exists',
          message:
          'You already have an active expert visit. Please wait for it to be completed or closed before creating another one.',
          icon: Icons.info_outline_rounded,
        );

        return;
      }

      final payload = _buildVisitPayload();

      await BookingService.bookExpertVisit(payload);
      await _saveBookingIdentityLocally();

      if (!mounted) return;

      setState(() => _isSubmitting = false);

      await _showInfoDialog(
        title: 'Booking Confirmed',
        message: 'Your expert visit has been created successfully.',
        icon: Icons.verified_rounded,
      );

      if (!mounted) return;

      final resolvedUserId = _normalizeUserId();

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => HomeView(
            userId: resolvedUserId,
            isServiceAvailable: true,
            locationTitle: 'Noida',
            locationLine: 'Noida, Uttar Pradesh',
            locationMessage: '',
            latitude: null,
            longitude: null,
          ),
        ),
            (route) => false,
      );
    } catch (e) {
      if (!mounted) return;

      setState(() => _isSubmitting = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Booking failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showInfoDialog({
    required String title,
    required String message,
    required IconData icon,
  }) async {
    await showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.35),
      builder: (_) => Dialog(
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
                decoration: const BoxDecoration(
                  color: _gold,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: _darkGreen,
                  size: 30,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: AppTextStyles.cardTitle.copyWith(
                  fontWeight: FontWeight.w900,
                  color: _darkGreen,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: AppTextStyles.body.copyWith(
                  height: 1.45,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _darkGreen,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: Text(
                    'OK',
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
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 94,
            child: Text(
              label,
              style: AppTextStyles.caption.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              textAlign: TextAlign.right,
              style: AppTextStyles.caption.copyWith(
                fontWeight: FontWeight.w800,
                color: _darkGreen,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    bool readOnly = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      readOnly: readOnly,
      enableInteractiveSelection: !readOnly,
      cursorColor: _darkGreen,
      style: AppTextStyles.body.copyWith(
        fontWeight: FontWeight.w800,
        color: readOnly ? AppColors.textSecondary : AppColors.textPrimary,
      ),
      decoration: InputDecoration(
        prefixIcon: Icon(
          icon,
          color: _gold,
          size: 21,
        ),
        suffixIcon: readOnly
            ? const Icon(
          Icons.lock_rounded,
          color: AppColors.textSecondary,
          size: 18,
        )
            : null,
        hintText: hint,
        hintStyle: AppTextStyles.caption.copyWith(
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary.withOpacity(0.70),
        ),
        filled: true,
        fillColor: readOnly
            ? const Color(0xFFF2F5F3)
            : Colors.white.withOpacity(0.84),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        errorStyle: AppTextStyles.tiny.copyWith(
          color: Colors.red,
          fontWeight: FontWeight.w600,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: BorderSide(
            color: _darkGreen.withOpacity(0.08),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: BorderSide(
            color: _darkGreen.withOpacity(0.08),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: BorderSide(
            color: readOnly ? _darkGreen.withOpacity(0.08) : _gold.withOpacity(0.85),
            width: 1.4,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: BorderSide(
            color: Colors.red.withOpacity(0.55),
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: BorderSide(
            color: Colors.red.withOpacity(0.75),
            width: 1.3,
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(
          icon,
          color: _gold,
          size: 19,
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: AppTextStyles.sectionTitle.copyWith(
            fontWeight: FontWeight.w500,
            color: _darkGreen,
          ),
        ),
      ],
    );
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
        elevation: 0,
        backgroundColor: _softBg,
        foregroundColor: AppColors.textPrimary,
        title: Text(
          'Booking Details',
          style: AppTextStyles.cardTitle.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: SafeArea(
        child: _isPrefilling
            ? const Center(
          child: CircularProgressIndicator(
            color: AppColors.primaryColor,
          ),
        )
            : Form(
          key: _formKey,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSelectedSlotCard(),
                const SizedBox(height: 24),

                _sectionTitle(
                  'Basic Information',
                  Icons.person_outline_rounded,
                ),
                const SizedBox(height: 14),
                _buildDetailsCard(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: firstNameController,
                            hint: 'First Name *',
                            icon: Icons.person_outline,
                            validator: (v) =>
                                _requiredValidator(v, 'first name'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTextField(
                            controller: lastNameController,
                            hint: 'Last Name *',
                            icon: Icons.person_outline,
                            validator: (v) =>
                                _requiredValidator(v, 'last name'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _buildTextField(
                      controller: phoneController,
                      hint: 'Phone Number',
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                      validator: _phoneValidator,
                      readOnly: true,
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                _sectionTitle(
                  'Address Details',
                  Icons.location_on_outlined,
                ),
                const SizedBox(height: 14),
                _buildDetailsCard(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: flatNumberController,
                            hint: 'Flat No. *',
                            icon: Icons.home_outlined,
                            validator: (v) =>
                                _requiredValidator(v, 'flat number'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTextField(
                            controller: towerNumberController,
                            hint: 'Tower No. *',
                            icon: Icons.apartment_outlined,
                            validator: (v) =>
                                _requiredValidator(v, 'tower number'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _buildTextField(
                      controller: societyNameController,
                      hint: 'Society Name *',
                      icon: Icons.location_city_outlined,
                      validator: (v) =>
                          _requiredValidator(v, 'society name'),
                    ),
                    const SizedBox(height: 14),
                    _buildTextField(
                      controller: sectorLocalityController,
                      hint: 'Sector / Locality *',
                      icon: Icons.place_outlined,
                      validator: (v) =>
                          _requiredValidator(v, 'sector/locality'),
                    ),
                  ],
                ),

                const SizedBox(height: 26),

                _buildAssuranceNote(),

                const SizedBox(height: 100),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: _isPrefilling ? null : _buildBottomConfirmButton(),
    );
  }

  Widget _buildSelectedSlotCard() {
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
                  'EXPERT VISIT DETAILS',
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w800,
                    color: _gold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.20),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  'Step 2 of 2',
                  style: AppTextStyles.chip.copyWith(
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            'Confirm your visit information',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.heroTitle.copyWith(
              fontSize: 21,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Our expert will use these details to reach your home on time.',
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
                  child: _selectedSlotTextBlock(
                    label: 'SELECTED DATE',
                    value: widget.selectedDate,
                  ),
                ),
                Container(
                  width: 1,
                  height: 34,
                  color: Colors.white.withOpacity(0.14),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _selectedSlotTextBlock(
                    label: 'TIME SLOT',
                    value: widget.selectedSlot,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _selectedSlotTextBlock({
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

  Widget _buildDetailsCard({required List<Widget> children}) {
    return _softCard(
      radius: 24,
      padding: const EdgeInsets.all(14),
      child: Column(children: children),
    );
  }

  Widget _buildAssuranceNote() {
    return LiquidGlassInstructionCard(
      radius: 24,
      minHeight: 88,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: Color(0xFFEAF8EF),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.verified_user_rounded,
              color: _darkGreen,
              size: 25,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'EXPERT ASSURANCE',
                  style: AppTextStyles.tiny.copyWith(
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Verified Gold Dust expert will visit your home.',
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w800,
                    color: _darkGreen,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Please keep your phone reachable around the selected slot.',
                  style: AppTextStyles.chip.copyWith(
                    height: 1.35,
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

  Widget _buildBottomConfirmButton() {
    return Container(
      color: _softBg,
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: ElevatedButton(
            onPressed: _isSubmitting ? null : _confirmBooking,
            style: ElevatedButton.styleFrom(
              backgroundColor: _darkGreen,
              foregroundColor: Colors.white,
              disabledBackgroundColor: _darkGreen.withOpacity(0.45),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(32),
              ),
            ),
            child: _isSubmitting
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