class ConsumerFlashSale {
  final String flashSaleID;
  final String productName;
  final String variantName;
  final String shortDescription;
  final String imageUrl;

  final double regularPrice;
  final double flashSalePrice;
  final double saving;
  final int discountPercent;

  final DateTime startAt;
  final DateTime endAt;

  final int maxQtyPerCustomer;
  final String computedStatus;
  final String availability;

  const ConsumerFlashSale({
    required this.flashSaleID,
    required this.productName,
    required this.variantName,
    required this.shortDescription,
    required this.imageUrl,
    required this.regularPrice,
    required this.flashSalePrice,
    required this.saving,
    required this.discountPercent,
    required this.startAt,
    required this.endAt,
    required this.maxQtyPerCustomer,
    required this.computedStatus,
    required this.availability,
  });

  bool get isLive =>
      computedStatus.trim().toUpperCase() == 'LIVE';

  bool get isSoldOut =>
      computedStatus.trim().toUpperCase() == 'SOLD_OUT' ||
          availability.trim().toUpperCase() == 'SOLD_OUT';

  factory ConsumerFlashSale.fromJson(
      Map<String, dynamic> json,
      ) {
    return ConsumerFlashSale(
      flashSaleID:
      (json['flashSaleID'] ?? '').toString(),
      productName:
      (json['productName'] ?? '').toString(),
      variantName:
      (json['variantName'] ?? '').toString(),
      shortDescription:
      (json['shortDescription'] ?? '').toString(),
      imageUrl:
      (json['imageUrl'] ?? '').toString(),
      regularPrice:
      _toDouble(json['regularPrice']),
      flashSalePrice:
      _toDouble(json['flashSalePrice']),
      saving:
      _toDouble(json['saving']),
      discountPercent:
      _toInt(json['discountPercent']),
      startAt: _parseDateTime(json['startAt']),
      endAt: _parseDateTime(json['endAt']),
      maxQtyPerCustomer:
      _toInt(json['maxQtyPerCustomer'], fallback: 1),
      computedStatus:
      (json['computedStatus'] ?? '').toString(),
      availability:
      (json['availability'] ?? '').toString(),
    );
  }
}

class ActiveFlashSaleResponse {
  final bool hasActiveSale;
  final DateTime serverTime;
  final int? serverTimeEpoch;
  final ConsumerFlashSale? sale;

  const ActiveFlashSaleResponse({
    required this.hasActiveSale,
    required this.serverTime,
    required this.serverTimeEpoch,
    required this.sale,
  });

  factory ActiveFlashSaleResponse.fromJson(
      Map<String, dynamic> json,
      ) {
    final hasSale = json['hasActiveSale'] == true;
    final rawSale = json['sale'];

    return ActiveFlashSaleResponse(
      hasActiveSale: hasSale,
      serverTime: _parseDateTime(
        json['serverTime'],
        fallback: DateTime.now(),
      ),
      serverTimeEpoch:
      _toNullableInt(json['serverTimeEpoch']),
      sale: hasSale && rawSale is Map
          ? ConsumerFlashSale.fromJson(
        Map<String, dynamic>.from(rawSale),
      )
          : null,
    );
  }
}

// ============================================================
// ORDER VALIDATION MODELS
// ============================================================

class FlashSaleOrderPreview {
  final String flashSaleID;
  final String productName;
  final String variantName;
  final int quantity;
  final double unitPrice;
  final double regularUnitPrice;
  final double totalAmount;
  final double totalSaving;
  final int maxQtyPerCustomer;
  final int alreadyPurchased;
  final int remainingCustomerAllowance;

  const FlashSaleOrderPreview({
    required this.flashSaleID,
    required this.productName,
    required this.variantName,
    required this.quantity,
    required this.unitPrice,
    required this.regularUnitPrice,
    required this.totalAmount,
    required this.totalSaving,
    required this.maxQtyPerCustomer,
    required this.alreadyPurchased,
    required this.remainingCustomerAllowance,
  });

  factory FlashSaleOrderPreview.fromJson(
      Map<String, dynamic> json,
      ) {
    return FlashSaleOrderPreview(
      flashSaleID:
      (json['flashSaleID'] ?? '').toString(),
      productName:
      (json['productName'] ?? '').toString(),
      variantName:
      (json['variantName'] ?? '').toString(),
      quantity:
      _toInt(json['quantity']),
      unitPrice:
      _toDouble(json['unitPrice']),
      regularUnitPrice:
      _toDouble(json['regularUnitPrice']),
      totalAmount:
      _toDouble(json['totalAmount']),
      totalSaving:
      _toDouble(json['totalSaving']),
      maxQtyPerCustomer:
      _toInt(json['maxQtyPerCustomer'], fallback: 1),
      alreadyPurchased:
      _toInt(json['alreadyPurchased']),
      remainingCustomerAllowance:
      _toInt(json['remainingCustomerAllowance']),
    );
  }
}

class FlashSaleValidationResponse {
  final bool canOrder;
  final DateTime? serverTime;
  final FlashSaleOrderPreview preview;

  const FlashSaleValidationResponse({
    required this.canOrder,
    required this.serverTime,
    required this.preview,
  });

  factory FlashSaleValidationResponse.fromJson(
      Map<String, dynamic> json,
      ) {
    final rawPreview = json['orderPreview'];

    if (rawPreview is! Map) {
      throw const FormatException(
        'Flash Sale validation response has no orderPreview.',
      );
    }

    return FlashSaleValidationResponse(
      canOrder: json['canOrder'] == true,
      serverTime: json['serverTime'] == null
          ? null
          : _parseDateTime(json['serverTime']),
      preview: FlashSaleOrderPreview.fromJson(
        Map<String, dynamic>.from(rawPreview),
      ),
    );
  }
}

// ============================================================
// CONFIRMED ORDER MODELS
// ============================================================

class FlashSaleConfirmedOrder {
  final String orderID;
  final String requestId;
  final String flashSaleID;
  final String userID;
  final String productName;
  final String variantName;
  final String imageUrl;
  final int quantity;
  final double unitPrice;
  final double regularUnitPrice;
  final double totalAmount;
  final double savingPerUnit;
  final double totalSaving;
  final String status;
  final DateTime? orderedAt;

  const FlashSaleConfirmedOrder({
    required this.orderID,
    required this.requestId,
    required this.flashSaleID,
    required this.userID,
    required this.productName,
    required this.variantName,
    required this.imageUrl,
    required this.quantity,
    required this.unitPrice,
    required this.regularUnitPrice,
    required this.totalAmount,
    required this.savingPerUnit,
    required this.totalSaving,
    required this.status,
    required this.orderedAt,
  });

  factory FlashSaleConfirmedOrder.fromJson(
      Map<String, dynamic> json,
      ) {
    final quantity = _toInt(json['quantity']);
    final totalAmount = _toDouble(json['totalAmount']);
    final unitPrice = _toDouble(
      json['unitPrice'],
      fallback: quantity > 0
          ? totalAmount / quantity
          : 0,
    );

    return FlashSaleConfirmedOrder(
      orderID:
      (json['orderID'] ?? '').toString(),
      requestId:
      (json['requestId'] ?? '').toString(),
      flashSaleID:
      (json['flashSaleID'] ?? '').toString(),
      userID:
      (json['userID'] ?? '').toString(),
      productName:
      (json['productName'] ?? '').toString(),
      variantName:
      (json['variantName'] ?? '').toString(),
      imageUrl:
      (json['imageUrl'] ?? '').toString(),
      quantity: quantity,
      unitPrice: unitPrice,
      regularUnitPrice:
      _toDouble(json['regularUnitPrice']),
      totalAmount: totalAmount,
      savingPerUnit:
      _toDouble(json['savingPerUnit']),
      totalSaving:
      _toDouble(json['totalSaving']),
      status:
      (json['status'] ?? '').toString(),
      orderedAt: json['orderedAt'] == null
          ? null
          : _parseDateTime(json['orderedAt']),
    );
  }
}

class FlashSaleCustomerUsage {
  final int maxQtyPerCustomer;
  final int purchasedQuantity;
  final int remainingCustomerAllowance;

  const FlashSaleCustomerUsage({
    required this.maxQtyPerCustomer,
    required this.purchasedQuantity,
    required this.remainingCustomerAllowance,
  });

  factory FlashSaleCustomerUsage.fromJson(
      Map<String, dynamic> json,
      ) {
    return FlashSaleCustomerUsage(
      maxQtyPerCustomer:
      _toInt(json['maxQtyPerCustomer']),
      purchasedQuantity:
      _toInt(json['purchasedQuantity']),
      remainingCustomerAllowance:
      _toInt(json['remainingCustomerAllowance']),
    );
  }
}

class FlashSaleOrderResponse {
  final bool duplicateRequest;
  final String message;
  final FlashSaleConfirmedOrder order;
  final FlashSaleCustomerUsage usage;

  const FlashSaleOrderResponse({
    required this.duplicateRequest,
    required this.message,
    required this.order,
    required this.usage,
  });

  factory FlashSaleOrderResponse.fromJson(
      Map<String, dynamic> json,
      ) {
    final rawOrder = json['order'];
    final rawUsage = json['customerUsage'];

    if (rawOrder is! Map) {
      throw const FormatException(
        'Flash Sale order response has no order.',
      );
    }

    final usageJson = rawUsage is Map
        ? Map<String, dynamic>.from(rawUsage)
        : <String, dynamic>{};

    return FlashSaleOrderResponse(
      duplicateRequest:
      json['duplicateRequest'] == true,
      message:
      (json['message'] ?? '').toString(),
      order: FlashSaleConfirmedOrder.fromJson(
        Map<String, dynamic>.from(rawOrder),
      ),
      usage: FlashSaleCustomerUsage.fromJson(
        usageJson,
      ),
    );
  }
}

// ============================================================
// HELPERS
// ============================================================

double _toDouble(
    dynamic value, {
      double fallback = 0,
    }) {
  if (value is num) return value.toDouble();

  return double.tryParse(
    value?.toString() ?? '',
  ) ??
      fallback;
}

int _toInt(
    dynamic value, {
      int fallback = 0,
    }) {
  if (value is int) return value;
  if (value is num) return value.toInt();

  return int.tryParse(
    value?.toString() ?? '',
  ) ??
      fallback;
}

int? _toNullableInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();

  return int.tryParse(value.toString());
}

DateTime _parseDateTime(
    dynamic value, {
      DateTime? fallback,
    }) {
  final text = value?.toString().trim() ?? '';

  if (text.isNotEmpty) {
    final parsed = DateTime.tryParse(text);
    if (parsed != null) {
      return parsed;
    }
  }

  return fallback ??
      DateTime.fromMillisecondsSinceEpoch(0);
}
