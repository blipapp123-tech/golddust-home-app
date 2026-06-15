import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'delete_account_screen.dart';
import '../app/app_constants.dart';
import '../app/app_text_styles.dart';
import '../services/booking_service.dart';
import '../widgets/liquid_glass_instruction_card.dart';

class ProfileScreen extends StatefulWidget {
  final String userId;
  final Future<void> Function()? onMyBookingsTap;
  final VoidCallback? onHelpSupportTap;
  final VoidCallback? onReferAndEarnTap;
  final VoidCallback? onLogoutTap;

  const ProfileScreen({
    super.key,
    required this.userId,
    this.onMyBookingsTap,
    this.onHelpSupportTap,
    this.onReferAndEarnTap,
    this.onLogoutTap,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const Color _darkGreen = Color(0xFF063F20);
  static const Color _gold = Color(0xFFFFB72B);
  static const Color _softBg = Color(0xFFF6F7FC);

  static const String _termsUrl =
      'https://www.golddustgardening.com/pages/terms-of-service/';

  static const String _privacyUrl =
      'https://www.golddustgardening.com/pages/privacy-policy/';

  static const String _aboutUrl = 'https://www.golddustgardening.com/';

  bool _isLoading = true;

  String _userName = 'User';
  String _phoneNumber = '';

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final savedPhone = _extractPhoneNumber(
        prefs.getString('phoneNumber') ??
            prefs.getString('bookingPhone') ??
            prefs.getString('userPhone') ??
            widget.userId,
      );

      String resolvedName = '';

      final userId = widget.userId.trim().isNotEmpty
          ? widget.userId.trim()
          : savedPhone.isNotEmpty
          ? 'otp$savedPhone'
          : '';

      if (userId.isNotEmpty) {
        final visits = await BookingService.fetchExpertVisits(userId);

        if (visits.isNotEmpty) {
          final latest = visits.first;

          if (latest is Map) {
            resolvedName = _extractNameFromExpertVisit(
              Map<String, dynamic>.from(latest),
            );
          }
        }
      }

      if (!mounted) return;

      setState(() {
        _phoneNumber = savedPhone;
        _userName = resolvedName.trim().isNotEmpty
            ? resolvedName.trim()
            : 'User';
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ Profile load error: $e');

      if (!mounted) return;

      setState(() {
        _phoneNumber = _extractPhoneNumber(widget.userId);
        _userName = 'User';
        _isLoading = false;
      });
    }
  }

  String _extractPhoneNumber(String raw) {
    final clean = raw.trim();

    if (clean.startsWith('otp')) {
      return clean.replaceFirst('otp', '');
    }

    final digitsOnly = clean.replaceAll(RegExp(r'[^0-9]'), '');

    if (digitsOnly.length >= 10) {
      return digitsOnly.substring(digitsOnly.length - 10);
    }

    return digitsOnly;
  }

  String _extractNameFromExpertVisit(Map<String, dynamic> visit) {
    final fullName = (visit['fullName'] ??
        visit['Full_Name'] ??
        visit['customerName'] ??
        visit['name'] ??
        '')
        .toString()
        .trim();

    if (fullName.isNotEmpty) return _titleCase(fullName);

    final firstName = (visit['firstName'] ?? '').toString().trim();
    final lastName = (visit['lastName'] ?? '').toString().trim();

    final combined = '$firstName $lastName'.trim();

    if (combined.isNotEmpty) return _titleCase(combined);

    return '';
  }

  String _titleCase(String value) {
    return value
        .split(' ')
        .where((e) => e.trim().isNotEmpty)
        .map((word) {
      final clean = word.trim();

      if (clean.isEmpty) return clean;

      return clean[0].toUpperCase() + clean.substring(1).toLowerCase();
    })
        .join(' ');
  }

  Future<void> _openWebPage(String url) async {
    final uri = Uri.parse(url);

    try {
      final opened = await launchUrl(
        uri,
        mode: LaunchMode.inAppBrowserView,
      );

      if (!opened) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
      }
    } catch (e) {
      debugPrint('❌ Web page open error: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to open this page right now.'),
          backgroundColor: AppColors.primaryColor,
        ),
      );
    }
  }

  void _showComingSoon(String title) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$title will be available soon.'),
        backgroundColor: AppColors.primaryColor,
      ),
    );
  }

  Future<void> _handleMyBookingsTap() async {
    if (widget.onMyBookingsTap == null) {
      _showComingSoon('My bookings');
      return;
    }

    Navigator.pop(context);

    await Future.delayed(const Duration(milliseconds: 180));
    await widget.onMyBookingsTap?.call();
  }

  void _handleSimpleCallback(
      VoidCallback? callback,
      String fallbackTitle,
      ) {
    if (callback == null) {
      _showComingSoon(fallbackTitle);
      return;
    }

    Navigator.pop(context);

    Future.delayed(const Duration(milliseconds: 180), () {
      callback();
    });
  }

  void _confirmLogout() {
    if (widget.onLogoutTap == null) {
      _showComingSoon('Logout');
      return;
    }

    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Logout?',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: _darkGreen,
            ),
          ),
          content: const Text(
            'You will need to login again with OTP.',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);

                Future.delayed(const Duration(milliseconds: 180), () {
                  widget.onLogoutTap?.call();
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'Logout',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _openDeleteAccountPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DeleteAccountScreen(
          userId: widget.userId,
          phoneNumber: _phoneNumber,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _softBg,
      body: _isLoading
          ? const Center(
        child: CircularProgressIndicator(
          color: AppColors.primaryColor,
        ),
      )
          : Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
              children: [
                _buildQuickCards(),
                const SizedBox(height: 16),
                _profileListCard(
                  children: [
                    _profileRow(
                      icon: Icons.card_giftcard_rounded,
                      iconColor: _gold,
                      title: 'Refer & earn',
                      badge: 'Rewards',
                      onTap: () => _handleSimpleCallback(
                        widget.onReferAndEarnTap,
                        'Refer & earn',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _profileListCard(
                  children: [
                    _profileRow(
                      icon: Icons.info_outline_rounded,
                      title: 'About us',
                      onTap: () => _openWebPage(_aboutUrl),
                    ),
                    _divider(),
                    _profileRow(
                      icon: Icons.description_outlined,
                      title: 'Terms of service',
                      onTap: () => _openWebPage(_termsUrl),
                    ),
                    _divider(),
                    _profileRow(
                      icon: Icons.privacy_tip_outlined,
                      title: 'Privacy policy',
                      onTap: () => _openWebPage(_privacyUrl),
                    ),
                    _divider(),
                    _profileRow(
                      icon: Icons.delete_outline_rounded,
                      iconColor: Colors.red,
                      title: 'Delete account',
                      onTap: _openDeleteAccountPage,
                    ),
                    _divider(),
                    _profileRow(
                      icon: Icons.logout_rounded,
                      title: 'Log out',
                      onTap: _confirmLogout,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  'GOLD DUST GARDENING',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 10,
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.w800,
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

  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        22,
        MediaQuery.of(context).padding.top + 12,
        22,
        26,
      ),
      decoration: const BoxDecoration(
        color: _darkGreen,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const SizedBox(
                  width: 38,
                  height: 38,
                  child: Icon(
                    Icons.arrow_back_rounded,
                    color: Colors.white,
                    size: 25,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Profile',
                style: AppTextStyles.bodyLarge.copyWith(
                  fontSize: 18,
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Container(
                width: 78,
                height: 78,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFEDEEFF),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.82),
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.person_rounded,
                  color: Color(0xFFA9ADD2),
                  size: 50,
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _userName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.heroTitle.copyWith(
                        fontSize: 23,
                        height: 1.12,
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _phoneNumber.isEmpty ? '' : '+91 $_phoneNumber',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.body.copyWith(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.62),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickCards() {
    return Row(
      children: [
        Expanded(
          child: _quickCard(
            icon: Icons.assignment_rounded,
            title: 'My\nbookings',
            onTap: _handleMyBookingsTap,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _quickCard(
            icon: Icons.support_agent_rounded,
            title: 'Help &\nSupport',
            onTap: () => _handleSimpleCallback(
              widget.onHelpSupportTap,
              'Help & Support',
            ),
          ),
        ),
      ],
    );
  }

  Widget _quickCard({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        height: 112,
        child: LiquidGlassInstructionCard(
          radius: 22,
          minHeight: 112,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                color: const Color(0xFF5E6A7D),
                size: 25,
              ),
              const SizedBox(height: 14),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.body.copyWith(
                  fontSize: 13.5,
                  height: 1.12,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _profileListCard({
    required List<Widget> children,
  }) {
    return LiquidGlassInstructionCard(
      radius: 24,
      minHeight: 0,
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          children: children,
        ),
      ),
    );
  }

  Widget _profileRow({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? iconColor,
    String? badge,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 15,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: iconColor ?? const Color(0xFF5E6A7D),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: AppTextStyles.body.copyWith(
                  fontSize: 14,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (badge != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF4D7),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  badge,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFCC8A00),
                  ),
                ),
              ),
              const SizedBox(width: 10),
            ],
            const Icon(
              Icons.chevron_right_rounded,
              size: 23,
              color: AppColors.textPrimary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _divider() {
    return Container(
      height: 1,
      margin: const EdgeInsets.only(left: 54),
      color: Colors.black.withOpacity(0.05),
    );
  }
}