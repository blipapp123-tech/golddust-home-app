import 'package:flutter/material.dart';

import '../app/app_constants.dart';
import '../app/app_text_styles.dart';

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

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
                _TermsSection(
                  title: '1. Acceptance of Terms',
                  bullets: [
                    'By using the Gold Dust Gardening app, website, services, products, or customer support, you agree to these Terms of Service.',
                    'If you do not agree with these terms, you should not use our app or services.',
                    'These terms apply to all users, customers, subscribers, and visitors using Gold Dust Gardening services.',
                  ],
                ),
                _TermsSection(
                  title: '2. Our Services',
                  bullets: [
                    'Gold Dust Gardening provides gardening services, plant care services, expert visits, plant and garden-related products, recommendations, support, and related services.',
                    'Service availability may depend on your location, plan, staff availability, weather conditions, customer access, and operational constraints.',
                    'We may modify, improve, pause, or discontinue certain features or services from time to time.',
                  ],
                ),
                _TermsSection(
                  title: '3. Account and User Information',
                  bullets: [
                    'You are responsible for providing accurate information such as name, phone number, address, service location, and booking details.',
                    'You are responsible for maintaining the confidentiality of your account and OTP-based access.',
                    'You must not misuse the app, create false bookings, impersonate another person, or provide misleading information.',
                  ],
                ),
                _TermsSection(
                  title: '4. Bookings and Visits',
                  bullets: [
                    'Bookings, expert visits, gardening visits, and service schedules are subject to confirmation and availability.',
                    'Visit timings may vary due to traffic, weather, staff availability, customer access, prior visit delays, or operational reasons.',
                    'Customers are expected to provide safe and reasonable access to the service location at the scheduled time.',
                    'If our team is unable to access the premises or complete the visit due to customer-side issues, the visit may still be counted or rescheduled at our discretion.',
                  ],
                ),
                _TermsSection(
                  title: '5. Payments, Invoices, and Subscriptions',
                  bullets: [
                    'Customers agree to pay all applicable charges, subscription fees, visit fees, product charges, delivery charges, and taxes where applicable.',
                    'Invoices must be cleared on time to continue uninterrupted services.',
                    'Gold Dust Gardening may pause services, replacements, deliveries, or additional requests if payments are overdue.',
                    'Subscription plans, pricing, offers, and benefits may change from time to time.',
                  ],
                ),
                _TermsSection(
                  title: '6. Rescheduling and Cancellation',
                  bullets: [
                    'Rescheduling is subject to available slots, assigned maali availability, and operational feasibility.',
                    'Certain rescheduling requests may not be accepted if they are too close to the visit time or if no suitable slot is available.',
                    'Cancellation, refund, or adjustment requests will be reviewed based on the nature of the service, visit status, product status, and applicable policy.',
                  ],
                ),
                _TermsSection(
                  title: '7. Plant Care and Replacements',
                  bullets: [
                    'Plant health depends on many factors including sunlight, watering, soil, season, weather, pests, customer care, and plant condition before service.',
                    'We aim to provide reliable care and guidance, but we cannot guarantee that every plant will survive or remain healthy in all conditions.',
                    'Replacement eligibility may depend on whether the plant was provided by Gold Dust Gardening, the reason for damage, time since delivery, customer care conditions, and payment status.',
                    'Free replacements, goodwill replacements, or additional plants may be provided at our discretion and do not create a permanent obligation for future replacements.',
                  ],
                ),
                _TermsSection(
                  title: '8. Products and Delivery',
                  bullets: [
                    'Product images, plant sizes, colors, and appearance are indicative and may vary because plants are natural products.',
                    'Availability of plants, pots, soil, tools, and other products may change without prior notice.',
                    'Delivery timelines are estimates and may be affected by stock availability, weather, traffic, or operational issues.',
                  ],
                ),
                _TermsSection(
                  title: '9. Customer Responsibilities',
                  bullets: [
                    'Customers must provide correct address details, access instructions, parking or entry support, and any relevant plant care history.',
                    'Customers should keep pets, children, valuables, fragile items, and restricted areas safe during service visits.',
                    'Customers should inform us in advance about society rules, entry restrictions, preferred timing, water access, tool availability, or any safety concerns.',
                    'Customers should follow care instructions shared by our team where applicable.',
                  ],
                ),
                _TermsSection(
                  title: '10. App Usage Rules',
                  bullets: [
                    'You must use the app only for lawful and intended purposes.',
                    'You must not attempt to hack, disrupt, reverse engineer, overload, copy, or misuse the app, backend systems, or services.',
                    'You must not upload abusive, illegal, misleading, harmful, or inappropriate content through the app.',
                  ],
                ),
                _TermsSection(
                  title: '11. User Content and Photos',
                  bullets: [
                    'You may upload photos, plant images, garden images, feedback, complaints, or other information for service, diagnosis, support, and improvement purposes.',
                    'You confirm that you have the right to share such content with us.',
                    'We may use this content internally to provide services, resolve issues, train staff, improve quality, and maintain service records.',
                  ],
                ),
                _TermsSection(
                  title: '12. Notifications and Communications',
                  bullets: [
                    'We may contact you through app notifications, phone calls, WhatsApp, SMS, email, or other communication channels for service-related purposes.',
                    'Service communications may include booking updates, visit reminders, payment reminders, support updates, offers, and important account information.',
                    'You may opt out of promotional communications where supported, but important service-related messages may still be sent.',
                  ],
                ),
                _TermsSection(
                  title: '13. Account Deletion',
                  bullets: [
                    'You may initiate account deletion from the app through Profile / Settings > Delete account.',
                    'Deletion requests will be processed as per applicable law and operational requirements.',
                    'Certain records may be retained where required for legal, tax, payment, fraud prevention, dispute resolution, or compliance purposes.',
                  ],
                ),
                _TermsSection(
                  title: '14. Limitation of Liability',
                  bullets: [
                    'Gold Dust Gardening will make reasonable efforts to provide reliable services, but we are not liable for indirect, incidental, special, or consequential losses.',
                    'We are not responsible for plant damage or service delays caused by weather, pests, lack of sunlight, overwatering, underwatering, customer-side conditions, restricted access, or factors beyond our reasonable control.',
                    'Our liability, if any, will be limited to the amount paid by the customer for the specific affected service or product, subject to applicable law.',
                  ],
                ),
                _TermsSection(
                  title: '15. Third-Party Services',
                  bullets: [
                    'The app may use third-party services for payments, notifications, analytics, maps, hosting, communication, CRM, or customer support.',
                    'Your use of such third-party services may also be subject to their respective terms and privacy policies.',
                  ],
                ),
                _TermsSection(
                  title: '16. Intellectual Property',
                  bullets: [
                    'All app content, branding, design, logos, text, graphics, service flows, and software are owned by or licensed to Gold Dust Gardening.',
                    'You may not copy, reproduce, distribute, modify, or commercially use our content without written permission.',
                  ],
                ),
                _TermsSection(
                  title: '17. Changes to Terms',
                  bullets: [
                    'We may update these Terms of Service from time to time.',
                    'Updated terms will be made available in the app and will apply from the date they are published.',
                    'Continued use of the app or services after updates means you accept the revised terms.',
                  ],
                ),
                _TermsSection(
                  title: '18. Governing Law',
                  bullets: [
                    'These terms shall be governed by the laws of India.',
                    'Any disputes shall be subject to the jurisdiction of courts in India, unless otherwise required by applicable law.',
                  ],
                ),
                _TermsSection(
                  title: '19. Contact Us',
                  bullets: [
                    'For support, billing, service, cancellation, privacy, or account-related queries, contact us at care@golddustgardening.com.',
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
              'Terms of Service',
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
            'Gold Dust Gardening Terms of Service',
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
            'These Terms of Service explain the rules and conditions for using the Gold Dust Gardening app, website, gardening services, plant care services, expert visits, product ordering, customer support, and related services.',
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

class _TermsSection extends StatelessWidget {
  final String title;
  final List<String> bullets;

  const _TermsSection({
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