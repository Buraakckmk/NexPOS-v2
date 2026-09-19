class TableOrderPreviewItem {
  final int productId;
  final String name;
  final double quantity;
  final double lineTotal;
  final double unitPrice;

  const TableOrderPreviewItem({
    required this.productId,
    required this.name,
    required this.quantity,
    required this.lineTotal,
    required this.unitPrice,
  });

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse((value ?? "").toString()) ?? 0;
  }

  factory TableOrderPreviewItem.fromJson(Map<String, dynamic> json) {
    final qty = _toDouble(json["quantity"]);
    final total = _toDouble(json["line_total"]);
    final unitPriceFromJson = _toDouble(json["unit_price"]);
    return TableOrderPreviewItem(
      productId: int.tryParse((json["product_id"] ?? "").toString()) ?? 0,
      name: (json["name"] ?? "").toString(),
      quantity: qty,
      lineTotal: total,
      unitPrice: unitPriceFromJson > 0 ? unitPriceFromJson : (qty > 0 ? total / qty : 0),
    );
  }

  TableOrderPreviewItem copyWith({double? quantity, double? lineTotal}) {
    return TableOrderPreviewItem(
      productId: productId,
      name: name,
      quantity: quantity ?? this.quantity,
      lineTotal: lineTotal ?? this.lineTotal,
      unitPrice: unitPrice,
    );
  }
}

class CollectedPayment {
  final String paymentMethod;
  final double amount;
  final String? mealCardType;

  const CollectedPayment({
    required this.paymentMethod,
    required this.amount,
    this.mealCardType,
  });
}

class CheckoutDialogResult {
  final List<CollectedPayment> payments;
  final double discountAmount;
  final double netAmount;
  final List<TableOrderPreviewItem> selectedItems;

  const CheckoutDialogResult({
    required this.payments,
    required this.discountAmount,
    required this.netAmount,
    this.selectedItems = const [],
  });
}

class XReportData {
  final String reportDate;
  final String? printedAt;
  final double totalRevenue;
  final double cashTotal;
  final double cardTotal;
  final int totalOrders;
  final double totalDiscounts;
  final String averageGuestCount;
  final int averageDuration;
  final double totalExpenses;
  final List<ExpenseDetail> expenses;
  final double cashIn;
  final double cashOut;
  final double generalCashRegister;
  final double generalCashStatus;

  const XReportData({
    required this.reportDate,
    this.printedAt,
    required this.totalRevenue,
    required this.cashTotal,
    required this.cardTotal,
    required this.totalOrders,
    required this.totalDiscounts,
    required this.averageGuestCount,
    required this.averageDuration,
    required this.totalExpenses,
    required this.expenses,
    required this.cashIn,
    required this.cashOut,
    required this.generalCashRegister,
    required this.generalCashStatus,
  });

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse((value ?? "").toString()) ?? 0;
  }

  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse((value ?? "").toString()) ?? 0;
  }

  factory XReportData.fromJson(Map<String, dynamic> json) {
    return XReportData(
      reportDate: json["reportDate"] ?? "",
      printedAt: json["printedAt"]?.toString(),
      totalRevenue: _toDouble(json["totalRevenue"]),
      cashTotal: _toDouble(json["cashTotal"]),
      cardTotal: _toDouble(json["cardTotal"]),
      totalOrders: _toInt(json["totalOrders"]),
      totalDiscounts: _toDouble(json["totalDiscounts"]),
      averageGuestCount: json["averageGuestCount"]?.toString() ?? "0.0",
      averageDuration: _toInt(json["averageDuration"]),
      totalExpenses: _toDouble(json["totalExpenses"]),
      expenses: (json["expenses"] as List?)
              ?.map((e) => ExpenseDetail.fromJson(e))
              .toList() ??
          [],
      cashIn: _toDouble(json["cashIn"]),
      cashOut: _toDouble(json["cashOut"]),
      generalCashRegister: _toDouble(json["generalCashRegister"]),
      generalCashStatus: _toDouble(json["generalCashStatus"]),
    );
  }
}

class ExpenseDetail {
  final String name;
  final double amount;

  const ExpenseDetail({required this.name, required this.amount});

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse((value ?? "").toString()) ?? 0;
  }

  factory ExpenseDetail.fromJson(Map<String, dynamic> json) {
    return ExpenseDetail(
      name: json["name"] ?? "",
      amount: _toDouble(json["amount"]),
    );
  }
}
