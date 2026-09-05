import 'package:flutter/material.dart';

import '../app/app_constants.dart';
import '../app/app_text_styles.dart';
import '../widgets/liquid_glass_instruction_card.dart';
import '../services/visit_feedback_service.dart';

class VisitFeedbackScreen extends StatefulWidget {
  final String userId;
  final String dueDate;
  final String maaliName;
  final String taskId;
  final String bookingId;

  const VisitFeedbackScreen({
    super.key,
    required this.userId,
    required this.dueDate,
    required this.maaliName,
    this.taskId = '',
    this.bookingId = '',
  });

  @override
  State<VisitFeedbackScreen> createState() =>
      _VisitFeedbackScreenState();
}

class _VisitFeedbackScreenState
    extends State<VisitFeedbackScreen> {
  final VisitFeedbackService _service =
  VisitFeedbackService();

  final TextEditingController _commentController =
  TextEditingController();

  int _rating = 0;
  bool _isSubmitting = false;

  final Set<String> _selectedTags = {};

  static const Color _darkGreen =
  Color(0xFF063F20);

  static const Color _gold =
  Color(0xFFFFB72B);

  static const List<String> _tags = [
    'Plant care',
    'Professional',
    'Cleaning',
    'On time',
    'Helpful advice',
    'Needs improvement',
  ];

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_rating < 1 || _rating > 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please select a star rating.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final result =
      await _service.submitFeedback(
        userId: widget.userId,
        dueDate: widget.dueDate,
        rating: _rating,
        feedbackTags:
        _selectedTags.toList(),
        feedbackText:
        _commentController.text,
      );

      if (!mounted) return;

      final message =
      result['message']?.toString().trim();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            message?.isNotEmpty == true
                ? message!
                : 'Thank you for your feedback.',
          ),
          backgroundColor:
          const Color(0xFF00875A),
        ),
      );

      Navigator.pop(
        context,
        true,
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst(
              'Exception: ',
              '',
            ),
          ),
          backgroundColor:
          Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  String get _title {
    if (widget.maaliName.trim().isNotEmpty &&
        widget.maaliName.trim() !=
            'Not assigned') {
      return 'How was your visit with ${widget.maaliName.trim()}?';
    }

    return 'How was your gardening visit?';
  }

  String get _ratingLabel {
    switch (_rating) {
      case 1:
        return 'Very poor';
      case 2:
        return 'Needs improvement';
      case 3:
        return 'Good';
      case 4:
        return 'Very good';
      case 5:
        return 'Excellent';
      default:
        return 'Tap a star to rate';
    }
  }

  @override
  Widget build(
      BuildContext context,
      ) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Rate Your Visit',
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding:
          const EdgeInsets.fromLTRB(
            18,
            18,
            18,
            28,
          ),
          children: [
            LiquidGlassInstructionCard(
              radius: 26,
              minHeight: 0,
              padding:
              const EdgeInsets.all(20),
              child: Column(
                children: [
                  Container(
                    width: 62,
                    height: 62,
                    decoration: BoxDecoration(
                      color: _gold.withOpacity(
                        0.16,
                      ),
                      borderRadius:
                      BorderRadius.circular(
                        20,
                      ),
                    ),
                    child: const Icon(
                      Icons
                          .local_florist_rounded,
                      color: _darkGreen,
                      size: 32,
                    ),
                  ),

                  const SizedBox(height: 16),

                  Text(
                    _title,
                    textAlign:
                    TextAlign.center,
                    style:
                    AppTextStyles.cardTitle
                        .copyWith(
                      color: _darkGreen,
                      fontWeight:
                      FontWeight.w900,
                    ),
                  ),

                  const SizedBox(height: 6),

                  Text(
                    'Visit: ${widget.dueDate}',
                    style:
                    AppTextStyles.caption
                        .copyWith(
                      color:
                      AppColors.textSecondary,
                      fontWeight:
                      FontWeight.w600,
                    ),
                  ),

                  const SizedBox(height: 22),

                  Row(
                    mainAxisAlignment:
                    MainAxisAlignment.center,
                    children:
                    List.generate(
                      5,
                          (index) {
                        final value =
                            index + 1;

                        final selected =
                            value <= _rating;

                        return IconButton(
                          tooltip:
                          '$value star',
                          onPressed:
                          _isSubmitting
                              ? null
                              : () {
                            setState(() {
                              _rating =
                                  value;
                            });
                          },
                          icon: Icon(
                            selected
                                ? Icons
                                .star_rounded
                                : Icons
                                .star_border_rounded,
                            size: 38,
                            color: _gold,
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 2),

                  Text(
                    _ratingLabel,
                    style:
                    AppTextStyles.body
                        .copyWith(
                      color: _darkGreen,
                      fontWeight:
                      FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 22),

            Text(
              'Tell us about the visit',
              style:
              AppTextStyles.sectionTitle
                  .copyWith(
                color: _darkGreen,
                fontWeight:
                FontWeight.w700,
              ),
            ),

            const SizedBox(height: 10),

            Wrap(
              spacing: 9,
              runSpacing: 9,
              children:
              _tags.map(
                    (tag) {
                  final selected =
                  _selectedTags
                      .contains(tag);

                  return FilterChip(
                    selected:
                    selected,
                    showCheckmark:
                    false,
                    label: Text(
                      tag,
                    ),
                    onSelected:
                    _isSubmitting
                        ? null
                        : (_) {
                      setState(() {
                        if (selected) {
                          _selectedTags
                              .remove(
                            tag,
                          );
                        } else {
                          _selectedTags
                              .add(
                            tag,
                          );
                        }
                      });
                    },
                    selectedColor:
                    const Color(
                      0xFFDFF8E6,
                    ),
                    backgroundColor:
                    Colors.white,
                    side: BorderSide(
                      color: selected
                          ? const Color(
                        0xFF0BAE5B,
                      )
                          : const Color(
                        0xFFE1E7E2,
                      ),
                    ),
                    labelStyle:
                    TextStyle(
                      fontWeight:
                      FontWeight.w700,
                      color: selected
                          ? const Color(
                        0xFF00875A,
                      )
                          : AppColors
                          .textPrimary,
                    ),
                  );
                },
              ).toList(),
            ),

            const SizedBox(height: 22),

            TextField(
              controller:
              _commentController,
              enabled:
              !_isSubmitting,
              minLines: 4,
              maxLines: 7,
              maxLength: 1500,
              decoration:
              InputDecoration(
                labelText:
                'Anything else?',
                hintText:
                'Tell us what went well or what we can improve...',
                alignLabelWithHint:
                true,
                filled: true,
                fillColor:
                const Color(
                  0xFFF8FAF8,
                ),
                border:
                OutlineInputBorder(
                  borderRadius:
                  BorderRadius.circular(
                    18,
                  ),
                ),
                enabledBorder:
                OutlineInputBorder(
                  borderRadius:
                  BorderRadius.circular(
                    18,
                  ),
                  borderSide:
                  const BorderSide(
                    color:
                    Color(0xFFE1E7E2),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 18),

            SizedBox(
              width:
              double.infinity,
              height: 52,
              child:
              ElevatedButton.icon(
                onPressed:
                _isSubmitting
                    ? null
                    : _submit,
                icon:
                _isSubmitting
                    ? const SizedBox(
                  width: 18,
                  height: 18,
                  child:
                  CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
                    : const Icon(
                  Icons
                      .send_rounded,
                ),
                label: Text(
                  _isSubmitting
                      ? 'Submitting...'
                      : 'Submit Feedback',
                ),
                style:
                ElevatedButton.styleFrom(
                  backgroundColor:
                  _gold,
                  foregroundColor:
                  Colors.black,
                  elevation: 0,
                  shape:
                  RoundedRectangleBorder(
                    borderRadius:
                    BorderRadius.circular(
                      26,
                    ),
                  ),
                  textStyle:
                  const TextStyle(
                    fontSize: 14,
                    fontWeight:
                    FontWeight.w900,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
