import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../app/app_text_styles.dart';
import 'subscription_details_screen.dart';
import 'expert_visit_details_screen.dart';
import '../app/app_constants.dart';
import '../app/routes.dart';
import '../services/booking_service.dart';
import 'plan_details_page.dart';
import 'refer_and_earn_screen.dart';
import 'confirm_location_map_screen.dart';
import '../widgets/liquid_glass_instruction_card.dart';
import 'add_products_for_next_visit_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:ui';
import 'profile_screen.dart';
import 'package:video_player/video_player.dart';

class HomeView extends StatefulWidget {
  final String userId;
  final bool isServiceAvailable;
  final String locationTitle;
  final String locationLine;
  final String locationMessage;
  final double? latitude;
  final double? longitude;

  const HomeView({
    super.key,
    required this.userId,
    required this.isServiceAvailable,
    required this.locationTitle,
    required this.locationLine,
    required this.locationMessage,
    this.latitude,
    this.longitude,
  });

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  bool hasActivePlan = false;
  bool hasPendingExpertVisit = false;
  Timer? _transformCarouselTimer;
  bool _isFetchingSubscription = false;
  Map<String, dynamic>? _activeBooking;
  Map<String, dynamic>? _pendingExpertVisit;
  String _resolvedUserId = '';
  static const String _cachedActiveBookingKey = 'cached_active_booking';
  static const String _cachedPendingExpertVisitKey = 'cached_pending_expert_visit';
  static const String _savedProductCartKeyPrefix = 'saved_product_cart';
  final GlobalKey _plansSectionKey = GlobalKey();
  int _selectedNavIndex = 0;
  List<Map<String, dynamic>> _cartItems = [];
  late final ScrollController _transformScrollController;
  final TextEditingController _locationSearchController = TextEditingController();
  Timer? _locationSearchDebounce;
  bool _isSearchingLocation = false;
  List<Map<String, dynamic>> _locationPredictions = [];
  late final VideoPlayerController _transformVideoController;
  bool _isTransformVideoReady = false;
  static const String _googlePlacesApiKey = 'AIzaSyAijxsBur5n7sI4lhgQu5gAGYzX4cgWflg';
  final List<Map<String, String>> _transformItems = [
    {
      'image': 'assets/images/work/work1.webp',
      'caption': 'Healthy indoor plants, maintained the right way',
    },
    {
      'image': 'assets/images/work/work2.webp',
      'caption': 'Expert pruning for neat, well-shaped plants',
    },
    {
      'image': 'assets/images/work/work3.webp',
      'caption': 'Fresh lawn setup for a greener outdoor space',
    },
    {
      'image': 'assets/images/work/work4.webp',
      'caption': 'Plant protection treatments prepared by trained experts',
    },
    {
      'image': 'assets/images/work/work5.webp',
      'caption': 'Complete garden care, from soil to setup',
    },
    {
      'image': 'assets/images/work/work6.webp',
      'caption': 'Plant propagation done by trained experts',
    },
    {
      'image': 'assets/images/work/work7.webp',
      'caption': 'Regular trimming to keep plants neat and healthy',
    },
    {
      'image': 'assets/images/work/work8.webp',
      'caption': 'Professional care for every plant, every visit',
    },
  ];

  @override
  void initState() {
    super.initState();

    _transformScrollController = ScrollController();
    _startTransformCarousel();
    _initTransformVideo();

    if (widget.isServiceAvailable) {
      _loadCachedBookingInstantly();
      _fetchActiveSubscription();
    }
  }

  @override
  void dispose() {
    _transformCarouselTimer?.cancel();
    _locationSearchDebounce?.cancel();
    _locationSearchController.dispose();
    _transformScrollController.dispose();
    _transformVideoController.dispose();
    super.dispose();
  }

  Future<String> _getCartStorageKey() async {
    final resolvedUserId = _resolvedUserId.isNotEmpty
        ? _resolvedUserId
        : await _resolveUserId();

    String bookingId = '';

    if (_activeBooking != null) {
      final booking = _normalizeBookingForSubscriptionDetails(_activeBooking!);

      bookingId = (booking['bookingID'] ??
          booking['bookingId'] ??
          booking['id'] ??
          booking['visitID'] ??
          '')
          .toString()
          .trim();
    }

    final userKey = resolvedUserId.trim().isNotEmpty
        ? resolvedUserId.trim()
        : widget.userId.trim();

    return '${_savedProductCartKeyPrefix}_${userKey}_$bookingId';
  }

  Future<void> _loadSavedCartItems() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = await _getCartStorageKey();

      final savedCartJson = prefs.getString(key);

      if (savedCartJson == null || savedCartJson.trim().isEmpty) {
        return;
      }

      final decoded = jsonDecode(savedCartJson);

      if (decoded is! List) {
        return;
      }

      final restoredCart = decoded
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();

      if (!mounted) return;

      setState(() {
        _cartItems = restoredCart;
      });

      debugPrint('🛒 Restored saved cart: ${_cartItems.length} items');
    } catch (e) {
      debugPrint('❌ Failed to load saved cart: $e');
    }
  }

  Future<void> _saveCartItemsToStorage(
      List<Map<String, dynamic>> cartItems,
      ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = await _getCartStorageKey();

      final copiedCart = cartItems
          .map((item) => Map<String, dynamic>.from(item))
          .toList();

      await prefs.setString(key, jsonEncode(copiedCart));

      debugPrint('🛒 Saved cart: ${copiedCart.length} items');
    } catch (e) {
      debugPrint('❌ Failed to save cart: $e');
    }
  }

  Future<void> _clearSavedCartItems() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = await _getCartStorageKey();

      await prefs.remove(key);

      if (!mounted) return;

      setState(() {
        _cartItems = [];
      });

      debugPrint('🛒 Cart cleared');
    } catch (e) {
      debugPrint('❌ Failed to clear cart: $e');
    }
  }

  void _updateCartItems(List<Map<String, dynamic>> updatedCart) {
    final copiedCart = updatedCart
        .map((item) => Map<String, dynamic>.from(item))
        .toList();

    if (!mounted) return;

    setState(() {
      _cartItems = copiedCart;
    });

    _saveCartItemsToStorage(copiedCart);
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

  void _onLocationSearchChanged(String value, StateSetter modalSetState) {
    _locationSearchDebounce?.cancel();

    final query = value.trim();

    if (query.length < 2) {
      modalSetState(() {
        _locationPredictions = [];
        _isSearchingLocation = false;
      });
      return;
    }

    _locationSearchDebounce = Timer(const Duration(milliseconds: 450), () {
      _fetchLocationPredictions(query, modalSetState);
    });
  }

  Future<void> _fetchLocationPredictions(
      String query,
      StateSetter modalSetState,
      ) async {
    if (query.trim().length < 2) {
      modalSetState(() {
        _locationPredictions = [];
        _isSearchingLocation = false;
      });
      return;
    }

    modalSetState(() {
      _isSearchingLocation = true;
    });

    try {
      final uri = Uri.parse(
        'https://places.googleapis.com/v1/places:autocomplete',
      );

      final body = {
        'input': query.trim(),
        'includedRegionCodes': ['in'],
        'languageCode': 'en',
        'locationBias': {
          'circle': {
            'center': {
              'latitude': 28.5355,
              'longitude': 77.3910,
            },
            'radius': 50000.0,
          },
        },
      };

      debugPrint('📍 Places New Autocomplete URL: $uri');
      debugPrint('📍 Places New Autocomplete body: ${jsonEncode(body)}');

      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'X-Goog-Api-Key': _googlePlacesApiKey,
        },
        body: jsonEncode(body),
      );

      debugPrint('📍 Places New HTTP status: ${response.statusCode}');
      debugPrint('📍 Places New body: ${response.body}');

      final data = jsonDecode(response.body);

      if (response.statusCode != 200) {
        final message = data is Map
            ? (data['error']?['message'] ?? 'Google Places API failed').toString()
            : 'Google Places API failed';

        throw Exception(message);
      }

      final suggestions = data['suggestions'];

      final predictions = <Map<String, dynamic>>[];

      if (suggestions is List) {
        for (final item in suggestions) {
          if (item is! Map) continue;

          final placePrediction = item['placePrediction'];

          if (placePrediction is! Map) continue;

          final placeId = placePrediction['placeId']?.toString() ?? '';
          final placeText =
              placePrediction['text']?['text']?.toString() ?? '';

          final mainText =
              placePrediction['structuredFormat']?['mainText']?['text']
                  ?.toString() ??
                  placeText;

          final secondaryText =
              placePrediction['structuredFormat']?['secondaryText']?['text']
                  ?.toString() ??
                  '';

          if (placeId.isEmpty || placeText.isEmpty) continue;

          predictions.add({
            'place_id': placeId,
            'description': placeText,
            'structured_formatting': {
              'main_text': mainText,
              'secondary_text': secondaryText,
            },
          });
        }
      }

      modalSetState(() {
        _locationPredictions = predictions;
        _isSearchingLocation = false;
      });
    } catch (e) {
      debugPrint('❌ Places New autocomplete error: $e');

      modalSetState(() {
        _locationPredictions = [];
        _isSearchingLocation = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Location search failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _selectGooglePlace(Map<String, dynamic> prediction) async {
    final placeId = prediction['place_id']?.toString() ?? '';
    final description = prediction['description']?.toString() ?? '';

    if (placeId.isEmpty) return;

    try {
      final uri = Uri.parse(
        'https://places.googleapis.com/v1/places/$placeId',
      );

      debugPrint('📍 Places New Details URL: $uri');

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'X-Goog-Api-Key': _googlePlacesApiKey,

          // Important: Places New needs field mask.
          'X-Goog-FieldMask': 'id,displayName,formattedAddress,location',
        },
      );

      debugPrint('📍 Places New Details HTTP status: ${response.statusCode}');
      debugPrint('📍 Places New Details body: ${response.body}');

      final data = jsonDecode(response.body);

      if (response.statusCode != 200) {
        final message = data is Map
            ? (data['error']?['message'] ?? 'Place details failed').toString()
            : 'Place details failed';

        throw Exception(message);
      }

      final location = data['location'];

      if (location is! Map) {
        throw Exception('Location not found for selected place');
      }

      final lat = double.tryParse(location['latitude'].toString());
      final lng = double.tryParse(location['longitude'].toString());

      if (lat == null || lng == null) {
        throw Exception('Invalid latitude/longitude');
      }

      final formattedAddress =
      (data['formattedAddress'] ?? description).toString();

      if (!mounted) return;

      Navigator.pop(context);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ConfirmLocationMapScreen(
            userId: widget.userId,
            initialLatitude: lat,
            initialLongitude: lng,
            initialAddress: formattedAddress,
          ),
        ),
      );
    } catch (e) {
      debugPrint('❌ Places New details error: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to select location: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _initTransformVideo() async {
    _transformVideoController = VideoPlayerController.asset(
      'assets/videos/transform_home_garden.mp4',
    );

    try {
      await _transformVideoController.initialize();

      await _transformVideoController.setLooping(true);
      await _transformVideoController.setVolume(0.0);
      await _transformVideoController.play();

      if (!mounted) return;

      setState(() {
        _isTransformVideoReady = true;
      });
    } catch (e) {
      debugPrint('❌ Transform video load error: $e');

      if (!mounted) return;

      setState(() {
        _isTransformVideoReady = false;
      });
    }
  }

  void _handleShopTap() {
    if (hasActivePlan && _activeBooking != null) {
      final booking = _normalizeBookingForSubscriptionDetails(_activeBooking!);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AddProductsForNextVisitScreen(
            userID: _resolvedUserId.isNotEmpty ? _resolvedUserId : widget.userId,
            bookingID: (booking['bookingID'] ?? '').toString(),
            visitDate: _getNextFutureBookedDate(booking),
            assignedMali: (booking['assignedMali'] ?? '').toString(),
            fetchCatalogUrl:
            'https://18hkwgpuo1.execute-api.ap-south-1.amazonaws.com/zohoInventoryFetch',
            cartItems: _cartItems,
            onCartUpdated: _updateCartItems,
          ),
        ),
      ).then((result) {
        if (!mounted) return;

        if (result is Map && result['orderConfirmed'] == true) {
          _clearSavedCartItems();
          return;
        }

        if (result is Map && result['cartItems'] != null) {
          _updateCartItems(
            List<Map<String, dynamic>>.from(result['cartItems']),
          );
          return;
        }

        if (result == true) {
          _clearSavedCartItems();
        }
      });
      return;
    }

    Get.toNamed(
      AppRoutes.scheduleBooking,
      arguments: _resolvedUserId.isNotEmpty ? _resolvedUserId : widget.userId,
    );
  }

  void _startTransformCarousel() {
    _transformCarouselTimer?.cancel();

    _transformCarouselTimer = Timer.periodic(
      const Duration(seconds: 3),
          (_) {
        if (!mounted || !_transformScrollController.hasClients) return;

        final maxScroll = _transformScrollController.position.maxScrollExtent;
        final current = _transformScrollController.offset;

        double next = current + 304;

        if (next >= maxScroll) {
          next = 0;
        }

        _transformScrollController.animateTo(
          next,
          duration: const Duration(milliseconds: 650),
          curve: Curves.easeInOutCubic,
        );
      },
    );
  }

  Future<void> _loadCachedBookingInstantly() async {
    final prefs = await SharedPreferences.getInstance();

    final cachedActive = prefs.getString(_cachedActiveBookingKey);
    final cachedExpert = prefs.getString(_cachedPendingExpertVisitKey);

    if (!mounted) return;

    if (cachedActive != null && cachedActive.isNotEmpty) {
      final decoded = jsonDecode(cachedActive);

      if (decoded is Map) {
        setState(() {
          _activeBooking = Map<String, dynamic>.from(decoded);
          hasActivePlan = true;
        });

        await _loadSavedCartItems();
      }
    }

    if (cachedExpert != null && cachedExpert.isNotEmpty && _activeBooking == null) {
      final decoded = jsonDecode(cachedExpert);

      if (decoded is Map) {
        setState(() {
          _pendingExpertVisit = Map<String, dynamic>.from(decoded);
          hasPendingExpertVisit = true;
        });
      }
    }
  }

  Future<void> _saveBookingCache({
    Map<String, dynamic>? activeBooking,
    Map<String, dynamic>? pendingExpertVisit,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    if (activeBooking != null) {
      await prefs.setString(
        _cachedActiveBookingKey,
        jsonEncode(activeBooking),
      );
    } else {
      await prefs.remove(_cachedActiveBookingKey);
    }

    if (pendingExpertVisit != null) {
      await prefs.setString(
        _cachedPendingExpertVisitKey,
        jsonEncode(pendingExpertVisit),
      );
    } else {
      await prefs.remove(_cachedPendingExpertVisitKey);
    }
  }

  Widget _waterDropCard({
    required Widget child,
    double radius = 24,
    EdgeInsets padding = EdgeInsets.zero,
  }) {
    return Container(
      decoration: _softCardDecoration(radius: radius),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Stack(
          children: [
            Positioned(
              top: -14,
              left: 2,
              right: 2,
              child: Container(
                height: 16,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(radius),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.13),
                      blurRadius: 8,
                      spreadRadius: 1,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: padding,
              child: child,
            ),
          ],
        ),
      ),
    );
  }

  Map<String, dynamic>? _mergeZohoBookingsIntoSubscription(
      List<Map<String, dynamic>> zohoBookings,
      ) {
    if (zohoBookings.isEmpty) return null;

    final sortedBookings = List<Map<String, dynamic>>.from(zohoBookings);

    sortedBookings.sort((a, b) {
      final aDate = _getBookingMainDate(a);
      final bDate = _getBookingMainDate(b);

      if (aDate == null && bDate == null) return 0;
      if (aDate == null) return 1;
      if (bDate == null) return -1;

      return aDate.compareTo(bDate);
    });

    final nearestUpcomingBooking =
        _pickNearestUpcomingZohoBooking(sortedBookings) ?? sortedBookings.first;

    final allBookedDates = <String>[];
    final allScheduledVisits = <Map<String, dynamic>>[];

    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);

    for (final booking in sortedBookings) {
      final date = _extractBookingDateString(booking);
      if (date.isEmpty) continue;

      final parsedDate = _parseBookedDate(date);
      final dateOnly = parsedDate == null
          ? null
          : DateTime(parsedDate.year, parsedDate.month, parsedDate.day);

      final isPast = dateOnly == null ? false : dateOnly.isBefore(todayOnly);
      final isToday =
      dateOnly == null ? false : dateOnly.isAtSameMomentAs(todayOnly);
      final isFuture = dateOnly == null ? false : dateOnly.isAfter(todayOnly);

      // IMPORTANT:
      // This reads only the separate DynamoDB column named "status".
      // It does not use taskStatus, subscriptionStatus, or dealStatus.
      final visitStatus = (booking['status'] ?? '').toString().trim();
      final normalizedVisitStatus = visitStatus.toLowerCase();

      final isDoneByStatus = normalizedVisitStatus == 'done' ||
          normalizedVisitStatus == 'completed' ||
          normalizedVisitStatus == 'complete' ||
          normalizedVisitStatus == 'closed' ||
          normalizedVisitStatus == 'finished' ||
          normalizedVisitStatus == 'visit completed' ||
          normalizedVisitStatus == 'service completed';

      final isDone = isDoneByStatus || isPast;

      debugPrint(
        'VISIT STATUS FROM DDB => date=$date, '
            'bookingID=${booking['bookingID']}, '
            'status=$visitStatus, '
            'isDone=$isDone',
      );

      if (!allBookedDates.contains(date)) {
        allBookedDates.add(date);
      }

      allScheduledVisits.add({
        'date': date,
        'mali': booking['assignedMali'] ?? booking['maaliName'] ?? 'Not assigned',
        'timeSlot': booking['visitTimeSlot1'] ??
            booking['timeSlot'] ??
            _extractTimeSlotFromDayTimeSlots(booking),
        'bookingID': booking['bookingID'] ?? '',
        'taskID': booking['taskID'] ?? '',
        'dealID': booking['dealID'] ?? '',
        'planName': booking['planName'] ?? '',

        // Visit-level status from zohoBookings.status
        'status': visitStatus,
        'visitStatus': visitStatus,
        'isDone': isDone,

        'booking': booking,

        // Date flags are kept only for display/selection logic.
        // DONE should be based on isDone, not isPast.
        'isPast': isPast,
        'isToday': isToday,
        'isFuture': isFuture,
      });
    }

    allBookedDates.sort((a, b) {
      final aDate = _parseBookedDate(a) ?? DateTime(2100);
      final bDate = _parseBookedDate(b) ?? DateTime(2100);
      return aDate.compareTo(bDate);
    });

    allScheduledVisits.sort((a, b) {
      final aDate = _parseBookedDate(a['date'].toString()) ?? DateTime(2100);
      final bDate = _parseBookedDate(b['date'].toString()) ?? DateTime(2100);
      return aDate.compareTo(bDate);
    });

    final merged = Map<String, dynamic>.from(nearestUpcomingBooking);
    merged['currentCycleDealID'] = nearestUpcomingBooking['dealID'] ?? '';
    merged['currentCycleStartDate'] =
        nearestUpcomingBooking['Current_Cycle_Subscription_Start_Date'] ??
            nearestUpcomingBooking['currentCycleStartDate'] ??
            '';
    final nearestDate = _extractBookingDateString(nearestUpcomingBooking);
    final nearestTime = (nearestUpcomingBooking['visitTimeSlot1'] ??
        nearestUpcomingBooking['timeSlot'] ??
        _extractTimeSlotFromDayTimeSlots(nearestUpcomingBooking))
        .toString();

    // Home card should show only nearest upcoming visit.
    merged['dueDate'] = nearestDate;
    merged['date'] = nearestDate;
    merged['visitTimeSlot1'] = nearestTime;
    merged['timeSlot'] = nearestTime;

    // Details screen should show all visits.
    merged['bookingType'] = 'monthlySubscription';
    merged['bookedDates'] = allBookedDates;
    merged['allScheduledVisits'] = allScheduledVisits;
    merged['rawZohoBookings'] = sortedBookings;

    merged['planName'] = nearestUpcomingBooking['planName'] ?? 'Current Plan';
    merged['assignedMali'] =
        nearestUpcomingBooking['assignedMali'] ?? 'Not assigned';
    merged['subscriptionStatus'] =
        nearestUpcomingBooking['subscriptionStatus'] ?? 'Active';
    merged['dealStatus'] = nearestUpcomingBooking['dealStatus'] ?? 'Active';

    debugPrint('✅ MERGED subscription for Home: $merged');

    return merged;
  }

  void _openProfileScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProfileScreen(
          userId: _resolvedUserId.isNotEmpty ? _resolvedUserId : widget.userId,
          onMyBookingsTap: () async {
            if (hasActivePlan && _activeBooking != null) {
              await _openManageBooking();
              return;
            }

            if (hasPendingExpertVisit && _pendingExpertVisit != null) {
              await _openExpertVisitDetails();
              return;
            }

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('No active booking found.'),
              ),
            );
          },
          onHelpSupportTap: _openWhatsAppSupport,
          onReferAndEarnTap: _openReferAndEarnScreen,
          onLogoutTap: _confirmLogout,
        ),
      ),
    );
  }



  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: const Text(
            'Logout?',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: AppColors.primaryColor,
            ),
          ),
          content: const Text(
            'You will need to login again with OTP.',
            style: TextStyle(
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
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _logout();
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
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _logout() async {
    try {
      await FirebaseAuth.instance.signOut();

      final prefs = await SharedPreferences.getInstance();

      await prefs.remove('userId');
      await prefs.remove('userID');
      await prefs.remove('firebaseUserId');
      await prefs.remove('phoneNumber');
      await prefs.remove('bookingPhone');
      await prefs.remove('userPhone');
      await prefs.remove('maaliUserId');
      await prefs.remove('isLoggedIn');

      await prefs.remove(_cachedActiveBookingKey);
      await prefs.remove(_cachedPendingExpertVisitKey);

      final savedCartKeys = prefs
          .getKeys()
          .where((key) => key.startsWith(_savedProductCartKeyPrefix))
          .toList();

      for (final key in savedCartKeys) {
        await prefs.remove(key);
      }

      if (!mounted) return;

      Get.offAllNamed(AppRoutes.login);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Logout failed. Please try again.'),
        ),
      );
    }
  }

  Map<String, dynamic>? _pickNearestUpcomingZohoBooking(
      List<Map<String, dynamic>> bookings,
      ) {
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);

    final futureBookings = bookings.where((booking) {
      final date = _getBookingMainDate(booking);
      if (date == null) return false;

      final dateOnly = DateTime(date.year, date.month, date.day);
      return !dateOnly.isBefore(todayOnly);
    }).toList();

    if (futureBookings.isEmpty) return null;

    futureBookings.sort((a, b) {
      final aDate = _getBookingMainDate(a);
      final bDate = _getBookingMainDate(b);

      if (aDate == null && bDate == null) return 0;
      if (aDate == null) return 1;
      if (bDate == null) return -1;

      return aDate.compareTo(bDate);
    });

    return futureBookings.first;
  }

  DateTime? _getBookingMainDate(Map<String, dynamic> booking) {
    final dateString = _extractBookingDateString(booking);
    if (dateString.isEmpty) return null;
    return _parseBookedDate(dateString);
  }

  String _extractBookingDateString(Map<String, dynamic> booking) {
    final bookedDates = booking['bookedDates'];

    if (bookedDates is List && bookedDates.isNotEmpty) {
      final cleanDates = bookedDates
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();

      if (cleanDates.isNotEmpty) {
        cleanDates.sort((a, b) {
          final aDate = _parseBookedDate(a) ?? DateTime(2100);
          final bDate = _parseBookedDate(b) ?? DateTime(2100);
          return aDate.compareTo(bDate);
        });

        return cleanDates.first;
      }
    }

    return (booking['dueDate'] ?? booking['date'] ?? booking['dateOfVisit'] ?? '')
        .toString()
        .trim();
  }

  String _extractTimeSlotFromDayTimeSlots(Map<String, dynamic> booking) {
    final slots = booking['dayTimeSlots'];

    if (slots is List && slots.isNotEmpty && slots.first is Map) {
      final firstSlot = Map<String, dynamic>.from(slots.first as Map);
      return (firstSlot['timeSlot'] ?? firstSlot['time'] ?? '').toString();
    }

    return '';
  }

  Future<void> _fetchActiveSubscription() async {
    if (!mounted) return;

    setState(() {
      _isFetchingSubscription = true;
    });

    try {
      final resolvedUserId = await _resolveUserId();

      if (resolvedUserId.isEmpty) {
        if (!mounted) return;

        setState(() {
          _resolvedUserId = '';
          hasActivePlan = false;
          hasPendingExpertVisit = false;
          _activeBooking = null;
          _pendingExpertVisit = null;
          _isFetchingSubscription = false;
        });

        await _saveBookingCache(
          activeBooking: null,
          pendingExpertVisit: null,
        );

        return;
      }

      debugPrint('================ HOME DEBUG START ================');
      debugPrint('resolvedUserId: $resolvedUserId');

      // Expert visits are only for expert visit flow.
      // Subscription should not depend on expert visits.
      List<dynamic> expertVisitData = [];

      try {
        expertVisitData = await BookingService.fetchExpertVisits(resolvedUserId);
      } catch (e) {
        debugPrint('⚠️ Expert visit fetch failed, continuing: $e');
        expertVisitData = [];
      }

      debugPrint('expertVisitData count: ${expertVisitData.length}');
      debugPrint('expertVisitData full: $expertVisitData');

      final pendingExpertVisit = _pickPendingExpertVisit(expertVisitData);

      debugPrint('pendingExpertVisit: $pendingExpertVisit');

      Map<String, dynamic>? activeBooking;

      // IMPORTANT:
      // If Zoho subscription booking is not found, do not stop Home screen.
      // Expert visit / recommendation card should still show.
      List<dynamic> zohoBookings = [];

      try {
        zohoBookings = await BookingService.fetchZohoBookings(resolvedUserId);
      } catch (e) {
        final errorText = e.toString().toLowerCase();

        final isNoBookingError =
            errorText.contains('404') ||
                errorText.contains('no bookings found') ||
                errorText.contains('no bookings founnd') ||
                errorText.contains('totalbookings') ||
                errorText.contains('"bookings": []') ||
                errorText.contains('bookings: []');

        if (isNoBookingError) {
          debugPrint(
            'ℹ️ No Zoho subscription bookings found. Continuing with expert visit/recommendation flow.',
          );
          zohoBookings = [];
        } else {
          rethrow;
        }
      }

      debugPrint('zohoBookings count: ${zohoBookings.length}');
      debugPrint('zohoBookings full: $zohoBookings');

      final mappedZohoBookings = zohoBookings
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      final now = DateTime.now();
      final todayOnly = DateTime(now.year, now.month, now.day);

      bool isCancelledBooking(Map<String, dynamic> booking) {
        final dealStatus =
        (booking['dealStatus'] ?? '').toString().trim().toLowerCase();

        final subscriptionStatus =
        (booking['subscriptionStatus'] ?? '').toString().trim().toLowerCase();

        final status =
        (booking['status'] ?? '').toString().trim().toLowerCase();

        return dealStatus == 'cancelled' ||
            dealStatus == 'canceled' ||
            subscriptionStatus == 'cancelled' ||
            subscriptionStatus == 'canceled' ||
            status == 'cancelled' ||
            status == 'canceled' ||
            status == 'inactive' ||
            status == 'plan cancelled' ||
            status == 'cancelled plan';
      }

      bool hasPendingRenewal(Map<String, dynamic> booking) {
        final renewalPaymentPending =
        (booking['renewalPaymentPending'] ?? '')
            .toString()
            .trim()
            .toLowerCase();

        return renewalPaymentPending == 'true' ||
            renewalPaymentPending == 'yes' ||
            renewalPaymentPending == '1' ||
            renewalPaymentPending == 'pending';
      }

      bool isActiveStatus(Map<String, dynamic> booking) {
        final dealStatus =
        (booking['dealStatus'] ?? '').toString().trim().toLowerCase();

        final subscriptionStatus =
        (booking['subscriptionStatus'] ?? '').toString().trim().toLowerCase();

        final status =
        (booking['status'] ?? '').toString().trim().toLowerCase();

        return dealStatus == 'active' ||
            subscriptionStatus == 'active' ||
            subscriptionStatus == 'subscription booked' ||
            status == 'active' ||
            status == 'subscription booked' ||
            status == 'completed' ||
            status.isEmpty;
      }

      DateTime? getDueDate(Map<String, dynamic> booking) {
        final dueDateStr =
        (booking['dueDate'] ?? booking['date'] ?? '').toString().trim();

        if (dueDateStr.isEmpty) return null;

        return _parseBookedDate(dueDateStr);
      }

      String getCycleStart(Map<String, dynamic> booking) {
        return (booking['Current_Cycle_Subscription_Start_Date'] ??
            booking['currentCycleStartDate'] ??
            booking['cycleStartDate'] ??
            '')
            .toString()
            .trim();
      }

      // Step 1:
      // Find the row that identifies the CURRENT CYCLE.
      // Current cycle = deal/cycle having nearest today/future active visit.
      final futureActiveRows = mappedZohoBookings.where((booking) {
        if (isCancelledBooking(booking)) return false;

        final dueDate = getDueDate(booking);

        final isTodayOrFutureVisit = dueDate != null &&
            !DateTime(dueDate.year, dueDate.month, dueDate.day)
                .isBefore(todayOnly);

        final include = isActiveStatus(booking) && isTodayOrFutureVisit;

        debugPrint(
          'Future marker check => dueDate=${booking['dueDate']}, '
              'dealID=${booking['dealID']}, '
              'cycleStart=${getCycleStart(booking)}, '
              'dealStatus=${booking['dealStatus']}, '
              'subscriptionStatus=${booking['subscriptionStatus']}, '
              'status=${booking['status']}, '
              'isTodayOrFutureVisit=$isTodayOrFutureVisit, '
              'include=$include',
        );

        return include;
      }).toList();

      futureActiveRows.sort((a, b) {
        final aDate = getDueDate(a);
        final bDate = getDueDate(b);

        if (aDate == null && bDate == null) return 0;
        if (aDate == null) return 1;
        if (bDate == null) return -1;

        return aDate.compareTo(bDate);
      });

      Map<String, dynamic>? currentCycleMarker;

      if (futureActiveRows.isNotEmpty) {
        currentCycleMarker = futureActiveRows.first;
      } else {
        // Fallback only for renewal-pending subscriptions.
        // This prevents old expired cycles from being shown as active.
        final renewalRows = mappedZohoBookings.where((booking) {
          if (isCancelledBooking(booking)) return false;
          return hasPendingRenewal(booking);
        }).toList();

        renewalRows.sort((a, b) {
          final aDate = getDueDate(a);
          final bDate = getDueDate(b);

          if (aDate == null && bDate == null) return 0;
          if (aDate == null) return 1;
          if (bDate == null) return -1;

          return bDate.compareTo(aDate);
        });

        if (renewalRows.isNotEmpty) {
          currentCycleMarker = renewalRows.first;
        }
      }

      debugPrint('currentCycleMarker: $currentCycleMarker');

      List<Map<String, dynamic>> activeZohoBookings = [];

      if (currentCycleMarker != null) {
        final currentDealId =
        (currentCycleMarker['dealID'] ?? '').toString().trim();

        final currentCycleStart = getCycleStart(currentCycleMarker);

        debugPrint('Current cycle dealID: $currentDealId');
        debugPrint('Current cycle start: $currentCycleStart');

        // Step 2:
        // Once current cycle is identified, include ALL visits of that cycle,
        // including past/completed visits.
        activeZohoBookings = mappedZohoBookings.where((booking) {
          if (isCancelledBooking(booking)) return false;

          final dealId = (booking['dealID'] ?? '').toString().trim();
          final cycleStart = getCycleStart(booking);

          if (currentDealId.isNotEmpty) {
            return dealId == currentDealId;
          }

          if (currentCycleStart.isNotEmpty) {
            return cycleStart == currentCycleStart;
          }

          return false;
        }).toList();

        activeZohoBookings.sort((a, b) {
          final aDate = getDueDate(a);
          final bDate = getDueDate(b);

          if (aDate == null && bDate == null) return 0;
          if (aDate == null) return 1;
          if (bDate == null) return -1;

          return aDate.compareTo(bDate);
        });
      }

      debugPrint(
        'activeZohoBookings/current cycle count: ${activeZohoBookings.length}',
      );
      debugPrint(
        'activeZohoBookings/current cycle full: $activeZohoBookings',
      );

      if (activeZohoBookings.isNotEmpty) {
        activeBooking = _mergeZohoBookingsIntoSubscription(activeZohoBookings);

        if (currentCycleMarker != null) {
          activeBooking?['currentCycleDealID'] =
              (currentCycleMarker['dealID'] ?? '').toString().trim();

          activeBooking?['currentCycleStartDate'] =
              getCycleStart(currentCycleMarker);
        }
      } else {
        activeBooking = null;
      }

      debugPrint('FINAL activeBooking selected: $activeBooking');
      debugPrint('FINAL pendingExpertVisit selected: $pendingExpertVisit');
      debugPrint('================ HOME DEBUG END ================');

      if (!mounted) return;

      setState(() {
        _resolvedUserId = resolvedUserId;

        _activeBooking = activeBooking;
        _pendingExpertVisit = pendingExpertVisit;

        hasActivePlan = activeBooking != null;
        hasPendingExpertVisit = pendingExpertVisit != null;

        _isFetchingSubscription = false;
      });

      await _saveBookingCache(
        activeBooking: activeBooking,
        pendingExpertVisit: pendingExpertVisit,
      );

      if (activeBooking != null) {
        await _loadSavedCartItems();
      } else if (mounted) {
        setState(() {
          _cartItems = [];
        });
      }
    } catch (e) {
      debugPrint('❌ _fetchActiveSubscription error: $e');

      if (!mounted) return;

      setState(() {
        _isFetchingSubscription = false;
      });
    }
  }


  String _getNextFutureBookedDate(Map<String, dynamic> booking) {
    final rawDates = booking['bookedDates'];

    if (rawDates is! List || rawDates.isEmpty) {
      return (booking['dueDate'] ?? booking['date'] ?? '').toString();
    }

    final dates = rawDates
        .map((e) => e.toString())
        .where((e) => e.trim().isNotEmpty)
        .toList();

    dates.sort((a, b) {
      final aDate = _parseBookedDate(a) ?? DateTime(2100);
      final bDate = _parseBookedDate(b) ?? DateTime(2100);
      return aDate.compareTo(bDate);
    });

    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);

    for (final dateStr in dates) {
      final parsed = _parseBookedDate(dateStr);
      if (parsed == null) continue;

      final dateOnly = DateTime(parsed.year, parsed.month, parsed.day);

      if (!dateOnly.isBefore(todayOnly)) {
        return dateStr;
      }
    }

    return dates.isNotEmpty ? dates.last : '';
  }

  DateTime? _parseBookedDate(String dateStr) {
    try {
      final parts = dateStr.split('-');
      if (parts.length != 3) return null;

      final day = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final yearRaw = int.parse(parts[2]);
      final year = parts[2].length == 2 ? 2000 + yearRaw : yearRaw;

      return DateTime(year, month, day);
    } catch (_) {
      return null;
    }
  }

  bool _canModifyVisit(String dateStr) {
    final visitDate = _parseBookedDate(dateStr);
    if (visitDate == null) return false;

    final cutoff = DateTime(
      visitDate.year,
      visitDate.month,
      visitDate.day,
    ).subtract(const Duration(days: 1));

    final cutoffDateTime = DateTime(
      cutoff.year,
      cutoff.month,
      cutoff.day,
      15,
      30,
    );

    return DateTime.now().isBefore(cutoffDateTime);
  }

  String _getVisitModificationCutoffText(String dateStr) {
    final visitDate = _parseBookedDate(dateStr);
    if (visitDate == null) return 'the previous day at 3:30 PM';

    final cutoff = visitDate.subtract(const Duration(days: 1));

    return '${cutoff.day.toString().padLeft(2, '0')}-${cutoff.month.toString().padLeft(2, '0')}-${cutoff.year}, 3:30 PM';
  }

  String _getCutoffDateString(String bookingDate) {
    final visitDate = _parseBookedDate(bookingDate);
    if (visitDate == null) return '';

    final cutoff = visitDate.subtract(const Duration(days: 1));

    return '${cutoff.day.toString().padLeft(2, '0')}-${cutoff.month.toString().padLeft(2, '0')}-${cutoff.year}';
  }

  DateTime? _getLatestBookingDate(Map<String, dynamic> booking) {
    final candidates = <DateTime>[];

    final bookedDates = booking['bookedDates'];
    if (bookedDates is List) {
      for (final raw in bookedDates) {
        final parsed = _parseBookedDate(raw.toString());
        if (parsed != null) candidates.add(parsed);
      }
    }

    final dueDate = _parseBookedDate((booking['dueDate'] ?? '').toString());
    if (dueDate != null) candidates.add(dueDate);

    final date = _parseBookedDate((booking['date'] ?? '').toString());
    if (date != null) candidates.add(date);

    final dateOfVisit =
    _parseBookedDate((booking['dateOfVisit'] ?? '').toString());
    if (dateOfVisit != null) candidates.add(dateOfVisit);

    final startDate = _parseFlexibleDate((booking['startDate'] ?? '').toString());
    if (startDate != null) candidates.add(startDate);

    final createdAt = _parseFlexibleDate((booking['createdAt'] ?? '').toString());
    if (createdAt != null) candidates.add(createdAt);

    final updatedAt = _parseFlexibleDate((booking['updatedAt'] ?? '').toString());
    if (updatedAt != null) candidates.add(updatedAt);

    if (candidates.isEmpty) return null;

    candidates.sort((a, b) => b.compareTo(a));
    return candidates.first;
  }

  DateTime? _parseFlexibleDate(String value) {
    final clean = value.trim();
    if (clean.isEmpty) return null;

    final numeric = int.tryParse(clean);
    if (numeric != null) {
      try {
        if (clean.length >= 13) {
          return DateTime.fromMillisecondsSinceEpoch(numeric);
        }
        if (clean.length == 10) {
          return DateTime.fromMillisecondsSinceEpoch(numeric * 1000);
        }
      } catch (_) {}
    }

    final parsedBooked = _parseBookedDate(clean);
    if (parsedBooked != null) return parsedBooked;

    try {
      return DateTime.tryParse(clean);
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic>? _pickActiveSubscriptionBooking(List<dynamic> bookings) {
    if (bookings.isEmpty) return null;

    final mappedBookings = bookings
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .where(_isActiveSubscriptionBooking)
        .toList();

    if (mappedBookings.isEmpty) return null;

    mappedBookings.sort((a, b) {
      final aDate = _getLatestBookingDate(a);
      final bDate = _getLatestBookingDate(b);

      if (aDate == null && bDate == null) return 0;
      if (aDate == null) return 1;
      if (bDate == null) return -1;

      return bDate.compareTo(aDate);
    });

    return mappedBookings.first;
  }

  Map<String, dynamic>? _pickPendingExpertVisit(List<dynamic> bookings) {
    if (bookings.isEmpty) return null;

    final mappedBookings = bookings
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .where(_isPendingExpertVisitBooking)
        .toList();

    if (mappedBookings.isEmpty) return null;

    mappedBookings.sort((a, b) {
      final aDate = _getLatestBookingDate(a);
      final bDate = _getLatestBookingDate(b);

      if (aDate == null && bDate == null) return 0;
      if (aDate == null) return 1;
      if (bDate == null) return -1;

      return bDate.compareTo(aDate);
    });

    return mappedBookings.first;
  }

  bool _isActiveSubscriptionBooking(Map<String, dynamic> booking) {
    final status = (booking['status'] ??
        booking['subscriptionStatus'] ??
        booking['dealStatus'] ??
        '')
        .toString()
        .trim()
        .toLowerCase();

    final bookingType = (booking['bookingType'] ?? '')
        .toString()
        .trim()
        .toLowerCase();

    final planName = (booking['planName'] ??
        booking['subscriptionPlan'] ??
        booking['plan'] ??
        '')
        .toString()
        .trim();

    if (status == 'cancelled' ||
        status == 'inactive' ||
        status == 'cancelled plan' ||
        status == 'plan cancelled') {
      return false;
    }

    return status == 'subscription booked' ||
        status == 'active' ||
        status == 'active cycle' ||
        status == 'renewal due' ||
        (bookingType == 'monthlysubscription' && planName.isNotEmpty);
  }

  bool _isPendingExpertVisitBooking(Map<String, dynamic> booking) {
    final status = (booking['status'] ?? '')
        .toString()
        .trim()
        .toLowerCase();

    if (status == 'cancelled' ||
        status == 'inactive' ||
        status == 'cancelled plan' ||
        status == 'plan cancelled' ||
        status == 'subscription booked' ||
        status == 'active' ||
        status == 'active cycle' ||
        status == 'renewal due') {
      return false;
    }

    return status == 'booked' ||
        status == 'expert visit booked' ||
        status == 'visit booked' ||
        status == 'scheduled' ||
        status == 'confirmed' ||
        status == 'rescheduled' ||
        status == 'pending' ||
        status == 'follow up' ||
        status == 'slots provided' ||
        status == 'expert slots provided' ||
        status == 'slot provided' ||
        status == 'completed' ||
        status == 'visit completed' ||
        status == 'expert visit completed' ||
        status == 'recommendation submitted' ||
        status == 'expert recommendation submitted' ||
        status == 'recommendation ready' ||
        status == 'plan recommended';
  }

  DateTime? _getBookingVisitDate(Map<String, dynamic> booking) {
    final rawDate = (booking['dueDate'] ??
        booking['date'] ??
        booking['dateOfVisit'] ??
        _getNextFutureBookedDate(booking))
        .toString()
        .trim();

    return _parseDate(rawDate);
  }

  DateTime? _parseDate(String value) {
    if (value.trim().isEmpty) return null;

    try {
      final clean = value.trim();

      if (clean.contains('-')) {
        final parts = clean.split('-');

        if (parts.length == 3) {
          final first = int.parse(parts[0]);
          final second = int.parse(parts[1]);
          final third = int.parse(parts[2]);

          if (parts[0].length == 4) {
            return DateTime(first, second, third);
          }

          final year = parts[2].length == 2 ? 2000 + third : third;
          return DateTime(year, second, first);
        }
      }

      return DateTime.tryParse(clean);
    } catch (_) {
      return null;
    }
  }

  String _formatNextVisit(Map<String, dynamic> booking) {
    final visitDate = _getBookingVisitDate(booking);
    final timeOfVisit =
    (booking['timeOfVisit'] ?? booking['visitTimeSlot1'] ?? '').toString();

    if (visitDate == null) {
      return timeOfVisit.trim().isEmpty
          ? 'Next visit: Not scheduled'
          : 'Next visit: $timeOfVisit';
    }

    final weekday = _weekdayName(visitDate.weekday);
    final dateText =
        '$weekday, ${visitDate.day} ${_monthName(visitDate.month)}';

    if (timeOfVisit.trim().isEmpty) {
      return 'Next visit: $dateText';
    }

    return 'Next visit: $dateText, $timeOfVisit';
  }

  String _weekdayName(int weekday) {
    switch (weekday) {
      case 1:
        return 'Monday';
      case 2:
        return 'Tuesday';
      case 3:
        return 'Wednesday';
      case 4:
        return 'Thursday';
      case 5:
        return 'Friday';
      case 6:
        return 'Saturday';
      case 7:
        return 'Sunday';
      default:
        return '';
    }
  }

  String _monthName(int month) {
    switch (month) {
      case 1:
        return 'Jan';
      case 2:
        return 'Feb';
      case 3:
        return 'Mar';
      case 4:
        return 'Apr';
      case 5:
        return 'May';
      case 6:
        return 'Jun';
      case 7:
        return 'Jul';
      case 8:
        return 'Aug';
      case 9:
        return 'Sep';
      case 10:
        return 'Oct';
      case 11:
        return 'Nov';
      case 12:
        return 'Dec';
      default:
        return '';
    }
  }

  String _getPlanName(Map<String, dynamic> booking) {
    return (booking['planName'] ??
        booking['subscriptionPlan'] ??
        booking['plan'] ??
        'Current Plan')
        .toString();
  }

  String _getAssignedMali(Map<String, dynamic> booking) {
    final mali =
    (booking['assignedMali'] ?? booking['maaliName'] ?? '').toString();

    if (mali.trim().isEmpty) return 'Not assigned';

    return mali;
  }

  String _getStatus(Map<String, dynamic> booking) {
    final status =
    (booking['status'] ?? booking['subscriptionStatus'] ?? 'Active')
        .toString()
        .trim();

    if (status.isEmpty) return 'Active';

    if (status.toLowerCase() == 'subscription booked') {
      return 'Active';
    }

    if (status.toLowerCase() == 'active cycle') {
      return 'Active';
    }

    return status;
  }

  BoxDecoration _softCardDecoration({
    double radius = 24,
    bool gradient = true,
  }) {
    return BoxDecoration(
      color: Colors.white.withOpacity(0.98),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: Colors.black.withOpacity(0.03),
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.08),
          blurRadius: 18,
          spreadRadius: -8,
          offset: const Offset(0, 10),
        ),
      ],
    );
  }

  BoxDecoration _softIconDecoration() {
    return BoxDecoration(
      color: AppColors.primaryColor.withOpacity(0.08),
      borderRadius: BorderRadius.circular(16),
    );
  }

  void _scrollToPlansSection() {
    final targetContext = _plansSectionKey.currentContext;

    if (targetContext == null) return;

    Scrollable.ensureVisible(
      targetContext,
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeInOutCubic,
      alignment: 0.08,
    );
  }

  void _openReferAndEarnScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ReferAndEarnScreen(),
      ),
    );
  }

  void _showLocationSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.25),
      builder: (_) {
        return DraggableScrollableSheet(
          initialChildSize: 0.84,
          minChildSize: 0.55,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(32),
              ),
              child: Container(
                color: Colors.white,
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 34),
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
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
                          child: Text(
                            'Search your location',
                            style: AppTextStyles.cardTitle.copyWith(
                              color: AppColors.primaryColor,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 22),

                    StatefulBuilder(
                      builder: (context, modalSetState) {
                        return Column(
                          children: [
                            LiquidGlassInstructionCard(
                              radius: 22,
                              minHeight: 56,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.search_rounded,
                                    color: Color(0xFFFFB72B),
                                    size: 24,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: TextField(
                                      controller: _locationSearchController,
                                      autofocus: false,
                                      textInputAction: TextInputAction.search,
                                      onChanged: (value) {
                                        _onLocationSearchChanged(value, modalSetState);
                                      },
                                      decoration: const InputDecoration(
                                        hintText: 'Search locality, sector, area',
                                        border: InputBorder.none,
                                        isDense: true,
                                        hintStyle: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                      style: AppTextStyles.body.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                  if (_isSearchingLocation)
                                    const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Color(0xFFFFB72B),
                                      ),
                                    )
                                  else if (_locationSearchController.text.isNotEmpty)
                                    GestureDetector(
                                      onTap: () {
                                        _locationSearchController.clear();
                                        modalSetState(() {
                                          _locationPredictions = [];
                                          _isSearchingLocation = false;
                                        });
                                      },
                                      child: const Icon(
                                        Icons.close_rounded,
                                        color: AppColors.textSecondary,
                                        size: 20,
                                      ),
                                    ),
                                ],
                              ),
                            ),

                            if (_locationPredictions.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              LiquidGlassInstructionCard(
                                radius: 24,
                                minHeight: 0,
                                padding: EdgeInsets.zero,
                                child: Column(
                                  children: List.generate(_locationPredictions.length, (index) {
                                    final prediction = _locationPredictions[index];
                                    final mainText = prediction['structured_formatting'] is Map
                                        ? (prediction['structured_formatting']['main_text'] ?? '')
                                        .toString()
                                        : prediction['description']?.toString() ?? '';

                                    final secondaryText =
                                    prediction['structured_formatting'] is Map
                                        ? (prediction['structured_formatting']
                                    ['secondary_text'] ??
                                        '')
                                        .toString()
                                        : '';

                                    return Column(
                                      children: [
                                        InkWell(
                                          onTap: () => _selectGooglePlace(prediction),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 14,
                                            ),
                                            child: Row(
                                              children: [
                                                Container(
                                                  width: 38,
                                                  height: 38,
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFFFB72B)
                                                        .withValues(alpha: 0.16),
                                                    borderRadius: BorderRadius.circular(14),
                                                  ),
                                                  child: const Icon(
                                                    Icons.location_on_rounded,
                                                    color: Color(0xFFFFB72B),
                                                    size: 22,
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        mainText.isEmpty
                                                            ? 'Selected location'
                                                            : mainText,
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                        style: AppTextStyles.body.copyWith(
                                                          fontWeight: FontWeight.w800,
                                                          color: AppColors.primaryColor,
                                                        ),
                                                      ),
                                                      if (secondaryText.isNotEmpty) ...[
                                                        const SizedBox(height: 3),
                                                        Text(
                                                          secondaryText,
                                                          maxLines: 2,
                                                          overflow: TextOverflow.ellipsis,
                                                          style: AppTextStyles.caption.copyWith(
                                                            color: AppColors.textSecondary,
                                                            fontWeight: FontWeight.w500,
                                                          ),
                                                        ),
                                                      ],
                                                    ],
                                                  ),
                                                ),
                                                const Icon(
                                                  Icons.chevron_right_rounded,
                                                  color: AppColors.primaryColor,
                                                  size: 24,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        if (index != _locationPredictions.length - 1)
                                          Container(
                                            height: 1,
                                            margin: const EdgeInsets.symmetric(horizontal: 18),
                                            color: AppColors.primaryColor.withValues(alpha: 0.08),
                                          ),
                                      ],
                                    );
                                  }),
                                ),
                              ),
                            ],
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 22),

                    LiquidGlassInstructionCard(
                      radius: 26,
                      minHeight: 0,
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          _buildLocationOptionRow(
                            icon: Icons.add_rounded,
                            title: 'Add address',
                            onTap: () {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Add address flow will open here.'),
                                ),
                              );
                            },
                          ),
                          Container(
                            height: 1,
                            margin: const EdgeInsets.symmetric(horizontal: 18),
                            color: AppColors.primaryColor.withValues(alpha: 0.08),
                          ),
                          _buildLocationOptionRow(
                            icon: Icons.my_location_rounded,
                            title: 'Use current location',
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ConfirmLocationMapScreen(
                                    userId: widget.userId,
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 28),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        'SAVED ADDRESSES',
                        style: AppTextStyles.caption.copyWith(
                          letterSpacing: 0.8,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    InkWell(
                      borderRadius: BorderRadius.circular(26),
                      onTap: () => Navigator.pop(context),
                      child: LiquidGlassInstructionCard(
                        radius: 26,
                        minHeight: 0,
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 54,
                              height: 54,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFB72B)
                                    .withValues(alpha: 0.18),
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
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Wrap(
                                    spacing: 10,
                                    runSpacing: 8,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    children: [
                                      Text(
                                        widget.locationTitle.isEmpty
                                            ? 'Home'
                                            : widget.locationTitle,
                                        style: AppTextStyles.bodyLarge.copyWith(
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.primaryColor,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFDFF8E6),
                                          borderRadius: BorderRadius.circular(14),
                                        ),
                                        child: const Text(
                                          'Currently selected',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF00875A),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    widget.locationLine.isEmpty
                                        ? 'Detected location'
                                        : widget.locationLine,
                                    style: AppTextStyles.body.copyWith(
                                      height: 1.4,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  GestureDetector(
                                    onTap: () {
                                      Navigator.pop(context);
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => ConfirmLocationMapScreen(
                                            userId: widget.userId,
                                          ),
                                        ),
                                      );
                                    },
                                    child: const Text(
                                      'EDIT ADDRESS',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFFFFB72B),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildLocationOptionRow({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFFFFB72B).withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                icon,
                color: const Color(0xFFFFB72B),
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: AppTextStyles.bodyLarge.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryColor,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.primaryColor,
              size: 28,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openManageBooking() async {
    Map<String, dynamic>? booking = _activeBooking;

    if (booking == null) {
      await _fetchActiveSubscription();
      booking = _activeBooking;
    }

    if (!mounted) return;

    if (booking == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No active subscription found.'),
        ),
      );
      return;
    }

    final normalizedBooking = _normalizeBookingForSubscriptionDetails(booking);

    final resolvedUserId =
    _resolvedUserId.isNotEmpty ? _resolvedUserId : widget.userId;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SubscriptionDetailsScreen(
          booking: normalizedBooking,
          userId: resolvedUserId,
          userName: (normalizedBooking['Full_Name'] ??
              normalizedBooking['userName'] ??
              normalizedBooking['customerName'] ??
              '')
              .toString(),
          profilePhotoUrl: (normalizedBooking['profilePhotoUrl'] ?? '').toString(),
          cartItems: _cartItems,
          nextEligibleBookingDate: _getNextFutureBookedDate(normalizedBooking),
          nextFutureDate: _getNextFutureBookedDate(normalizedBooking),
          timeRemaining: '',
          isWithinCutoff: true,
          fetchCatalogUrl:
          'https://18hkwgpuo1.execute-api.ap-south-1.amazonaws.com/zohoInventoryFetch',
          onCartUpdated: _updateCartItems,
          onRefreshRequested: () async {
            await _fetchActiveSubscription();
          },
          onSkipWeek: ({
            required Map<String, dynamic> booking,
            required String dueDate,
          }) async {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Skip week action is not connected here yet.'),
              ),
            );
          },
          canModifyVisit: _canModifyVisit,
          getVisitModificationCutoffText: _getVisitModificationCutoffText,
          getCutoffDateString: _getCutoffDateString,
        ),
      ),
    ).then((result) async {
      if (widget.isServiceAvailable) {
        await _fetchActiveSubscription();
      }

      if (!mounted) return;

      if (result == true) {
        setState(() {});
      }
    });
  }

  Future<void> _openExpertVisitDetails() async {
    Map<String, dynamic>? booking = _pendingExpertVisit;

    if (booking == null) {
      await _fetchActiveSubscription();
      booking = _pendingExpertVisit;
    }

    if (!mounted) return;

    if (booking == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No expert visit found.'),
        ),
      );
      return;
    }

    final resolvedUserId =
    _resolvedUserId.isNotEmpty ? _resolvedUserId : widget.userId;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ExpertVisitDetailsScreen(
          booking: booking!,
          userId: resolvedUserId,
          onRefreshRequested: () async {
            await _fetchActiveSubscription();
          },
        ),
      ),
    ).then((_) async {
      if (widget.isServiceAvailable) {
        await _fetchActiveSubscription();
      }
    });
  }

  Map<String, dynamic> _normalizeBookingForSubscriptionDetails(
      Map<String, dynamic> booking,
      ) {
    final normalized = Map<String, dynamic>.from(booking);

    if (booking['allScheduledVisits'] is List) {
      normalized['allScheduledVisits'] = booking['allScheduledVisits'];
    }

    if (booking['rawZohoBookings'] is List) {
      normalized['rawZohoBookings'] = booking['rawZohoBookings'];
    }

    final dueDate =
    (booking['dueDate'] ?? booking['date'] ?? booking['dateOfVisit'] ?? '')
        .toString()
        .trim();

    final visitTimeSlot = (booking['visitTimeSlot1'] ??
        booking['timeOfVisit'] ??
        booking['timeSlot'] ??
        '')
        .toString()
        .trim();

    final bookedDates = booking['bookedDates'];

    if (bookedDates is! List || bookedDates.isEmpty) {
      if (dueDate.isNotEmpty) {
        normalized['bookedDates'] = [dueDate];
      } else {
        normalized['bookedDates'] = <String>[];
      }
    } else {
      normalized['bookedDates'] = bookedDates
          .map((e) => e.toString())
          .where((e) => e.trim().isNotEmpty)
          .toList();
    }

    final dayTimeSlots = booking['dayTimeSlots'];

    if (dayTimeSlots is! List || dayTimeSlots.isEmpty) {
      normalized['dayTimeSlots'] = [
        {
          'timeSlot': visitTimeSlot.isNotEmpty ? visitTimeSlot : 'N/A',
        }
      ];
    }

    normalized['planName'] = (booking['planName'] ??
        booking['subscriptionPlan'] ??
        booking['plan'] ??
        'Current Plan')
        .toString();

    normalized['assignedMali'] = (booking['assignedMali'] ??
        booking['maaliName'] ??
        booking['assignedMaali'] ??
        'Not assigned')
        .toString();

    normalized['subscriptionStatus'] = _getStatus(booking);

    normalized['bookingID'] = (booking['bookingID'] ??
        booking['bookingId'] ??
        booking['id'] ??
        booking['visitID'] ??
        '')
        .toString();

    normalized['bookingType'] =
        (booking['bookingType'] ?? 'monthlySubscription').toString();

    return normalized;
  }

  void _handleRescheduleTap() {
    if (hasActivePlan && _activeBooking != null) {
      _openManageBooking();
      return;
    }

    if (hasPendingExpertVisit && _pendingExpertVisit != null) {
      _openExpertVisitDetails();
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('No booking found to reschedule.'),
      ),
    );
  }

  Future<void> _openWhatsAppSupport() async {
    const phoneNumber = '919217206273';
    final message = Uri.encodeComponent(
      'Hi GoldDust Gardening, I need help with my booking.',
    );

    final whatsappUri = Uri.parse(
      'whatsapp://send?phone=$phoneNumber&text=$message',
    );

    final webWhatsappUri = Uri.parse(
      'https://wa.me/$phoneNumber?text=$message',
    );

    try {
      final opened = await launchUrl(
        whatsappUri,
        mode: LaunchMode.externalApplication,
      );

      if (!opened) {
        await launchUrl(
          webWhatsappUri,
          mode: LaunchMode.externalApplication,
        );
      }
    } catch (_) {
      final openedWeb = await launchUrl(
        webWhatsappUri,
        mode: LaunchMode.externalApplication,
      );

      if (!openedWeb && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to open WhatsApp right now.'),
          ),
        );
      }
    }
  }

  Future<void> _handleRefresh() async {
    if (widget.isServiceAvailable) {
      await _fetchActiveSubscription();
    }
  }

  String _getExpertVisitCardTitle(String status) {
    final normalized = status.trim().toLowerCase();

    if (normalized == 'completed' ||
        normalized == 'visit completed' ||
        normalized == 'expert visit completed') {
      return 'Your expert visit is completed';
    }

    if (normalized == 'recommendation submitted' ||
        normalized == 'expert recommendation submitted' ||
        normalized == 'recommendation ready' ||
        normalized == 'plan recommended') {
      return 'Expert recommendation is ready';
    }

    if (normalized == 'slots provided' ||
        normalized == 'expert slots provided' ||
        normalized == 'slot provided') {
      return 'Expert slots are available';
    }

    if (normalized == 'rescheduled') {
      return 'Your expert visit is rescheduled';
    }

    return 'Your expert visit is scheduled';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      extendBody: true,
      body: Stack(
        children: [
          SafeArea(
            child: RefreshIndicator(
              color: AppColors.primaryColor,
              onRefresh: _handleRefresh,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Column(
                      children: [
                        _buildTopBar(),
                        const SizedBox(height: 12),
                        _buildHeroBanner(),
                        const SizedBox(height: 18),

                        if (widget.isServiceAvailable &&
                            _isFetchingSubscription &&
                            _activeBooking == null &&
                            _pendingExpertVisit == null) ...[
                          _buildSubscriptionLoadingCard(),
                          const SizedBox(height: 18),
                        ],

                        if (widget.isServiceAvailable &&
                            hasActivePlan &&
                            _activeBooking != null) ...[
                          _buildCurrentSubscriptionCard(_activeBooking!),
                          const SizedBox(height: 18),
                        ],

                        if (widget.isServiceAvailable &&
                            !hasActivePlan &&
                            hasPendingExpertVisit &&
                            _pendingExpertVisit != null) ...[
                          _buildExpertVisitBookedCard(_pendingExpertVisit!),
                          const SizedBox(height: 18),
                        ],

                        if (widget.isServiceAvailable) ...[
                          if (!_isFetchingSubscription) ...[
                            _buildQuickActionsGrid(),
                            const SizedBox(height: 24),
                          ],

                          _buildSectionTitle('Our Services'),
                          const SizedBox(height: 16),
                          _buildServiceGrid(),

                          const SizedBox(height: 28),
                          _buildSectionTitle('How it works?'),
                          const SizedBox(height: 8),
                          _buildSectionSubtitle(
                            'A simple 3-step process designed for busy homeowners.',
                          ),
                          const SizedBox(height: 14),
                          _buildHowItWorks(),

                          const SizedBox(height: 28),
                          if (!hasActivePlan && !hasPendingExpertVisit) ...[
                            Container(
                              key: _plansSectionKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildSectionTitle('Monthly Subscription Plans'),
                                  const SizedBox(height: 8),
                                  _buildSectionSubtitle(
                                    'Choose a plan and tap to view complete details.',
                                  ),
                                  const SizedBox(height: 14),
                                  _buildPlansSection(),
                                ],
                              ),
                            ),
                          ],

                          const SizedBox(height: 28),
                          _buildSectionTitle('See how we transform home gardens'),
                          const SizedBox(height: 14),
                          _buildTransformSection(),

                          const SizedBox(height: 18),
                          _buildPortraitTransformVideo(),

                          const SizedBox(height: 24),
                          _buildTrustStatsStrip(),

                          const SizedBox(height: 28),
                          _buildReadyToTransformCard(),

                          SizedBox(
                            height: MediaQuery.of(context).padding.bottom + 150,
                          ),
                        ] else ...[
                          const SizedBox(height: 40),
                          _buildLocationUnavailableCard(),
                          SizedBox(
                            height: MediaQuery.of(context).padding.bottom + 150,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          Positioned(
            left: 28,
            right: 28,
            bottom: MediaQuery.of(context).padding.bottom + 16,
            child: _buildBottomNavBar(),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 4),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: _showLocationSelector,
              child: Row(
                children: [
                  const Icon(
                    Icons.location_on_rounded,
                    size: 20,
                    color: AppColors.primaryColor,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                widget.locationTitle.isEmpty
                                    ? 'Your location'
                                    : widget.locationTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.bodyLarge.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 2),
                            const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: AppColors.textPrimary,
                              size: 20,
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.locationLine.isEmpty
                              ? 'Detected location'
                              : widget.locationLine,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.caption.copyWith(
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _openReferAndEarnScreen,
            child: _waterDropCard(
              radius: 21,
              child: const SizedBox(
                width: 42,
                height: 42,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(
                      Icons.card_giftcard_rounded,
                      color: AppColors.primaryColor,
                      size: 23,
                    ),
                    Positioned(
                      bottom: 2,
                      child: Text(
                        '₹100',
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _openProfileScreen,
            child: _waterDropCard(
              radius: 21,
              child: const SizedBox(
                width: 42,
                height: 42,
                child: Icon(
                  Icons.person_rounded,
                  color: AppColors.textPrimary,
                  size: 24,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroBanner() {
    final screenHeight = MediaQuery.of(context).size.height;
    final bannerHeight = screenHeight * 0.33;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Container(
        width: double.infinity,
        height: bannerHeight.clamp(250.0, 310.0),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(
              color: AppColors.cardShadow,
              blurRadius: 12,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                'assets/images/home/hero_garden_bg.webp',
                fit: BoxFit.cover,
                alignment: Alignment.centerRight,
                gaplessPlayback: true,
                filterQuality: FilterQuality.medium,
                errorBuilder: (_, __, ___) => Container(
                  color: AppColors.primaryColor,
                  child: const Center(
                    child: Icon(
                      Icons.image_outlined,
                      size: 36,
                      color: AppColors.white,
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      AppColors.primaryColor.withOpacity(0.96),
                      AppColors.primaryColor.withOpacity(0.82),
                      AppColors.primaryColor.withOpacity(0.35),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.48, 0.78, 1.0],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.white.withOpacity(0.16),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: AppColors.white.withOpacity(0.14),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.verified_rounded,
                          size: 13,
                          color: AppColors.white,
                        ),
                        SizedBox(width: 5),
                        Text(
                          "CURRENTLY SERVING NOIDA",
                          style: TextStyle(
                            fontSize: 9.5,
                            letterSpacing: 1.1,
                            fontWeight: FontWeight.w700,
                            color: AppColors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: 220,
                    child: Text(
                      'Professional Care\nfor Your Garden',
                      style: AppTextStyles.heroTitle.copyWith(
                        height: 1.12,
                        color: AppColors.white,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const SizedBox(
                    width: 235,
                    child: Text(
                      'Trained maali visits, pruning, repotting and seasonal plant care.',
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.4,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFFE7F2EA),
                      ),
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: 210,
                    height: 42,
                    child: ElevatedButton(
                      onPressed: hasActivePlan || hasPendingExpertVisit
                          ? _handleRescheduleTap
                          : () {
                        Get.toNamed(
                          AppRoutes.scheduleBooking,
                          arguments: _resolvedUserId.isNotEmpty
                              ? _resolvedUserId
                              : widget.userId,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF063F20),
                        foregroundColor: AppColors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(22),
                        ),
                      ),
                      child: Text(
                        hasActivePlan || hasPendingExpertVisit
                            ? 'View Your Booking'
                            : 'Book Free Consultation',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _scrollToPlansSection,
                    child: const SizedBox(
                      width: 210,
                      child: Center(
                        child: Text(
                          'Explore Plans',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.white,
                            decoration: TextDecoration.underline,
                            decorationColor: AppColors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubscriptionLoadingCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: _softCardDecoration(radius: 28),
        child: const Row(
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppColors.primaryColor,
              ),
            ),
            SizedBox(width: 14),
            Text(
              'Checking your booking...',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentSubscriptionCard(Map<String, dynamic> booking) {
    final planName = _getPlanName(booking);
    final assignedMali = _getAssignedMali(booking);
    final status = _getStatus(booking);
    final nextVisitText = _formatNextVisit(booking);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: LiquidGlassInstructionCard(
        radius: 24,
        padding: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Expanded(
                    child: Text(
                      'CURRENT SUBSCRIPTION',
                      style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 1.3,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF6B756A),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDFF8E6),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFFB7EBC8),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            color: Color(0xFF0BAE5B),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          status.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF00875A),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              Text(
                planName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.cardTitle.copyWith(
                  height: 1.1,
                  color: AppColors.primaryColor,
                  letterSpacing: -0.3,
                ),
              ),

              const SizedBox(height: 18),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.white.withValues(alpha: 0.74),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.primaryColor.withValues(alpha: 0.08),
                  ),
                ),
                child: Column(
                  children: [
                    _buildSubscriptionInfoRow(
                      icon: Icons.calendar_month_rounded,
                      label: 'Next visit',
                      text: nextVisitText.replaceFirst(
                        'Next visit: ',
                        '',
                      ),
                    ),

                    const SizedBox(height: 14),

                    Container(
                      height: 1,
                      color: const Color(0xFFE6EFE8),
                    ),

                    const SizedBox(height: 14),

                    _buildSubscriptionInfoRow(
                      icon: Icons.person_pin_circle_rounded,
                      label: 'Assigned maali',
                      text: assignedMali,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: _orangePillButton(
                      text: 'Manage Booking',
                      onTap: _openManageBooking,
                    ),
                  ),

                  const SizedBox(width: 10),

                  GestureDetector(
                    onTap: _handleRescheduleTap,
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFB72B),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFFB72B)
                                .withValues(alpha: 0.45),
                            blurRadius: 14,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.edit_calendar_rounded,
                        size: 20,
                        color: Colors.black,
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
  }

  Widget _orangePillButton({
    required String text,
    required VoidCallback onTap,
    IconData? icon,
  }) {
    return SizedBox(
      height: 42,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFFB72B),
          foregroundColor: Colors.black,
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              style: AppTextStyles.body.copyWith(
                fontWeight: FontWeight.w800,
                color: Colors.black,
              ),
            ),
            if (icon != null) ...[
              const SizedBox(width: 8),
              Icon(icon, size: 18, color: Colors.black),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildExpertVisitBookedCard(Map<String, dynamic> booking) {
    final visitDate =
    (booking['dateOfVisit'] ?? booking['dueDate'] ?? booking['date'] ?? '')
        .toString()
        .trim();

    final visitTime = (booking['timeOfVisit'] ??
        booking['visitTimeSlot1'] ??
        booking['timeSlot'] ??
        '')
        .toString()
        .trim();

    final status = (booking['status'] ?? 'Booked').toString().trim();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        width: double.infinity,
        decoration: _softCardDecoration(radius: 28),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Expanded(
                    child: Text(
                      'EXPERT VISIT BOOKED',
                      style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 1.3,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF6B756A),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDFF8E6),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFFB7EBC8),
                      ),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF00875A),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                _getExpertVisitCardTitle(status),
                style: AppTextStyles.cardTitle.copyWith(
                  height: 1.15,
                  color: AppColors.primaryColor,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.white.withOpacity(0.74),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.primaryColor.withOpacity(0.08),
                  ),
                ),
                child: Column(
                  children: [
                    _buildSubscriptionInfoRow(
                      icon: Icons.calendar_month_rounded,
                      label: 'Visit date',
                      text: visitDate.isEmpty ? 'Not scheduled' : visitDate,
                    ),
                    const SizedBox(height: 14),
                    Container(
                      height: 1,
                      color: const Color(0xFFE6EFE8),
                    ),
                    const SizedBox(height: 14),
                    _buildSubscriptionInfoRow(
                      icon: Icons.access_time_rounded,
                      label: 'Visit time',
                      text: visitTime.isEmpty ? 'Not available' : visitTime,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 42,
                      child: ElevatedButton.icon(
                        onPressed: _openExpertVisitDetails,
                        icon: const Icon(
                          Icons.visibility_rounded,
                          size: 16,
                        ),
                        label: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'View Details',
                            maxLines: 1,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryColor,
                          foregroundColor: AppColors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(21),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SizedBox(
                      height: 42,
                      child: OutlinedButton.icon(
                        onPressed: _openWhatsAppSupport,
                        icon: const Icon(
                          Icons.support_agent_rounded,
                          size: 16,
                        ),
                        label: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'Support',
                            maxLines: 1,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primaryColor,
                          side: BorderSide(
                            color: AppColors.primaryColor.withOpacity(0.20),
                          ),
                          backgroundColor: AppColors.white.withOpacity(0.70),
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(21),
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
  }

  Widget _buildSubscriptionInfoRow({
    required IconData icon,
    required String label,
    required String text,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: const Color(0xFFFFB72B).withOpacity(0.18),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            size: 18,
            color: const Color(0xFFFFB72B),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTextStyles.caption.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                text.trim().isEmpty ? 'Not available' : text,
                style: AppTextStyles.body.copyWith(
                  height: 1.25,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionsGrid() {
    final List<Widget> cards = [];

    if (!hasActivePlan && !hasPendingExpertVisit) {
      cards.addAll([
        _buildQuickActionCard(
          icon: Icons.calendar_month_outlined,
          title: 'Book a Visit',
          onTap: () {
            Get.toNamed(
              AppRoutes.scheduleBooking,
              arguments:
              _resolvedUserId.isNotEmpty ? _resolvedUserId : widget.userId,
            );
          },
        ),
      ]);
    }

    cards.addAll([
      _buildQuickActionCard(
        icon: Icons.history_outlined,
        title: 'Reschedule',
        onTap: _handleRescheduleTap,
      ),
      _buildQuickActionCard(
        icon: Icons.support_agent_outlined,
        title: 'Support',
        onTap: _openWhatsAppSupport,
      ),
    ]);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 2.15,
        children: cards,
      ),
    );
  }

  Widget _buildQuickActionCard({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: LiquidGlassInstructionCard(
        radius: 22,
        minHeight: 74,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 24,
              color: const Color(0xFFFFB72B),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: AppTextStyles.chip.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.primaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationUnavailableCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: _softCardDecoration(radius: 24),
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: _softIconDecoration(),
              child: const Icon(
                Icons.location_off_outlined,
                size: 32,
                color: AppColors.primaryColor,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Currently not available in your location',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              widget.locationMessage.isEmpty
                  ? 'Our gardening service is currently available only in Noida.'
                  : widget.locationMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                height: 1.5,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'We currently serve selected areas in Noida. Please check back soon as we expand to more locations.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: _showLocationSelector,
              icon: const Icon(Icons.edit_location_alt_outlined),
              label: const Text('Change location'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryColor,
                side: const BorderSide(color: AppColors.primaryColor),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 13,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: AppTextStyles.sectionTitle.copyWith(
            fontWeight: FontWeight.w500,
            color: AppColors.primaryColor,
          ),
        ),
      ),
    );
  }

  Widget _buildSectionSubtitle(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(
        text,
        style: AppTextStyles.body.copyWith(
          height: 1.5,
          fontWeight: FontWeight.w400,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _buildServiceGrid() {
    final items = [
      {
        'title': 'Cutting & Pruning',
        'image': 'assets/images/services/golddust-cutting-pruning.webp',
      },
      {
        'title': 'Cleaning the Place',
        'image': 'assets/images/services/golddust-cleaning-balcony.webp',
      },
      {
        'title': 'Soil Loosening & Weeding',
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
        'title': 'Pest Management',
        'image': 'assets/images/services/golddust-pest-management.webp',
      },
      {
        'title': 'Leaf Cleaning',
        'image': 'assets/images/services/golddust-leaf-cleaning.webp',
      },
    ];

    return SizedBox(
      height: 210,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final item = items[index];

          return SizedBox(
            width: 165,
            child: LiquidGlassInstructionCard(
              radius: 26,
              minHeight: 0,
              padding: EdgeInsets.zero,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(26),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: SizedBox(
                        width: double.infinity,
                        child: Image.asset(
                          item['image']!,
                          fit: BoxFit.cover,
                          gaplessPlayback: true,
                          filterQuality: FilterQuality.medium,
                          errorBuilder: (_, __, ___) => Container(
                            color: const Color(0xFFEAF8EF),
                            child: const Center(
                              child: Icon(
                                Icons.image_outlined,
                                size: 38,
                                color: AppColors.primaryColor,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 58,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            item['title']!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              height: 1.25,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
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

  Widget _buildHowItWorks() {
    final steps = [
      {
        'step': '1',
        'title': 'Book a free expert visit',
        'desc': 'Tell us about your home garden, balcony, or terrace setup on WhatsApp.',
      },
      {
        'step': '2',
        'title': 'We assess your plants',
        'desc': 'Our expert evaluates sunlight, plant condition, maintenance needs, and treatment requirements.',
      },
      {
        'step': '3',
        'title': 'Start your care plan',
        'desc': 'Choose the plan that fits your space and schedule, and let us handle the maintenance.',
      },
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: steps.map((step) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: LiquidGlassInstructionCard(
              radius: 26,
              minHeight: 0,
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFB72B).withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        step['step']!,
                        style: const TextStyle(
                          color: Color(0xFFFFB72B),
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          step['title']!,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          step['desc']!,
                          style: const TextStyle(
                            fontSize: 13,
                            height: 1.45,
                            fontWeight: FontWeight.w400,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPlansSection() {
    final plans = [
      {
        'tag': 'Basic Care',
        'name': 'Bloom Plan',
        'price': '₹999',
        'subtitle': 'Basic care for small home gardens',
        'duration': '1 visit per week • 45 mins',
        'details': [
          'Perfect for small balconies and indoor plant setups',
          'Less than 10 pots',
          'Soil loosening and weeding',
          'Deadheading & removal of dry leaves',
          'Pruning, trimming & cutting',
          'Fertilisation & nourishment',
          'Watering',
          'Repotting & plant restructuring',
          'Leaf cleaning',
          'Pest & disease management',
          'Post-work clean-up and upkeep',
        ],
      },
      {
        'tag': 'Most Popular',
        'name': 'Evergreen Plan',
        'price': '₹1499',
        'subtitle': 'Extended care for larger balconies and terraces',
        'duration': '1 visit per week • 1 hr 15 mins',
        'details': [
          'Ideal for larger balconies, terraces, and plant collections',
          'Between 11 to 50 pots',
          'Soil loosening and weeding',
          'Deadheading & removal of dry leaves',
          'Pruning, trimming & cutting',
          'Fertilisation & nourishment',
          'Watering',
          'Repotting & plant restructuring',
          'Leaf cleaning',
          'Pest & disease management',
          'Post-work clean-up and upkeep',
          'Dedicated expert attention once a month',
        ],
      },
      {
        'tag': 'Premium Care',
        'name': 'Nurture Plan',
        'price': '₹2499',
        'subtitle': 'Advanced care for dense gardens',
        'duration': '1 visit per week • 2 hours',
        'details': [
          'Best for dense gardens and high-maintenance setups',
          '50+ pots or dense plant setups',
          'Deep pruning and structural maintenance',
          'Soil loosening and weeding',
          'Deadheading & removal of dry leaves',
          'Fertilisation & plant nourishment',
          'Watering & moisture balance management',
          'Leaf cleaning & shine maintenance',
          'Advanced pest & disease treatment',
          'Soil enrichment & conditioning',
          'Repotting & plant restructuring',
          'Detailed plant health monitoring',
          'Post-work clean-up and upkeep',
          'Dedicated expert attention on alternate visits',
        ],
      },
      {
        'tag': 'Flexible',
        'name': 'Custom Plan',
        'price': 'Custom',
        'subtitle': 'Tailored plan based on your garden needs',
        'duration': 'As per requirement',
        'details': [
          'Designed specifically for your garden size and needs',
          'Flexible number of visits per week',
          'Suitable for villas, large terraces, or special requirements',
          'Includes all services: pruning, fertilisation, pest control, etc.',
          'Priority expert support',
          'Customised plant care strategy',
        ],
      },
    ];

    return SizedBox(
      height: 268,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        scrollDirection: Axis.horizontal,
        itemCount: plans.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final plan = plans[index];

          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PlanDetailsPage(
                    plan: plan,
                    userId: _resolvedUserId.isNotEmpty ? _resolvedUserId : widget.userId,
                    isServiceAvailable: widget.isServiceAvailable,
                    hasActiveBooking: hasActivePlan || hasPendingExpertVisit,
                  ),
                ),
              );
            },
            child: SizedBox(
              width: 270,
              child: LiquidGlassInstructionCard(
                radius: 24,
                minHeight: 0,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFB72B),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Text(
                        plan['tag'] as String,
                        style: AppTextStyles.caption.copyWith(
                          fontWeight: FontWeight.w800,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    const SizedBox(height: 13),
                    Text(
                      plan['name'] as String,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.cardTitle.copyWith(
                        color: AppColors.primaryColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      plan['price'] as String,
                      style: AppTextStyles.cardTitle.copyWith(
                        height: 1,
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 9),
                    Text(
                      plan['subtitle'] as String,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.body.copyWith(
                        height: 1.35,
                        fontWeight: FontWeight.w400,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      plan['duration'] as String,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.small.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryColor,
                      ),
                    ),
                    const Spacer(),
                    SizedBox(
                      width: double.infinity,
                      child: _orangePillButton(
                        text: 'View Details',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PlanDetailsPage(
                                plan: plan,
                                userId: _resolvedUserId.isNotEmpty ? _resolvedUserId : widget.userId,
                                isServiceAvailable: widget.isServiceAvailable,
                                hasActiveBooking: hasActivePlan || hasPendingExpertVisit,
                              ),
                            ),
                          );
                        },
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

  Widget _buildTransformSection() {
    return SizedBox(
      height: 250,
      child: ListView.separated(
        controller: _transformScrollController,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: _transformItems.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final item = _transformItems[index];
          return _buildTransformImageCard(
            imagePath: item['image']!,
            caption: item['caption']!,
          );
        },
      ),
    );
  }
  Widget _buildPortraitTransformVideo() {
    return SizedBox(
      width: double.infinity,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(0),
        child: AspectRatio(
          aspectRatio: 9 / 16,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: _isTransformVideoReady
                    ? FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _transformVideoController.value.size.width,
                    height: _transformVideoController.value.size.height,
                    child: VideoPlayer(_transformVideoController),
                  ),
                )
                    : Container(
                  color: const Color(0xFFEAF8EF),
                  child: const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primaryColor,
                      strokeWidth: 2.5,
                    ),
                  ),
                ),
              ),

              if (_isTransformVideoReady)
                Positioned(
                  top: 12,
                  right: 12,
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        if (_transformVideoController.value.isPlaying) {
                          _transformVideoController.pause();
                        } else {
                          _transformVideoController.play();
                        }
                      });
                    },
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.35),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _transformVideoController.value.isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 23,
                      ),
                    ),
                  ),
                ),

              if (_isTransformVideoReady)
                Positioned(
                  top: 12,
                  left: 12,
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        final currentVolume =
                            _transformVideoController.value.volume;

                        if (currentVolume > 0) {
                          _transformVideoController.setVolume(0);
                        } else {
                          _transformVideoController.setVolume(1.0);
                        }
                      });
                    },
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.35),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _transformVideoController.value.volume > 0
                            ? Icons.volume_up_rounded
                            : Icons.volume_off_rounded,
                        color: Colors.white,
                        size: 21,
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

  Widget _buildTransformImageCard({
    required String imagePath,
    required String caption,
  }) {
    return Container(
      width: 290,
      clipBehavior: Clip.antiAlias,
      decoration: _softCardDecoration(radius: 28),
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              imagePath,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              filterQuality: FilterQuality.medium,
              errorBuilder: (_, __, ___) => Container(
                color: const Color(0xFFEAF8EF),
                child: const Center(
                  child: Icon(
                    Icons.image_outlined,
                    size: 44,
                    color: AppColors.primaryColor,
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
              padding: const EdgeInsets.fromLTRB(16, 36, 16, 16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Color(0xCC002A13),
                  ],
                ),
              ),
              child: Text(
                caption,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                  color: AppColors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrustStatsStrip() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: LiquidGlassInstructionCard(
        radius: 24,
        minHeight: 0,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
        child: Row(
          children: [
            Expanded(
              child: _buildTrustStatItem(
                icon: Icons.groups_rounded,
                title: '500+ Homes Served',
                subtitle: 'in Noida',
              ),
            ),
            Container(
              width: 1,
              height: 46,
              color: AppColors.primaryColor.withValues(alpha: 0.12),
            ),
            Expanded(
              child: _buildTrustStatItem(
                icon: Icons.verified_outlined,
                title: 'Verified Maalis',
                subtitle: 'Expertly Trained',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrustStatItem({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 28,
          color: const Color(0xFFFFB72B),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: AppColors.primaryColor,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w400,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildReadyToTransformCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: LiquidGlassInstructionCard(
        radius: 28,
        minHeight: 0,
        padding: const EdgeInsets.fromLTRB(22, 26, 22, 24),
        child: Column(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: const Color(0xFFFFB72B).withValues(alpha: 0.20),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.eco_rounded,
                size: 30,
                color: Color(0xFFFFB72B),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Ready to transform\nyour green space?',
              textAlign: TextAlign.center,
              style: AppTextStyles.heroTitle.copyWith(
                fontSize: 21,
                height: 1.15,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Our experts are ready to provide the botanical care your plants deserve.',
              textAlign: TextAlign.center,
              style: AppTextStyles.body.copyWith(
                height: 1.45,
                fontWeight: FontWeight.w400,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: _orangePillButton(
                text: hasActivePlan || hasPendingExpertVisit
                    ? 'View Your Booking'
                    : 'Book Free Consultation',
                icon: Icons.arrow_forward_rounded,
                onTap: hasActivePlan || hasPendingExpertVisit
                    ? _handleRescheduleTap
                    : () {
                  Get.toNamed(
                    AppRoutes.scheduleBooking,
                    arguments: _resolvedUserId.isNotEmpty
                        ? _resolvedUserId
                        : widget.userId,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
  Widget _buildBottomNavBar() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: 18,
          sigmaY: 18,
        ),
        child: Container(
          height: 62, // increased from 58 to avoid tiny overflow
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.55), // visible outline
              width: 1.1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 22,
                spreadRadius: -10,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildBottomNavItem(
                index: 0,
                icon: Icons.home_rounded,
                label: 'Home',
                onTap: () {},
              ),
              _buildBottomNavItem(
                index: 1,
                icon: Icons.calendar_month_rounded,
                label: 'Bookings',
                onTap: _openManageBooking,
              ),
              _buildBottomNavItem(
                index: 2,
                icon: Icons.support_agent_rounded,
                label: 'Support',
                onTap: _openWhatsAppSupport,
              ),
              _buildBottomNavItem(
                index: 3,
                icon: Icons.shopping_bag_rounded,
                label: 'Shop',
                onTap: _handleShopTap,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavItem({
    required int index,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final bool isActive = _selectedNavIndex == index;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        setState(() {
          _selectedNavIndex = index;
        });

        if (index != 0) {
          onTap();
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: isActive
              ? Colors.white.withValues(alpha: 0.24)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: isActive ? 23 : 21,
              color: isActive
                  ? const Color(0xFFFFB72B) // selected = orange
                  : AppColors.primaryColor.withValues(alpha: 0.68),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                height: 1.0,
                fontWeight: FontWeight.w800,
                color: isActive
                    ? const Color(0xFFFFB72B) // selected = orange
                    : AppColors.primaryColor.withValues(alpha: 0.68),
              ),
            ),
          ],
        ),
      ),
    );
  }

}