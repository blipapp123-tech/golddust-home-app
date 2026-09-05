import 'dart:async';

import 'package:flutter/material.dart';

import 'flash_sale_detail_screen.dart';
import 'flash_sale_model.dart';

class WeekendFlashSaleCard extends StatefulWidget {
  final ConsumerFlashSale sale;
  final Duration serverOffset;
  final String userID;

  final VoidCallback? onExpired;
  final VoidCallback? onOrderPlaced;

  const WeekendFlashSaleCard({
    super.key,
    required this.sale,
    required this.serverOffset,
    required this.userID,
    this.onExpired,
    this.onOrderPlaced,
  });

  @override
  State<WeekendFlashSaleCard> createState() =>
      _WeekendFlashSaleCardState();
}

class _WeekendFlashSaleCardState
    extends State<WeekendFlashSaleCard> {
  static const Color _green =
  Color(0xff0d3a1e);

  static const Color _gold =
  Color(0xffD4A72C);

  Timer? _timer;
  late Duration _remaining;
  bool _expiryNotified = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void didUpdateWidget(
      covariant WeekendFlashSaleCard oldWidget,
      ) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.sale.flashSaleID !=
        widget.sale.flashSaleID ||
        oldWidget.sale.endAt !=
            widget.sale.endAt ||
        oldWidget.serverOffset !=
            widget.serverOffset) {
      _timer?.cancel();
      _expiryNotified = false;
      _startTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _remaining = _calculateRemaining();

    if (_remaining ==
        Duration.zero) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) {
        _notifyExpired();
      });

      return;
    }

    _timer = Timer.periodic(
      const Duration(seconds: 1),
          (_) {
        if (!mounted) return;

        final remaining =
        _calculateRemaining();

        setState(() {
          _remaining = remaining;
        });

        if (remaining ==
            Duration.zero) {
          _timer?.cancel();
          _notifyExpired();
        }
      },
    );
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

  void _notifyExpired() {
    if (_expiryNotified) return;

    _expiryNotified = true;

    widget.onExpired?.call();
  }

  String _money(num value) {
    if (value % 1 == 0) {
      return '₹${value.toInt()}';
    }

    return '₹${value.toStringAsFixed(2)}';
  }

  String _two(int value) =>
      value.toString().padLeft(2, '0');

  String get _countdown {
    final days =
        _remaining.inDays;

    final hours =
        _remaining.inHours % 24;

    final minutes =
        _remaining.inMinutes % 60;

    final seconds =
        _remaining.inSeconds % 60;

    if (days > 0) {
      return '${days}d '
          '${_two(hours)}h '
          '${_two(minutes)}m';
    }

    return '${_two(_remaining.inHours)}:'
        '${_two(minutes)}:'
        '${_two(seconds)}';
  }

  Future<void> _openDetail() async {
    final result =
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            FlashSaleDetailScreen(
              sale: widget.sale,
              serverOffset:
              widget.serverOffset,
              userID: widget.userID,
            ),
      ),
    );

    if (result == true) {
      widget.onOrderPlaced?.call();
    }
  }

  @override
  Widget build(
      BuildContext context,
      ) {
    final sale =
        widget.sale;

    final soldOut =
        sale.isSoldOut;

    return Container(
      margin:
      const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(22),
        border: Border.all(
          color:
          _gold.withOpacity(0.38),
        ),
        boxShadow: const [
          BoxShadow(
            color:
            Color(0x0E000000),
            blurRadius: 18,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius:
        BorderRadius.circular(22),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _openDetail,
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Container(
                  width:
                  double.infinity,
                  padding:
                  const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  color:
                  const Color(
                    0xffFFF7DD,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.bolt_rounded,
                        color:
                        Color(
                          0xff9B7100,
                        ),
                        size: 20,
                      ),
                      const SizedBox(
                        width: 6,
                      ),
                      const Expanded(
                        child: Text(
                          'WEEKEND FLASH SALE',
                          style:
                          TextStyle(
                            color:
                            Color(
                              0xff795900,
                            ),
                            fontSize:
                            12,
                            fontWeight:
                            FontWeight
                                .w900,
                            letterSpacing:
                            .5,
                          ),
                        ),
                      ),
                      if (!soldOut)
                        Text(
                          _countdown,
                          style:
                          const TextStyle(
                            color:
                            Color(
                              0xff795900,
                            ),
                            fontSize:
                            12,
                            fontWeight:
                            FontWeight
                                .w900,
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding:
                  const EdgeInsets.all(
                    14,
                  ),
                  child: Row(
                    crossAxisAlignment:
                    CrossAxisAlignment
                        .center,
                    children: [
                      ClipRRect(
                        borderRadius:
                        BorderRadius
                            .circular(
                          16,
                        ),
                        child:
                        SizedBox(
                          width: 112,
                          height: 128,
                          child: sale
                              .imageUrl
                              .trim()
                              .isEmpty
                              ? _imageFallback()
                              : Image.network(
                            sale.imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder:
                                (
                                context,
                                error,
                                stackTrace,
                                ) {
                              return _imageFallback();
                            },
                          ),
                        ),
                      ),
                      const SizedBox(
                        width: 14,
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                          children: [
                            Text(
                              sale.productName,
                              maxLines: 2,
                              overflow:
                              TextOverflow
                                  .ellipsis,
                              style:
                              const TextStyle(
                                fontSize: 18,
                                height: 1.15,
                                fontWeight:
                                FontWeight
                                    .w900,
                                color:
                                Color(
                                  0xff202124,
                                ),
                              ),
                            ),
                            if (sale
                                .variantName
                                .trim()
                                .isNotEmpty) ...[
                              const SizedBox(
                                height: 4,
                              ),
                              Text(
                                sale.variantName,
                                maxLines: 1,
                                overflow:
                                TextOverflow
                                    .ellipsis,
                                style:
                                const TextStyle(
                                  fontSize:
                                  12.5,
                                  color:
                                  Colors
                                      .black54,
                                  fontWeight:
                                  FontWeight
                                      .w600,
                                ),
                              ),
                            ],
                            const SizedBox(
                              height: 10,
                            ),
                            Row(
                              crossAxisAlignment:
                              CrossAxisAlignment
                                  .end,
                              children: [
                                Flexible(
                                  child: Text(
                                    _money(
                                      sale.flashSalePrice,
                                    ),
                                    style:
                                    const TextStyle(
                                      color:
                                      _green,
                                      fontSize:
                                      22,
                                      fontWeight:
                                      FontWeight
                                          .w900,
                                    ),
                                  ),
                                ),
                                const SizedBox(
                                  width: 7,
                                ),
                                Padding(
                                  padding:
                                  const EdgeInsets
                                      .only(
                                    bottom: 2,
                                  ),
                                  child: Text(
                                    _money(
                                      sale.regularPrice,
                                    ),
                                    style:
                                    const TextStyle(
                                      color:
                                      Colors
                                          .black38,
                                      fontSize:
                                      13,
                                      decoration:
                                      TextDecoration
                                          .lineThrough,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(
                              height: 5,
                            ),
                            Text(
                              soldOut
                                  ? 'SOLD OUT'
                                  : '${sale.discountPercent}% OFF  •  '
                                  'Save ${_money(sale.saving)}',
                              style:
                              TextStyle(
                                color: soldOut
                                    ? Colors
                                    .red.shade700
                                    : const Color(
                                  0xff557145,
                                ),
                                fontSize:
                                11.5,
                                fontWeight:
                                FontWeight
                                    .w900,
                              ),
                            ),
                            const SizedBox(
                              height: 12,
                            ),
                            Container(
                              width:
                              double.infinity,
                              height: 38,
                              alignment:
                              Alignment.center,
                              decoration:
                              BoxDecoration(
                                color: soldOut
                                    ? Colors.grey
                                    .shade300
                                    : _green,
                                borderRadius:
                                BorderRadius
                                    .circular(
                                  12,
                                ),
                              ),
                              child: Text(
                                soldOut
                                    ? 'Sold Out'
                                    : 'Grab the Deal',
                                style:
                                TextStyle(
                                  color: soldOut
                                      ? Colors
                                      .black45
                                      : Colors
                                      .white,
                                  fontSize:
                                  12.5,
                                  fontWeight:
                                  FontWeight
                                      .w900,
                                ),
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
          ),
        ),
      ),
    );
  }

  Widget _imageFallback() {
    return Container(
      color:
      const Color(0xffEDF2E9),
      alignment: Alignment.center,
      child: const Icon(
        Icons.local_florist_outlined,
        color: _green,
        size: 42,
      ),
    );
  }
}
