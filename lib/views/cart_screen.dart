import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../widgets/liquid_glass_instruction_card.dart';
import '../app/app_constants.dart';
import '../app/app_text_styles.dart';

class CartScreen extends StatefulWidget {
  final List<Map<String, dynamic>> cartItems;
  final Function(List<Map<String, dynamic>>) onCartUpdated;
  final String bookingID;
  final String date;
  final String userID;
  final String assignedMali;

  const CartScreen({
    super.key,
    required this.cartItems,
    required this.onCartUpdated,
    required this.bookingID,
    required this.date,
    required this.userID,
    this.assignedMali = '',
  });

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  late List<Map<String, dynamic>> localCart;
  bool _isProcessing = false;

  static const Color _darkGreen = Color(0xFF00230D);
  static const Color _gold = Color(0xFFFFB72B);

  @override
  void initState() {
    super.initState();
    localCart = List<Map<String, dynamic>>.from(widget.cartItems);
  }

  double get totalAmount {
    return localCart.fold(0, (sum, item) {
      final price = double.tryParse((item['price'] ?? 0).toString()) ?? 0;
      final qty = int.tryParse((item['quantity'] ?? 1).toString()) ?? 1;
      return sum + (price * qty);
    });
  }

  String get _displayDate {
    final parts = widget.date.split('-');
    if (parts.length != 3) return widget.date;

    final day = int.tryParse(parts[0]) ?? 0;
    final month = int.tryParse(parts[1]) ?? 0;
    final yearRaw = int.tryParse(parts[2]) ?? 0;
    final year = yearRaw < 100 ? 2000 + yearRaw : yearRaw;

    final date = DateTime(year, month, day);

    const weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];

    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return '${weekdays[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}';
  }

  DateTime? _parseVisitDate(String dateStr) {
    try {
      final parts = dateStr.split('-');
      if (parts.length != 3) return null;

      final day = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final yearRaw = int.parse(parts[2]);
      final year = parts[2].length == 2 ? 2000 + yearRaw : yearRaw;

      return DateTime(year, month, day);
    } catch (_) {
      return null;
    }
  }

  DateTime? _getProductOrderingCutoff() {
    final visitDate = _parseVisitDate(widget.date);
    if (visitDate == null) return null;

    final previousDay = visitDate.subtract(const Duration(days: 1));

    return DateTime(
      previousDay.year,
      previousDay.month,
      previousDay.day,
      15,
      30,
    );
  }

  bool _isOrderingOpen() {
    final cutoff = _getProductOrderingCutoff();

    if (cutoff == null) {
      return false;
    }

    return DateTime.now().isBefore(cutoff);
  }

  String _getOrderingClosedMessage() {
    final cutoff = _getProductOrderingCutoff();

    if (cutoff == null) {
      return 'Ordering window for this visit is closed.';
    }

    final dateText =
        '${cutoff.day.toString().padLeft(2, '0')}-${cutoff.month.toString().padLeft(2, '0')}-${cutoff.year}';

    return 'Ordering window closed on $dateText at 3:30 PM. You can add products for your next eligible visit.';
  }

  void _showOrderingClosedMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_getOrderingClosedMessage()),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _updateQuantity(int index, int delta) {
    if (delta > 0 && !_isOrderingOpen()) {
      _showOrderingClosedMessage();
      return;
    }

    setState(() {
      final currentQty =
          int.tryParse((localCart[index]['quantity'] ?? 1).toString()) ?? 1;
      final newQty = currentQty + delta;

      if (newQty > 0) {
        localCart[index]['quantity'] = newQty;
      } else {
        localCart.removeAt(index);
      }
    });

    widget.onCartUpdated(localCart);
  }

  Future<void> _submitOrder() async {
    if (localCart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your cart is empty'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (!_isOrderingOpen()) {
      _showOrderingClosedMessage();
      return;
    }

    setState(() => _isProcessing = true);

    final formattedItems = localCart.map((item) {
      final price = double.tryParse((item['price'] ?? 0).toString()) ?? 0;
      final quantity = int.tryParse((item['quantity'] ?? 1).toString()) ?? 1;

      return {
        'title': item['title'] ?? '',
        'quantity': quantity,
        'unitPrice': price.round(),
        'lineTotal': (price * quantity).round(),
        'imageUrl': item['Image_1'] ?? '',
      };
    }).toList();

    String formattedDate = widget.date;
    try {
      final parts = widget.date.split('-');
      if (parts.length == 3 && parts[2].length == 4) {
        formattedDate = '${parts[0]}-${parts[1]}-${parts[2].substring(2)}';
      }
    } catch (_) {}

    final payload = {
      'bookingID': widget.userID,
      'date': formattedDate,
      'items': formattedItems,
    };

    try {
      final res = await http.post(
        Uri.parse(
          'https://7ndjbw4n6g.execute-api.ap-south-1.amazonaws.com/zohoAddProductsOverwrite',
        ),
        body: jsonEncode(payload),
        headers: {'Content-Type': 'application/json'},
      );

      if (res.statusCode == 200) {
        if (!mounted) return;
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order confirmed! Items will be brought during next visit.'),
          ),
        );
      } else {
        throw Exception('Failed to confirm order: ${res.body}');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Widget _waterDropCard({
    required Widget child,
    double radius = 24,
    EdgeInsets padding = EdgeInsets.zero,
  }) {
    return LiquidGlassInstructionCard(
      radius: radius,
      minHeight: 0,
      padding: padding,
      child: child,
    );
  }

  Widget _buildVisitSummaryCard() {
    return _waterDropCard(
      radius: 10,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 50,
            decoration: BoxDecoration(
              color: _gold,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.calendar_month_rounded,
              color: _darkGreen,
              size: 26,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'NEXT VISIT SUMMARY',
                  style: AppTextStyles.caption.copyWith(
                    color: Colors.black.withOpacity(0.65),
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  _displayDate,
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: _darkGreen,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.person_outline_rounded,
                      size: 13,
                      color: Colors.black.withOpacity(0.65),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Assigned\nMaali:',
                      style: AppTextStyles.body.copyWith(
                        height: 1.25,
                        color: Colors.black.withOpacity(0.65),
                      ),
                    ),
                    const SizedBox(width: 22),
                    Text(
                      widget.assignedMali.trim().isEmpty ? 'Assigned\nMaali' : widget.assignedMali,
                      style: AppTextStyles.body.copyWith(
                        height: 1.25,
                        color: _darkGreen,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartItemCard(int index) {
    final item = localCart[index];
    final imageUrl = (item['Image_1'] ?? '').toString();
    final title = (item['title'] ?? 'Product').toString();
    final price = item['price'] ?? 0;
    final qty = int.tryParse((item['quantity'] ?? 1).toString()) ?? 1;

    return _waterDropCard(
      radius: 22,
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.network(
              imageUrl,
              width: 78,
              height: 78,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 78,
                height: 78,
                color: Colors.grey.shade200,
                child: const Icon(Icons.image_outlined),
              ),
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body.copyWith(
                    fontSize: 13,
                    height: 1.25,
                    fontWeight: FontWeight.w800,
                    color: _darkGreen,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  '₹$price',
                  style: AppTextStyles.bodyLarge.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: _darkGreen,
                  ),
                ),

                const SizedBox(height: 12),

                Row(
                  children: [
                    GestureDetector(
                      onTap: () => _updateQuantity(index, -1),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.08),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.remove_rounded,
                          color: Colors.red,
                          size: 19,
                        ),
                      ),
                    ),

                    const SizedBox(width: 12),

                    Text(
                      'QTY $qty',
                      style: AppTextStyles.chip.copyWith(
                        fontSize: 12,
                        color: _darkGreen,
                        fontWeight: FontWeight.w900,
                      ),
                    ),

                    const SizedBox(width: 12),

                    GestureDetector(
                      onTap: () => _updateQuantity(index, 1),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: _gold,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: _gold.withOpacity(0.35),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.add_rounded,
                          color: Colors.black,
                          size: 20,
                        ),
                      ),
                    ),

                    const Spacer(),

                    GestureDetector(
                      onTap: () {
                        setState(() {
                          localCart.removeAt(index);
                        });
                        widget.onCartUpdated(localCart);
                      },
                      child: Text(
                        'Remove',
                        style: AppTextStyles.tiny.copyWith(
                          color: Colors.red,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalSection() {
    return LiquidGlassInstructionCard(
      radius: 24,
      minHeight: 0,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Total Order Value',
                  style: AppTextStyles.title.copyWith(
                    color: _darkGreen,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '₹${totalAmount.toStringAsFixed(2)}',
                style: AppTextStyles.cardTitle.copyWith(
                  color: _darkGreen,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Subtotal only. No immediate payment required.',
              style: AppTextStyles.caption.copyWith(
                color: Colors.black.withValues(alpha: 0.62),
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionsSection() {
    return LiquidGlassInstructionCard(
      radius: 24,
      minHeight: 0,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.edit_note_rounded,
                size: 20,
                color: _gold,
              ),
              const SizedBox(width: 8),
              Text(
                'Special Instructions',
                style: AppTextStyles.bodyLarge.copyWith(
                  color: _darkGreen,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'These items will be delivered to you during your next scheduled visit.',
            style: AppTextStyles.body.copyWith(
              height: 1.55,
              color: Colors.black.withValues(alpha: 0.68),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shopping_basket_outlined,
              size: 80,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              'Your cart is empty',
              style: AppTextStyles.cardTitle.copyWith(
                color: _darkGreen,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add some plants or tools for your next visit!',
              style: AppTextStyles.body.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfirmButton() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 14),
        child: LiquidGlassInstructionCard(
          radius: 28,
          minHeight: 0,
          padding: const EdgeInsets.all(7),
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _gold,
                foregroundColor: Colors.black,
                elevation: 0,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              onPressed: _isProcessing ? null : _submitOrder,
              child: _isProcessing
                  ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.black,
                ),
              )
                  : Text(
                'Confirm & Schedule',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.body.copyWith(
                  fontSize: 14,
                  color: Colors.black,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReviewBody() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 20),
      children: [
        _buildVisitSummaryCard(),
        const SizedBox(height: 24),
        Text(
          'ITEMS FOR NEXT VISIT',
          style: AppTextStyles.caption.copyWith(
            color: Colors.black.withOpacity(0.65),
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 12),
        ...List.generate(
          localCart.length,
              (index) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildCartItemCard(index),
          ),
        ),
        const SizedBox(height: 28),
        _buildTotalSection(),
        const SizedBox(height: 18),
        _buildInstructionsSection(),
        const SizedBox(height: 24),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        foregroundColor: AppColors.textPrimary,
        title: Text(
          'Confirm Details',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.bodyLarge.copyWith(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: localCart.isEmpty ? _buildEmptyState() : _buildReviewBody(),
      bottomNavigationBar: localCart.isEmpty ? null : _buildConfirmButton(),
    );
  }
}