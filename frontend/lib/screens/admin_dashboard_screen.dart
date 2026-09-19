import "package:flutter/material.dart";
import "package:fl_chart/fl_chart.dart";
import "package:provider/provider.dart";

import "../services/api_client.dart";
import "../services/socket_service.dart";
import "../widgets/x_report_preview_dialog.dart";
import "../models/payment_models.dart";
import "../models/dashboard_models.dart";
import "../providers/auth_provider.dart";
import "login_screen.dart";
import "admin_menu_management_screen.dart";
import "waiter_tables_screen.dart";
import "admin_transactions_screen.dart";
import "admin_expenses_screen.dart";
import "admin_customers_screen.dart";

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  static const String _adminDeletePin = "2323";

  late Future<DailySummary> _summaryFuture;
  late Future<AdminStats> _statsFuture;
  late Future<List<Expense>> _expensesFuture;
  late Future<List<PaymentTransaction>> _transactionsFuture;
  late Future<List<TableItem>> _customTablesFuture;
  late Future<List<dynamic>> _combinedFuture;

  late TabController _tabController;
  bool _isGeneratingZReport = false;
  bool _isFetchingXReport = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initFutures();
    _setupSocketListeners();
  }

  void _setupSocketListeners() {
    final socket = SocketService().socket;
    if (socket != null) {
      socket.on("orders:refresh", (_) => _refreshData());
      socket.on("tables:refresh", (_) => _refreshData());
      socket.on("payment:completed", (_) => _refreshData());
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    final socket = SocketService().socket;
    if (socket != null) {
      socket.off("orders:refresh");
      socket.off("tables:refresh");
      socket.off("payment:completed");
    }
    super.dispose();
  }

  void _initFutures() {
    _summaryFuture = _fetchDailySummary();
    _statsFuture = _fetchStats();
    _expensesFuture = _fetchExpenses();
    _transactionsFuture = _fetchTransactions();
    _customTablesFuture = _fetchCustomTables();
    _combinedFuture = Future.wait([
      _summaryFuture,
      _statsFuture,
      _expensesFuture,
      _transactionsFuture,
      _customTablesFuture,
    ]);
  }

  void _refreshData() {
    if (mounted) {
      setState(() {
        _initFutures();
      });
    }
  }

  Future<void> _logout() async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (ctx) => Theme(
        data: ThemeData.light(useMaterial3: true).copyWith(
          colorScheme: const ColorScheme.light(
            surface: Colors.white,
            onSurface: Color(0xFF0F172A),
          ),
        ),
        child: AlertDialog(
          backgroundColor: Colors.white,
          title: const Text(
            "Çıkış Yap",
            style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold),
          ),
          content: const Text(
            "Yönetici panelinden çıkış yapmak istiyor musunuz?",
            style: TextStyle(color: Color(0xFF334155)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text("Vazgeç"),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white,
              ),
              child: const Text("Çıkış Yap"),
            ),
          ],
        ),
      ),
    );

    if (approved != true || !mounted) return;

    await context.read<AuthProvider>().logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Future<DailySummary> _fetchDailySummary() async {
    try {
      final response = await ApiClient.dio.get("/admin/daily-summary");
      final data = response.data as Map<String, dynamic>;
      final summaryData = data["data"] as Map<String, dynamic>?;
      if (summaryData == null) throw Exception("Veri bulunamadı");
      return DailySummary.fromJson(summaryData);
    } catch (e) {
      throw Exception("Günlük özet alınamadı: $e");
    }
  }

  Future<AdminStats> _fetchStats() async {
    try {
      final response = await ApiClient.dio.get("/admin/stats");
      final data = response.data as Map<String, dynamic>;
      final statsData = data["data"] as Map<String, dynamic>?;
      if (statsData == null) throw Exception("Veri bulunamadı");
      return AdminStats.fromJson(statsData);
    } catch (e) {
      throw Exception("İstatistikler alınamadı: $e");
    }
  }

  Future<List<Expense>> _fetchExpenses() async {
    try {
      final response = await ApiClient.dio.get("/admin/expenses");
      final data = response.data as Map<String, dynamic>;
      final list = data["data"] as List<dynamic>? ?? [];
      return list
          .map((e) => Expense.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<PaymentTransaction>> _fetchTransactions() async {
    try {
      final response = await ApiClient.dio.get("/admin/paid-transactions");
      final data = response.data as Map<String, dynamic>;
      final list = data["data"] as List<dynamic>? ?? [];
      return list
          .map((e) => PaymentTransaction.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<TableItem>> _fetchCustomTables() async {
    try {
      final response = await ApiClient.dio.get("/waiter/tables");
      final data = response.data as Map<String, dynamic>;
      final list = data["data"] as List<dynamic>? ?? [];
      return list
          .map((e) => TableItem.fromJson(e as Map<String, dynamic>))
          .where((t) => t.isCustom)
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> _deleteExpense(int expenseId) async {
    final verified = await _verifyDeletePin();
    if (verified != true) return;

    try {
      await ApiClient.dio.delete("/admin/expenses/$expenseId");
      _refreshData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Gider silinemedi: $e"),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  Future<bool?> _verifyDeletePin() async {
    final pinController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text("Silme Şifresi", style: TextStyle(color: Color(0xFF0F172A))),
        content: TextField(
          controller: pinController,
          autofocus: true,
          keyboardType: TextInputType.number,
          obscureText: true,
          decoration: const InputDecoration(hintText: "Silme şifresini girin"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text("Vazgeç"),
          ),
          FilledButton(
            onPressed: () {
              final isValid = pinController.text.trim() == _adminDeletePin;
              Navigator.of(ctx).pop(isValid);
            },
            child: const Text("Doğrula"),
          ),
        ],
      ),
    );

    if (result != true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Silme şifresi hatalı."),
          backgroundColor: Color(0xFFB91C1C),
        ),
      );
    }

    return result;
  }

  Future<void> _showAddExpenseDialog() async {
    final nameController = TextEditingController();
    final quantityController = TextEditingController(text: "1");
    final priceController = TextEditingController();
    final noteController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Gider Ekle", style: TextStyle(color: Color(0xFF0F172A))),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: "Ürün/Hizmet Adı"),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: quantityController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Miktar"),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: priceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Birim Fiyat (TL)",
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteController,
                decoration: const InputDecoration(labelText: "Not (Opsiyonel)"),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Vazgeç"),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isEmpty || priceController.text.isEmpty) {
                return;
              }
              try {
                await ApiClient.dio.post(
                  "/admin/expenses",
                  data: {
                    "item_name": nameController.text,
                    "quantity": double.tryParse(quantityController.text) ?? 1,
                    "unit_price": double.tryParse(priceController.text) ?? 0,
                    "note": noteController.text,
                  },
                );
                if (context.mounted) Navigator.pop(context, true);
              } catch (e) {
                // handled by interceptor
              }
            },
            child: const Text("Kaydet"),
          ),
        ],
      ),
    );

    if (result == true) {
      _refreshData();
    }
  }

  Future<void> _fetchXReport() async {
    setState(() => _isFetchingXReport = true);
    try {
      final response = await ApiClient.dio.get("/admin/x-report");
      final data = response.data as Map<String, dynamic>;
      final xReportData = XReportData.fromJson(
        data["data"] as Map<String, dynamic>,
      );

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => XReportPreviewDialog(data: xReportData),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("X Raporu alınamadı: ${e.toString()}"),
            backgroundColor: const Color(0xFFB91C1C),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isFetchingXReport = false);
      }
    }
  }

  Future<void> _generateZReport() async {
    final approved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Günü Kapat (Z Raporu)", style: TextStyle(color: Color(0xFF0F172A))),
        content: const Text(
          "Gün sonu raporu oluşturulacak ve sistem kapatılacak. Devam etmek istiyor musunuz?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text("Vazgeç"),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text("Onayla"),
          ),
        ],
      ),
    );

    if (approved != true || !mounted) return;

    setState(() => _isGeneratingZReport = true);

    try {
      await ApiClient.dio.post("/admin/z-report");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Z Raporu başarıyla oluşturuldu!"),
            backgroundColor: Color(0xFF166534),
          ),
        );
        _refreshData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Z Raporu oluşturulamadı: ${e.toString()}"),
            backgroundColor: const Color(0xFFB91C1C),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGeneratingZReport = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Column(
          children: [
            // ── ÜST BAR / MODERN HEADER ─────────────────────────────────
            _buildModernHeader(context),

            // ── İÇERİK BÖLGESİ (BEYAZ TEMA DÜZELTMESİ) ───────────────────
            Expanded(
              child: Theme(
                data: ThemeData.light(useMaterial3: true).copyWith(
                  colorScheme: const ColorScheme.light(
                    surface: Colors.white,
                    onSurface: Color(0xFF0F172A),
                  ),
                  textTheme: ThemeData.light().textTheme.apply(
                    bodyColor: const Color(0xFF0F172A),
                    displayColor: const Color(0xFF0F172A),
                  ),
                ),
                child: Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: FutureBuilder<List<dynamic>>(
                    future: _combinedFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(color: Color(0xFF10B981)),
                        );
                      }

                      if (snapshot.hasError) {
                        return _buildErrorState(snapshot.error);
                      }

                      final summary = snapshot.data![0] as DailySummary;
                      final stats = snapshot.data![1] as AdminStats;
                      final expenses = snapshot.data![2] as List<Expense>;
                      final transactions = snapshot.data![3] as List<PaymentTransaction>;
                      final customTables = snapshot.data![4] as List<TableItem>;

                      final totalExpensesSum = expenses.fold<double>(
                        0.0,
                        (sum, item) => sum + item.totalAmount,
                      );

                      return RefreshIndicator(
                        onRefresh: () async => _refreshData(),
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // ── METRİK KARTLARI (KPI) ────────────────────
                              _buildKpiMetricsGrid(summary, totalExpensesSum),

                              const SizedBox(height: 24),

                              // ── SEKMELİ GEZİNTİ BARI ─────────────────────
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF1E293B).withValues(alpha: 0.05),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: TabBar(
                                  controller: _tabController,
                                  labelColor: const Color(0xFF0F172A),
                                  unselectedLabelColor: const Color(0xFF64748B),
                                  labelStyle: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                  ),
                                  indicatorColor: const Color(0xFF10B981),
                                  indicatorWeight: 3,
                                  tabs: const [
                                    Tab(
                                      icon: Icon(Icons.bar_chart_rounded),
                                      text: "Analiz & Grafikler",
                                    ),
                                    Tab(
                                      icon: Icon(Icons.receipt_long_rounded),
                                      text: "Tahsilat & Giderler",
                                    ),
                                    Tab(
                                      icon: Icon(Icons.grid_view_rounded),
                                      text: "Hızlı Modüller & Masalar",
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 20),

                              // ── SEKME İÇERİKLERİ ──────────────────────────
                              SizedBox(
                                height: 620,
                                child: TabBarView(
                                  controller: _tabController,
                                  children: [
                                    // Sekme 1: Grafikler
                                    _buildChartsTab(stats),
                                    // Sekme 2: İşlem Hareketleri
                                    _buildTransactionsTab(transactions, expenses),
                                    // Sekme 3: Modüller & Özel Masalar
                                    _buildModulesTab(customTables),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── HEADER DESIGN ───────────────────────────────────────────────────
  Widget _buildModernHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      color: const Color(0xFF0F172A),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF10B981).withValues(alpha: 0.3),
              ),
            ),
            child: const Icon(
              Icons.dashboard_rounded,
              color: Color(0xFF10B981),
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "NEXPOS YÖNETİCİ KONTROL PANELİ",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  letterSpacing: -0.3,
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFF10B981),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    "Canlı Ağ Bağlantısı Aktif",
                    style: TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const Spacer(),
          // Hızlı Butonlar
          _buildHeaderPillButton(
            icon: Icons.account_balance_wallet_rounded,
            label: "Cari Hesaplar",
            color: const Color(0xFF8B5CF6),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AdminCustomersScreen()),
              );
            },
          ),
          const SizedBox(width: 8),
          _buildHeaderPillButton(
            icon: Icons.inventory_2_rounded,
            label: "Ürün Yönetimi",
            color: const Color(0xFF0EA5E9),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AdminMenuManagementScreen()),
              );
            },
          ),
          const SizedBox(width: 8),
          _buildHeaderPillButton(
            icon: Icons.description_rounded,
            label: "X Raporu",
            color: const Color(0xFFF59E0B),
            isLoading: _isFetchingXReport,
            onPressed: _isFetchingXReport ? null : _fetchXReport,
          ),
          const SizedBox(width: 8),
          _buildHeaderPillButton(
            icon: Icons.power_settings_new_rounded,
            label: "Günü Kapat",
            color: const Color(0xFFEF4444),
            isLoading: _isGeneratingZReport,
            onPressed: _isGeneratingZReport ? null : _generateZReport,
          ),
          const SizedBox(width: 8),
          _buildHeaderPillButton(
            icon: Icons.logout_rounded,
            label: "Çıkış Yap",
            color: const Color(0xFF475569),
            onPressed: _logout,
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            tooltip: "Yenile",
            onPressed: _refreshData,
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderPillButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback? onPressed,
    bool isLoading = false,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: isLoading
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
          : Icon(icon, size: 16, color: Colors.white),
      label: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ── KPI METRİKLERİ (GRADIENT KARTLAR) ──────────────────────────────────
  Widget _buildKpiMetricsGrid(DailySummary summary, double totalExpenses) {
    final netKasa = summary.totalRevenue - totalExpenses;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 1000;

        return GridView.count(
          crossAxisCount: isDesktop ? 4 : 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          childAspectRatio: isDesktop ? 1.85 : 1.5,
          children: [
            _buildGradientCard(
              title: "Günlük Ciro",
              value: "${summary.totalRevenue.toStringAsFixed(0)} ₺",
              subText: "Nakit: ${summary.cashTotal.toStringAsFixed(0)}₺ • Kart: ${summary.cardTotal.toStringAsFixed(0)}₺",
              icon: Icons.payments_rounded,
              gradientColors: [const Color(0xFF059669), const Color(0xFF10B981)],
            ),
            _buildGradientCard(
              title: "Adisyon Sayısı",
              value: "${summary.totalOrders} Adet",
              subText: "Tamamlanan Masalar",
              icon: Icons.receipt_long_rounded,
              gradientColors: [const Color(0xFF2563EB), const Color(0xFF3B82F6)],
            ),
            _buildGradientCard(
              title: "Net Kasa Durumu",
              value: "${netKasa.toStringAsFixed(0)} ₺",
              subText: "Giderler: ${totalExpenses.toStringAsFixed(0)} ₺",
              icon: Icons.account_balance_rounded,
              gradientColors: netKasa >= 0
                  ? [const Color(0xFF0F766E), const Color(0xFF14B8A6)]
                  : [const Color(0xFFBE123C), const Color(0xFFF43F5E)],
            ),
            _buildGradientCard(
              title: "Hızlı İşlemler",
              value: "Cari & Kasa",
              subText: "Müşteri Borç / Tahsilat",
              icon: Icons.account_balance_wallet_rounded,
              gradientColors: [const Color(0xFF6D28D9), const Color(0xFF8B5CF6)],
            ),
          ],
        );
      },
    );
  }

  Widget _buildGradientCard({
    required String title,
    required String value,
    required String subText,
    required IconData icon,
    required List<Color> gradientColors,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: gradientColors.last.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title.toUpperCase(),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  letterSpacing: 0.8,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
            ],
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 24,
              letterSpacing: -0.5,
            ),
          ),
          Text(
            subText,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ── SEKME 1: ANALİZ & GRAFİKLER ──────────────────────────────────────
  Widget _buildChartsTab(AdminStats stats) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: Column(
            children: [
              Expanded(
                child: _buildWeeklyRevenueChart(stats.weeklyRevenue),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _buildTopProductsChart(stats.topProducts),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 2,
          child: _buildCategorySalesChart(stats.categorySales),
        ),
      ],
    );
  }

  // ── SEKME 2: TAHSİLAT & GİDERLER ────────────────────────────────────
  Widget _buildTransactionsTab(
    List<PaymentTransaction> transactions,
    List<Expense> expenses,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeaderWithActions(
                "Son Tahsilatlar",
                onSeeAll: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AdminTransactionsScreen(),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(child: _buildTransactionsCard(transactions)),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeaderWithActions(
                "Son Giderler",
                onAdd: _showAddExpenseDialog,
                onSeeAll: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AdminExpensesScreen(),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(child: _buildExpensesCard(expenses)),
            ],
          ),
        ),
      ],
    );
  }

  // ── SEKME 3: HIZLI MODÜLLER & MASALAR ─────────────────────────────
  Widget _buildModulesTab(List<TableItem> customTables) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "HIZLI MODÜLLER",
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFF1F5F9),
                    child: Icon(Icons.account_balance_wallet, color: Color(0xFF8B5CF6)),
                  ),
                  title: const Text(
                    "Cari & Müşteri Hesabı Yönetimi",
                    style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  subtitle: const Text(
                    "Müşteri veresiye bakiyelerini takip edin ve tahsilat girin",
                    style: TextStyle(color: Color(0xFF64748B)),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF0F172A)),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AdminCustomersScreen()),
                    );
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFF1F5F9),
                    child: Icon(Icons.inventory_2, color: Color(0xFF0EA5E9)),
                  ),
                  title: const Text(
                    "Ürün & Menü Yönetimi",
                    style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  subtitle: const Text(
                    "Kategori ekleyin, ürün fiyatlarını ve yazıcı rotalarını güncelleyin",
                    style: TextStyle(color: Color(0xFF64748B)),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF0F172A)),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AdminMenuManagementScreen()),
                    );
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFF1F5F9),
                    child: Icon(Icons.table_restaurant, color: Color(0xFF10B981)),
                  ),
                  title: const Text(
                    "Masalar Görünümüne Geç",
                    style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  subtitle: const Text(
                    "Oyun Salonu ve VIP masalarını canlı izleyin",
                    style: TextStyle(color: Color(0xFF64748B)),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF0F172A)),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const WaiterTablesScreen()),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader("Özel Masalar"),
              const SizedBox(height: 8),
              Expanded(child: _buildCustomTablesCard(customTables)),
            ],
          ),
        ),
      ],
    );
  }

  // ── GRAFİK BİLEŞENLERİ ──────────────────────────────────────────────
  Widget _buildWeeklyRevenueChart(List<WeeklyRevenue> data) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Haftalık Ciro Trendi",
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: data.isEmpty
                ? const Center(child: Text("Veri yok", style: TextStyle(color: Color(0xFF64748B))))
                : BarChart(
                    BarChartData(
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (val, meta) {
                              final index = val.toInt();
                              if (index >= 0 && index < data.length) {
                                return Text(
                                  data[index].dayName,
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                );
                              }
                              return const SizedBox();
                            },
                          ),
                        ),
                      ),
                      barGroups: data.asMap().entries.map((e) {
                        return BarChartGroupData(
                          x: e.key,
                          barRods: [
                            BarChartRodData(
                              toY: e.value.revenue,
                              color: const Color(0xFF10B981),
                              width: 16,
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySalesChart(List<CategorySales> data) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Kategori Dağılımı",
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: data.isEmpty
                ? const Center(child: Text("Veri yok", style: TextStyle(color: Color(0xFF64748B))))
                : PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 40,
                      sections: data.asMap().entries.map((e) {
                        final colors = [
                          const Color(0xFF10B981),
                          const Color(0xFF3B82F6),
                          const Color(0xFF8B5CF6),
                          const Color(0xFFF59E0B),
                          const Color(0xFFEF4444),
                        ];
                        return PieChartSectionData(
                          color: colors[e.key % colors.length],
                          value: e.value.revenue,
                          title: "${e.value.name}\n${e.value.revenue.toStringAsFixed(0)}₺",
                          radius: 55,
                          titleStyle: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopProductsChart(List<TopProduct> data) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "En Çok Satılan Ürünler",
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: data.isEmpty
                ? const Center(child: Text("Veri yok", style: TextStyle(color: Color(0xFF64748B))))
                : ListView.builder(
                    itemCount: data.length,
                    itemBuilder: (context, index) {
                      final item = data[index];
                      return ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          radius: 14,
                          backgroundColor: const Color(0xFFE0F2FE),
                          child: Text(
                            "${index + 1}",
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0369A1),
                            ),
                          ),
                        ),
                        title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                        trailing: Text(
                          "${item.quantity.toStringAsFixed(0)} Adet",
                          style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionsCard(List<PaymentTransaction> transactions) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: transactions.isEmpty
          ? const Center(child: Text("Tahsilat kaydı yok", style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600)))
          : ListView.builder(
              itemCount: transactions.length,
              itemBuilder: (context, index) {
                final tx = transactions[index];
                return ListTile(
                  dense: true,
                  leading: Icon(
                    tx.paymentMethod == "CASH"
                        ? Icons.money_rounded
                        : tx.paymentMethod == "CUSTOMER"
                        ? Icons.account_balance_wallet_rounded
                        : Icons.credit_card_rounded,
                    color: tx.paymentMethod == "CASH"
                        ? const Color(0xFF10B981)
                        : tx.paymentMethod == "CUSTOMER"
                        ? const Color(0xFF8B5CF6)
                        : const Color(0xFF3B82F6),
                  ),
                  title: Text(
                    "Masa: ${tx.tableName}",
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  subtitle: Text(
                    "${tx.cashierName} • ${tx.paymentMethod}",
                    style: const TextStyle(color: Color(0xFF64748B)),
                  ),
                  trailing: Text(
                    "${tx.amount.toStringAsFixed(2)} TL",
                    style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF10B981)),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildExpensesCard(List<Expense> expenses) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: expenses.isEmpty
          ? const Center(child: Text("Gider kaydı yok", style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600)))
          : ListView.builder(
              itemCount: expenses.length,
              itemBuilder: (context, index) {
                final exp = expenses[index];
                return ListTile(
                  dense: true,
                  leading: const Icon(Icons.remove_circle_outline, color: Color(0xFFEF4444)),
                  title: Text(
                    exp.itemName,
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  subtitle: Text(
                    "${exp.quantity} x ${exp.unitPrice} TL",
                    style: const TextStyle(color: Color(0xFF64748B)),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "${exp.totalAmount.toStringAsFixed(2)} TL",
                        style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFFEF4444)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18, color: Colors.grey),
                        onPressed: () => _deleteExpense(exp.id),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _buildCustomTablesCard(List<TableItem> customTables) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: customTables.isEmpty
          ? const Center(child: Text("Özel masa yok", style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600)))
          : ListView.builder(
              itemCount: customTables.length,
              itemBuilder: (context, index) {
                final table = customTables[index];
                return ListTile(
                  dense: true,
                  leading: const Icon(Icons.table_restaurant, color: Color(0xFF8B5CF6)),
                  title: Text(
                    table.label,
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  subtitle: Text(
                    "Bölge: ${table.zone}",
                    style: const TextStyle(color: Color(0xFF64748B)),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontWeight: FontWeight.w900,
        fontSize: 16,
        color: Color(0xFF0F172A),
      ),
    );
  }

  Widget _buildSectionHeaderWithActions(
    String title, {
    VoidCallback? onAdd,
    VoidCallback? onSeeAll,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 16,
            color: Color(0xFF0F172A),
          ),
        ),
        Row(
          children: [
            if (onAdd != null)
              IconButton(
                icon: const Icon(Icons.add_circle_outline, color: Color(0xFF10B981)),
                onPressed: onAdd,
              ),
            if (onSeeAll != null)
              TextButton(
                onPressed: onSeeAll,
                child: const Text("Tümünü Gör"),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildErrorState(dynamic error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 48),
          const SizedBox(height: 12),
          Text(
            "Veriler Yüklenemedi",
            style: TextStyle(
              color: Colors.grey.shade900,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            error.toString(),
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _refreshData,
            icon: const Icon(Icons.refresh),
            label: const Text("Tekrar Dene"),
          ),
        ],
      ),
    );
  }
}
