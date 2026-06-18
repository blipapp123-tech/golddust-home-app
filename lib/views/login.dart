import 'dart:async';
import 'dart:convert';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:sendotp_flutter_sdk/sendotp_flutter_sdk.dart';
import '../services/onesignal_notification_service.dart';
import '../app/app_constants.dart';
import '../app/app_text_styles.dart';
import '../widgets/liquid_glass_instruction_card.dart';
import 'home_view.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController otpController = TextEditingController();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseAnalytics analytics = FirebaseAnalytics.instance;

  bool isLoading = false;
  String loadingMessage = 'Loading...';

  bool isOtpSent = false;
  String selectedOtpChannel = 'whatsapp';

  String? _reqId;

  int _resendCountdown = 60;
  Timer? _resendTimer;
  bool _isResendEnabled = false;

  late final ScrollController _serviceScrollController1;
  late final ScrollController _serviceScrollController2;

  Timer? _serviceAutoScrollTimer1;
  Timer? _serviceAutoScrollTimer2;

  static const Color primaryGreen = AppColors.primaryColor;
  static const Color accentOrange = Color(0xFFFFB72B);
  static const Color softBg = Color(0xFFFFFBF3);

  static const String otpLoginLambdaUrl =
      'https://ozof7so6e0.execute-api.ap-south-1.amazonaws.com/otp_login_lambda';

  static const String invalidNumberLogUrl =
      'https://d2lhw1jjv7.execute-api.ap-south-1.amazonaws.com/invalid_number_log';
  static const String googleReviewPhone = '9999999999';
  static const String googleReviewOtp = '123456';
  static const String googleReviewUserId = 'otp9999999999';
  static const String googleReviewUserName = 'Google Reviewer';
  final List<Map<String, String>> _serviceImages = const [
    {
      'title': 'Cutting',
      'image': 'assets/images/services/golddust-cutting-pruning.webp',
    },
    {
      'title': 'Cleaning',
      'image': 'assets/images/services/golddust-cleaning-balcony.webp',
    },
    {
      'title': 'Soil Care',
      'image': 'assets/images/services/golddust-soil-weeding.webp',
    },
    {
      'title': 'Dry Leaf Removal',
      'image': 'assets/images/services/golddust-deadheading.webp',
    },
    {
      'title': 'Plant Nourishment',
      'image': 'assets/images/services/golddust-fertilisation.webp',
    },
    {
      'title': 'Watering',
      'image': 'assets/images/services/golddust-watering.webp',
    },
    {
      'title': 'Pest Care',
      'image': 'assets/images/services/golddust-pest-management.webp',
    },
    {
      'title': 'Leaf Cleaning',
      'image': 'assets/images/services/golddust-leaf-cleaning.webp',
    },
  ];

  @override
  void initState() {
    super.initState();

    _serviceScrollController1 = ScrollController();
    _serviceScrollController2 = ScrollController();

    analytics.logEvent(name: 'login_screen_viewed');

    OTPWidget.initializeWidget(
      '3566746d727a313630363530',
      '456793TzOsD5pgd7A68554df9P1',
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startContinuousServiceScroll();
    });
  }

  @override
  void dispose() {
    phoneController.dispose();
    otpController.dispose();

    _resendTimer?.cancel();

    _serviceAutoScrollTimer1?.cancel();
    _serviceAutoScrollTimer2?.cancel();
    _serviceScrollController1.dispose();
    _serviceScrollController2.dispose();

    super.dispose();
  }

  String? normalizeIndianMobileStrict(String input) {
    var digits = input.replaceAll(RegExp(r'\D'), '');

    if (digits.length == 12 && digits.startsWith('91')) {
      digits = digits.substring(2);
    }

    if (digits.length == 10 && RegExp(r'^[6-9]\d{9}$').hasMatch(digits)) {
      return digits;
    }

    return null;
  }

  bool get _isPhoneValid {
    return normalizeIndianMobileStrict(phoneController.text.trim()) != null;
  }

  Future<void> _loginAsGoogleReviewer() async {
    setState(() {
      isLoading = true;
      loadingMessage = 'Opening demo account...';
    });

    try {
      await analytics.logEvent(name: 'google_play_reviewer_demo_login');
      await analytics.logLogin(loginMethod: 'google_play_reviewer_demo');

      final prefs = await SharedPreferences.getInstance();

      await prefs.setString('userId', googleReviewUserId);
      await prefs.setString('userID', googleReviewUserId);
      await prefs.setString('firebaseUserId', googleReviewUserId);
      await prefs.setString('phoneNumber', googleReviewPhone);
      await prefs.setString('bookingPhone', googleReviewPhone);
      await prefs.setString('userPhone', '+91$googleReviewPhone');
      await prefs.setString('maaliUserId', googleReviewUserId);
      await prefs.setString('userName', googleReviewUserName);
      await prefs.setBool('isLoggedIn', true);

      await analytics.setUserId(id: googleReviewUserId);
      await OneSignalNotificationService.initialize(
        userId: googleReviewUserId,
        userName: googleReviewUserName,
      );
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      _navigateAfterLogin(
        firebaseUserId: googleReviewUserId,
        maaliUserId: googleReviewUserId,
        phoneNumber: '+91$googleReviewPhone',
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to open demo account. Please try again.'),
        ),
      );
    }
  }

  void _startContinuousServiceScroll() {
    _serviceAutoScrollTimer1?.cancel();
    _serviceAutoScrollTimer2?.cancel();

    _serviceAutoScrollTimer1 = Timer.periodic(
      const Duration(milliseconds: 16),
          (_) => _continuousScrollForward(_serviceScrollController1, 1.0),
    );

    _serviceAutoScrollTimer2 = Timer.periodic(
      const Duration(milliseconds: 16),
          (_) => _continuousScrollBackward(_serviceScrollController2, 1.0),
    );
  }

  void _continuousScrollForward(
      ScrollController controller,
      double speed,
      ) {
    if (!mounted || !controller.hasClients) return;

    final maxScroll = controller.position.maxScrollExtent;

    if (maxScroll <= 0) return;

    final nextOffset = controller.offset + speed;

    if (nextOffset >= maxScroll) {
      controller.jumpTo(0);
    } else {
      controller.jumpTo(nextOffset);
    }
  }

  void _continuousScrollBackward(
      ScrollController controller,
      double speed,
      ) {
    if (!mounted || !controller.hasClients) return;

    final maxScroll = controller.position.maxScrollExtent;

    if (maxScroll <= 0) return;

    final nextOffset = controller.offset - speed;

    if (nextOffset <= 0) {
      controller.jumpTo(maxScroll);
    } else {
      controller.jumpTo(nextOffset);
    }
  }

  void _autoScrollForward(
      ScrollController controller,
      double scrollAmount,
      ) {
    if (!controller.hasClients) return;

    final maxScroll = controller.position.maxScrollExtent;
    final currentOffset = controller.offset;

    double nextOffset = currentOffset + scrollAmount;

    if (nextOffset >= maxScroll) {
      nextOffset = 0;
    }

    controller.animateTo(
      nextOffset,
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeInOutCubic,
    );
  }

  void _autoScrollBackward(
      ScrollController controller,
      double scrollAmount,
      ) {
    if (!controller.hasClients) return;

    final maxScroll = controller.position.maxScrollExtent;
    final currentOffset = controller.offset;

    double nextOffset = currentOffset - scrollAmount;

    if (nextOffset <= 0) {
      nextOffset = maxScroll;
    }

    controller.animateTo(
      nextOffset,
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeInOutCubic,
    );
  }


  Future<void> handleSendOtp() async {
    FocusScope.of(context).unfocus();

    final cleaned = normalizeIndianMobileStrict(phoneController.text.trim());

    if (cleaned == null) {
      await _logInvalidNumber(phoneController.text.trim());

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a valid 10-digit Indian mobile number'),
        ),
      );
      return;
    }

    if (cleaned == googleReviewPhone) {
      await analytics.logEvent(name: 'google_play_reviewer_demo_otp_requested');

      if (!mounted) return;

      setState(() {
        isOtpSent = true;
        _reqId = 'google_play_review_demo_req';
        _resendCountdown = 0;
        _isResendEnabled = false;
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Demo OTP is 123456'),
        ),
      );

      return;
    }

    final identifier = '91$cleaned';

    setState(() {
      isLoading = true;
      loadingMessage =
      'Sending OTP on ${selectedOtpChannel == 'sms' ? 'SMS' : 'WhatsApp'}...';
    });

    try {
      if (selectedOtpChannel == 'sms') {
        OTPWidget.initializeWidget(
          '3566746c6171323730373833',
          '456793TzOsD5pgd7A68554df9P1',
        );
        await analytics.logEvent(name: 'otp_sms_send_attempted');
      } else {
        OTPWidget.initializeWidget(
          '3566746d727a313630363530',
          '456793TzOsD5pgd7A68554df9P1',
        );
        await analytics.logEvent(name: 'otp_whatsapp_send_attempted');
      }

      final response = await OTPWidget.sendOTP({
        'identifier': identifier,
      }).timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          throw TimeoutException('OTP sending timed out');
        },
      );

      if (response == null) {
        throw Exception('Null response from SendOTP SDK');
      }

      final reqId = response['message'];

      if (response['type'] != 'success' || reqId == null) {
        throw Exception('Invalid OTP send response: $response');
      }

      await analytics.logEvent(
        name: selectedOtpChannel == 'sms'
            ? 'otp_sms_send_success'
            : 'otp_whatsapp_send_success',
      );

      if (!mounted) return;
      setState(() {
        isOtpSent = true;
        _reqId = reqId;
        _resendCountdown = 60;
        _isResendEnabled = false;
        isLoading = false;
      });

      _startResendTimer();
    } catch (e) {
      await analytics.logEvent(
        name: selectedOtpChannel == 'sms'
            ? 'otp_sms_send_failed'
            : 'otp_whatsapp_send_failed',
      );

      if (!mounted) return;
      setState(() => isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('OTP sending failed. Please try again.'),
        ),
      );
    }
  }

  Future<void> handleVerifyOtp() async {
    FocusScope.of(context).unfocus();

    final enteredOtp = otpController.text.trim();
    final cleaned = normalizeIndianMobileStrict(phoneController.text.trim());

    if (cleaned == googleReviewPhone) {
      if (enteredOtp == googleReviewOtp) {
        await _loginAsGoogleReviewer();
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid demo OTP. Please use 123456.'),
        ),
      );
      return;
    }

    if (_reqId == null || enteredOtp.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the OTP')),
      );
      return;
    }

    if (cleaned == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid phone number')),
      );
      return;
    }

    setState(() {
      isLoading = true;
      loadingMessage = 'Verifying OTP...';
    });

    try {
      await analytics.logEvent(
        name: selectedOtpChannel == 'sms'
            ? 'otp_sms_verify_attempted'
            : 'otp_whatsapp_verify_attempted',
      );

      final response = await OTPWidget.verifyOTP({
        'reqId': _reqId!,
        'otp': enteredOtp,
      }).timeout(
        const Duration(seconds: 120),
        onTimeout: () {
          throw TimeoutException('OTP verification timed out');
        },
      );

      if (response == null) {
        throw Exception('Null response from OTP verification');
      }

      final isVerified = response['type'] == 'success';

      if (!isVerified) {
        if (!mounted) return;
        setState(() => isLoading = false);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid or expired OTP')),
        );
        return;
      }

      final phoneNumber = '+91$cleaned';

      final loginResponse = await http.post(
        Uri.parse(otpLoginLambdaUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phoneNumber': phoneNumber,
        }),
      );

      if (loginResponse.statusCode != 200) {
        throw Exception('Login Lambda failed: ${loginResponse.body}');
      }

      final data = jsonDecode(loginResponse.body);

      if (data['customToken'] == null) {
        throw Exception('Custom token not returned');
      }

      final customToken = data['customToken'];

      final userCredential = await _auth.signInWithCustomToken(customToken);
      final firebaseUser = userCredential.user;

      if (firebaseUser == null) {
        throw Exception('Firebase user is null after custom token login');
      }

      await analytics.logEvent(
        name: selectedOtpChannel == 'sms'
            ? 'otp_sms_verify_success'
            : 'otp_whatsapp_verify_success',
      );

      await analytics.logLogin(loginMethod: selectedOtpChannel);
      await analytics.setUserId(id: firebaseUser.uid);

      final maaliUserId = 'otp$cleaned';

      final prefs = await SharedPreferences.getInstance();

      await prefs.setString('userId', maaliUserId);
      await prefs.setString('userID', maaliUserId);
      await prefs.setString('firebaseUserId', firebaseUser.uid);
      await prefs.setString('phoneNumber', cleaned);
      await prefs.setString('bookingPhone', cleaned);
      await prefs.setString('userPhone', phoneNumber);
      await prefs.setString('maaliUserId', maaliUserId);
      await prefs.setBool('isLoggedIn', true);
      await OneSignalNotificationService.initialize(
        userId: maaliUserId,
        userName: phoneNumber,
      );
      if (!mounted) return;
      setState(() => isLoading = false);

      _navigateAfterLogin(
        firebaseUserId: firebaseUser.uid,
        maaliUserId: maaliUserId,
        phoneNumber: phoneNumber,
      );
    } catch (e) {
      await analytics.logEvent(
        name: selectedOtpChannel == 'sms'
            ? 'otp_sms_verify_failed'
            : 'otp_whatsapp_verify_failed',
      );

      if (!mounted) return;
      setState(() => isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('OTP verification failed')),
      );
    }
  }

  Future<void> _resendOtp() async {
    if (_reqId == null) return;

    setState(() {
      isLoading = true;
      loadingMessage =
      'Resending OTP on ${selectedOtpChannel == 'sms' ? 'SMS' : 'WhatsApp'}...';
    });

    try {
      final response = await OTPWidget.retryOTP({
        'reqId': _reqId!,
        'retryChannel': selectedOtpChannel == 'sms' ? 11 : 12,
      }).timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          throw TimeoutException('OTP resend timed out');
        },
      );

      if (response == null) {
        throw Exception('Null response from retryOTP');
      }

      await analytics.logEvent(
        name: selectedOtpChannel == 'sms'
            ? 'otp_sms_resend_success'
            : 'otp_whatsapp_resend_success',
      );

      if (!mounted) return;
      setState(() {
        _resendCountdown = 60;
        _isResendEnabled = false;
        isLoading = false;
      });

      _startResendTimer();
    } catch (e) {
      await analytics.logEvent(
        name: selectedOtpChannel == 'sms'
            ? 'otp_sms_resend_failed'
            : 'otp_whatsapp_resend_failed',
      );

      if (!mounted) return;
      setState(() => isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to resend OTP')),
      );
    }
  }

  void _startResendTimer() {
    _resendTimer?.cancel();

    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;

      if (_resendCountdown == 0) {
        timer.cancel();
        setState(() => _isResendEnabled = true);
      } else {
        setState(() => _resendCountdown--);
      }
    });
  }

  Future<void> _logInvalidNumber(String input) async {
    try {
      final istNow = DateTime.now().toUtc().add(
        const Duration(hours: 5, minutes: 30),
      );

      final unixTimestamp = istNow.millisecondsSinceEpoch ~/ 1000;

      await http.post(
        Uri.parse(invalidNumberLogUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phoneNumber': input,
          'reason': 'invalid_format',
          'timestamp': unixTimestamp,
        }),
      );
    } catch (_) {
      // Do not block login if invalid-number logging fails.
    }
  }

  void _resetOtpFlow() {
    _resendTimer?.cancel();

    setState(() {
      isOtpSent = false;
      otpController.clear();
      _reqId = null;
      _resendCountdown = 60;
      _isResendEnabled = false;
    });
  }

  void _navigateAfterLogin({
    required String firebaseUserId,
    required String maaliUserId,
    required String phoneNumber,
  }) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => HomeView(
          userId: maaliUserId,
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
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: softBg,
          body: SafeArea(
            bottom: false,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  _buildGreenHero(),

                  // White space between green banner and moving images
                  const SizedBox(height: 18),

                  _buildImageScroller(),

                  const SizedBox(height: 10),

                  _buildLoginSection(),

                  const SizedBox(height: 10),

                  _buildTermsText(),

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
        if (isLoading) _buildLoadingOverlay(),
      ],
    );
  }

  Widget _buildGreenHero() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 26, 22, 34),
      decoration: const BoxDecoration(
        color: primaryGreen,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(34),
          bottomRight: Radius.circular(34),
        ),
      ),
      child: Column(
        children: [
          Text(
            'Gold Dust\nGardening',
            textAlign: TextAlign.center,
            style: AppTextStyles.heroTitle.copyWith(
              fontSize: 30,
              height: 1.02,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Professional Maali Service',
            textAlign: TextAlign.center,
            style: AppTextStyles.cardTitle.copyWith(
              fontSize: 16,
              height: 1.15,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Expert plant care, pruning, watering and garden maintenance at home.',
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.body.copyWith(
              fontSize: 11.5,
              height: 1.35,
              fontWeight: FontWeight.w500,
              color: Colors.white.withOpacity(0.82),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageScroller() {
    return SizedBox(
      height: 166,
      child: Column(
        children: [
          SizedBox(
            height: 76,
            child: ListView.separated(
              controller: _serviceScrollController1,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: _serviceImages.length * 3,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final item = _serviceImages[index % _serviceImages.length];

                return _buildServiceImageTile(
                  image: item['image']!,
                  title: item['title']!,
                  width: 118,
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 76,
            child: ListView.separated(
              controller: _serviceScrollController2,
              padding: const EdgeInsets.symmetric(horizontal: 40),
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: _serviceImages.length * 3,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final reversedIndex =
                    _serviceImages.length - 1 - (index % _serviceImages.length);
                final item = _serviceImages[reversedIndex];

                return _buildServiceImageTile(
                  image: item['image']!,
                  title: item['title']!,
                  width: 118,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceImageTile({
    required String image,
    required String title,
    required double width,
  }) {
    return SizedBox(
      width: width,
      child: LiquidGlassInstructionCard(
        radius: 16,
        minHeight: 0,
        padding: EdgeInsets.zero,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              Positioned.fill(
                child: Image.asset(
                  image,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  filterQuality: FilterQuality.medium,
                  errorBuilder: (_, __, ___) => Container(
                    color: const Color(0xFFEAF8EF),
                    child: const Center(
                      child: Icon(
                        Icons.image_outlined,
                        color: primaryGreen,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(7, 16, 7, 6),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Color(0xB3002A13),
                      ],
                    ),
                  ),
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
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

  Widget _buildLoginSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Column(
        children: [
          Text(
            'Log in or Sign up',
            textAlign: TextAlign.center,
            style: AppTextStyles.heroTitle.copyWith(
              fontSize: 22,
              height: 1.1,
              fontWeight: FontWeight.w900,
              color: Colors.black,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 12),
          LiquidGlassInstructionCard(
            radius: 24,
            minHeight: 0,
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            child: Column(
              children: [
                if (!isOtpSent) ...[
                  _buildPhoneInput(),
                  const SizedBox(height: 10),
                  _buildOtpChannelSelector(),
                  const SizedBox(height: 12),
                  _buildPrimaryButton(
                    label: 'Continue',
                    icon: Icons.arrow_forward_rounded,
                    onTap: handleSendOtp,
                    enabled: true,
                  ),
                ] else ...[
                  _buildReadOnlyPhoneNumber(),
                  const SizedBox(height: 10),
                  _buildOtpInput(),
                  const SizedBox(height: 12),
                  _buildPrimaryButton(
                    label: 'Verify & Continue',
                    icon: Icons.verified_rounded,
                    onTap: handleVerifyOtp,
                    enabled: true,
                  ),
                  const SizedBox(height: 10),
                  _buildResendSection(),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhoneInput() {
    return AnimatedBuilder(
      animation: phoneController,
      builder: (context, _) {
        final valid = _isPhoneValid;

        return Container(
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.82),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: valid
                  ? primaryGreen.withOpacity(0.35)
                  : Colors.black.withOpacity(0.15),
            ),
          ),
          child: Row(
            children: [
              const Text(
                '+91',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: Colors.black,
                ),
              ),
              const SizedBox(width: 10),
              Container(
                height: 22,
                width: 1,
                color: Colors.black.withOpacity(0.12),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  style: AppTextStyles.body.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Colors.black,
                  ),
                  decoration: InputDecoration(
                    counterText: '',
                    border: InputBorder.none,
                    hintText: 'Enter mobile number',
                    hintStyle: AppTextStyles.caption.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.black.withOpacity(0.34),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOtpInput() {
    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.82),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: primaryGreen.withOpacity(0.20),
        ),
      ),
      child: TextField(
        controller: otpController,
        keyboardType: TextInputType.number,
        maxLength: 6,
        style: AppTextStyles.bodyLarge.copyWith(
          fontWeight: FontWeight.w900,
          letterSpacing: 2,
          color: Colors.black,
        ),
        decoration: InputDecoration(
          counterText: '',
          border: InputBorder.none,
          hintText: 'Enter OTP',
          hintStyle: AppTextStyles.body.copyWith(
            letterSpacing: 0,
            fontWeight: FontWeight.w700,
            color: Colors.black.withOpacity(0.34),
          ),
        ),
      ),
    );
  }

  Widget _buildReadOnlyPhoneNumber() {
    final cleaned = normalizeIndianMobileStrict(phoneController.text.trim());

    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: primaryGreen.withOpacity(0.06),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: primaryGreen.withOpacity(0.14),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.phone_android_rounded,
            color: primaryGreen,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              cleaned != null ? '+91 $cleaned' : '—',
              style: AppTextStyles.bodyLarge.copyWith(
                fontWeight: FontWeight.w900,
                color: primaryGreen,
              ),
            ),
          ),
          GestureDetector(
            onTap: _resetOtpFlow,
            child: Text(
              'Change',
              style: AppTextStyles.caption.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: accentOrange,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOtpChannelSelector() {
    return Row(
      children: [
        Expanded(
          flex: 6,
          child: _buildChannelChip(
            label: 'WhatsApp OTP',
            icon: Icons.chat_rounded,
            value: 'whatsapp',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 4,
          child: _buildChannelChip(
            label: 'SMS OTP',
            icon: Icons.sms_rounded,
            value: 'sms',
          ),
        ),
      ],
    );
  }

  Widget _buildChannelChip({
    required String label,
    required IconData icon,
    required String value,
  }) {
    final bool selected = selectedOtpChannel == value;

    return GestureDetector(
      onTap: () {
        setState(() {
          selectedOtpChannel = value;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: selected ? primaryGreen : Colors.white.withOpacity(0.76),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? primaryGreen : primaryGreen.withOpacity(0.16),
          ),
          boxShadow: selected
              ? [
            BoxShadow(
              color: primaryGreen.withOpacity(0.16),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: selected ? Colors.white : primaryGreen,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              maxLines: 1,
              softWrap: false,
              style: AppTextStyles.caption.copyWith(
                fontSize: 11.5,
                fontWeight: FontWeight.w900,
                color: selected ? Colors.white : primaryGreen,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrimaryButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    bool enabled = true,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: enabled ? onTap : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: enabled ? primaryGreen : Colors.black.withOpacity(0.22),
          disabledBackgroundColor: Colors.black.withOpacity(0.22),
          foregroundColor: Colors.white,
          disabledForegroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: AppTextStyles.body.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(width: 8),
            Icon(icon, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildResendSection() {

    final cleaned = normalizeIndianMobileStrict(phoneController.text.trim());

    if (cleaned == googleReviewPhone) {
      return Text(
        'Use demo OTP 123456',
        style: AppTextStyles.caption.copyWith(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
        ),
      );
    }
    return Column(
      children: [
        Text(
          _isResendEnabled
              ? "Didn't receive the code?"
              : 'Resend OTP in $_resendCountdown sec',
          style: AppTextStyles.caption.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
          ),
        ),
        if (_isResendEnabled) ...[
          const SizedBox(height: 6),
          TextButton(
            onPressed: _resendOtp,
            child: Text(
              'Resend OTP',
              style: AppTextStyles.body.copyWith(
                color: primaryGreen,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTermsText() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Text.rich(
        TextSpan(
          text: 'By continuing, you agree to our ',
          children: const [
            TextSpan(
              text: 'Terms of Service',
              style: TextStyle(
                decoration: TextDecoration.underline,
                fontWeight: FontWeight.w800,
                color: Colors.black87,
              ),
            ),
            TextSpan(text: ' & '),
            TextSpan(
              text: 'Privacy Policy',
              style: TextStyle(
                decoration: TextDecoration.underline,
                fontWeight: FontWeight.w800,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        textAlign: TextAlign.center,
        style: AppTextStyles.caption.copyWith(
          height: 1.3,
          fontSize: 10.8,
          fontWeight: FontWeight.w500,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.white.withOpacity(0.86),
      child: Center(
        child: LiquidGlassInstructionCard(
          radius: 26,
          minHeight: 0,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                color: primaryGreen,
                strokeWidth: 3,
              ),
              const SizedBox(height: 16),
              Text(
                loadingMessage,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyLarge.copyWith(
                  fontWeight: FontWeight.w900,
                  color: primaryGreen,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}