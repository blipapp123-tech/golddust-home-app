import 'package:flutter/foundation.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

import 'send_onesignal_data_to_server.dart';

class OneSignalNotificationService {
  OneSignalNotificationService._();

  static const String oneSignalAppId = 'b8f1be42-70d4-4b16-bdcf-020c0389c051';

  static bool _initialized = false;

  static Future<void> initialize({
    required String userId,
    required String userName,
  }) async {
    if (userId.trim().isEmpty) {
      debugPrint('❌ OneSignal init skipped: userId empty');
      return;
    }

    try {
      if (!_initialized) {
        OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
        OneSignal.initialize(oneSignalAppId);
        _initialized = true;
      }

      // Link OneSignal user with your app userId
      OneSignal.login(userId);

      // Ask notification permission
      final permissionGranted =
      await OneSignal.Notifications.requestPermission(true);

      debugPrint('🔔 OneSignal permission granted: $permissionGranted');

      // Explicitly opt-in push subscription
      OneSignal.User.pushSubscription.optIn();

      // Wait for OneSignal to update subscription status
      await Future.delayed(const Duration(seconds: 5));

      await _sendSubscriptionIfReady(
        userId: userId,
        userName: userName,
        source: 'initial',
      );

      OneSignal.User.pushSubscription.addObserver((state) async {
        debugPrint('🔁 OneSignal subscription observer triggered');

        await _sendSubscriptionIfReady(
          userId: userId,
          userName: userName,
          source: 'observer',
        );
      });

      OneSignal.Notifications.addClickListener((event) {
        final data = event.notification.additionalData;
        debugPrint('🔔 Notification clicked: $data');
      });

      debugPrint('✅ OneSignal initialized successfully');
    } catch (e) {
      debugPrint('❌ OneSignal initialization failed: $e');
    }
  }

  static Future<void> _sendSubscriptionIfReady({
    required String userId,
    required String userName,
    required String source,
  }) async {
    final subscriptionId = OneSignal.User.pushSubscription.id;
    final token = OneSignal.User.pushSubscription.token;
    final optedIn = OneSignal.User.pushSubscription.optedIn;
    final permission = OneSignal.Notifications.permission;

    debugPrint('🔔 [$source] OneSignal permission: $permission');
    debugPrint('🔔 [$source] OneSignal optedIn: $optedIn');
    debugPrint('🔔 [$source] OneSignal subscriptionId: $subscriptionId');
    debugPrint('🔔 [$source] OneSignal token: $token');

    final isReady = permission == true &&
        optedIn == true &&
        subscriptionId != null &&
        subscriptionId.trim().isNotEmpty &&
        token != null &&
        token.trim().isNotEmpty &&
        !subscriptionId.startsWith('local-');

    if (!isReady) {
      debugPrint('⚠️ [$source] OneSignal subscription not ready. Not sending to AWS yet.');
      return;
    }

    await sendOneSignalDataToServer(
      userId: userId,
      userName: userName,
      subscriptionId: subscriptionId,
      token: token,
    );
  }
}