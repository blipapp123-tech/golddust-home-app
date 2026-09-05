import 'package:flutter/material.dart';

import 'flash_sale_model.dart';
import 'flash_sale_service.dart';
import 'weekend_flash_sale_card.dart';

class FlashSaleHomeSection
    extends StatefulWidget {
  final String userID;

  const FlashSaleHomeSection({
    super.key,
    required this.userID,
  });

  @override
  State<FlashSaleHomeSection>
  createState() =>
      FlashSaleHomeSectionState();
}

class FlashSaleHomeSectionState
    extends State<FlashSaleHomeSection>
    with WidgetsBindingObserver {
  ConsumerFlashSale? _sale;

  Duration _serverOffset =
      Duration.zero;

  bool _loading = true;
  bool _refreshing = false;

  int _requestVersion = 0;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance
        .addObserver(this);

    refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance
        .removeObserver(this);

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(
      AppLifecycleState state,
      ) {
    if (state ==
        AppLifecycleState.resumed) {
      refresh(
        silent: true,
      );
    }
  }

  Future<void> refresh({
    bool silent = false,
  }) async {
    final request =
    ++_requestVersion;

    if (!silent && mounted) {
      setState(() {
        _loading = true;
      });
    } else if (mounted) {
      setState(() {
        _refreshing = true;
      });
    }

    try {
      final localRequestTime =
      DateTime.now();

      final response =
      await ConsumerFlashSaleService
          .getActiveSale();

      if (!mounted ||
          request !=
              _requestVersion) {
        return;
      }

      final offset =
      response.serverTime
          .difference(
        localRequestTime,
      );

      setState(() {
        _serverOffset = offset;

        _sale =
        response.hasActiveSale
            ? response.sale
            : null;
      });
    } catch (e) {
      // Flash Sale failure must never
      // break the Home screen.
      debugPrint(
        'Flash Sale refresh failed: $e',
      );
    } finally {
      if (mounted &&
          request ==
              _requestVersion) {
        setState(() {
          _loading = false;
          _refreshing = false;
        });
      }
    }
  }

  @override
  Widget build(
      BuildContext context,
      ) {
    if (_loading &&
        _sale == null) {
      return const SizedBox.shrink();
    }

    final sale =
        _sale;

    if (sale == null) {
      return const SizedBox.shrink();
    }

    return Stack(
      children: [
        WeekendFlashSaleCard(
          sale: sale,
          serverOffset:
          _serverOffset,
          userID:
          widget.userID,
          onExpired: () {
            refresh(
              silent: true,
            );
          },
          onOrderPlaced: () {
            // Refresh sold-out/current status
            // immediately after a confirmed order.
            refresh(
              silent: true,
            );
          },
        ),
        if (_refreshing)
          const Positioned(
            right: 24,
            bottom: 16,
            child: SizedBox(
              width: 14,
              height: 14,
              child:
              CircularProgressIndicator(
                strokeWidth: 1.5,
              ),
            ),
          ),
      ],
    );
  }
}
