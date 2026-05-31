import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../app/app_text_styles.dart';
import '../widgets/liquid_glass_instruction_card.dart';
import '../app/app_constants.dart';
import '../app/routes.dart';

class ConfirmLocationMapScreen extends StatefulWidget {
  final String userId;
  final double? initialLatitude;
  final double? initialLongitude;
  final String? initialAddress;

  const ConfirmLocationMapScreen({
    super.key,
    required this.userId,
    this.initialLatitude,
    this.initialLongitude,
    this.initialAddress,
  });

  @override
  State<ConfirmLocationMapScreen> createState() =>
      _ConfirmLocationMapScreenState();
}

class _ConfirmLocationMapScreenState extends State<ConfirmLocationMapScreen> {
  GoogleMapController? _mapController;

  bool _isLoading = true;
  bool _isResolvingAddress = false;

  LatLng? _currentLatLng;
  LatLng? _selectedLatLng;

  String _locationTitle = 'Fetching location...';
  String _locationLine = 'Please wait';

  static const LatLng _defaultNoidaLatLng = LatLng(28.5355, 77.3910);

  @override
  void initState() {
    super.initState();

    final hasInitialLocation =
        widget.initialLatitude != null && widget.initialLongitude != null;

    if (hasInitialLocation) {
      final passedLatLng = LatLng(
        widget.initialLatitude!,
        widget.initialLongitude!,
      );

      _selectedLatLng = passedLatLng;

      final passedAddress = widget.initialAddress?.trim() ?? '';

      if (passedAddress.isNotEmpty) {
        _locationTitle = _extractTitleFromAddress(passedAddress);
        _locationLine = passedAddress;
      } else {
        _locationTitle = 'Selected location';
        _locationLine =
        '${passedLatLng.latitude.toStringAsFixed(6)}, ${passedLatLng.longitude.toStringAsFixed(6)}';
      }

      _isLoading = false;

      debugPrint(
        '✅ ConfirmLocationMapScreen opened with passed location: '
            'lat=${passedLatLng.latitude}, lng=${passedLatLng.longitude}, '
            'address=$passedAddress',
      );

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _moveCameraTo(passedLatLng);

        // Optional: resolve exact address again only if address was not passed.
        if (passedAddress.isEmpty) {
          _resolveAddress(passedLatLng);
        }
      });
    } else {
      debugPrint('ℹ️ No passed location. Loading current location.');
      _loadCurrentLocation();
    }
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  String _extractTitleFromAddress(String address) {
    final parts = address
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    if (parts.isEmpty) return 'Selected location';

    return parts.first.length > 35 ? 'Selected location' : parts.first;
  }

  Future<void> _moveCameraTo(LatLng latLng) async {
    if (_mapController == null) return;

    await _mapController!.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: latLng,
          zoom: 17,
        ),
      ),
    );
  }

  Future<void> _loadCurrentLocation() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        _showSnack('Please enable location services.');
        setState(() => _isLoading = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _showSnack('Location permission is required.');
        setState(() => _isLoading = false);
        return;
      }

      // ignore: deprecated_member_use
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final latLng = LatLng(position.latitude, position.longitude);

      if (!mounted) return;

      setState(() {
        _currentLatLng = latLng;
        _selectedLatLng = latLng;
        _isLoading = false;
      });

      await _moveCameraTo(latLng);
      await _resolveAddress(latLng);
    } catch (e) {
      debugPrint('❌ _loadCurrentLocation error: $e');

      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _selectedLatLng ??= _defaultNoidaLatLng;
        _locationTitle = 'Selected location';
        _locationLine = 'Unable to fetch current location';
      });

      _showSnack('Unable to fetch your current location.');
    }
  }

  Future<void> _goToCurrentLocation() async {
    if (_currentLatLng == null) {
      await _loadCurrentLocation();
      return;
    }

    await _moveCameraTo(_currentLatLng!);

    setState(() {
      _selectedLatLng = _currentLatLng;
    });

    await _resolveAddress(_currentLatLng!);
  }

  Future<void> _resolveAddress(LatLng latLng) async {
    if (!mounted) return;

    setState(() {
      _isResolvingAddress = true;
    });

    try {
      final placemarks = await placemarkFromCoordinates(
        latLng.latitude,
        latLng.longitude,
      );

      if (!mounted) return;

      if (placemarks.isEmpty) {
        setState(() {
          _locationTitle = 'Selected location';
          _locationLine =
          '${latLng.latitude.toStringAsFixed(6)}, ${latLng.longitude.toStringAsFixed(6)}';
          _isResolvingAddress = false;
        });
        return;
      }

      final place = placemarks.first;

      final title = _buildLocationTitle(place);
      final line = _buildLocationLine(place);

      setState(() {
        _locationTitle = title;
        _locationLine = line;
        _isResolvingAddress = false;
      });
    } catch (e) {
      debugPrint('❌ _resolveAddress error: $e');

      if (!mounted) return;

      setState(() {
        _locationTitle = 'Selected location';
        _locationLine =
        '${latLng.latitude.toStringAsFixed(6)}, ${latLng.longitude.toStringAsFixed(6)}';
        _isResolvingAddress = false;
      });
    }
  }

  String _buildLocationTitle(Placemark place) {
    final name = (place.name ?? '').trim();
    final subLocality = (place.subLocality ?? '').trim();
    final locality = (place.locality ?? '').trim();
    final street = (place.street ?? '').trim();

    if (name.isNotEmpty && name.length <= 30) return name;
    if (street.isNotEmpty && street.length <= 30) return street;
    if (subLocality.isNotEmpty) return subLocality;
    if (locality.isNotEmpty) return locality;

    return 'Selected location';
  }

  String _buildLocationLine(Placemark place) {
    final parts = [
      place.subLocality,
      place.locality,
      place.subAdministrativeArea,
      place.administrativeArea,
      place.postalCode,
    ]
        .where((e) => e != null && e.trim().isNotEmpty)
        .map((e) => e!.trim())
        .toSet()
        .toList();

    if (parts.isEmpty) return 'Address not available';

    return parts.join(', ');
  }

  bool _isServiceAvailableInNoida() {
    final text = '$_locationTitle $_locationLine'.toLowerCase();

    // First block locations where you do NOT serve.
    final blockedLocations = [
      'greater noida',
      'greaternoida',
      'gurgaon',
      'gurugram',
      'delhi',
      'new delhi',
      'faridabad',
      'ghaziabad',
    ];

    for (final blocked in blockedLocations) {
      if (text.contains(blocked)) {
        return false;
      }
    }

    // Then allow only proper Noida.
    final allowedLocations = [
      'noida',
      'gautam buddha nagar',
    ];

    for (final allowed in allowedLocations) {
      if (text.contains(allowed)) {
        return true;
      }
    }

    return false;
  }

  void _confirmLocation() {
    final selected = _selectedLatLng;

    if (selected == null) {
      _showSnack('Please select a location first.');
      return;
    }

    final isServiceAvailable = _isServiceAvailableInNoida();

    Get.offNamed(
      AppRoutes.home,
      arguments: {
        'userId': widget.userId,
        'isServiceAvailable': isServiceAvailable,
        'locationTitle': _locationTitle,
        'locationLine': _locationLine,
        'locationMessage': isServiceAvailable
            ? 'Service available in your area'
            : 'Currently not available in your location',
        'latitude': selected.latitude,
        'longitude': selected.longitude,
      },
    );
  }

  void _showSnack(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final initialTarget = _selectedLatLng ?? _defaultNoidaLatLng;

    return Scaffold(
      backgroundColor: Colors.white,
      extendBody: true,
      body: _isLoading
          ? const Center(
        child: CircularProgressIndicator(
          color: AppColors.primaryColor,
        ),
      )
          : Stack(
        children: [
          Positioned.fill(
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: initialTarget,
                zoom: 17,
              ),
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              compassEnabled: false,
              mapToolbarEnabled: false,
              onMapCreated: (controller) async {
                _mapController = controller;

                final selected = _selectedLatLng ?? _defaultNoidaLatLng;

                debugPrint(
                  '🗺️ Map created. Moving camera to: '
                      '${selected.latitude}, ${selected.longitude}',
                );

                await Future.delayed(const Duration(milliseconds: 300));
                await _moveCameraTo(selected);
              },
              onCameraMove: (position) {
                _selectedLatLng = position.target;
              },
              onCameraIdle: () {
                final selected = _selectedLatLng;
                if (selected != null) {
                  _resolveAddress(selected);
                }
              },
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
              child: _buildTopBackArea(),
            ),
          ),

          Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 70),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LiquidGlassInstructionCard(
                    radius: 22,
                    minHeight: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                    child: Column(
                      children: [
                        Text(
                          'SET THIS AS YOUR LOCATION',
                          style: AppTextStyles.tiny.copyWith(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _locationTitle.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.bodyLarge.copyWith(
                            color: AppColors.primaryColor,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Icon(
                    Icons.location_on_rounded,
                    size: 52,
                    color: Color(0xFFFFB72B),
                  ),
                ],
              ),
            ),
          ),

          Positioned(
            left: 18,
            right: 18,
            bottom: 18,
            child: _buildBottomConfirmSheet(),
          ),

          Positioned(
            right: 18,
            bottom: 180,
            child: GestureDetector(
              onTap: _goToCurrentLocation,
              child: SizedBox(
                width: 116,
                height: 52,
                child: LiquidGlassInstructionCard(
                  radius: 24,
                  minHeight: 52,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.my_location_rounded,
                        size: 22,
                        color: Color(0xFFFFB72B),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Current',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBackArea() {
    return Row(
      children: [
        GestureDetector(
          onTap: () => Get.back(),
          child: SizedBox(
            width: 42,
            height: 42,
            child: LiquidGlassInstructionCard(
              radius: 21,
              minHeight: 42,
              padding: EdgeInsets.zero,
              child: const Center(
                child: Icon(
                  Icons.arrow_back_rounded,
                  size: 24,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: LiquidGlassInstructionCard(
            radius: 24,
            minHeight: 52,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Icon(
                  Icons.location_on_rounded,
                  color: Color(0xFFFFB72B),
                  size: 24,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Confirm your location',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.body.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomConfirmSheet() {
    return LiquidGlassInstructionCard(
      radius: 30,
      minHeight: 0,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFB72B).withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.location_on_rounded,
                  color: Color(0xFFFFB72B),
                  size: 30,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _isResolvingAddress
                    ? Text(
                  'Fetching address...',
                  style: AppTextStyles.bodyLarge.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryColor,
                  ),
                )
                    : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _locationTitle.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodyLarge.copyWith(
                        fontWeight: FontWeight.w900,
                        color: AppColors.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _locationLine,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.body.copyWith(
                        height: 1.4,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _confirmLocation,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFB72B),
                foregroundColor: Colors.black,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(27),
                ),
              ),
              child: const Text(
                'Confirm Location',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}