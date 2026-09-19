import "package:flutter/material.dart";
import "package:intl/intl.dart";
import "../models/dashboard_models.dart";
import "../services/api_client.dart";
import "../services/app_feedback_service.dart";

class AdminTransactionsScreen extends StatefulWidget {
  const AdminTransactionsScreen({super.key});

  @override
  State<AdminTransactionsScreen> createState() =>
      _AdminTransactionsScreenState();
}

class _AdminTransactionsScreenState extends State<AdminTransactionsScreen> {
  bool _isLoading = false;
  int _currentPage = 1;
  int _limit = 50;
  int _totalItems = 0;
  int _totalPages = 0;
  List<PaymentTransaction> _transactions = [];

  // Filters
  DateTime? _startDate;
  DateTime? _endDate;
  String? _paymentMethod;
  double? _minAmount;
  double? _maxAmount;
  String _sortBy = "paid_at";
  String _sortOrder = "DESC";

  final _minAmountController = TextEditingController();
  final _maxAmountController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchTransactions();
  }

  @override
  void dispose() {
    _minAmountController.dispose();
    _maxAmountController.dispose();
    super.dispose();
  }

  Future<void> _fetchTransactions() async {
    setState(() => _isLoading = true);
    try {
      final queryParams = {
        "page": _currentPage,
        "limit": _limit,
        "sortBy": _sortBy,
        "sortOrder": _sortOrder,
      };

      if (_startDate != null) {
        queryParams["startDate"] = _startDate!.toIso8601String();
      }
      if (_endDate != null) {
        queryParams["endDate"] = _endDate!.toIso8601String();
      }
      if (_paymentMethod != null && _paymentMethod != "ALL") {
        queryParams["paymentMethod"] = _paymentMethod!;
      }
      if (_minAmount != null) {
        queryParams["minAmount"] = _minAmount!;
      }
      if (_maxAmount != null) {
        queryParams["maxAmount"] = _maxAmount!;
      }

      final response = await ApiClient.dio.get(
        "/admin/paid-transactions",
        queryParameters: queryParams,
      );
      final data = response.data["data"];

      setState(() {
        _transactions = (data["transactions"] as List)
            .map((e) => PaymentTransaction.fromJson(e))
            .toList();
        _totalItems = data["total"];
        _totalPages = data["totalPages"];
        _currentPage = data["page"];
      });
    } catch (e) {
      AppFeedbackService.showError("Tahsilatlar yüklenemedi: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteTransaction(PaymentTransaction transaction) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Tahsilat Sil"),
        content: Text(
          "#${transaction.orderId} nolu siparişin ${transaction.amount} TL tutarındaki tahsilatını silmek istediğinize emin misiniz?",
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
        await ApiClient.dio.delete("/admin/payments/${transaction.id}");
        AppFeedbackService.showSuccess("Tahsilat silindi.");
        _fetchTransactions();
      } catch (e) {
        AppFeedbackService.showError("Silme işlemi başarısız: $e");
      }
    }
  }

  Future<void> _editTransaction(PaymentTransaction transaction) async {
    String selectedMethod = transaction.paymentMethod;

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          title: const Text("Tahsilat Düzenle"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Ödeme Yöntemi"),
              const SizedBox(height: 8),
              DropdownButton<String>(
                value: selectedMethod,
                isExpanded: true,
                items: const [
                  DropdownMenuItem(value: "CASH", child: Text("Nakit")),
                  DropdownMenuItem(value: "CARD", child: Text("Kredi Kartı")),
                ],
                onChanged: (val) {
                  if (val != null) setModalState(() => selectedMethod = val);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("İptal"),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, selectedMethod),
              child: const Text("Güncelle"),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      try {
        await ApiClient.dio.patch(
          "/admin/payments/${transaction.id}/method",
          data: {"paymentMethod": result},
        );
        AppFeedbackService.showSuccess("Tahsilat güncellendi.");
        _fetchTransactions();
      } catch (e) {
        AppFeedbackService.showError("Güncelleme başarısız: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Tüm Tahsilatlar"),
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
            child: _transactions.isEmpty && !_isLoading
                ? const Center(child: Text("Kayıt bulunamadı."))
                : ListView.separated(
                    itemCount: _transactions.length,
                    separatorBuilder: (ctx, index) => const Divider(),
                    itemBuilder: (ctx, index) {
                      final tx = _transactions[index];
                      final isCash = tx.paymentMethod == "CASH";
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              (isCash ? Colors.orange : Colors.deepPurple)
                                  .withValues(alpha: 0.1),
                          child: Icon(
                            isCash ? Icons.money : Icons.credit_card,
                            color: isCash ? Colors.orange : Colors.deepPurple,
                          ),
                        ),
                        title: Text("${tx.tableName} - #${tx.orderId}"),
                        subtitle: Text(
                          "${DateFormat("dd.MM.yyyy HH:mm").format(DateTime.parse(tx.paidAt))} • ${tx.cashierName}",
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              "${tx.amount.toStringAsFixed(2)} TL",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(width: 8),
                            PopupMenuButton<String>(
                              onSelected: (val) {
                                if (val == "edit") _editTransaction(tx);
                                if (val == "delete") _deleteTransaction(tx);
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
                        _fetchTransactions();
                      }
                    : null,
              ),
              Text("$_currentPage / $_totalPages"),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: _currentPage < _totalPages
                    ? () {
                        setState(() => _currentPage++);
                        _fetchTransactions();
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
                _fetchTransactions();
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
                DropdownButtonFormField<String>(
                  initialValue: _paymentMethod ?? "ALL",
                  style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
                  decoration: const InputDecoration(labelText: "Ödeme Yöntemi"),
                  items: const [
                    DropdownMenuItem(value: "ALL", child: Text("Tümü", style: TextStyle(color: Color(0xFF0F172A)))),
                    DropdownMenuItem(value: "CASH", child: Text("Nakit", style: TextStyle(color: Color(0xFF0F172A)))),
                    DropdownMenuItem(value: "CARD", child: Text("Kredi Kartı", style: TextStyle(color: Color(0xFF0F172A)))),
                  ],
                  onChanged: (val) => setModalState(() => _paymentMethod = val),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _minAmountController,
                        style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: "Min Tutar",
                          labelStyle: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w700),
                        ),
                        onChanged: (val) => _minAmount = double.tryParse(val),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextField(
                        controller: _maxAmountController,
                        style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: "Max Tutar",
                          labelStyle: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w700),
                        ),
                        onChanged: (val) => _maxAmount = double.tryParse(val),
                      ),
                    ),
                  ],
                ),
                const Divider(),
                DropdownButtonFormField<String>(
                  initialValue: _sortBy,
                  style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
                  decoration: const InputDecoration(labelText: "Sıralama"),
                  items: const [
                    DropdownMenuItem(value: "paid_at", child: Text("Tarih", style: TextStyle(color: Color(0xFF0F172A)))),
                    DropdownMenuItem(value: "amount", child: Text("Tutar", style: TextStyle(color: Color(0xFF0F172A)))),
                  ],
                  onChanged: (val) => setModalState(() => _sortBy = val!),
                ),
                DropdownButtonFormField<String>(
                  initialValue: _sortOrder,
                  style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
                  decoration: const InputDecoration(labelText: "Düzen"),
                  items: const [
                    DropdownMenuItem(value: "DESC", child: Text("Azalan", style: TextStyle(color: Color(0xFF0F172A)))),
                    DropdownMenuItem(value: "ASC", child: Text("Artan", style: TextStyle(color: Color(0xFF0F172A)))),
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
                  _paymentMethod = null;
                  _minAmount = null;
                  _maxAmount = null;
                  _sortBy = "paid_at";
                  _sortOrder = "DESC";
                  _minAmountController.clear();
                  _maxAmountController.clear();
                });
                Navigator.pop(ctx);
                _fetchTransactions();
              },
              child: const Text("Sıfırla"),
            ),
            FilledButton(
              onPressed: () {
                setState(() => _currentPage = 1);
                Navigator.pop(ctx);
                _fetchTransactions();
              },
              child: const Text("Uygula"),
            ),
          ],
        ),
      ),
    );
  }
}
