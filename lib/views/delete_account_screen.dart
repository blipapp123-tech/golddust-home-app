import 'dart:io';

import 'package:flutter/material.dart';

import '../app/app_constants.dart';
import '../app/app_text_styles.dart';
import '../services/account_deletion_service.dart';
import '../widgets/liquid_glass_instruction_card.dart';

class DeleteAccountScreen extends StatefulWidget {
  final String userId;
  final String phoneNumber;

  const DeleteAccountScreen({
    super.key,
    required this.userId,
    required this.phoneNumber,
  });

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  static const Color _darkGreen = Color(0xFF063F20);
  static const Color _softBg = Color(0xFFF6F7FC);
  static const Color _dangerRed = Color(0xFFE53935);

  final TextEditingController _reasonController = TextEditingController();

  bool _isSubmitting = false;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  String get _resolvedUserId {
    final cleanUserId = widget.userId.trim();

    if (cleanUserId.isNotEmpty) return cleanUserId;

    final phone = widget.phoneNumber.trim();

    if (phone.isNotEmpty) return 'otp$phone';

    return '';
  }

  String get _platform {
    if (Platform.isIOS) return 'ios';
    if (Platform.isAndroid) return 'android';
    return 'unknown';
  }

  Future<void> _submitDeletionRequest() async {
    final userId = _resolvedUserId;

    if (userId.isEmpty) {
      _showSnackBar(
        'Unable to identify your account. Please login again and try.',
        isError: true,
      );
      return;
    }

    final confirmed = await _showConfirmDialog();

    if (confirmed != true) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final result = await AccountDeletionService.submitDeletionRequest(
        userId: userId,
        phoneNumber: widget.phoneNumber,
        reason: _reasonController.text.trim(),
        platform: _platform,
      );

      if (!mounted) return;

      await _showSuccessDialog(result);

      if (!mounted) return;

      Navigator.pop(context);
    } catch (e) {
      debugPrint('❌ Delete account request error: $e');

      if (!mounted) return;

      _showSnackBar(
        'Unable to submit request right now. Please try again.',
        isError: true,
      );
    } finally {
      if (!mounted) return;

      setState(() {
        _isSubmitting = false;
      });
    }
  }

  Future<bool?> _showConfirmDialog() {
    return showDialog<bool>(
      context: context,
      barrierDismissible: !_isSubmitting,
      builder: (_) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: const Text(
            'Delete account?',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: _darkGreen,
            ),
          ),
          content: const Text(
            'This will submit a request to permanently delete your Gold Dust account and associated personal data that we are not legally required to retain.',
            style: TextStyle(
              fontSize: 13.5,
              height: 1.45,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: _dangerRed,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'Confirm',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showSuccessDialog(AccountDeletionResult result) {
    final message = result.alreadyExists
        ? 'Your account deletion request has already been submitted. We will process it within 7 days and send you a confirmation once completed.'
        : 'Your account deletion request has been submitted successfully. We will process it within 7 days and send you a confirmation once completed.';

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: const Text(
            'Request submitted',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: _darkGreen,
            ),
          ),
          content: Text(
            message,
            style: const TextStyle(
              fontSize: 13.5,
              height: 1.45,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'Done',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showSnackBar(
      String message, {
        bool isError = false,
      }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? _dangerRed : AppColors.primaryColor,
      ),
    );
  }

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
              children: [
                LiquidGlassInstructionCard(
                  radius: 24,
                  minHeight: 0,
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: _dangerRed,
                        size: 30,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Request account deletion',
                        style: AppTextStyles.bodyLarge.copyWith(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'You can submit your account deletion request directly from the app. This request will permanently delete your Gold Dust account and associated personal data that we are not legally required to retain.',
                        style: AppTextStyles.body.copyWith(
                          fontSize: 13.5,
                          height: 1.45,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Deletion requests are processed within 7 days. We will send you a confirmation once the deletion is completed.',
                        style: AppTextStyles.body.copyWith(
                          fontSize: 13.5,
                          height: 1.45,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                LiquidGlassInstructionCard(
                  radius: 24,
                  minHeight: 0,
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Account details',
                        style: AppTextStyles.body.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _detailRow('User ID', _resolvedUserId),
                      const SizedBox(height: 8),
                      _detailRow(
                        'Phone',
                        widget.phoneNumber.trim().isEmpty
                            ? 'Not available'
                            : '+91 ${widget.phoneNumber.trim()}',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                LiquidGlassInstructionCard(
                  radius: 24,
                  minHeight: 0,
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Reason',
                        style: AppTextStyles.body.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Optional',
                        style: AppTextStyles.caption.copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _reasonController,
                        maxLines: 4,
                        textInputAction: TextInputAction.done,
                        decoration: InputDecoration(
                          hintText: 'Tell us why you want to delete your account',
                          hintStyle: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.72),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: BorderSide(
                              color: Colors.black.withOpacity(0.06),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: BorderSide(
                              color: Colors.black.withOpacity(0.06),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: const BorderSide(
                              color: AppColors.primaryColor,
                              width: 1.2,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitDeletionRequest,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _dangerRed,
                      disabledBackgroundColor: Colors.red.withOpacity(0.35),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    )
                        : const Text(
                      'Submit delete account request',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
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
        22,
        MediaQuery.of(context).padding.top + 12,
        22,
        24,
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
          Expanded(
            child: Text(
              'Delete account',
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

  Widget _detailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 78,
          child: Text(
            label,
            style: AppTextStyles.caption.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: AppTextStyles.body.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}