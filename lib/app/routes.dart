import 'package:get/get.dart';

import '../views/bookings_view.dart';
import '../views/home_view.dart';
import '../views/login.dart';
import '../views/schedule_booking_view.dart';
import '../views/splash_view.dart';
import '../services/location_splash_screen.dart';

class AppRoutes {
  static const String splash = '/';
  static const String login = '/login';
  static const String home = '/home';
  static const String bookings = '/bookings';
  static const String scheduleBooking = '/schedule-booking';
  static const String locationSplash = '/location-splash';

  static final pages = <GetPage>[
    GetPage(
      name: splash,
      page: () => const SplashView(),
    ),

    GetPage(
      name: login,
      page: () => const LoginScreen(),
    ),

    GetPage(
      name: home,
      page: () {
        final args = Get.arguments;

        if (args is Map<String, dynamic>) {
          return HomeView(
            userId: (args['userId'] ?? args['userID'] ?? '').toString(),
            isServiceAvailable: args['isServiceAvailable'] == true,
            locationTitle: (args['locationTitle'] ?? 'Your location').toString(),
            locationLine: (args['locationLine'] ?? 'Detected location').toString(),
            locationMessage: (args['locationMessage'] ?? '').toString(),
            latitude: _toDoubleOrNull(args['latitude']),
            longitude: _toDoubleOrNull(args['longitude']),
          );
        }

        if (args is String) {
          return HomeView(
            userId: args,
            isServiceAvailable: true,
            locationTitle: 'Noida',
            locationLine: 'Service available in your area',
            locationMessage: 'Service available in your area',
          );
        }

        return const HomeView(
          userId: '',
          isServiceAvailable: true,
          locationTitle: 'Noida',
          locationLine: 'Service available in your area',
          locationMessage: 'Service available in your area',
        );
      },
    ),

    GetPage(
      name: bookings,
      page: () {
        final args = Get.arguments;

        String userId = '';

        if (args is String) {
          userId = args;
        } else if (args is Map<String, dynamic>) {
          userId = (args['userId'] ?? args['userID'] ?? '').toString();
        } else if (args != null) {
          userId = args.toString();
        }

        return BookingsView(userId: userId);
      },
    ),

    GetPage(
      name: scheduleBooking,
      page: () {
        final args = Get.arguments;

        String userId = '';

        if (args is String) {
          userId = args;
        } else if (args is Map<String, dynamic>) {
          userId = (args['userId'] ?? args['userID'] ?? '').toString();
        } else if (args != null) {
          userId = args.toString();
        }

        return ScheduleBookingView(userId: userId);
      },
    ),

    GetPage(
      name: locationSplash,
      page: () {
        final args = Get.arguments;

        String userId = '';

        if (args is String) {
          userId = args;
        } else if (args is Map<String, dynamic>) {
          userId = (args['userId'] ?? args['userID'] ?? '').toString();
        } else if (args != null) {
          userId = args.toString();
        }

        return LocationSplashScreen(userId: userId);
      },
    ),
  ];

  static double? _toDoubleOrNull(dynamic value) {
    if (value == null) return null;

    if (value is double) return value;

    if (value is int) return value.toDouble();

    if (value is String) {
      return double.tryParse(value);
    }

    return null;
  }
}