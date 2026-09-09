import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../app/routes.dart';

class DeepLinkService extends GetxService {
  DeepLinkService._();

  static final DeepLinkService instance = DeepLinkService._();

  static const String _allowedHost =
      'links.golddustgardening.com';

  final AppLinks _appLinks = AppLinks();

  StreamSubscription<Uri>? _subscription;

  Uri? _pendingUri;

  bool _sessionReady = false;
  bool _loggedIn = false;

  String _userId = '';

  bool _navigationReady = false;

  String? _lastHandledUrl;
  DateTime? _lastHandledAt;

  Future<void> initialize() async {
    debugPrint('🔗 DeepLinkService initializing');

    /*
     * Listen for links received while the application
     * is already running or in the background.
     */
    _subscription = _appLinks.uriLinkStream.listen(
      _receiveUri,
      onError: (Object error) {
        debugPrint(
          '❌ DeepLink stream error: $error',
        );
      },
    );

    /*
     * Handle a link that launched the application
     * from a completely terminated state.
     */
    try {
      final Uri? initialUri =
      await _appLinks.getInitialLink();

      if (initialUri != null) {
        debugPrint(
          '🔗 Initial deep link: $initialUri',
        );

        _receiveUri(initialUri);
      }
    } catch (error) {
      debugPrint(
        '❌ Unable to read initial deep link: $error',
      );
    }
  }

  /*
   * main.dart calls this after GetMaterialApp has
   * completed its first frame.
   */
  void markNavigationReady() {
    debugPrint(
      '🔗 Deep link navigation is ready',
    );

    _navigationReady = true;

    _processPendingUri();
  }

  /*
   * Splash/Login must call this once customer
   * authentication has been resolved.
   *
   * Example:
   *
   * DeepLinkService.instance.setSession(
   *   loggedIn: true,
   *   userId: '12345',
   * );
   */
  bool setSession({
    required bool loggedIn,
    String userId = '',
  }) {
    _sessionReady = true;
    _loggedIn = loggedIn;
    _userId = userId.trim();

    debugPrint(
      '🔗 Deep link session ready. '
          'loggedIn=$_loggedIn, userId=$_userId',
    );

    return _processPendingUri();
  }

  /*
   * Call this during logout.
   */
  void clearSession() {
    _sessionReady = true;
    _loggedIn = false;
    _userId = '';

    debugPrint(
      '🔗 Deep link session cleared',
    );
  }

  bool get hasPendingDeepLink =>
      _pendingUri != null;

  String? get pendingPath =>
      _pendingUri?.path;

  void _receiveUri(Uri uri) {
    debugPrint(
      '🔗 Deep link received: $uri',
    );

    if (!_isAllowedUri(uri)) {
      debugPrint(
        '⚠️ Rejected deep link: $uri',
      );

      return;
    }

    /*
     * app_links may expose the cold-start URL through
     * both the initial API and the stream.
     *
     * Prevent accidental double navigation.
     */
    final now = DateTime.now();
    final url = uri.toString();

    if (_lastHandledUrl == url &&
        _lastHandledAt != null &&
        now
            .difference(_lastHandledAt!)
            .inSeconds <
            2) {
      debugPrint(
        '🔗 Duplicate deep link ignored',
      );

      return;
    }

    _lastHandledUrl = url;
    _lastHandledAt = now;

    _pendingUri = uri;

    _processPendingUri();
  }

  bool _isAllowedUri(Uri uri) {
    if (uri.scheme.toLowerCase() != 'https') {
      return false;
    }

    if (uri.host.toLowerCase() !=
        _allowedHost) {
      return false;
    }

    return true;
  }

  bool _processPendingUri() {
    final uri = _pendingUri;

    if (uri == null) {
      return false;
    }

    if (!_navigationReady) {
      debugPrint('🔗 Waiting for navigation');
      return false;
    }

    if (!_sessionReady) {
      debugPrint('🔗 Waiting for session');
      return false;
    }

    final path = _normalizePath(uri.path);

    debugPrint(
      '🔗 Processing deep-link path: $path',
    );

    // Customer must log in first.
    if (!_loggedIn || _userId.isEmpty) {
      debugPrint(
        '🔗 Customer not logged in. Opening login.',
      );

      if (Get.currentRoute != AppRoutes.login) {
        Get.offAllNamed(
          AppRoutes.login,
          arguments: {
            'openedFromDeepLink': true,
          },
        );
      }

      // Keep _pendingUri.
      // It will continue after OTP login.
      return true;
    }

    switch (path) {
      case '/':
      case '/home':
        _pendingUri = null;

        Get.offAllNamed(
          AppRoutes.home,
          arguments: _homeArguments(),
        );

        return true;

      case '/my-visits':
        _pendingUri = null;

        Get.offAllNamed(
          AppRoutes.bookings,
          arguments: {
            'userId': _userId,
          },
        );

        return true;

    // We will activate these once their actual
    // Flutter screens are registered.
      case '/payment-history':
        _pendingUri = null;

        Get.offAllNamed(
          AppRoutes.paymentHistory,
          arguments: {
            'userId': _userId,
          },
        );

        return true;

      case '/shop':
      case '/feedback':
      case '/support':
        debugPrint(
          '⚠️ Deep-link screen is not registered yet: $path',
        );

        return false;

      default:
        debugPrint(
          '⚠️ Unsupported deep-link path: $path',
        );

        _pendingUri = null;

        return false;
    }
  }

  String _normalizePath(String path) {
    var value = path.trim();

    if (value.isEmpty) {
      return '/';
    }

    while (value.length > 1 &&
        value.endsWith('/')) {
      value =
          value.substring(0, value.length - 1);
    }

    return value.toLowerCase();
  }

  Map<String, dynamic> _homeArguments() {
    return {
      'userId': _userId,
      'isServiceAvailable': true,
      'locationTitle': 'Noida',
      'locationLine':
      'Service available in your area',
      'locationMessage':
      'Service available in your area',
    };
  }

  Future<void> disposeService() async {
    await _subscription?.cancel();
    _subscription = null;
  }
}