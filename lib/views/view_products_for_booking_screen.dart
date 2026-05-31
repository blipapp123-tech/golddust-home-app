import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../app/app_constants.dart';
import '../app/app_text_styles.dart';
import '../widgets/liquid_glass_instruction_card.dart';
import 'edit_order_screen.dart';

class ViewProductsForBookingScreen extends StatefulWidget {
  final String bookingID;
  final String date;
  final String userID;

  const ViewProductsForBookingScreen({
    super.key,
    required this.bookingID,
    required this.date,
    required this.userID,
  });

  @override
  State<ViewProductsForBookingScreen> createState() =>
      _ViewProductsForBookingScreenState();
}

class _ViewProductsForBookingScreenState
    extends State<ViewProductsForBookingScreen> with TickerProviderStateMixin {
  late Future<Map<String, List<Map<String, dynamic>>>> _separatedOrdersFuture;

  int _refreshKey = 0;
  bool _isDeleting = false;

  static const Color _darkGreen = Color(0xFF063F20);
  static const Color _gold = Color(0xFFFFB72B);
  static const Color _softBg = Colors.white;

  @override
  void initState() {
    super.initState();
    _fetchOrders();
  }

  void _fetchOrders() {
    _separatedOrdersFuture = _fetchAndSeparateOrders();
  }

  DateTime _parseDate(String dateStr) {
    try {
      final parts = dateStr.split('-');
      int d = int.parse(parts[0]);
      int m = int.parse(parts[1]);
      int y = int.parse(parts[2]);
      if (y < 100) y += 2000;
      return DateTime(y, m, d);
    } catch (_) {
      return DateTime.now();
    }
  }

  double _numValue(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '0') ?? 0;
  }

  Widget _glassCard({
    required Widget child,
    EdgeInsets padding = const EdgeInsets.all(16),
    double radius = 24,
  }) {
    return LiquidGlassInstructionCard(
      radius: radius,
      minHeight: 0,
      padding: padding,
      child: child,
    );
  }

  Future<Map<String, List<Map<String, dynamic>>>>
  _fetchAndSeparateOrders() async {
    final uri = Uri.parse(
      'https://9qnmftczj8.execute-api.ap-south-1.amazonaws.com/zohofetchProductsForBooking',
    );

    try {
      final res = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Cache-Control': 'no-cache',
        },
        body: jsonEncode({'userID': widget.userID}),
      );

      if (res.statusCode == 200) {
        final raw = jsonDecode(res.body);

        if (raw is Map && raw.containsKey('products')) {
          final List<Map<String, dynamic>> futureOrders = [];
          final List<Map<String, dynamic>> pastOrders = [];

          for (final order in (raw['products'] as List)) {
            if (order is Map) {
              if (order['productTodelivered']?.isNotEmpty ?? false) {
                pastOrders.add({
                  'date': order['date'],
                  'bookingID': widget.bookingID,
                  'items': List<Map<String, dynamic>>.from(
                    order['productTodelivered'],
                  ),
                });
              }

              if (order['productTostand']?.isNotEmpty ?? false) {
                futureOrders.add({
                  'date': order['date'],
                  'bookingID': widget.bookingID,
                  'items': List<Map<String, dynamic>>.from(
                    order['productTostand'],
                  ),
                });
              }
            }
          }

          futureOrders.sort(
                (a, b) => _parseDate(a['date']).compareTo(_parseDate(b['date'])),
          );

          pastOrders.sort(
                (a, b) => _parseDate(b['date']).compareTo(_parseDate(a['date'])),
          );

          return {
            'upcoming': futureOrders,
            'past': pastOrders,
          };
        }
      }

      return {'upcoming': [], 'past': []};
    } catch (_) {
      return {'upcoming': [], 'past': []};
    }
  }

  Future<void> _refreshOrders() async {
    setState(() {
      _refreshKey++;
      _separatedOrdersFuture = _fetchAndSeparateOrders();
    });

    await _separatedOrdersFuture;
  }

  void _handleDelete(Map<String, dynamic> order) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Text(
          'Cancel Order?',
          style: AppTextStyles.cardTitle.copyWith(
            color: _darkGreen,
            fontWeight: FontWeight.w900,
          ),
        ),
        content: Text(
          'This will remove all items scheduled for ${order['date']}.',
          style: AppTextStyles.body.copyWith(
            color: AppColors.textSecondary,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'No, Keep it',
              style: AppTextStyles.body.copyWith(
                color: _darkGreen,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);

              final messenger = ScaffoldMessenger.of(context);
              setState(() => _isDeleting = true);

              try {
                final response = await http.post(
                  Uri.parse(
                    'https://jt64v6pp76.execute-api.ap-south-1.amazonaws.com/zohoDeleteProductTostand',
                  ),
                  body: jsonEncode({
                    'userID': widget.userID,
                    'dueDate': order['date'],
                  }),
                  headers: {'Content-Type': 'application/json'},
                );

                if (response.statusCode == 200) {
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Order cancelled successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  await _refreshOrders();
                } else {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Unable to cancel order: ${response.body}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('Error: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              } finally {
                if (mounted) setState(() => _isDeleting = false);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusPill(bool isDelivered) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isDelivered
            ? const Color(0xFFEAF8EF)
            : _gold.withOpacity(0.18),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        isDelivered ? 'Delivered' : 'Pending',
        style: AppTextStyles.tiny.copyWith(
          color: isDelivered ? _darkGreen : Colors.black87,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _buildItemRow(Map<String, dynamic> item) {
    final title = (item['title'] ?? 'Product').toString();
    final imageUrl = (item['imageUrl'] ?? '').toString();
    final qty = _numValue(item['quantity']).toInt();
    final unitPrice = _numValue(item['unitPrice']);
    final lineTotal = _numValue(item['lineTotal']);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.network(
              imageUrl,
              width: 62,
              height: 62,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 62,
                height: 62,
                color: const Color(0xFFEAF8EF),
                child: const Icon(
                  Icons.image_outlined,
                  color: _darkGreen,
                ),
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
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w800,
                    color: _darkGreen,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Qty: $qty × ₹${unitPrice.toStringAsFixed(0)}',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '₹${lineTotal.toStringAsFixed(0)}',
            style: AppTextStyles.bodyLarge.copyWith(
              color: _darkGreen,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernOrderCard(Map<String, dynamic> order, bool isDelivered) {
    final List items = order['items'] ?? [];

    final double total = items.fold<double>(
      0,
          (sum, item) {
        if (item is Map<String, dynamic>) {
          return sum + _numValue(item['lineTotal']);
        }
        if (item is Map) {
          return sum + _numValue(item['lineTotal']);
        }
        return sum;
      },
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: _glassCard(
        radius: 24,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _gold,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    isDelivered
                        ? Icons.check_circle_rounded
                        : Icons.shopping_bag_rounded,
                    color: Colors.black,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isDelivered ? 'Delivered Order' : 'Upcoming Order',
                        style: AppTextStyles.bodyLarge.copyWith(
                          fontWeight: FontWeight.w900,
                          color: _darkGreen,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        order['date']?.toString() ?? '',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildStatusPill(isDelivered),
              ],
            ),

            const SizedBox(height: 14),

            Container(
              height: 1,
              color: Colors.black.withOpacity(0.06),
            ),

            const SizedBox(height: 4),

            ...items.map((item) {
              if (item is Map<String, dynamic>) {
                return _buildItemRow(item);
              }

              if (item is Map) {
                return _buildItemRow(Map<String, dynamic>.from(item));
              }

              return const SizedBox.shrink();
            }),

            const SizedBox(height: 8),

            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFEAF8EF),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Total Order Value',
                      style: AppTextStyles.body.copyWith(
                        color: _darkGreen,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    '₹${total.toStringAsFixed(0)}',
                    style: AppTextStyles.cardTitle.copyWith(
                      color: _darkGreen,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),

            if (!isDelivered) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => EditOrderScreen(
                            order: order,
                            userID: widget.userID,
                            bookingID: widget.bookingID,
                          ),
                        ),
                      ).then((_) => _refreshOrders()),
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('Edit'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _darkGreen,
                        side: BorderSide(
                          color: _darkGreen.withOpacity(0.22),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed:
                      _isDeleting ? null : () => _handleDelete(order),
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('Cancel'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red.shade700,
                        side: BorderSide(
                          color: Colors.red.shade100,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOrderList(
      List<Map<String, dynamic>> orders, {
        required bool isDelivered,
      }) {
    if (orders.isEmpty) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.66,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              LiquidGlassInstructionCard(
                radius: 34,
                minHeight: 104,
                padding: const EdgeInsets.all(24),
                child: Icon(
                  Icons.shopping_basket_outlined,
                  size: 56,
                  color: _darkGreen.withOpacity(0.35),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                isDelivered
                    ? 'No delivered orders found'
                    : 'No upcoming orders scheduled',
                style: AppTextStyles.bodyLarge.copyWith(
                  color: _darkGreen,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                isDelivered
                    ? 'Delivered product orders will appear here.'
                    : 'Products added for your next visit will appear here.',
                textAlign: TextAlign.center,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        return _buildModernOrderCard(orders[index], isDelivered);
      },
    );
  }

  Widget _buildTabSelector() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 8),
      child: _glassCard(
        radius: 26,
        padding: const EdgeInsets.all(6),
        child: TabBar(
          labelColor: Colors.black,
          unselectedLabelColor: AppColors.textSecondary,
          indicator: BoxDecoration(
            color: _gold,
            borderRadius: BorderRadius.circular(22),
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          labelStyle: AppTextStyles.body.copyWith(
            fontWeight: FontWeight.w900,
          ),
          unselectedLabelStyle: AppTextStyles.body.copyWith(
            fontWeight: FontWeight.w700,
          ),
          tabs: const [
            Tab(text: 'Upcoming'),
            Tab(text: 'Delivered'),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: _softBg,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: _softBg,
          centerTitle: true,
          foregroundColor: AppColors.textPrimary,
          title: Text(
            'Your Orders',
            style: AppTextStyles.cardTitle.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
        ),
        body: Column(
          children: [
            _buildTabSelector(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refreshOrders,
                color: _darkGreen,
                child: FutureBuilder<Map<String, List<Map<String, dynamic>>>>(
                  key: ValueKey(_refreshKey),
                  future: _separatedOrdersFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: _darkGreen,
                        ),
                      );
                    }

                    final upcoming = snapshot.data?['upcoming'] ?? [];
                    final past = snapshot.data?['past'] ?? [];

                    return TabBarView(
                      children: [
                        _buildOrderList(upcoming, isDelivered: false),
                        _buildOrderList(past, isDelivered: true),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}