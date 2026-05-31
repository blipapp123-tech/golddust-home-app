import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

import '../app/app_constants.dart';
import '../app/routes.dart';

class LocationSplashScreen extends StatefulWidget {
  final String userId;

  const LocationSplashScreen({
    super.key,
    required this.userId,
  });

  @override
  State<LocationSplashScreen> createState() => _LocationSplashScreenState();
}

class _LocationSplashScreenState extends State<LocationSplashScreen> {
  String _statusText = 'Fetching location...';

  @override
  void initState() {
    super.initState();
    _detectLocationAndContinue();
  }

  Future<void> _detectLocationAndContinue() async {
    try {
      setState(() {
        _statusText = 'Checking location services...';
      });

      final serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        _goToHome(
          isServiceAvailable: false,
          locationTitle: 'Location off',
          locationLine: 'Please enable location services',
          locationMessage: 'Location services are turned off.',
        );
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        setState(() {
          _statusText = 'Requesting location permission...';
        });

        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        _goToHome(
          isServiceAvailable: false,
          locationTitle: 'Location denied',
          locationLine: 'Tap to change location',
          locationMessage: 'Location permission denied.',
        );
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        _goToHome(
          isServiceAvailable: false,
          locationTitle: 'Location blocked',
          locationLine: 'Enable permission from settings',
          locationMessage:
          'Location permission is permanently denied. Please enable it from settings.',
        );
        return;
      }

      setState(() {
        _statusText = 'Detecting your area...';
      });

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(
        const Duration(seconds: 12),
        onTimeout: () async {
          return await Geolocator.getLastKnownPosition() ??
              Future.error('Location timeout');
        },
      );

      setState(() {
        _statusText = 'Finding service availability...';
      });

      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isEmpty) {
        _goToHome(
          isServiceAvailable: false,
          locationTitle: 'Unknown location',
          locationLine: 'Unable to detect address',
          locationMessage: 'Unable to detect your location.',
        );
        return;
      }

      final place = placemarks.first;

      final locality = place.locality ?? '';
      final subLocality = place.subLocality ?? '';
      final street = place.street ?? '';
      final administrativeArea = place.administrativeArea ?? '';
      final subAdministrativeArea = place.subAdministrativeArea ?? '';

      final combinedAddress = [
        subLocality,
        locality,
        subAdministrativeArea,
        administrativeArea,
      ].where((e) => e.trim().isNotEmpty).join(', ');

      final searchableAddress = combinedAddress.toLowerCase();

      final isNoida = searchableAddress.contains('noida') ||
          searchableAddress.contains('gautam buddha nagar');

      final locationTitle = _buildLocationTitle(place);
      final locationLine = _buildLocationLine(place);

      _goToHome(
        isServiceAvailable: isNoida,
        locationTitle: locationTitle,
        locationLine: locationLine,
        locationMessage: isNoida
            ? 'Service available in your area'
            : 'Currently not available in your location',
        latitude: position.latitude,
        longitude: position.longitude,
      );
    } catch (e) {
      _goToHome(
        isServiceAvailable: false,
        locationTitle: 'Location unavailable',
        locationLine: 'Tap to change location',
        locationMessage: 'Unable to check your location right now.',
      );
    }
  }

  String _buildLocationTitle(Placemark place) {
    final name = place.name ?? '';
    final subLocality = place.subLocality ?? '';
    final locality = place.locality ?? '';

    if (name.trim().isNotEmpty && name.length <= 24) {
      return name;
    }

    if (subLocality.trim().isNotEmpty) {
      return subLocality;
    }

    if (locality.trim().isNotEmpty) {
      return locality;
    }

    return 'Your location';
  }

  String _buildLocationLine(Placemark place) {
    final parts = [
      place.name,
      place.street,
      place.subLocality,
      place.locality,
    ]
        .where((e) => e != null && e.trim().isNotEmpty)
        .map((e) => e!.trim())
        .toSet()
        .toList();

    if (parts.isEmpty) return 'Detected location';

    return parts.join(', ');
  }

  void _goToHome({
    required bool isServiceAvailable,
    required String locationTitle,
    required String locationLine,
    required String locationMessage,
    double? latitude,
    double? longitude,
  }) {
    if (!mounted) return;

    Get.offNamed(
      AppRoutes.home,
      arguments: {
        'userId': widget.userId,
        'isServiceAvailable': isServiceAvailable,
        'locationTitle': locationTitle,
        'locationLine': locationLine,
        'locationMessage': locationMessage,
        'latitude': latitude,
        'longitude': longitude,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 170,
                  height: 170,
                  decoration: BoxDecoration(
                    color: AppColors.lightGreen,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryColor.withOpacity(0.10),
                        blurRadius: 30,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(
                        Icons.map_outlined,
                        size: 110,
                        color: AppColors.primaryColor.withOpacity(0.15),
                      ),
                      const Icon(
                        Icons.location_on,
                        size: 76,
                        color: AppColors.primaryColor,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 34),
                Text(
                  _statusText,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'We are checking whether GoldDust Gardening is available in your area.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 28),
                const SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: AppColors.primaryColor,
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