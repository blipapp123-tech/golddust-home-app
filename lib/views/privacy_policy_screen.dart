import 'package:flutter/material.dart';

import '../app/app_constants.dart';
import '../app/app_text_styles.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  static const Color _darkGreen = Color(0xFF063F20);
  static const Color _softBg = Color(0xFFF6F7FC);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _softBg,
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
              children: const [
                _IntroCard(),
                SizedBox(height: 14),
                _PolicySection(
                  title: '1. Information We Collect',
                  bullets: [
                    'Account details such as name, phone number, email address, and login information.',
                    'Service details such as booking date, visit schedule, address or service location, plan details, and service preferences.',
                    'Order and payment-related information such as invoice details, payment status, transaction reference, and order history.',
                    'Communication details shared through customer support, WhatsApp, calls, emails, feedback, complaints, or app forms.',
                    'Device and app usage information such as app version, device type, crash logs, notification token, and basic analytics data.',
                    'Photos, plant images, garden images, or other media uploaded by you for plant care, diagnosis, support, or service quality purposes.',
                  ],
                ),
                _PolicySection(
                  title: '2. How We Use Your Information',
                  bullets: [
                    'To create and manage your Gold Dust Gardening account.',
                    'To schedule, reschedule, track, and complete gardening visits and expert visits.',
                    'To process orders, invoices, payments, refunds, replacements, and service requests.',
                    'To send booking updates, visit reminders, payment reminders, service notifications, offers, and support messages.',
                    'To improve our app, services, customer support, plant recommendations, and user experience.',
                    'To detect errors, prevent misuse, protect our users, and maintain service security.',
                    'To comply with applicable legal, regulatory, accounting, and tax requirements.',
                  ],
                ),
                _PolicySection(
                  title: '3. App Permissions',
                  bullets: [
                    'Camera and photo access may be used when you upload plant or garden photos for diagnosis, support, or service requests.',
                    'Notification permission may be used to send visit reminders, order updates, service alerts, payment reminders, and other important updates.',
                    'Location or address information may be used only when required for providing gardening services, delivery, visit planning, or customer support.',
                    'You can control app permissions from your device settings.',
                  ],
                ),
                _PolicySection(
                  title: '4. Payments',
                  bullets: [
                    'Payments may be processed through secure third-party payment service providers.',
                    'We do not store complete card, UPI PIN, bank password, or sensitive payment authentication details in the app.',
                    'We may store payment status, invoice number, transaction reference, amount, and related billing details for service, accounting, and support purposes.',
                  ],
                ),
                _PolicySection(
                  title: '5. Sharing of Information',
                  bullets: [
                    'We may share necessary information with our internal team, assigned maalis, supervisors, horticulturists, delivery partners, and support staff to provide services.',
                    'We may share limited information with trusted technology, hosting, CRM, analytics, notification, payment, and communication service providers.',
                    'We may disclose information if required by law, regulation, legal process, or to protect our rights, users, business, or services.',
                    'We do not sell your personal information to advertisers.',
                  ],
                ),
                _PolicySection(
                  title: '6. Data Retention',
                  bullets: [
                    'We retain your information as long as needed to provide services, maintain records, resolve disputes, prevent fraud, comply with legal obligations, and improve our services.',
                    'When information is no longer required, we may delete, anonymize, or securely archive it as permitted by law.',
                  ],
                ),
                _PolicySection(
                  title: '7. Account Deletion',
                  bullets: [
                    'You can initiate account deletion from the app through Profile / Settings > Delete account.',
                    'Once a valid deletion request is submitted, we will process it as per applicable law and our operational requirements.',
                    'Some information may be retained where required for legal, tax, fraud prevention, payment, dispute resolution, or compliance purposes.',
                  ],
                ),
                _PolicySection(
                  title: '8. Security',
                  bullets: [
                    'We use reasonable technical and organizational measures to protect your information.',
                    'However, no method of electronic storage or transmission over the internet is completely secure, and we cannot guarantee absolute security.',
                  ],
                ),
                _PolicySection(
                  title: '9. Children’s Privacy',
                  bullets: [
                    'Our services are not intended for children below the age required by applicable law.',
                    'If we become aware that personal information of a child has been collected without appropriate consent, we will take steps to delete it where required.',
                  ],
                ),
                _PolicySection(
                  title: '10. Your Choices',
                  bullets: [
                    'You may request access, correction, update, or deletion of your personal information by contacting us.',
                    'You may opt out of certain promotional communications where supported.',
                    'You may disable app permissions from your device settings, although some features may not work properly after disabling required permissions.',
                  ],
                ),
                _PolicySection(
                  title: '11. Changes to This Privacy Policy',
                  bullets: [
                    'We may update this Privacy Policy from time to time.',
                    'Any changes will be posted in the app, and the updated policy will apply from the date it is made available.',
                  ],
                ),
                _PolicySection(
                  title: '12. Contact Us',
                  bullets: [
                    'For privacy questions, support, or account deletion queries, contact us at care@golddustgardening.com.',
                    'Business name: Gold Dust Gardening.',
                  ],
                ),
              ],
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
        14,
        MediaQuery.of(context).padding.top + 10,
        18,
        20,
      ),
      decoration: const BoxDecoration(
        color: _darkGreen,
      ),
      child: Row(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: () => Navigator.pop(context),
            child: const SizedBox(
              width: 42,
              height: 42,
              child: Icon(
                Icons.arrow_back_rounded,
                color: Colors.white,
                size: 25,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Privacy Policy',
              style: AppTextStyles.bodyLarge.copyWith(
                fontSize: 18,
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IntroCard extends StatelessWidget {
  const _IntroCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Gold Dust Gardening Privacy Policy',
            style: AppTextStyles.bodyLarge.copyWith(
              fontSize: 17,
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Last updated: 19 June 2026',
            style: AppTextStyles.caption.copyWith(
              fontSize: 11,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Gold Dust Gardening respects your privacy. This Privacy Policy explains how we collect, use, store, share, and protect your information when you use our mobile app, website, gardening services, plant care services, product ordering, customer support, and related services.',
            style: AppTextStyles.body.copyWith(
              fontSize: 13,
              height: 1.5,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _PolicySection extends StatelessWidget {
  final String title;
  final List<String> bullets;

  const _PolicySection({
    required this.title,
    required this.bullets,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(18, 17, 18, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTextStyles.body.copyWith(
              fontSize: 14.5,
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          ...bullets.map(
                (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 5,
                    height: 5,
                    margin: const EdgeInsets.only(top: 8),
                    decoration: const BoxDecoration(
                      color: Color(0xFF063F20),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item,
                      style: AppTextStyles.body.copyWith(
                        fontSize: 12.8,
                        height: 1.45,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
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
}