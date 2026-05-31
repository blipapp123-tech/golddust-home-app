import 'package:flutter/material.dart';
import 'app_constants.dart';

class AppTextStyles {
  static const String fontFamily = 'Gotham';

  static const tiny = TextStyle(fontSize: 9, fontFamily: fontFamily);
  static const chip = TextStyle(fontSize: 10, fontFamily: fontFamily);
  static const caption = TextStyle(fontSize: 11, fontFamily: fontFamily);
  static const small = TextStyle(fontSize: 12, fontFamily: fontFamily);
  static const body = TextStyle(fontSize: 13, fontFamily: fontFamily);
  static const bodyLarge = TextStyle(fontSize: 14, fontFamily: fontFamily);

  static const title = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    fontFamily: fontFamily,
  );

  static const sectionTitle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    fontFamily: fontFamily,
  );

  static const cardTitle = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w700,
    color: AppColors.primaryColor,
    fontFamily: fontFamily,
  );

  static const heroTitle = TextStyle(
    fontSize: 21,
    height: 1.15,
    fontWeight: FontWeight.w700,
    color: AppColors.white,
    fontFamily: fontFamily,
  );

  static const price = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
    fontFamily: fontFamily,
  );
}