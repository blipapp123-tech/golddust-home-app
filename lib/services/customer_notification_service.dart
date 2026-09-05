import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../firebase_options.dart';
import '../views/visit_feedback_screen.dart';


@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(
    RemoteMessage message,
    ) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  debugPrint(
    '📩 Background FCM message: ${message.messageId}',
  );
}


class CustomerNotificationService {
  CustomerNotificationService._();

  static final CustomerNotificationService instance =
  CustomerNotificationService._();

  static const String _registerTokenUrl =
      'https://ap387u8mi5.execute-api.ap-south-1.amazonaws.com/default/registerCustomerPushToken';

  static const String _deviceIdKey =
      'customer_push_device_id';

  String _registeredUserId = '';
  String _deviceId = '';
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    final messaging =
        FirebaseMessaging.instance;

    final settings =
    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    debugPrint(
      '🔔 Notification permission: '
          '${settings.authorizationStatus}',
    );

    FirebaseMessaging.onMessage.listen(
      _handleForegroundMessage,
    );

    FirebaseMessaging.onMessageOpenedApp.listen(
      _handleNotificationTap,
    );

    final initialMessage =
    await messaging.getInitialMessage();

    if (initialMessage != null) {
      Future.delayed(
        const Duration(
          milliseconds: 600,
        ),
            () {
          _handleNotificationTap(
            initialMessage,
          );
        },
      );
    }

    messaging.onTokenRefresh.listen(
          (token) async {
        if (_registeredUserId.isEmpty) {
          return;
        }

        await _sendToken(
          userId:
          _registeredUserId,
          token:
          token,
        );
      },
    );
  }

  Future<void> registerForUser(
      String userId,
      ) async {
    final cleanUserId =
    userId.trim();

    if (cleanUserId.isEmpty) {
      return;
    }

    _registeredUserId =
        cleanUserId;

    final token =
    await FirebaseMessaging
        .instance
        .getToken();

    if (token == null ||
        token.trim().isEmpty) {
      debugPrint(
        '⚠️ FCM token not available yet',
      );
      return;
    }

    await _sendToken(
      userId:
      cleanUserId,
      token:
      token,
    );
  }

  Future<void> _sendToken({
    required String userId,
    required String token,
  }) async {
    if (_registerTokenUrl.startsWith(
      'PASTE_',
    ) ||
        _registerTokenUrl
            .trim()
            .isEmpty) {
      debugPrint(
        '⚠️ registerCustomerPushToken URL is not configured',
      );
      return;
    }

    _deviceId =
    await _getOrCreateDeviceId();

    final platform =
    kIsWeb
        ? 'web'
        : Platform.isAndroid
        ? 'android'
        : Platform.isIOS
        ? 'ios'
        : 'other';

    final payload = {
      'userID':
      userId,
      'deviceId':
      _deviceId,
      'fcmToken':
      token,
      'platform':
      platform,
    };

    final response =
    await http.post(
      Uri.parse(
        _registerTokenUrl,
      ),
      headers: const {
        'Content-Type':
        'application/json',
      },
      body: jsonEncode(
        payload,
      ),
    );

    debugPrint(
      '🔔 Push token registration '
          'status=${response.statusCode}',
    );
  }

  Future<String> _getOrCreateDeviceId() async {
    if (_deviceId.isNotEmpty) {
      return _deviceId;
    }

    final prefs =
    await SharedPreferences.getInstance();

    final existing =
    prefs.getString(
      _deviceIdKey,
    );

    if (existing != null &&
        existing.trim().isNotEmpty) {
      _deviceId =
          existing.trim();

      return _deviceId;
    }

    final random =
    Random.secure();

    _deviceId =
    'DEV_${DateTime.now().microsecondsSinceEpoch}_'
        '${random.nextInt(999999)}';

    await prefs.setString(
      _deviceIdKey,
      _deviceId,
    );

    return _deviceId;
  }

  void _handleForegroundMessage(
      RemoteMessage message,
      ) {
    final data =
        message.data;

    if (data['type'] !=
        'visit_feedback') {
      return;
    }

    final maaliName =
    (data['maaliName'] ?? '')
        .toString();

    Get.snackbar(
      'Your gardening visit is complete 🌿',
      maaliName.trim().isEmpty
          ? 'How was your visit? Tap to share feedback.'
          : 'How was your visit with $maaliName? Tap to share feedback.',
      snackPosition:
      SnackPosition.TOP,
      duration:
      const Duration(
        seconds: 8,
      ),
      margin:
      const EdgeInsets.all(
        14,
      ),
      mainButton:
      TextButton(
        onPressed: () {
          _openFeedback(
            data,
          );
        },
        child:
        const Text(
          'RATE',
          style:
          TextStyle(
            fontWeight:
            FontWeight.w900,
          ),
        ),
      ),
    );
  }

  void _handleNotificationTap(
      RemoteMessage message,
      ) {
    final data =
        message.data;

    if (data['type'] ==
        'visit_feedback') {
      _openFeedback(
        data,
      );
    }
  }

  void _openFeedback(
      Map<String, dynamic> data,
      ) {
    final userId =
    (data['userID'] ?? '')
        .toString()
        .trim();

    final dueDate =
    (data['dueDate'] ?? '')
        .toString()
        .trim();

    if (userId.isEmpty ||
        dueDate.isEmpty) {
      debugPrint(
        '⚠️ Feedback notification missing userID/dueDate',
      );
      return;
    }

    Get.to(
          () => VisitFeedbackScreen(
        userId:
        userId,
        dueDate:
        dueDate,
        maaliName:
        (data['maaliName'] ?? '')
            .toString(),
        taskId:
        (data['taskID'] ?? '')
            .toString(),
        bookingId:
        (data['bookingID'] ?? '')
            .toString(),
      ),
    );
  }
}
