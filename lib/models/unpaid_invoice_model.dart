class UnpaidInvoice {
  final String userID;
  final String invoiceID;
  final String crmRecordID;
  final String invoiceNumber;
  final String customerName;
  final String status;
  final num balance;
  final num totalAmount;
  final String invoiceDate;
  final String dueDate;
  final String paymentUrl;
  final String lastSyncTime;

  UnpaidInvoice({
    required this.userID,
    required this.invoiceID,
    required this.crmRecordID,
    required this.invoiceNumber,
    required this.customerName,
    required this.status,
    required this.balance,
    required this.totalAmount,
    required this.invoiceDate,
    required this.dueDate,
    required this.paymentUrl,
    required this.lastSyncTime,
  });

  factory UnpaidInvoice.fromJson(Map<String, dynamic> json) {
    num parseNum(dynamic value) {
      if (value is num) return value;
      return num.tryParse(value?.toString() ?? '0') ?? 0;
    }

    return UnpaidInvoice(
      userID: json['userID']?.toString() ?? '',
      invoiceID: json['invoiceID']?.toString() ?? '',
      crmRecordID: json['crmRecordID']?.toString() ?? '',
      invoiceNumber: json['invoiceNumber']?.toString() ?? '',
      customerName: json['customerName']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      balance: parseNum(json['balance']),
      totalAmount: parseNum(json['totalAmount']),
      invoiceDate: json['invoiceDate']?.toString() ?? '',
      dueDate: json['dueDate']?.toString() ?? '',
      paymentUrl: json['paymentUrl']?.toString() ?? '',
      lastSyncTime: json['lastSyncTime']?.toString() ?? '',
    );
  }
}