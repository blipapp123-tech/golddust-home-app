import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../app/app_constants.dart';
import '../app/app_text_styles.dart';
import '../widgets/liquid_glass_instruction_card.dart';

class ReferAndEarnScreen extends StatelessWidget {
  const ReferAndEarnScreen({super.key});

  static const Color _darkGreen = Color(0xFF063F20);
  static const Color _gold = Color(0xFFFFB72B);
  static const Color _softGreen = Color(0xFFEAF8EF);
  static const Color _softBg = Colors.white;

  Future<void> _shareInvite() async {
    await Share.share(
      'I’m using Gold Dust Gardening for professional home garden care. '
          'They are offering referral rewards: I can get 1 free plant on referral, '
          '1 free visit when the referral converts, and you can get 5 free plants. '
          'Contact Gold Dust support to claim the referral reward.',
    );
  }

  void _showSupportInfo(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.28),
      builder: (_) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 22),
          child: LiquidGlassInstructionCard(
            radius: 30,
            minHeight: 0,
            padding: EdgeInsets.zero,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: 18,
                  sigmaY: 18,
                ),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.84),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.65),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          color: _gold.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(
                          Icons.support_agent_rounded,
                          color: _darkGreen,
                          size: 32,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Contact Support',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.cardTitle.copyWith(
                          color: _darkGreen,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Please contact Gold Dust support after giving a referral. Our team will verify the referral and help you claim your reward.',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.body.copyWith(
                          height: 1.45,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _gold,
                            foregroundColor: Colors.black,
                            elevation: 0,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(23),
                            ),
                          ),
                          child: const Text(
                            'Okay',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _softBg,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(context),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(18, 10, 18, 120),
                    children: [
                      _buildHeroCard(context),
                      const SizedBox(height: 18),
                      _buildRewardSplitCard(),
                      const SizedBox(height: 18),
                      _buildHowItWorksCard(),
                      const SizedBox(height: 18),
                      _buildTermsCard(),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 18,
            right: 18,
            bottom: 18 + MediaQuery.of(context).padding.bottom,
            child: _buildBottomCta(),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 8),
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
              'Refer & Earn',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.cardTitle.copyWith(
                color: _darkGreen,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroCard(BuildContext context) {
    return LiquidGlassInstructionCard(
      radius: 30,
      minHeight: 0,
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: Stack(
          children: [
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      _darkGreen,
                      Color(0xFF0B5A2D),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              right: -28,
              top: -26,
              child: Container(
                width: 132,
                height: 132,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              left: -32,
              bottom: -34,
              child: Container(
                width: 118,
                height: 118,
                decoration: BoxDecoration(
                  color: _gold.withOpacity(0.13),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: _gold.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.12),
                      ),
                    ),
                    child: const Icon(
                      Icons.local_florist_rounded,
                      color: _gold,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Share Gold Dust\nwith your friends',
                    style: AppTextStyles.heroTitle.copyWith(
                      fontSize: 25,
                      height: 1.12,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Refer a friend to Gold Dust and contact support to claim your referral reward.',
                    style: AppTextStyles.body.copyWith(
                      height: 1.45,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFFE7F2EA),
                    ),
                  ),
                  const SizedBox(height: 22),
                  GestureDetector(
                    onTap: () => _showSupportInfo(context),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 15,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.13),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.18),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.support_agent_rounded,
                                size: 18,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Contact support to earn reward',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white.withOpacity(0.95),
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRewardSplitCard() {
    return LiquidGlassInstructionCard(
      radius: 28,
      minHeight: 0,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your Rewards',
            style: AppTextStyles.sectionTitle.copyWith(
              fontWeight: FontWeight.w500,
              color: _darkGreen,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _rewardTile(
                  icon: Icons.eco_rounded,
                  title: '1 Plant Free',
                  subtitle: 'when you refer a customer to Gold Dust',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _rewardTile(
                  icon: Icons.event_available_rounded,
                  title: '1 Visit Free',
                  subtitle: 'when your referral converts to a paid customer',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _softGreen,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: _darkGreen.withOpacity(0.08),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: _gold.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Icon(
                    Icons.card_giftcard_rounded,
                    color: _gold,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your friend gets 5 free plants',
                        style: AppTextStyles.bodyLarge.copyWith(
                          color: _darkGreen,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'A warm welcome gift when they join through your referral.',
                        style: AppTextStyles.caption.copyWith(
                          height: 1.35,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _rewardTile({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      height: 158,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.76),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: _darkGreen.withOpacity(0.07),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: _gold.withOpacity(0.16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              color: _gold,
              size: 21,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodyLarge.copyWith(
              fontSize: 14,
              height: 1.12,
              fontWeight: FontWeight.w900,
              color: _darkGreen,
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: Text(
              subtitle,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption.copyWith(
                fontSize: 11,
                height: 1.28,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHowItWorksCard() {
    return LiquidGlassInstructionCard(
      radius: 28,
      minHeight: 0,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'How it works',
            style: AppTextStyles.sectionTitle.copyWith(
              fontWeight: FontWeight.w500,
              color: _darkGreen,
            ),
          ),
          const SizedBox(height: 16),
          const _ReferStep(
            number: '1',
            title: 'Refer Gold Dust to a friend',
            subtitle: 'Share our service with friends, neighbours, and society groups.',
          ),
          const SizedBox(height: 14),
          const _ReferStep(
            number: '2',
            title: 'Ask them to mention your name',
            subtitle: 'Your friend gets 5 free plants after joining through your referral.',
          ),
          const SizedBox(height: 14),
          const _ReferStep(
            number: '3',
            title: 'Contact support to claim rewards',
            subtitle: 'Get 1 free plant on referral and 1 free visit once they convert.',
          ),
        ],
      ),
    );
  }

  Widget _buildTermsCard() {
    return LiquidGlassInstructionCard(
      radius: 26,
      minHeight: 0,
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: _gold,
            size: 21,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'To claim referral rewards, please contact Gold Dust support after referring a customer. Rewards are applicable after referral details are verified. Free visit reward is applicable only after the referred customer converts to a paid plan.',
              style: AppTextStyles.caption.copyWith(
                height: 1.45,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomCta() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.72),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: Colors.white.withOpacity(0.65),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 22,
                spreadRadius: -10,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _shareInvite,
              icon: const Icon(
                Icons.share_rounded,
                size: 18,
              ),
              label: const Text(
                'Share Referral Message',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _gold,
                foregroundColor: Colors.black,
                elevation: 0,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReferStep extends StatelessWidget {
  final String number;
  final String title;
  final String subtitle;

  const _ReferStep({
    required this.number,
    required this.title,
    required this.subtitle,
  });

  static const Color _darkGreen = Color(0xFF063F20);
  static const Color _gold = Color(0xFFFFB72B);

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: _gold.withOpacity(0.16),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: _gold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Text(
                  title,
                  style: AppTextStyles.bodyLarge.copyWith(
                    height: 1.25,
                    fontWeight: FontWeight.w800,
                    color: _darkGreen,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: AppTextStyles.caption.copyWith(
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}