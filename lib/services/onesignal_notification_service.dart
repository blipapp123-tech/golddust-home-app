import 'package:flutter/foundation.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

import 'send_onesignal_data_to_server.dart';

class OneSignalNotificationService {
  OneSignalNotificationService._();

  static const String oneSignalAppId = 'YOUR_ONESIGNAL_APP_ID';

  static Future<void> initialize({
    required String userId,
    required String userName,
  }) async {
    try {
      OneSignal.Debug.setLogLevel(OSLogLevel.verbose);

      OneSignal.initialize(oneSignalAppId);

      // Links this device/subscription with your customer userID.
      // Very important for future targeting/debugging.
      OneSignal.login(userId);

      await OneSignal.Notifications.requestPermission(true);

      await Future.delayed(const Duration(seconds: 2));

      final subscriptionId = OneSignal.User.pushSubscription.id;
      final token = OneSignal.User.pushSubscription.token;

      debugPrint('🔔 OneSignal subscriptionId: $subscriptionId');
      debugPrint('🔔 OneSignal token: $token');

      await sendOneSignalDataToServer(
        userId: userId,
        userName: userName,
        subscriptionId: subscriptionId,
        token: token,
      );

      OneSignal.User.pushSubscription.addObserver((state) async {
        final newSubscriptionId = state.current.id;
        final newToken = state.current.token;

        debugPrint('🔁 OneSignal subscription changed: $newSubscriptionId');
        debugPrint('🔁 OneSignal token changed: $newToken');

        await sendOneSignalDataToServer(
          userId: userId,
          userName: userName,
          subscriptionId: newSubscriptionId,
          token: newToken,
        );
      });

      OneSignal.Notifications.addClickListener((event) {
        final data = event.notification.additionalData;
        debugPrint('🔔 Notification clicked: $data');

        // Later we can navigate based on:
        // data?['targetScreen']
        // data?['notificationType']
      });
    } catch (e) {
      debugPrint('❌ OneSignal initialization failed: $e');
    }
  }
}