import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../app/app_constants.dart';
import '../app/app_text_styles.dart';
import '../app/routes.dart';
import '../widgets/liquid_glass_instruction_card.dart';

class PlanDetailsPage extends StatelessWidget {
  final Map<String, dynamic> plan;
  final String? userId;
  final bool isServiceAvailable;
  final bool hasActiveBooking;

  const PlanDetailsPage({
    super.key,
    required this.plan,
    this.userId,
    this.isServiceAvailable = true,
    this.hasActiveBooking = false,
  });

  static const Color _gold = Color(0xFFFFB72B);

  String _safeString(String key, {String fallback = ''}) {
    final value = plan[key];
    if (value == null) return fallback;

    final text = value.toString().trim();
    return text.isEmpty ? fallback : text;
  }

  List<String> _safeDetails() {
    final raw = plan['details'];

    if (raw is List) {
      return raw
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    return <String>[];
  }

  @override
  Widget build(BuildContext context) {
    final tag = _safeString('tag', fallback: 'Plan');
    final name = _safeString('name', fallback: 'Monthly Plan');
    final price = _safeString('price', fallback: 'Custom');
    final subtitle = _safeString(
      'subtitle',
      fallback: 'Professional maali service for your home garden.',
    );
    final duration = _safeString('duration', fallback: 'As per requirement');
    final details = _safeDetails();

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(context),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  18,
                  12,
                  18,
                  hasActiveBooking ? 28 : 100,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeroCard(
                      tag: tag,
                      name: name,
                      price: price,
                      subtitle: subtitle,
                      duration: duration,
                    ),
                    const SizedBox(height: 26),
                    Text(
                      'What’s included',
                      style: AppTextStyles.sectionTitle.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (details.isEmpty)
                      _buildEmptyDetailsCard()
                    else
                      ...details.map(_buildDetailItem),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),

      // Safety: If somehow this page is opened while user has active booking,
      // hide the Choose Plan button.
      bottomNavigationBar:
      hasActiveBooking ? null : _buildBottomButton(context, name),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
      child: Row(
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
              'Plan Details',
              textAlign: TextAlign.center,
              style: AppTextStyles.cardTitle.copyWith(
                color: AppColors.primaryColor,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 54),
        ],
      ),
    );
  }

  Widget _buildHeroCard({
    required String tag,
    required String name,
    required String price,
    required String subtitle,
    required String duration,
  }) {
    return SizedBox(
      width: double.infinity,
      child: LiquidGlassInstructionCard(
        radius: 28,
        minHeight: 0,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 11,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: _gold,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                tag,
                style: AppTextStyles.caption.copyWith(
                  fontWeight: FontWeight.w900,
                  color: Colors.black,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              name,
              style: AppTextStyles.heroTitle.copyWith(
                fontSize: 28,
                height: 1.1,
                fontWeight: FontWeight.w900,
                color: AppColors.primaryColor,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Flexible(
                  child: Text(
                    price,
                    style: AppTextStyles.heroTitle.copyWith(
                      fontSize: 34,
                      height: 1,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                if (price.toLowerCase() != 'custom') ...[
                  const SizedBox(width: 6),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '/month',
                      style: AppTextStyles.body.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Text(
              subtitle,
              style: AppTextStyles.body.copyWith(
                height: 1.45,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                color: _gold.withOpacity(0.18),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.schedule_rounded,
                    size: 20,
                    color: _gold,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      duration,
                      style: AppTextStyles.body.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryColor,
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

  Widget _buildDetailItem(String item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SizedBox(
        width: double.infinity,
        child: LiquidGlassInstructionCard(
          radius: 22,
          minHeight: 0,
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: _gold.withOpacity(0.18),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  size: 18,
                  color: _gold,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item,
                  style: AppTextStyles.body.copyWith(
                    height: 1.45,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyDetailsCard() {
    return SizedBox(
      width: double.infinity,
      child: LiquidGlassInstructionCard(
        radius: 22,
        minHeight: 0,
        padding: const EdgeInsets.all(16),
        child: Text(
          'Plan details will be shared after expert assessment.',
          style: AppTextStyles.body.copyWith(
            height: 1.45,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildBottomButton(BuildContext context, String name) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
        child: SizedBox(
          width: double.infinity,
          child: LiquidGlassInstructionCard(
            radius: 30,
            minHeight: 64,
            padding: const EdgeInsets.all(8),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () {
                  if (!isServiceAvailable) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Our service is currently available only in selected Noida locations.',
                        ),
                      ),
                    );
                    return;
                  }

                  Get.toNamed(
                    AppRoutes.scheduleBooking,
                    arguments: userId,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _gold,
                  foregroundColor: Colors.black,
                  elevation: 0,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(26),
                  ),
                ),
                child: Text(
                  'Choose $name',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}