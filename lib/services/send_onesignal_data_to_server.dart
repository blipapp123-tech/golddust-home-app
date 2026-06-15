import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

Future<void> sendOneSignalDataToServer({
  required String userId,
  required String userName,
  required String? subscriptionId,
  required String? token,
}) async {
  final url = Uri.parse(
    'https://yrbsjfs97k.execute-api.ap-south-1.amazonaws.com/notificationOnesignal',
  );

  String platform = "unknown";
  if (Platform.isAndroid) {
    platform = "android";
  } else if (Platform.isIOS) {
    platform = "ios";
  }

  final payload = {
    "userId": userId,
    "userName": userName,
    "subscriptionId": subscriptionId ?? "",
    "token": token ?? "",
    "platform": platform,
  };

  print("📤 Sending OneSignal Data to API:");
  print(payload);

  try {
    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(payload),
    );

    print("📡 API Response Status: ${response.statusCode}");
    print("📡 API Response Body: ${response.body}");

    if (response.statusCode == 200) {
      print("✅ OneSignal data sent successfully");
    } else {
      print("❌ Failed to send OneSignal data");
    }
  } catch (e) {
    print("❌ Error sending OneSignal data: $e");
  }
}