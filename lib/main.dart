import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'services/salesiq_service.dart';
import 'services/customer_notification_service.dart';
import 'firebase_options.dart';
import 'app/app_constants.dart';
import 'app/routes.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  debugPrint('✅ Step 1: Flutter binding initialized');

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  debugPrint('✅ Step 2: Firebase initialized');

  FirebaseMessaging.onBackgroundMessage(
    firebaseMessagingBackgroundHandler,
  );

  runApp(const GoldDustHomeApp());

  debugPrint('✅ Step 3: runApp called');
}

class GoldDustHomeApp extends StatefulWidget {
  const GoldDustHomeApp({super.key});

  @override
  State<GoldDustHomeApp> createState() =>
      _GoldDustHomeAppState();
}

class _GoldDustHomeAppState extends State<GoldDustHomeApp> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      debugPrint('✅ Step 4: Flutter first frame completed');

      unawaited(_initializePostStartupServices());
    });
  }

  Future<void> _initializePostStartupServices() async {
    try {
      await CustomerNotificationService.instance.initialize();

      debugPrint(
        '✅ Customer push notification service initialized',
      );
    } catch (error, stackTrace) {
      debugPrint(
        '❌ Push notification initialization failed: $error',
      );

      debugPrintStack(
        stackTrace: stackTrace,
      );
    }

    try {
      await SalesIQService.instance.initialize();

      debugPrint(
        '✅ Step 5: SalesIQ initialized after app startup',
      );
    } catch (error, stackTrace) {
      debugPrint(
        '❌ SalesIQ initialization failed: $error',
      );

      debugPrintStack(
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final baseTextTheme = ThemeData.light().textTheme;

    return GetMaterialApp(
      title: 'Gold Dust Gardening',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Gotham',
        scaffoldBackgroundColor: AppColors.secondaryColor,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primaryColor,
          primary: AppColors.primaryColor,
          secondary: AppColors.primaryColor,
          surface: AppColors.white,
        ),
        textTheme: baseTextTheme.apply(
          fontFamily: 'Gotham',
          bodyColor: AppColors.textPrimary,
          displayColor: AppColors.textPrimary,
        ),
        primaryTextTheme: baseTextTheme.apply(
          fontFamily: 'Gotham',
          bodyColor: AppColors.white,
          displayColor: AppColors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.primaryColor,
          foregroundColor: AppColors.white,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            fontFamily: 'Gotham',
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.white,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            textStyle: const TextStyle(
              fontFamily: 'Gotham',
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            textStyle: const TextStyle(
              fontFamily: 'Gotham',
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            textStyle: const TextStyle(
              fontFamily: 'Gotham',
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          labelStyle: const TextStyle(
            fontFamily: 'Gotham',
            fontWeight: FontWeight.w500,
          ),
          hintStyle: TextStyle(
            fontFamily: 'Gotham',
            fontWeight: FontWeight.w400,
            color: AppColors.textSecondary.withOpacity(0.75),
          ),
        ),
      ),
      initialRoute: AppRoutes.splash,
      getPages: AppRoutes.pages,
    );
  }
}
