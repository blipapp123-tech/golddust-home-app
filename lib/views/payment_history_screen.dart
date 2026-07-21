import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../app/app_constants.dart';
import '../app/app_text_styles.dart';
import '../widgets/liquid_glass_instruction_card.dart';

class PaymentHistoryScreen extends StatefulWidget {
  final String userId;

  const PaymentHistoryScreen({
    super.key,
    required this.userId,
  });

  @override
  State<PaymentHistoryScreen> createState() =>
      _PaymentHistoryScreenState();
}

class _PaymentHistoryScreenState extends State<PaymentHistoryScreen> {
  static const String _paymentHistoryApiUrl =
      'https://qgd9w5qi0k.execute-api.ap-south-1.amazonaws.com/default/paymenthistory';

  static const Color _darkGreen = Color(0xFF063F20);
  static const Color _gold = Color(0xFFFFB72B);
  static const Color _pendingRed = Color(0xFFC93535);
  static const Color _paidGreenBackground = Color(0xFFEAF8EF);
  static const Color _pendingRedBackground = Color(0xFFFFE3E3);

  // Compact typography aligned with the rest of the customer app.
  static const double _pageTitleFontSize = 16;
  static const double _cardTitleFontSize = 14;
  static const double _sectionTitleFontSize = 13;
  static const double _bodyFontSize = 11.5;
  static const double _captionFontSize = 10;
  static const double _statusFontSize = 8;
  static const double _buttonFontSize = 12;

  bool _isLoading = true;
  String _errorMessage = '';
  List<Map<String, dynamic>> _invoices = [];
  Map<String, dynamic> _summary = {};

  final Map<String, Map<String, dynamic>> _invoiceDetailsCache =
  <String, Map<String, dynamic>>{};
  final Map<String, Future<Map<String, dynamic>>> _invoiceRequestFutures =
  <String, Future<Map<String, dynamic>>>{};

  @override
  void initState() {
    super.initState();
    _fetchPaymentHistory();
  }

  num _toNum(dynamic value) {
    if (value is num) return value;

    final cleaned = value
        ?.toString()
        .replaceAll(',', '')
        .replaceAll('₹', '')
        .replaceAll('Rs.', '')
        .replaceAll('Rs', '')
        .trim();

    return num.tryParse(cleaned ?? '0') ?? 0;
  }

  String _formatCurrency(num amount) {
    final negative = amount < 0;
    final absolute = amount.abs();
    final hasDecimals = (absolute - absolute.round()).abs() > 0.001;
    final raw = absolute.toStringAsFixed(hasDecimals ? 2 : 0);
    final parts = raw.split('.');
    final digits = parts.first;

    String grouped;
    if (digits.length <= 3) {
      grouped = digits;
    } else {
      final lastThree = digits.substring(digits.length - 3);
      final leadingDigits = digits.substring(0, digits.length - 3);
      final reversedLeading = leadingDigits.split('').reversed.toList();
      final groupedLeading = <String>[];

      for (int i = 0; i < reversedLeading.length; i += 2) {
        final end = i + 2 < reversedLeading.length
            ? i + 2
            : reversedLeading.length;
        groupedLeading.add(
          reversedLeading.sublist(i, end).reversed.join(),
        );
      }

      grouped = '${groupedLeading.reversed.join(',')},$lastThree';
    }

    final decimalPart = parts.length > 1 ? '.${parts[1]}' : '';
    return '${negative ? '-' : ''}₹$grouped$decimalPart';
  }

  String _formatQuantity(num quantity) {
    if ((quantity - quantity.round()).abs() < 0.001) {
      return quantity.round().toString();
    }
    return quantity.toStringAsFixed(2);
  }

  DateTime? _parseDate(dynamic rawValue) {
    final value = rawValue?.toString().trim() ?? '';
    if (value.isEmpty) return null;

    final direct = DateTime.tryParse(value);
    if (direct != null) return direct;

    final normalized = value.replaceAll('/', '-').replaceAll('.', '-');
    final parts = normalized.split('-');

    if (parts.length == 3) {
      final first = int.tryParse(parts[0]);
      final second = int.tryParse(parts[1]);
      final third = int.tryParse(parts[2]);

      if (first != null && second != null && third != null) {
        if (parts[0].length == 4) {
          return DateTime(first, second, third);
        }

        final year = parts[2].length == 2 ? 2000 + third : third;
        return DateTime(year, second, first);
      }
    }

    return null;
  }

  String _formatDisplayDate(dynamic rawValue) {
    final date = _parseDate(rawValue);
    if (date == null) {
      final fallback = rawValue?.toString().trim() ?? '';
      return fallback.isEmpty ? 'Invoice' : fallback;
    }

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

    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String _monthYear(DateTime date) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    return '${months[date.month - 1]} ${date.year}';
  }

  String _prettyPaymentMode(dynamic rawValue) {
    final value = rawValue?.toString().trim().toLowerCase() ?? '';

    const replacements = {
      'banktransfer': 'Bank transfer',
      'bank_transfer': 'Bank transfer',
      'creditcard': 'Credit card',
      'credit_card': 'Credit card',
      'cash': 'Cash',
      'check': 'Cheque',
      'cheque': 'Cheque',
      'others': 'Other',
      'upi': 'UPI',
    };

    if (replacements.containsKey(value)) {
      return replacements[value]!;
    }

    if (value.isEmpty) return 'Payment';

    return value
        .replaceAll('_', ' ')
        .split(' ')
        .where((word) => word.isNotEmpty)
        .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
        .join(' ');
  }

  Map<String, dynamic> _decodeResponseBody(http.Response response) {
    final decoded = jsonDecode(response.body);

    if (decoded is! Map) {
      return <String, dynamic>{};
    }

    final outer = Map<String, dynamic>.from(decoded);

    if (outer['body'] is String) {
      final nested = jsonDecode(outer['body']);
      if (nested is Map) {
        return Map<String, dynamic>.from(nested);
      }
    }

    return outer;
  }

  Future<void> _fetchPaymentHistory({bool clearDetails = false}) async {
    if (widget.userId.trim().isEmpty) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Customer details are missing.';
      });
      return;
    }

    try {
      if (mounted) {
        setState(() {
          _isLoading = true;
          _errorMessage = '';

          if (clearDetails) {
            _invoiceDetailsCache.clear();
            _invoiceRequestFutures.clear();
          }
        });
      }

      final uri = Uri.parse(_paymentHistoryApiUrl).replace(
        queryParameters: {
          'userID': widget.userId.trim(),
        },
      );

      final response = await http
          .get(uri)
          .timeout(const Duration(seconds: 35));

      final body = _decodeResponseBody(response);

      if (response.statusCode != 200 || body['success'] != true) {
        throw Exception(
          body['message'] ??
              'Unable to fetch payment history. '
                  'Status: ${response.statusCode}',
        );
      }

      final rawInvoices = body['invoices'] ?? body['transactions'] ?? [];
      final invoices = rawInvoices is List
          ? rawInvoices
          .whereType<Map>()
          .map((invoice) => Map<String, dynamic>.from(invoice))
          .toList()
          : <Map<String, dynamic>>[];

      invoices.sort((a, b) {
        final aDate = _parseDate(a['invoiceDate'] ?? a['date']);
        final bDate = _parseDate(b['invoiceDate'] ?? b['date']);

        if (aDate == null && bDate == null) return 0;
        if (aDate == null) return 1;
        if (bDate == null) return -1;

        return bDate.compareTo(aDate);
      });

      if (!mounted) return;

      setState(() {
        _invoices = invoices;
        _summary = body['summary'] is Map
            ? Map<String, dynamic>.from(body['summary'])
            : <String, dynamic>{};
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage =
            error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<Map<String, dynamic>> _getInvoiceDetails(
      String invoiceId,
      ) {
    final cached = _invoiceDetailsCache[invoiceId];
    if (cached != null) {
      return Future<Map<String, dynamic>>.value(cached);
    }

    final existingRequest = _invoiceRequestFutures[invoiceId];
    if (existingRequest != null) {
      return existingRequest;
    }

    final request = _fetchInvoiceDetails(invoiceId).whenComplete(() {
      _invoiceRequestFutures.remove(invoiceId);
    });

    _invoiceRequestFutures[invoiceId] = request;
    return request;
  }

  Future<Map<String, dynamic>> _fetchInvoiceDetails(
      String invoiceId,
      ) async {
    final uri = Uri.parse(_paymentHistoryApiUrl).replace(
      queryParameters: {
        'action': 'invoiceDetails',
        'userID': widget.userId.trim(),
        'invoiceID': invoiceId,
      },
    );

    final response = await http
        .get(uri)
        .timeout(const Duration(seconds: 35));

    final body = _decodeResponseBody(response);

    if (response.statusCode != 200 || body['success'] != true) {
      throw Exception(
        body['message'] ??
            'Unable to load invoice details. '
                'Status: ${response.statusCode}',
      );
    }

    final rawInvoice = body['invoice'];
    if (rawInvoice is! Map) {
      throw Exception('Invoice details were not returned.');
    }

    final details = Map<String, dynamic>.from(rawInvoice);
    _invoiceDetailsCache[invoiceId] = details;
    return details;
  }

  String _invoiceId(Map<String, dynamic> invoice) {
    return (invoice['invoiceID'] ??
        invoice['invoiceId'] ??
        invoice['invoice_id'] ??
        '')
        .toString()
        .trim();
  }

  String _invoiceNumber(Map<String, dynamic> invoice) {
    final number =
    (invoice['invoiceNumber'] ?? invoice['invoice_number'] ?? '')
        .toString()
        .trim();

    if (number.isNotEmpty) return number;

    final id = _invoiceId(invoice);
    if (id.isNotEmpty) return 'Invoice $id';

    return 'Invoice';
  }

  bool _isPendingInvoice(Map<String, dynamic> invoice) {
    final status = (invoice['status'] ?? invoice['invoiceStatus'] ?? '')
        .toString()
        .trim()
        .toLowerCase();

    final balance = _toNum(invoice['balance']);
    final total = _toNum(invoice['total']);
    final amountPaid = _toNum(invoice['amountPaid']);

    if (status == 'void' ||
        status == 'cancelled' ||
        status == 'canceled') {
      return false;
    }

    if (status == 'paid' ||
        status == 'closed' ||
        balance <= 0 ||
        (total > 0 && amountPaid >= total)) {
      return false;
    }

    return true;
  }

  String _statusLabel(Map<String, dynamic> invoice) {
    final balance = _toNum(invoice['balance']);
    final amountPaid = _toNum(invoice['amountPaid']);
    final rawStatus = (invoice['status'] ?? invoice['invoiceStatus'] ?? '')
        .toString()
        .trim()
        .toLowerCase();

    if (rawStatus == 'void' ||
        rawStatus == 'cancelled' ||
        rawStatus == 'canceled') {
      return 'Cancelled';
    }

    if (balance <= 0 && amountPaid > 0) {
      return 'Paid';
    }

    if (amountPaid > 0 && balance > 0) {
      return 'Partially Paid';
    }

    if (rawStatus == 'overdue') {
      return 'Overdue';
    }

    return 'Payment Pending';
  }


  String _subscriptionPeriodForInvoice(
      Map<String, dynamic> invoice,
      ) {
    const directPeriodKeys = [
      'subscriptionPeriod',
      'subscription_period',
      'billingPeriod',
      'billing_period',
      'servicePeriod',
      'service_period',
      'invoicePeriod',
      'invoice_period',
      'period',
    ];

    for (final key in directPeriodKeys) {
      final rawValue = invoice[key]?.toString().trim() ?? '';
      if (rawValue.isEmpty) continue;

      final extracted = _extractInvoicePeriod(rawValue);
      if (extracted.isNotEmpty) return extracted;

      if (rawValue.length <= 70) {
        return rawValue;
      }
    }

    final textCandidates = <String>[
      (invoice['description'] ?? '').toString(),
      (invoice['notes'] ?? '').toString(),
      (invoice['lineItemDescription'] ??
          invoice['line_item_description'] ??
          '')
          .toString(),
    ];

    final rawLineItems = invoice['lineItems'] ?? invoice['line_items'];
    if (rawLineItems is List) {
      for (final item in rawLineItems.whereType<Map>()) {
        textCandidates.add(
          [
            item['name'],
            item['description'],
          ].where((value) => value != null).join(' '),
        );
      }
    }

    final combinedText = [
      invoice['invoiceType'],
      invoice['invoice_type'],
      invoice['type'],
      invoice['category'],
      ...textCandidates,
    ].where((value) => value != null).join(' ').toLowerCase();

    final looksLikeSubscription =
        combinedText.contains('subscription') ||
            combinedText.contains('monthly service') ||
            combinedText.contains('gardening service') ||
            combinedText.contains('billing period') ||
            combinedText.contains('service period');

    for (final candidate in textCandidates) {
      final extracted = _extractInvoicePeriod(candidate);
      if (extracted.isNotEmpty) return extracted;
    }

    if (looksLikeSubscription) {
      final invoiceDate = _parseDate(
        invoice['invoiceDate'] ?? invoice['date'],
      );

      if (invoiceDate != null) {
        return _monthYear(invoiceDate);
      }
    }

    return '';
  }


  Widget _subscriptionPeriodText(String period) {
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Text(
        'Subscription period: $period',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTextStyles.caption.copyWith(
          fontSize: _captionFontSize,
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _subscriptionPeriodLine(
      Map<String, dynamic> invoice,
      ) {
    final periodFromList = _subscriptionPeriodForInvoice(invoice);

    if (periodFromList.isNotEmpty) {
      return _subscriptionPeriodText(periodFromList);
    }

    final invoiceId = _invoiceId(invoice);
    if (invoiceId.isEmpty) {
      return const SizedBox.shrink();
    }

    return FutureBuilder<Map<String, dynamic>>(
      future: _getInvoiceDetails(invoiceId),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          final period = _subscriptionPeriodForInvoice(snapshot.data!);

          if (period.isNotEmpty) {
            return _subscriptionPeriodText(period);
          }

          return const SizedBox.shrink();
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(
              'Loading subscription period…',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption.copyWith(
                fontSize: _captionFontSize,
                color: AppColors.textSecondary.withOpacity(0.72),
                fontWeight: FontWeight.w500,
              ),
            ),
          );
        }

        return const SizedBox.shrink();
      },
    );
  }

  Future<void> _openUrl(String url) async {
    final cleanUrl = url.trim();

    if (cleanUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment link is currently unavailable.'),
        ),
      );
      return;
    }

    final uri = Uri.tryParse(cleanUrl);
    if (uri == null || !uri.hasScheme) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid payment link.'),
        ),
      );
      return;
    }

    final opened = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to open the payment link.'),
        ),
      );
    }
  }

  Future<void> _showInvoiceDetails(
      Map<String, dynamic> invoice,
      ) async {
    final invoiceId = _invoiceId(invoice);
    if (invoiceId.isEmpty) return;

    final detailsFuture = _getInvoiceDetails(invoiceId);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.40),
      builder: (sheetContext) {
        final screenHeight = MediaQuery.of(sheetContext).size.height;

        return Container(
          height: screenHeight * 0.84,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(30),
            ),
          ),
          child: Column(
            children: [
              const SizedBox(height: 7),
              Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textSecondary.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _invoiceNumber(invoice),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.bodyLarge.copyWith(
                              fontSize: _cardTitleFontSize,
                              color: _darkGreen,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Invoice details',
                            style: AppTextStyles.caption.copyWith(
                              fontSize: _captionFontSize,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: _darkGreen,
                      ),
                    ),
                  ],
                ),
              ),
              Divider(
                height: 1,
                color: _darkGreen.withOpacity(0.08),
              ),
              Expanded(
                child: FutureBuilder<Map<String, dynamic>>(
                  future: detailsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(
                              color: _darkGreen,
                              strokeWidth: 2.7,
                            ),
                            SizedBox(height: 14),
                            Text(
                              'Loading invoice details…',
                              style: TextStyle(
                                color: _darkGreen,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    if (snapshot.hasError || snapshot.data == null) {
                      final message = snapshot.error
                          ?.toString()
                          .replaceFirst('Exception: ', '') ??
                          'Unable to load invoice details.';

                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(28),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.error_outline_rounded,
                                color: _pendingRed,
                                size: 42,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                message,
                                textAlign: TextAlign.center,
                                style: AppTextStyles.body.copyWith(
                                  fontSize: _bodyFontSize,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.of(sheetContext).pop();
                                  _invoiceDetailsCache.remove(invoiceId);
                                  _invoiceRequestFutures.remove(invoiceId);
                                  _showInvoiceDetails(invoice);
                                },
                                icon: const Icon(Icons.refresh_rounded),
                                label: const Text('Retry'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _darkGreen,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return _invoiceDetailsContent(snapshot.data!);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        toolbarHeight: 50,
        titleSpacing: 4,
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        title: Text(
          'Payment History',
          style: AppTextStyles.bodyLarge.copyWith(
            fontSize: _pageTitleFontSize,
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: _darkGreen,
        ),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 46,
                color: _pendingRed,
              ),
              const SizedBox(height: 14),
              Text(
                _errorMessage,
                textAlign: TextAlign.center,
                style: AppTextStyles.body.copyWith(
                  fontSize: _bodyFontSize,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () => _fetchPaymentHistory(clearDetails: true),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _darkGreen,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_invoices.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => _fetchPaymentHistory(clearDetails: true),
        color: _darkGreen,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.24),
            Icon(
              Icons.receipt_long_outlined,
              size: 54,
              color: AppColors.textSecondary.withOpacity(0.45),
            ),
            const SizedBox(height: 14),
            Text(
              'No payment records found.',
              textAlign: TextAlign.center,
              style: AppTextStyles.body.copyWith(
                fontSize: _bodyFontSize,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _fetchPaymentHistory(clearDetails: true),
      color: _darkGreen,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 22),
        itemCount: _invoices.length + (_summary.isEmpty ? 0 : 1),
        itemBuilder: (context, index) {
          if (_summary.isNotEmpty && index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _summaryCard(),
            );
          }

          final invoiceIndex = index - (_summary.isEmpty ? 0 : 1);
          final invoice = _invoices[invoiceIndex];

          return _invoiceTimelineEntry(
            invoice: invoice,
            index: invoiceIndex,
          );
        },
      ),
    );
  }

  Widget _summaryCard() {
    final totalPending = _toNum(_summary['totalPending']);
    final paidCount = _toNum(_summary['paidInvoiceCount']).round();
    final pendingCount = _toNum(_summary['pendingInvoiceCount']).round();

    return LiquidGlassInstructionCard(
      radius: 18,
      minHeight: 0,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: totalPending > 0
                  ? _pendingRedBackground
                  : _paidGreenBackground,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.account_balance_wallet_rounded,
              color: totalPending > 0 ? _pendingRed : _darkGreen,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  totalPending > 0
                      ? '${_formatCurrency(totalPending)} pending'
                      : 'All payments are clear',
                  style: AppTextStyles.body.copyWith(
                    fontSize: _sectionTitleFontSize,
                    color: totalPending > 0 ? _pendingRed : _darkGreen,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$paidCount paid • $pendingCount pending invoices',
                  style: AppTextStyles.caption.copyWith(
                    fontSize: _captionFontSize,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _invoiceTimelineEntry({
    required Map<String, dynamic> invoice,
    required int index,
  }) {
    final pending = _isPendingInvoice(invoice);
    final invoiceDate = invoice['invoiceDate'] ?? invoice['date'] ?? '';
    final isLast = index == _invoices.length - 1;

    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 20,
                child: Column(
                  children: [
                    Container(
                      width: 11,
                      height: 11,
                      decoration: BoxDecoration(
                        color: pending ? _pendingRed : _darkGreen,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white,
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: (pending ? _pendingRed : _darkGreen)
                                .withOpacity(0.24),
                            blurRadius: 9,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 2,
                      height: 18,
                      margin: const EdgeInsets.only(top: 4),
                      decoration: BoxDecoration(
                        color: AppColors.textSecondary.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.zero,
                  child: Text(
                    _formatDisplayDate(invoiceDate),
                    style: AppTextStyles.caption.copyWith(
                      fontSize: _captionFontSize,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 26, top: 0),
            child: _invoiceCard(invoice),
          ),
        ],
      ),
    );
  }

  Widget _invoiceCard(Map<String, dynamic> invoice) {
    final balance = _toNum(invoice['balance']);
    final pending = _isPendingInvoice(invoice);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _showInvoiceDetails(invoice),
      child: LiquidGlassInstructionCard(
        radius: 18,
        minHeight: 0,
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 11,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _invoiceNumber(invoice),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyLarge.copyWith(
                      fontSize: _cardTitleFontSize,
                      color: _darkGreen,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  _subscriptionPeriodLine(invoice),
                  const SizedBox(height: 4),
                  Text(
                    'Pending amount ${_formatCurrency(balance)}',
                    style: AppTextStyles.caption.copyWith(
                      fontSize: _bodyFontSize,
                      color: pending ? _pendingRed : AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 9),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: pending
                        ? _pendingRedBackground
                        : _paidGreenBackground,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Text(
                    _statusLabel(invoice),
                    style: TextStyle(
                      fontSize: _statusFontSize,
                      fontWeight: FontWeight.w900,
                      color: pending ? _pendingRed : _darkGreen,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 13,
                  color: pending ? _pendingRed : _darkGreen,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _invoiceDetailsContent(Map<String, dynamic> details) {
    final rawLineItems = details['lineItems'];
    final lineItems = rawLineItems is List
        ? rawLineItems
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList()
        : <Map<String, dynamic>>[];

    final rawPayments = details['payments'];
    final payments = rawPayments is List
        ? rawPayments
        .whereType<Map>()
        .map((payment) => Map<String, dynamic>.from(payment))
        .toList()
        : <Map<String, dynamic>>[];

    final pending = _isPendingInvoice(details);
    final paymentUrl = (details['paymentUrl'] ?? '').toString();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _detailStatusCard(details),
          const SizedBox(height: 14),
          Text(
            'Invoice Items',
            style: AppTextStyles.bodyLarge.copyWith(
              fontSize: _sectionTitleFontSize,
              color: _darkGreen,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 7),
          if (lineItems.isEmpty)
            _emptyDetailMessage(
              icon: Icons.inventory_2_outlined,
              message: 'No line items are available for this invoice.',
            )
          else
            ...lineItems.asMap().entries.map((entry) {
              return _lineItemTile(
                entry.value,
                isLast: entry.key == lineItems.length - 1,
              );
            }),
          const SizedBox(height: 12),
          _invoiceTotals(details),
          const SizedBox(height: 14),
          Text(
            'Payments Received',
            style: AppTextStyles.bodyLarge.copyWith(
              fontSize: _sectionTitleFontSize,
              color: _darkGreen,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 7),
          if (payments.isEmpty)
            _emptyDetailMessage(
              icon: pending
                  ? Icons.schedule_rounded
                  : Icons.receipt_long_outlined,
              message: pending
                  ? 'No payment has been received for this invoice.'
                  : 'No separate payment record is available.',
              isPending: pending,
            )
          else
            ...payments.map(_paymentTile),
          if (pending && paymentUrl.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () => _openUrl(paymentUrl),
                icon: const Icon(Icons.payment_rounded),
                label: const Text(
                  'Pay Pending Amount',
                  style: TextStyle(
                    fontSize: _buttonFontSize,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _pendingRed,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _detailStatusCard(Map<String, dynamic> details) {
    final pending = _isPendingInvoice(details);
    final balance = _toNum(details['balance']);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: pending ? _pendingRedBackground : _paidGreenBackground,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            pending ? Icons.schedule_rounded : Icons.check_circle_rounded,
            color: pending ? _pendingRed : _darkGreen,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _statusLabel(details),
                  style: AppTextStyles.body.copyWith(
                    fontSize: _bodyFontSize,
                    color: pending ? _pendingRed : _darkGreen,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Pending amount ${_formatCurrency(balance)}',
                  style: AppTextStyles.caption.copyWith(
                    fontSize: _captionFontSize,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _lineItemTile(
      Map<String, dynamic> item, {
        required bool isLast,
      }) {
    final name = (item['name'] ?? 'Invoice item').toString().trim();
    final rawDescription = (item['description'] ?? '').toString().trim();
    final description = _displayLineItemDescription(
      name: name,
      description: rawDescription,
    );
    final quantity = _toNum(item['quantity']);
    final rate = _toNum(item['rate']);
    final itemTotal = _toNum(item['itemTotal']);
    final unit = (item['unit'] ?? '').toString().trim();
    final taxName = (item['taxName'] ?? '').toString().trim();
    final taxPercentage = _toNum(item['taxPercentage']);

    return Container(
      margin: EdgeInsets.only(bottom: isLast ? 0 : 10),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: _darkGreen.withOpacity(0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  name.isEmpty ? 'Invoice item' : name,
                  style: AppTextStyles.body.copyWith(
                    fontSize: _bodyFontSize,
                    color: _darkGreen,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 9),
              Text(
                _formatCurrency(itemTotal),
                style: AppTextStyles.body.copyWith(
                  fontSize: _bodyFontSize,
                  color: _darkGreen,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              description,
              style: AppTextStyles.caption.copyWith(
                fontSize: _captionFontSize,
                color: AppColors.textSecondary,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              _smallInfoChip(
                '${_formatQuantity(quantity)}${unit.isEmpty ? '' : ' $unit'} × ${_formatCurrency(rate)}',
              ),
              if (taxName.isNotEmpty || taxPercentage > 0)
                _smallInfoChip(
                  [
                    if (taxName.isNotEmpty) taxName,
                    if (taxPercentage > 0)
                      '${_formatQuantity(taxPercentage)}%',
                  ].join(' '),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _displayLineItemDescription({
    required String name,
    required String description,
  }) {
    if (description.isEmpty) return '';

    final combined = '$name $description'.toLowerCase();
    final isSubscription = combined.contains('subscription') ||
        combined.contains('monthly service') ||
        combined.contains('gardening service') ||
        combined.contains('service period') ||
        combined.contains('billing period');

    if (!isSubscription) {
      return description;
    }

    final period = _extractInvoicePeriod(description);
    return period.isEmpty ? '' : 'Subscription period: $period';
  }

  String _extractInvoicePeriod(String description) {
    final monthYearPattern = RegExp(
      r'\b(January|February|March|April|May|June|July|August|September|October|November|December|Jan|Feb|Mar|Apr|Jun|Jul|Aug|Sep|Sept|Oct|Nov|Dec)\s+\d{4}\b',
      caseSensitive: false,
    );

    final monthMatches = monthYearPattern
        .allMatches(description)
        .map((match) => match.group(0)?.trim() ?? '')
        .where((value) => value.isNotEmpty)
        .toList();

    if (monthMatches.isNotEmpty) {
      final unique = <String>[];
      for (final value in monthMatches) {
        if (!unique.any(
              (existing) => existing.toLowerCase() == value.toLowerCase(),
        )) {
          unique.add(value);
        }
      }

      if (unique.length == 1) return unique.first;
      return '${unique.first} – ${unique.last}';
    }

    final numericDatePattern = RegExp(
      r'\b(?:\d{4}[-/.]\d{1,2}[-/.]\d{1,2}|\d{1,2}[-/.]\d{1,2}[-/.]\d{2,4})\b',
    );

    final parsedDates = numericDatePattern
        .allMatches(description)
        .map((match) => _parseDate(match.group(0)))
        .whereType<DateTime>()
        .toList();

    if (parsedDates.isNotEmpty) {
      final first = parsedDates.first;
      final last = parsedDates.last;

      if (first.month == last.month && first.year == last.year) {
        return _monthYear(first);
      }

      return '${_monthYear(first)} – ${_monthYear(last)}';
    }

    final periodMatch = RegExp(
      r'(?:subscription\s+period|billing\s+period|service\s+period|period)\s*[:\-]\s*([^\n,;]+)',
      caseSensitive: false,
    ).firstMatch(description);

    return periodMatch?.group(1)?.trim() ?? '';
  }

  Widget _invoiceTotals(Map<String, dynamic> details) {
    final subTotal = _toNum(details['subTotal']);
    final discountTotal = _toNum(details['discountTotal']);
    final taxTotal = _toNum(details['taxTotal']);
    final shippingCharge = _toNum(details['shippingCharge']);
    final adjustment = _toNum(details['adjustment']);
    final total = _toNum(details['total']);
    final amountPaid = _toNum(details['amountPaid']);
    final balance = _toNum(details['balance']);
    final pending = _isPendingInvoice(details);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: _darkGreen.withOpacity(0.08),
        ),
      ),
      child: Column(
        children: [
          _amountRow('Subtotal', _formatCurrency(subTotal)),
          if (discountTotal > 0) ...[
            const SizedBox(height: 6),
            _amountRow(
              'Discount',
              '-${_formatCurrency(discountTotal)}',
            ),
          ],
          if (taxTotal > 0) ...[
            const SizedBox(height: 6),
            _amountRow('Tax', _formatCurrency(taxTotal)),
          ],
          if (shippingCharge > 0) ...[
            const SizedBox(height: 6),
            _amountRow('Shipping', _formatCurrency(shippingCharge)),
          ],
          if (adjustment != 0) ...[
            const SizedBox(height: 6),
            _amountRow('Adjustment', _formatCurrency(adjustment)),
          ],
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 11),
            child: Divider(height: 1),
          ),
          _amountRow(
            'Invoice Total',
            _formatCurrency(total),
            strong: true,
          ),
          const SizedBox(height: 7),
          _amountRow('Amount Paid', _formatCurrency(amountPaid)),
          const SizedBox(height: 7),
          _amountRow(
            'Pending Amount',
            _formatCurrency(balance),
            highlight: pending,
            strong: true,
          ),
        ],
      ),
    );
  }

  Widget _paymentTile(Map<String, dynamic> payment) {
    final amount = _toNum(payment['amount']);
    final paymentMode = _prettyPaymentMode(
      payment['paymentMode'] ?? payment['payment_mode'],
    );
    final referenceNumber =
    (payment['referenceNumber'] ?? payment['reference_number'] ?? '')
        .toString()
        .trim();
    final description =
    (payment['description'] ?? '').toString().trim();

    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: _darkGreen.withOpacity(0.08),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _paidGreenBackground,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              color: _darkGreen,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatCurrency(amount),
                  style: AppTextStyles.body.copyWith(
                    fontSize: _bodyFontSize,
                    color: _darkGreen,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  paymentMode,
                  style: AppTextStyles.caption.copyWith(
                    fontSize: _captionFontSize,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (referenceNumber.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    'Ref: $referenceNumber',
                    style: AppTextStyles.caption.copyWith(
                      fontSize: _captionFontSize,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    description,
                    style: AppTextStyles.caption.copyWith(
                      fontSize: _captionFontSize,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _smallInfoChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 7,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: _paidGreenBackground,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: AppTextStyles.caption.copyWith(
          fontSize: _captionFontSize,
          color: _darkGreen,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _emptyDetailMessage({
    required IconData icon,
    required String message,
    bool isPending = false,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isPending ? _pendingRedBackground : Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: isPending
              ? _pendingRed.withOpacity(0.12)
              : _darkGreen.withOpacity(0.08),
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: isPending ? _pendingRed : AppColors.textSecondary,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.body.copyWith(
                fontSize: _bodyFontSize,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _amountRow(
      String label,
      String amount, {
        bool highlight = false,
        bool strong = false,
      }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: AppTextStyles.body.copyWith(
              fontSize: _bodyFontSize,
              color: strong ? _darkGreen : AppColors.textSecondary,
              fontWeight: strong ? FontWeight.w900 : FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          amount,
          style: AppTextStyles.body.copyWith(
            fontSize: _bodyFontSize,
            color: highlight ? _pendingRed : _darkGreen,
            fontWeight: strong ? FontWeight.w900 : FontWeight.w800,
          ),
        ),
      ],
    );
  }
}
