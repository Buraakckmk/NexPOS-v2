class PaginatedResult<T> {
  final int total;
  final int page;
  final int limit;
  final int totalPages;
  final List<T> items;

  PaginatedResult({
    required this.total,
    required this.page,
    required this.limit,
    required this.totalPages,
    required this.items,
  });
}

class TableItem {
  final int id;
  final String label;
  final String status;
  final String zone;
  final DateTime? activeSince;
  final double totalAmount;
  final bool isCustom;

  const TableItem({
    required this.id,
    required this.label,
    required this.status,
    required this.zone,
    required this.activeSince,
    required this.totalAmount,
    required this.isCustom,
  });

  static String _zonePrefix(String zone) {
    final normalized = zone.trim().toLowerCase();
    if (normalized.contains("oyun salonu")) return "T";
    if (normalized.contains("balkon")) return "B";
    if (normalized == "salon" || normalized.contains(" salon")) return "S";
    return "";
  }

  static String _compactLabel(String zone, String label) {
    final prefix = _zonePrefix(zone);
    if (prefix.isEmpty) return label;

    final match = RegExp(r"(\d+)(?!.*\d)").firstMatch(label.trim());
    if (match == null) return label;

    final number = match.group(1);
    if (number == null || number.isEmpty) return label;
    return "$prefix-$number";
  }

  factory TableItem.fromJson(Map<String, dynamic> json) {
    final zone = ((json["zone"] ?? "Salon").toString().trim().isEmpty
        ? "Salon"
        : (json["zone"] ?? "Salon").toString().trim());
    final name = (json["display_name"] ?? "").toString().trim();
    final code = (json["table_code"] ?? "").toString().trim();
    final rawLabel = name.isNotEmpty ? name : (code.isNotEmpty ? code : "Masa");
    final label = _compactLabel(zone, rawLabel);
    final rawId = json["id"];
    final rawTotal = json["total_amount"];
    final rawIsCustom = json["is_custom"];
    return TableItem(
      id: rawId is num ? rawId.toInt() : int.parse(rawId.toString()),
      label: label,
      status: (json["table_status"] ?? "AVAILABLE").toString(),
      zone: zone,
      activeSince: DateTime.tryParse(
        (json["active_since"] ?? "").toString(),
      )?.toLocal(),
      totalAmount: rawTotal is num
          ? rawTotal.toDouble()
          : (double.tryParse(rawTotal?.toString() ?? "0") ?? 0),
      isCustom: rawIsCustom is bool
          ? rawIsCustom
          : (rawIsCustom?.toString().toLowerCase() == "true"),
    );
  }
}

double _toDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse((value ?? "").toString()) ?? 0.0;
}

int _toInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse((value ?? "0").toString()) ?? 0;
}

class DailySummary {
  final double totalRevenue;
  final double cashTotal;
  final double cardTotal;
  final int totalOrders;
  final String date;

  const DailySummary({
    required this.totalRevenue,
    required this.cashTotal,
    required this.cardTotal,
    required this.totalOrders,
    required this.date,
  });

  factory DailySummary.fromJson(Map<String, dynamic> json) {
    return DailySummary(
      totalRevenue: _toDouble(json["totalRevenue"]),
      cashTotal: _toDouble(json["cashTotal"]),
      cardTotal: _toDouble(json["cardTotal"]),
      totalOrders: _toInt(json["totalOrders"]),
      date: json["date"] as String? ?? "",
    );
  }
}

class DailyHistoryItem {
  final String date;
  final double totalRevenue;
  final double cashTotal;
  final double cardTotal;
  final double totalExpense;

  DailyHistoryItem({
    required this.date,
    required this.totalRevenue,
    required this.cashTotal,
    required this.cardTotal,
    required this.totalExpense,
  });

  factory DailyHistoryItem.fromJson(Map<String, dynamic> json) {
    return DailyHistoryItem(
      date: json["date"]?.toString() ?? "",
      totalRevenue: _toDouble(json["totalRevenue"]),
      cashTotal: _toDouble(json["cashTotal"]),
      cardTotal: _toDouble(json["cardTotal"]),
      totalExpense: _toDouble(json["totalExpense"]),
    );
  }
}

class AdminStats {
  final List<WeeklyRevenue> weeklyRevenue;
  final List<TopProduct> topProducts;
  final List<CategorySales> categorySales;

  const AdminStats({
    required this.weeklyRevenue,
    required this.topProducts,
    required this.categorySales,
  });

  factory AdminStats.fromJson(Map<String, dynamic> json) {
    return AdminStats(
      weeklyRevenue:
          (json["weeklyRevenue"] as List<dynamic>?)
              ?.map(
                (item) => WeeklyRevenue.fromJson(item as Map<String, dynamic>),
              )
              .toList() ??
          [],
      topProducts:
          (json["topProducts"] as List<dynamic>?)
              ?.map((item) => TopProduct.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
      categorySales:
          (json["categorySales"] as List<dynamic>?)
              ?.map(
                (item) => CategorySales.fromJson(item as Map<String, dynamic>),
              )
              .toList() ??
          [],
    );
  }
}

class CategorySales {
  final String name;
  final double revenue;
  final double quantity;

  const CategorySales({
    required this.name,
    required this.revenue,
    required this.quantity,
  });

  factory CategorySales.fromJson(Map<String, dynamic> json) {
    return CategorySales(
      name: json["name"] as String? ?? "",
      revenue: _toDouble(json["total_revenue"] ?? json["revenue"]),
      quantity: _toDouble(json["total_quantity"] ?? json["quantity"]),
    );
  }
}

class WeeklyRevenue {
  final String dayName;
  final double revenue;
  final int dayOfWeek;

  const WeeklyRevenue({
    required this.dayName,
    required this.revenue,
    required this.dayOfWeek,
  });

  factory WeeklyRevenue.fromJson(Map<String, dynamic> json) {
    return WeeklyRevenue(
      dayName: json["dayName"] as String? ?? "",
      revenue: _toDouble(json["revenue"]),
      dayOfWeek: _toInt(json["dayOfWeek"]),
    );
  }
}

class TopProduct {
  final String name;
  final double quantity;
  final double revenue;

  const TopProduct({
    required this.name,
    required this.quantity,
    required this.revenue,
  });

  factory TopProduct.fromJson(Map<String, dynamic> json) {
    return TopProduct(
      name: json["name"] as String? ?? "",
      quantity: _toDouble(json["quantity"]),
      revenue: _toDouble(json["revenue"]),
    );
  }
}

class Expense {
  final int id;
  final String itemName;
  final double quantity;
  final double unitPrice;
  final double totalAmount;
  final String? note;
  final String expenseDate;
  final String createdBy;

  Expense({
    required this.id,
    required this.itemName,
    required this.quantity,
    required this.unitPrice,
    required this.totalAmount,
    this.note,
    required this.expenseDate,
    this.createdBy = "-",
  });

  factory Expense.fromJson(Map<String, dynamic> json) {
    return Expense(
      id: _toInt(json["id"]),
      itemName: json["itemName"] as String? ?? "",
      quantity: _toDouble(json["quantity"]),
      unitPrice: _toDouble(json["unitPrice"]),
      totalAmount: _toDouble(json["totalAmount"]),
      note: json["note"] as String?,
      expenseDate: json["expenseDate"] as String? ?? "",
      createdBy: json["createdBy"] as String? ?? "-",
    );
  }
}

class PaymentTransaction {
  final int id;
  final int orderId;
  final String tableName;
  final String paymentMethod;
  final double amount;
  final String paidAt;
  final String cashierName;
  final String note;

  PaymentTransaction({
    required this.id,
    required this.orderId,
    required this.tableName,
    required this.paymentMethod,
    required this.amount,
    required this.paidAt,
    required this.cashierName,
    this.note = "",
  });

  factory PaymentTransaction.fromJson(Map<String, dynamic> json) {
    return PaymentTransaction(
      id: _toInt(json["id"]),
      orderId: _toInt(json["orderId"]),
      tableName: json["tableName"] as String? ?? "",
      paymentMethod: json["paymentMethod"] as String? ?? "CASH",
      amount: _toDouble(json["amount"]),
      paidAt: json["paidAt"] as String? ?? "",
      cashierName: json["cashierName"] as String? ?? "-",
      note: json["note"] as String? ?? "",
    );
  }
}
