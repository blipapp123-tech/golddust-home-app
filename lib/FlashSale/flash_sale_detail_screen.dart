import 'dart:async';

import 'package:flutter/material.dart';

import 'flash_sale_model.dart';
import 'flash_sale_service.dart';

class FlashSaleDetailScreen extends StatefulWidget {
  final ConsumerFlashSale sale;
  final Duration serverOffset;
  final String userID;

  const FlashSaleDetailScreen({
    super.key,
    required this.sale,
    required this.serverOffset,
    required this.userID,
  });

  @override
  State<FlashSaleDetailScreen> createState() =>
      _FlashSaleDetailScreenState();
}

class _FlashSaleDetailScreenState
    extends State<FlashSaleDetailScreen> {
  static const Color _green = Color(0xff0d3a1e);
  static const Color _gold = Color(0xffD4A72C);
  static const Color _background = Color(0xffF7F8F4);

  Timer? _timer;
  late Duration _remaining;

  int _quantity = 1;
  bool _submitting = false;

  // If the app loses the response after the backend has already
  // confirmed an order, retry with the SAME request ID.
  // The Lambda will return duplicateRequest=true instead of
  // incrementing soldQuantity a second time.
  String? _pendingRequestId;

  @override
  void initState() {
    super.initState();

    _remaining = _calculateRemaining();

    _timer = Timer.periodic(
      const Duration(seconds: 1),
          (_) {
        if (!mounted) return;

        final remaining =
        _calculateRemaining();

        setState(() {
          _remaining = remaining;
        });

        if (remaining == Duration.zero) {
          _timer?.cancel();
        }
      },
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  DateTime get _estimatedServerNow =>
      DateTime.now().add(
        widget.serverOffset,
      );

  Duration _calculateRemaining() {
    final difference =
    widget.sale.endAt.difference(
      _estimatedServerNow,
    );

    return difference.isNegative
        ? Duration.zero
        : difference;
  }

  bool get _expired =>
      _remaining == Duration.zero;

  bool get _disabled =>
      _expired ||
          widget.sale.isSoldOut ||
          _submitting;

  String _money(num value) {
    if (value % 1 == 0) {
      return '₹${value.toInt()}';
    }

    return '₹${value.toStringAsFixed(2)}';
  }

  String _twoDigits(int value) =>
      value.toString().padLeft(2, '0');

  String get _countdown {
    final days = _remaining.inDays;
    final hours = _remaining.inHours % 24;
    final minutes =
        _remaining.inMinutes % 60;
    final seconds =
        _remaining.inSeconds % 60;

    if (days > 0) {
      return '$days d  '
          '${_twoDigits(hours)} : '
          '${_twoDigits(minutes)} : '
          '${_twoDigits(seconds)}';
    }

    return '${_twoDigits(_remaining.inHours)} : '
        '${_twoDigits(minutes)} : '
        '${_twoDigits(seconds)}';
  }

  String _newRequestId() {
    final now =
        DateTime.now().microsecondsSinceEpoch;

    final salePart = widget.sale.flashSaleID
        .replaceAll(
      RegExp(r'[^A-Za-z0-9]'),
      '',
    );

    final userPart = widget.userID
        .replaceAll(
      RegExp(r'[^A-Za-z0-9]'),
      '',
    );

    return 'APP-$now-'
        '${salePart.length > 10 ? salePart.substring(salePart.length - 10) : salePart}-'
        '${userPart.length > 8 ? userPart.substring(userPart.length - 8) : userPart}';
  }

  void _changeQuantity(int value) {
    if (value < 1 ||
        value >
            widget.sale.maxQtyPerCustomer) {
      return;
    }

    setState(() {
      _quantity = value;

      // A different quantity is a different order intent.
      _pendingRequestId = null;
    });
  }

  Future<void> _buyNow() async {
    if (_disabled) return;

    final userID =
    widget.userID.trim();

    if (userID.isEmpty) {
      _showError(
        'Unable to identify your account. Please login again.',
      );
      return;
    }

    setState(() {
      _submitting = true;
    });

    try {
      // ------------------------------------------------------
      // 1. Ask backend for the authoritative order preview.
      // Flutter does NOT decide the final price.
      // ------------------------------------------------------

      final validation =
      await ConsumerFlashSaleService
          .validateOrder(
        userID: userID,
        flashSaleID:
        widget.sale.flashSaleID,
        quantity: _quantity,
      );

      if (!mounted) return;

      if (!validation.canOrder) {
        throw const FlashSaleApiException(
          'This Flash Sale order cannot be placed.',
        );
      }

      final shouldConfirm =
      await _showConfirmOrderDialog(
        validation.preview,
      );

      if (!mounted ||
          shouldConfirm != true) {
        return;
      }

      // ------------------------------------------------------
      // 2. Confirm with an idempotent request ID.
      // ------------------------------------------------------

      final requestId =
      _pendingRequestId ??=
          _newRequestId();

      final result =
      await ConsumerFlashSaleService
          .confirmOrder(
        userID: userID,
        flashSaleID:
        widget.sale.flashSaleID,
        quantity: _quantity,
        requestId: requestId,
      );

      if (!mounted) return;

      // Success or duplicate retry of the same successful order.
      _pendingRequestId = null;

      await _showSuccessDialog(
        result,
      );

      if (!mounted) return;

      Navigator.pop(
        context,
        true,
      );
    } on FlashSaleApiException catch (e) {
      if (!mounted) return;

      _showError(
        e.message,
      );
    } on TimeoutException {
      if (!mounted) return;

      // Keep _pendingRequestId so retry is idempotent.
      _showError(
        'The request timed out. Please try again. '
            'Your order will not be duplicated.',
      );
    } catch (e) {
      if (!mounted) return;

      // Keep _pendingRequestId if confirmation may have reached
      // the backend. A retry will reuse it.
      debugPrint(
        'Flash Sale order error: $e',
      );

      _showError(
        'Unable to place the order right now. Please try again.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  Future<bool?> _showConfirmOrderDialog(
      FlashSaleOrderPreview preview,
      ) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius:
            BorderRadius.circular(24),
          ),
          title: const Text(
            'Confirm Flash Sale order',
            style: TextStyle(
              color: _green,
              fontWeight: FontWeight.w900,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              Text(
                preview.productName,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (preview.variantName
                  .trim()
                  .isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  preview.variantName,
                  style: const TextStyle(
                    color: Colors.black54,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 18),
              _dialogRow(
                'Quantity',
                '${preview.quantity}',
              ),
              const SizedBox(height: 8),
              _dialogRow(
                'Flash price',
                _money(preview.unitPrice),
              ),
              const SizedBox(height: 8),
              _dialogRow(
                'You save',
                _money(preview.totalSaving),
              ),
              const Divider(height: 26),
              _dialogRow(
                'Order total',
                _money(preview.totalAmount),
                strong: true,
              ),
              if (preview.alreadyPurchased > 0) ...[
                const SizedBox(height: 12),
                Text(
                  'You have already purchased '
                      '${preview.alreadyPurchased} '
                      '${preview.alreadyPurchased == 1 ? 'unit' : 'units'} '
                      'in this Flash Sale.',
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 12.5,
                    height: 1.35,
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child: const Text(
                'Cancel',
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _green,
                foregroundColor:
                Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius:
                  BorderRadius.circular(14),
                ),
              ),
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              child: const Text(
                'Confirm Order',
                style: TextStyle(
                  fontWeight:
                  FontWeight.w900,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showSuccessDialog(
      FlashSaleOrderResponse result,
      ) {
    final order = result.order;

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius:
            BorderRadius.circular(24),
          ),
          contentPadding:
          const EdgeInsets.fromLTRB(
            24,
            26,
            24,
            16,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 62,
                height: 62,
                decoration: const BoxDecoration(
                  color: Color(0xffE8F5EA),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: _green,
                  size: 34,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Order confirmed',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _green,
                  fontSize: 21,
                  fontWeight:
                  FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '${order.productName}'
                    '${order.variantName.trim().isEmpty ? '' : ' • ${order.variantName}'}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight:
                  FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              _dialogRow(
                'Quantity',
                '${order.quantity}',
              ),
              const SizedBox(height: 7),
              _dialogRow(
                'Order value',
                _money(order.totalAmount),
                strong: true,
              ),
              if (order.orderID
                  .trim()
                  .isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Order ID: ${order.orderID}',
                  textAlign:
                  TextAlign.center,
                  style: const TextStyle(
                    color: Colors.black45,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ],
          ),
          actionsAlignment:
          MainAxisAlignment.center,
          actions: [
            SizedBox(
              width: 150,
              child: ElevatedButton(
                style:
                ElevatedButton.styleFrom(
                  backgroundColor: _green,
                  foregroundColor:
                  Colors.white,
                  elevation: 0,
                  shape:
                  RoundedRectangleBorder(
                    borderRadius:
                    BorderRadius.circular(
                      14,
                    ),
                  ),
                ),
                onPressed: () {
                  Navigator.pop(
                    dialogContext,
                  );
                },
                child: const Text(
                  'Done',
                  style: TextStyle(
                    fontWeight:
                    FontWeight.w900,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _dialogRow(
      String label,
      String value, {
        bool strong = false,
      }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: Colors.black54,
              fontWeight: strong
                  ? FontWeight.w800
                  : FontWeight.w600,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: strong
                ? _green
                : Colors.black87,
            fontWeight: strong
                ? FontWeight.w900
                : FontWeight.w800,
          ),
        ),
      ],
    );
  }

  void _showError(
      String message,
      ) {
    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(
          message,
        ),
        backgroundColor:
        Colors.red.shade700,
        behavior:
        SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sale = widget.sale;

    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _green,
        elevation: 0,
        title: const Text(
          'Weekend Flash Sale',
          style: TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(
            bottom: 120,
          ),
          children: [
            _heroImage(
              sale.imageUrl,
            ),
            Padding(
              padding:
              const EdgeInsets.fromLTRB(
                18,
                18,
                18,
                0,
              ),
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Container(
                    padding:
                    const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color:
                      _gold.withOpacity(0.16),
                      borderRadius:
                      BorderRadius.circular(100),
                    ),
                    child: const Text(
                      '⚡ WEEKEND FLASH SALE',
                      style: TextStyle(
                        color:
                        Color(0xff7A5A00),
                        fontWeight:
                        FontWeight.w900,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    sale.productName,
                    style: const TextStyle(
                      color:
                      Color(0xff202124),
                      fontSize: 26,
                      height: 1.1,
                      fontWeight:
                      FontWeight.w900,
                    ),
                  ),
                  if (sale.variantName
                      .trim()
                      .isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      sale.variantName,
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 15,
                        fontWeight:
                        FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  Row(
                    crossAxisAlignment:
                    CrossAxisAlignment.end,
                    children: [
                      Text(
                        _money(
                          sale.flashSalePrice,
                        ),
                        style: const TextStyle(
                          color: _green,
                          fontSize: 30,
                          fontWeight:
                          FontWeight.w900,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Padding(
                        padding:
                        const EdgeInsets.only(
                          bottom: 4,
                        ),
                        child: Text(
                          _money(
                            sale.regularPrice,
                          ),
                          style:
                          const TextStyle(
                            color:
                            Colors.black38,
                            fontSize: 17,
                            decoration:
                            TextDecoration
                                .lineThrough,
                            decorationThickness:
                            2,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _pill(
                        '${sale.discountPercent}% OFF',
                      ),
                      _pill(
                        'Save ${_money(sale.saving)}',
                      ),
                    ],
                  ),
                  if (sale.shortDescription
                      .trim()
                      .isNotEmpty) ...[
                    const SizedBox(height: 22),
                    Text(
                      sale.shortDescription,
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 14.5,
                        height: 1.55,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Container(
                    width: double.infinity,
                    padding:
                    const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                      BorderRadius.circular(18),
                      border: Border.all(
                        color: const Color(
                          0xffE3E8DF,
                        ),
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          sale.isSoldOut
                              ? 'SOLD OUT'
                              : _expired
                              ? 'OFFER ENDED'
                              : 'Offer ends in',
                          style: TextStyle(
                            color: sale.isSoldOut ||
                                _expired
                                ? Colors
                                .red.shade700
                                : Colors.black54,
                            fontSize: 12,
                            fontWeight:
                            FontWeight.w800,
                          ),
                        ),
                        if (!_expired &&
                            !sale.isSoldOut) ...[
                          const SizedBox(height: 7),
                          Text(
                            _countdown,
                            style: const TextStyle(
                              color: _green,
                              fontSize: 24,
                              fontWeight:
                              FontWeight.w900,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Quantity',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight:
                      FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _quantityButton(
                        icon: Icons.remove,
                        onTap: _quantity > 1
                            ? () =>
                            _changeQuantity(
                              _quantity - 1,
                            )
                            : null,
                      ),
                      Container(
                        width: 60,
                        alignment:
                        Alignment.center,
                        child: Text(
                          '$_quantity',
                          style:
                          const TextStyle(
                            fontSize: 20,
                            fontWeight:
                            FontWeight.w900,
                          ),
                        ),
                      ),
                      _quantityButton(
                        icon: Icons.add,
                        onTap: _quantity <
                            sale.maxQtyPerCustomer
                            ? () =>
                            _changeQuantity(
                              _quantity + 1,
                            )
                            : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Maximum ${sale.maxQtyPerCustomer} '
                        '${sale.maxQtyPerCustomer == 1 ? 'unit' : 'units'} '
                        'per customer',
                    style: const TextStyle(
                      color: Colors.black45,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding:
          const EdgeInsets.fromLTRB(
            16,
            10,
            16,
            14,
          ),
          decoration:
          const BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Color(0x12000000),
                blurRadius: 16,
                offset: Offset(0, -4),
              ),
            ],
          ),
          child: SizedBox(
            height: 54,
            child: ElevatedButton.icon(
              style:
              ElevatedButton.styleFrom(
                backgroundColor: _green,
                foregroundColor:
                Colors.white,
                disabledBackgroundColor:
                Colors.grey.shade400,
                shape:
                RoundedRectangleBorder(
                  borderRadius:
                  BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              onPressed:
              _disabled
                  ? null
                  : _buyNow,
              icon: _submitting
                  ? const SizedBox(
                width: 19,
                height: 19,
                child:
                CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
                  : const Icon(
                Icons.shopping_bag_outlined,
              ),
              label: Text(
                sale.isSoldOut
                    ? 'Sold Out'
                    : _expired
                    ? 'Offer Ended'
                    : _submitting
                    ? 'Checking offer...'
                    : 'Buy Now • '
                    '${_money(sale.flashSalePrice * _quantity)}',
                style: const TextStyle(
                  fontWeight:
                  FontWeight.w900,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _heroImage(
      String imageUrl,
      ) {
    return AspectRatio(
      aspectRatio: 1.08,
      child: imageUrl.trim().isEmpty
          ? _imageFallback()
          : Image.network(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (
            context,
            error,
            stackTrace,
            ) {
          return _imageFallback();
        },
      ),
    );
  }

  Widget _imageFallback() {
    return Container(
      color: const Color(0xffEDF2E9),
      alignment: Alignment.center,
      child: const Icon(
        Icons.local_florist_outlined,
        color: _green,
        size: 72,
      ),
    );
  }

  Widget _pill(
      String text,
      ) {
    return Container(
      padding:
      const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color:
        const Color(0xffEEF4EB),
        borderRadius:
        BorderRadius.circular(100),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: _green,
          fontSize: 12,
          fontWeight:
          FontWeight.w900,
        ),
      ),
    );
  }

  Widget _quantityButton({
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius:
      BorderRadius.circular(12),
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: onTap == null
              ? Colors.grey.shade100
              : Colors.white,
          borderRadius:
          BorderRadius.circular(12),
          border: Border.all(
            color:
            const Color(0xffDDE4D9),
          ),
        ),
        child: Icon(
          icon,
          color: onTap == null
              ? Colors.black26
              : _green,
        ),
      ),
    );
  }
}
