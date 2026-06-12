import 'dart:io';

import 'package:app_tracking_transparency/app_tracking_transparency.dart';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app/app_constants.dart';
import '../app/routes.dart';

class SplashView extends StatefulWidget {
  const SplashView({super.key});

  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(const Duration(milliseconds: 500));
      await _requestAttPermissionIfNeeded();

      _checkLoginAndNavigate();
    });
  }
  Future<void> _requestAttPermissionIfNeeded() async {
    if (!Platform.isIOS) return;

    try {
      final status = await AppTrackingTransparency.trackingAuthorizationStatus;

      if (status == TrackingStatus.notDetermined) {
        await Future.delayed(const Duration(milliseconds: 700));
        await AppTrackingTransparency.requestTrackingAuthorization();
      }
    } catch (e) {
      debugPrint("ATT permission request failed: $e");
    }
  }
  Future<void> _checkLoginAndNavigate() async {
    await Future.delayed(const Duration(milliseconds: 1200));

    final prefs = await SharedPreferences.getInstance();

    final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

    final userId = prefs.getString('userId')?.trim() ?? '';
    final maaliUserId = prefs.getString('maaliUserId')?.trim() ?? '';
    final bookingPhone = prefs.getString('bookingPhone')?.trim() ?? '';

    String finalUserId = '';

    if (maaliUserId.isNotEmpty) {
      finalUserId = maaliUserId;
    } else if (userId.isNotEmpty) {
      finalUserId = userId;
    } else if (bookingPhone.isNotEmpty) {
      finalUserId = 'otp$bookingPhone';
    }

    if (!mounted) return;

    if (isLoggedIn && finalUserId.isNotEmpty) {
      Get.offAllNamed(
        AppRoutes.home,
        arguments: {
          'userId': finalUserId,
          'isServiceAvailable': true,
          'locationTitle': 'Noida',
          'locationLine': 'Noida, Uttar Pradesh',
          'locationMessage': '',
          'latitude': null,
          'longitude': null,
        },
      );
    } else {
      Get.offAllNamed(AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryColor,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/images/logo.webp',
                  width: 132,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) {
                    return Container(
                      width: 118,
                      height: 118,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withOpacity(0.20),
                        ),
                      ),
                      child: const Icon(
                        Icons.local_florist_rounded,
                        color: Colors.white,
                        size: 58,
                      ),
                    );
                  },
                ),

                const SizedBox(height: 18),

                const Text(
                  'Gold Dust Gardening',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Gotham',
                    fontSize: 21,
                    height: 1.15,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 0.2,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  'Expert Plant Care Solution',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Gotham',
                    fontSize: 14,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withOpacity(0.82),
                    letterSpacing: 0.15,
                  ),
                ),

                const SizedBox(height: 34),

                const SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.8,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}