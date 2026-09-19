import 'package:flutter/material.dart';
import '../services/customer_service.dart';
import '../services/app_feedback_service.dart';

class AdminCustomersScreen extends StatefulWidget {
  const AdminCustomersScreen({super.key});

  @override
  State<AdminCustomersScreen> createState() => _AdminCustomersScreenState();
}

class _AdminCustomersScreenState extends State<AdminCustomersScreen> {
  final CustomerService _customerService = CustomerService();
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _customers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCustomers() async {
    setState(() => _isLoading = true);
    try {
      final list = await _customerService.listCustomers(search: _searchController.text);
      if (!mounted) return;
      setState(() {
        _customers = list;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      AppFeedbackService.showError("Müşteri listesi yüklenemedi: $e");
    }
  }

  void _showAddCustomerDialog() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final noteCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (dlgContext) => AlertDialog(
        title: const Text("Yeni Müşteri (Cari Hesabı)"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: "Ad Soyad *", prefixIcon: Icon(Icons.person)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: "Telefon", prefixIcon: Icon(Icons.phone)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: "E-Posta", prefixIcon: Icon(Icons.email)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteCtrl,
              decoration: const InputDecoration(labelText: "Not", prefixIcon: Icon(Icons.note)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlgContext),
            child: const Text("İptal"),
          ),
          FilledButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) {
                AppFeedbackService.showError("Müşteri adı zorunludur.");
                return;
              }
              try {
                await _customerService.createCustomer(
                  fullName: nameCtrl.text.trim(),
                  phone: phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
                  email: emailCtrl.text.trim().isEmpty ? null : emailCtrl.text.trim(),
                  note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
                );
                if (!dlgContext.mounted) return;
                Navigator.pop(dlgContext);
                AppFeedbackService.showSuccess("Müşteri eklendi.");
                _loadCustomers();
              } catch (e) {
                AppFeedbackService.showError("Müşteri eklenemedi: $e");
              }
            },
            child: const Text("Kaydet"),
          ),
        ],
      ),
    );
  }

  void _showTransactionDialog(Map<String, dynamic> customer) {
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    String txType = 'CREDIT'; // CREDIT = Tahsilat (Borç düşer), DEBIT = Borç Ekleme

    showDialog(
      context: context,
      builder: (dlgContext) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          title: Text("${customer['full_name']} - İşlem Ekle"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Text("Tahsilat Al (Borç Düş)"),
                      selected: txType == 'CREDIT',
                      onSelected: (val) => setDlgState(() => txType = 'CREDIT'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ChoiceChip(
                      label: const Text("Borç Ekle"),
                      selected: txType == 'DEBIT',
                      onSelected: (val) => setDlgState(() => txType = 'DEBIT'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: "Tutar (TL) *", prefixIcon: Icon(Icons.currency_lira)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteCtrl,
                decoration: const InputDecoration(labelText: "İşlem Açıklaması", prefixIcon: Icon(Icons.description)),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dlgContext),
              child: const Text("İptal"),
            ),
            FilledButton(
              onPressed: () async {
                final amount = double.tryParse(amountCtrl.text.replaceAll(',', '.'));
                if (amount == null || amount <= 0) {
                  AppFeedbackService.showError("Geçerli bir tutar girin.");
                  return;
                }
                try {
                  await _customerService.addTransaction(
                    customerId: customer['id'],
                    type: txType,
                    amount: amount,
                    note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
                  );
                  if (!dlgContext.mounted) return;
                  Navigator.pop(dlgContext);
                  AppFeedbackService.showSuccess("Cari işlem kaydedildi.");
                  _loadCustomers();
                } catch (e) {
                  AppFeedbackService.showError("İşlem kaydedilemedi: $e");
                }
              },
              child: const Text("Kaydet"),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Müşteri / Cari Hesap Yönetimi"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadCustomers,
            tooltip: "Yenile",
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddCustomerDialog,
        icon: const Icon(Icons.person_add),
        label: const Text("Yeni Müşteri"),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => _loadCustomers(),
              decoration: InputDecoration(
                hintText: "Müşteri adı veya telefon ile ara...",
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _loadCustomers();
                        },
                      )
                    : null,
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _customers.isEmpty
                    ? const Center(child: Text("Kayıtlı müşteri bulunamadı."))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: _customers.length,
                        itemBuilder: (context, index) {
                          final c = _customers[index];
                          final balance = double.tryParse(c['balance'].toString()) ?? 0.0;
                          final isDebt = balance > 0;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: isDebt
                                    ? Colors.amber.shade100
                                    : const Color(0xFFD1FAE5),
                                child: Icon(
                                  Icons.person,
                                  color: isDebt ? Colors.amber.shade900 : const Color(0xFF065F46),
                                ),
                              ),
                              title: Text(
                                c['full_name'] ?? '',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              subtitle: Text(
                                "${c['phone'] ?? 'Telefon yok'} ${c['note'] != null ? '• ${c['note']}' : ''}",
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        "${balance.toStringAsFixed(2)} TL",
                                        style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 16,
                                          color: isDebt ? Colors.red.shade700 : const Color(0xFF047857),
                                        ),
                                      ),
                                      Text(
                                        isDebt ? "Borçlu" : "Bakiye Temiz",
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: isDebt ? Colors.red.shade700 : const Color(0xFF047857),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.payment),
                                    tooltip: "Cari İşlem / Tahsilat",
                                    onPressed: () => _showTransactionDialog(c),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
