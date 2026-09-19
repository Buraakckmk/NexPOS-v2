import "package:flutter/material.dart";
import "package:intl/intl.dart";
import "../models/dashboard_models.dart";
import "../services/api_client.dart";
import "../services/app_feedback_service.dart";

class AdminExpensesScreen extends StatefulWidget {
  const AdminExpensesScreen({super.key});

  @override
  State<AdminExpensesScreen> createState() => _AdminExpensesScreenState();
}

class _AdminExpensesScreenState extends State<AdminExpensesScreen> {
  bool _isLoading = false;
  int _currentPage = 1;
  int _limit = 50;
  int _totalItems = 0;
  int _totalPages = 0;
  List<Expense> _expenses = [];

  // Filters
  DateTime? _startDate;
  DateTime? _endDate;
  double? _minAmount;
  double? _maxAmount;
  String? _search;
  String _sortBy = "expense_date";
  String _sortOrder = "DESC";

  final _minAmountController = TextEditingController();
  final _maxAmountController = TextEditingController();
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchExpenses();
  }

  @override
  void dispose() {
    _minAmountController.dispose();
    _maxAmountController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchExpenses() async {
    setState(() => _isLoading = true);
    try {
      final queryParams = {
        "page": _currentPage,
        "limit": _limit,
        "sortBy": _sortBy,
        "sortOrder": _sortOrder,
      };

      if (_startDate != null) {
        queryParams["startDate"] = DateFormat("yyyy-MM-dd").format(_startDate!);
      }
      if (_endDate != null) {
        queryParams["endDate"] = DateFormat("yyyy-MM-dd").format(_endDate!);
      }
      if (_minAmount != null) {
        queryParams["minAmount"] = _minAmount!;
      }
      if (_maxAmount != null) {
        queryParams["maxAmount"] = _maxAmount!;
      }
      if (_search != null && _search!.isNotEmpty) {
        queryParams["search"] = _search!;
      }

      final response = await ApiClient.dio.get(
        "/admin/expenses",
        queryParameters: queryParams,
      );
      final data = response.data["data"];

      setState(() {
        _expenses = (data["expenses"] as List)
            .map((e) => Expense.fromJson(e))
            .toList();
        _totalItems = data["total"];
        _totalPages = data["totalPages"];
        _currentPage = data["page"];
      });
    } catch (e) {
      AppFeedbackService.showError("Giderler yüklenemedi: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteExpense(Expense expense) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Gider Sil"),
        content: Text(
          "${expense.itemName} (${expense.totalAmount} TL) giderini silmek istediğinize emin misiniz?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Vazgeç"),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Sil"),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ApiClient.dio.delete("/admin/expenses/${expense.id}");
        AppFeedbackService.showSuccess("Gider silindi.");
        _fetchExpenses();
      } catch (e) {
        AppFeedbackService.showError("Silme işlemi başarısız: $e");
      }
    }
  }

  Future<void> _editExpense(Expense expense) async {
    final nameController = TextEditingController(text: expense.itemName);
    final quantityController = TextEditingController(
      text: expense.quantity.toString(),
    );
    final priceController = TextEditingController(
      text: expense.unitPrice.toString(),
    );
    final noteController = TextEditingController(text: expense.note ?? "");
    DateTime selectedDate = DateTime.parse(expense.expenseDate);

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          title: const Text("Gider Düzenle", style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
                  decoration: const InputDecoration(
                    labelText: "Ürün/Hizmet Adı",
                    labelStyle: TextStyle(color: Color(0xFF059669), fontWeight: FontWeight.w700),
                  ),
                ),
                TextField(
                  controller: quantityController,
                  style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
                  decoration: const InputDecoration(
                    labelText: "Miktar",
                    labelStyle: TextStyle(color: Color(0xFF059669), fontWeight: FontWeight.w700),
                  ),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: priceController,
                  style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
                  decoration: const InputDecoration(
                    labelText: "Birim Fiyat (TL)",
                    labelStyle: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w700),
                  ),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: noteController,
                  style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
                  decoration: const InputDecoration(
                    labelText: "Not",
                    labelStyle: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w700),
                  ),
                ),
                ListTile(
                  title: const Text("Tarih"),
                  subtitle: Text(DateFormat("dd.MM.yyyy").format(selectedDate)),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (date != null) setModalState(() => selectedDate = date);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("İptal"),
            ),
            FilledButton(
              onPressed: () {
                if (nameController.text.isEmpty) {
                  AppFeedbackService.showError("Ad boş olamaz.");
                  return;
                }
                Navigator.pop(ctx, true);
              },
              child: const Text("Güncelle"),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      try {
        await ApiClient.dio.patch(
          "/admin/expenses/${expense.id}",
          data: {
            "item_name": nameController.text,
            "quantity": double.tryParse(quantityController.text) ?? 1,
            "unit_price": double.tryParse(priceController.text) ?? 0,
            "note": noteController.text,
            "expense_date": DateFormat("yyyy-MM-dd").format(selectedDate),
          },
        );
        AppFeedbackService.showSuccess("Gider güncellendi.");
        _fetchExpenses();
      } catch (e) {
        AppFeedbackService.showError("Güncelleme başarısız: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Tüm Giderler"),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isLoading) const LinearProgressIndicator(),
          Expanded(
            child: _expenses.isEmpty && !_isLoading
                ? const Center(child: Text("Kayıt bulunamadı."))
                : ListView.separated(
                    itemCount: _expenses.length,
                    separatorBuilder: (ctx, index) => const Divider(),
                    itemBuilder: (ctx, index) {
                      final exp = _expenses[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.red.withValues(alpha: 0.1),
                          child: const Icon(Icons.outbound, color: Colors.red),
                        ),
                        title: Text(exp.itemName),
                        subtitle: Text(
                          "${DateFormat("dd.MM.yyyy").format(DateTime.parse(exp.expenseDate))} • ${exp.quantity} x ${exp.unitPrice.toStringAsFixed(2)} TL • ${exp.createdBy}",
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              "-${exp.totalAmount.toStringAsFixed(2)} TL",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.red,
                              ),
                            ),
                            const SizedBox(width: 8),
                            PopupMenuButton<String>(
                              onSelected: (val) {
                                if (val == "edit") _editExpense(exp);
                                if (val == "delete") _deleteExpense(exp);
                              },
                              itemBuilder: (ctx) => [
                                const PopupMenuItem(
                                  value: "edit",
                                  child: Text("Düzenle"),
                                ),
                                const PopupMenuItem(
                                  value: "delete",
                                  child: Text("Sil"),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          _buildPagination(),
        ],
      ),
    );
  }

  Widget _buildPagination() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text("Toplam: $_totalItems"),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: _currentPage > 1
                    ? () {
                        setState(() => _currentPage--);
                        _fetchExpenses();
                      }
                    : null,
              ),
              Text("$_currentPage / $_totalPages"),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: _currentPage < _totalPages
                    ? () {
                        setState(() => _currentPage++);
                        _fetchExpenses();
                      }
                    : null,
              ),
            ],
          ),
          DropdownButton<int>(
            value: _limit,
            items: [10, 50, 100]
                .map((e) => DropdownMenuItem(value: e, child: Text("$e")))
                .toList(),
            onChanged: (val) {
              if (val != null) {
                setState(() {
                  _limit = val;
                  _currentPage = 1;
                });
                _fetchExpenses();
              }
            },
          ),
        ],
      ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          title: const Text("Filtrele ve Sırala"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    labelText: "Arama (Ürün Adı)",
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (val) => _search = val,
                ),
                ListTile(
                  title: const Text("Başlangıç Tarihi"),
                  subtitle: Text(
                    _startDate == null
                        ? "Seçilmedi"
                        : DateFormat("dd.MM.yyyy").format(_startDate!),
                  ),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _startDate ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (date != null) setModalState(() => _startDate = date);
                  },
                ),
                ListTile(
                  title: const Text("Bitiş Tarihi"),
                  subtitle: Text(
                    _endDate == null
                        ? "Seçilmedi"
                        : DateFormat("dd.MM.yyyy").format(_endDate!),
                  ),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _endDate ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (date != null) setModalState(() => _endDate = date);
                  },
                ),
                const Divider(),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _minAmountController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: "Min Tutar",
                        ),
                        onChanged: (val) => _minAmount = double.tryParse(val),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextField(
                        controller: _maxAmountController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: "Max Tutar",
                        ),
                        onChanged: (val) => _maxAmount = double.tryParse(val),
                      ),
                    ),
                  ],
                ),
                const Divider(),
                DropdownButtonFormField<String>(
                  initialValue: _sortBy,
                  decoration: const InputDecoration(labelText: "Sıralama"),
                  items: const [
                    DropdownMenuItem(
                      value: "expense_date",
                      child: Text("Tarih"),
                    ),
                    DropdownMenuItem(
                      value: "total_amount",
                      child: Text("Tutar"),
                    ),
                  ],
                  onChanged: (val) => setModalState(() => _sortBy = val!),
                ),
                DropdownButtonFormField<String>(
                  initialValue: _sortOrder,
                  decoration: const InputDecoration(labelText: "Düzen"),
                  items: const [
                    DropdownMenuItem(value: "DESC", child: Text("Azalan")),
                    DropdownMenuItem(value: "ASC", child: Text("Artan")),
                  ],
                  onChanged: (val) => setModalState(() => _sortOrder = val!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                setState(() {
                  _startDate = null;
                  _endDate = null;
                  _minAmount = null;
                  _maxAmount = null;
                  _search = null;
                  _sortBy = "expense_date";
                  _sortOrder = "DESC";
                  _minAmountController.clear();
                  _maxAmountController.clear();
                  _searchController.clear();
                });
                Navigator.pop(ctx);
                _fetchExpenses();
              },
              child: const Text("Sıfırla"),
            ),
            FilledButton(
              onPressed: () {
                setState(() => _currentPage = 1);
                Navigator.pop(ctx);
                _fetchExpenses();
              },
              child: const Text("Uygula"),
            ),
          ],
        ),
      ),
    );
  }
}
