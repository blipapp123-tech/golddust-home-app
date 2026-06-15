import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app/app_constants.dart';
import '../app/app_text_styles.dart';
import '../widgets/liquid_glass_instruction_card.dart';

class DeleteAccountScreen extends StatelessWidget {
  final String userId;
  final String phoneNumber;

  const DeleteAccountScreen({
    super.key,
    required this.userId,
    required this.phoneNumber,
  });

  static const Color _darkGreen = Color(0xFF063F20);
  static const Color _softBg = Color(0xFFF6F7FC);

  String _extractPhoneNumber(String raw) {
    final clean = raw.trim();

    if (clean.startsWith('otp')) {
      return clean.replaceFirst('otp', '');
    }

    final digitsOnly = clean.replaceAll(RegExp(r'[^0-9]'), '');

    if (digitsOnly.length >= 10) {
      return digitsOnly.substring(digitsOnly.length - 10);
    }

    return digitsOnly;
  }

  Future<void> _sendDeleteAccountEmail(BuildContext context) async {
    final phone = _extractPhoneNumber(phoneNumber);

    final uri = Uri(
      scheme: 'mailto',
      path: 'care@golddustgardening.com',
      queryParameters: {
        'subject': 'Account Deletion Request',
        'body': '''
Hi Gold Dust Gardening Team,

I want to request deletion of my Gold Dust Gardening mobile app account.

Registered Mobile Number: ${phone.isEmpty ? 'Please enter/verify manually' : phone}
User ID: $userId

Please delete my account and associated personal data from your database.

Thank you.
''',
      },
    );

    try {
      final opened = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!opened && context.mounted) {
        _showSnack(context);
      }
    } catch (e) {
      debugPrint('❌ Delete account email open error: $e');

      if (context.mounted) {
        _showSnack(context);
      }
    }
  }

  void _showSnack(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Unable to open email app. Please email care@golddustgardening.com directly.',
        ),
        backgroundColor: AppColors.primaryColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final phone = _extractPhoneNumber(phoneNumber);

    return Scaffold(
      backgroundColor: _softBg,
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LiquidGlassInstructionCard(
                    radius: 24,
                    minHeight: 0,
                    padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Delete Account',
                          style: AppTextStyles.heroTitle.copyWith(
                            fontSize: 30,
                            height: 1.05,
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Last updated: Recently',
                          style: AppTextStyles.body.copyWith(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  LiquidGlassInstructionCard(
                    radius: 24,
                    minHeight: 0,
                    padding: const EdgeInsets.fromLTRB(18, 22, 18, 22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'To delete your account, please submit your phone number associated with your Gold Dust Gardening mobile app account by emailing us at care@golddustgardening.com with your request for account deletion.',
                          style: AppTextStyles.body.copyWith(
                            fontSize: 15,
                            height: 1.6,
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'We will respond promptly. User data including name, phone number, and address will be deleted from our database, except records that we are legally required to retain such as invoices, payments, tax records, or service history required for business compliance.',
                          style: AppTextStyles.body.copyWith(
                            fontSize: 15,
                            height: 1.6,
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 22),

                        if (phone.isNotEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: Colors.black.withOpacity(0.06),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.phone_rounded,
                                  size: 20,
                                  color: AppColors.primaryColor,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    '+91 $phone',
                                    style: AppTextStyles.body.copyWith(
                                      fontSize: 14,
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        const SizedBox(height: 18),

                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton.icon(
                            onPressed: () => _sendDeleteAccountEmail(context),
                            icon: const Icon(
                              Icons.email_outlined,
                              size: 20,
                            ),
                            label: const Text(
                              'Email Deletion Request',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        Text(
                          'Email: care@golddustgardening.com',
                          style: AppTextStyles.body.copyWith(
                            fontSize: 13,
                            height: 1.5,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w700,
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
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        22,
        MediaQuery.of(context).padding.top + 12,
        22,
        20,
      ),
      decoration: const BoxDecoration(
        color: _darkGreen,
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const SizedBox(
              width: 38,
              height: 38,
              child: Icon(
                Icons.arrow_back_rounded,
                color: Colors.white,
                size: 25,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Delete Account',
            style: AppTextStyles.bodyLarge.copyWith(
              fontSize: 18,
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}