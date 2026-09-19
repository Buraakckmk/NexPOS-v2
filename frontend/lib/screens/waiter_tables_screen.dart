import "dart:async";

import "package:dio/dio.dart";
import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "../models/payment_models.dart";
import "../models/dashboard_models.dart";
import "../providers/auth_provider.dart";
import "../providers/stats_provider.dart";
import "../services/api_client.dart";
import "../services/app_feedback_service.dart";
import "../services/socket_service.dart";
import "../widgets/admin_pin_dialog.dart";
import "admin_dashboard_screen.dart";
import "login_screen.dart";
import "pos_order_screen.dart";

class WaiterTablesScreen extends StatefulWidget {
  const WaiterTablesScreen({super.key});

  @override
  State<WaiterTablesScreen> createState() => _WaiterTablesScreenState();
}

class _WaiterTablesScreenState extends State<WaiterTablesScreen>
    with WidgetsBindingObserver {
  late Future<List<TableItem>> _tablesFuture = _fetchTables();
  TableItem? _selectedTable;
  bool _isSocketConnected = true;
  bool _isTransferMode = false;
  bool _isMergeMode = false;
  TableItem? _mergeSourceTable;
  String? _selectedZone;
  TableItem? _activePosTable;
  bool _showCategoriesSidebar = true;
  Timer? _durationTicker;
  final Map<int, DateTime> _optimisticallyClosedTables = {};

  void _handlePaymentFinished(TableItem table, bool tableClosed) {
    setState(() {
      if (tableClosed) {
        _optimisticallyClosedTables[table.id] = DateTime.now();
      }
      _activePosTable = null;
      _selectedTable = null;
      _showCategoriesSidebar = true;
      _tablesFuture = _fetchTables();
    });
  }

  int _extractTableNumber(TableItem table) {
    final match = RegExp(r"(\d+)").firstMatch(table.label);
    if (match == null) return 9999;
    return int.tryParse(match.group(1) ?? "") ?? 9999;
  }

  List<TableItem> _buildOrderedTables(List<TableItem> tables) {
    final ordered = List<TableItem>.from(tables);
    ordered.sort((a, b) {
      final aNo = _extractTableNumber(a);
      final bNo = _extractTableNumber(b);
      if (aNo != bNo) return aNo.compareTo(bNo);

      return a.label.compareTo(b.label);
    });
    return ordered;
  }

  List<String> _buildZoneFilters(List<TableItem> tables) {
    final zones =
        tables
            .map((table) => table.zone.trim())
            .where((zone) => zone.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return zones;
  }

  int _extractTableSequence(String tableName) {
    final match = RegExp(r"(\d+)(?!.*\d)").firstMatch(tableName.trim());
    if (match == null) return 0;
    return int.tryParse(match.group(1) ?? "") ?? 0;
  }

  String _calculateNextTableName(String regionName, List<TableItem> tables) {
    final normalizedRegion = regionName.trim().toLowerCase();
    final regionTables = tables.where(
      (table) => table.zone.trim().toLowerCase() == normalizedRegion,
    );

    var maxNumber = 0;
    for (final table in regionTables) {
      final number = _extractTableSequence(table.label);
      if (number > maxNumber) {
        maxNumber = number;
      }
    }

    final nextNumber = maxNumber == 0 ? 1 : maxNumber + 1;
    return "${regionName.trim()} $nextNumber";
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _connectRealtime();
    _syncSocketConnectionState();

    SocketService().connectionStatus.addListener(_syncSocketConnectionState);
    SocketService().socketNotifier.addListener(_connectRealtime);

    // Stats polling başlat
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<StatsProvider>().startPolling();
      }
    });

    _durationTicker = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!mounted) return;
      setState(() {});
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _durationTicker?.cancel();
    _durationTicker = null;

    SocketService().connectionStatus.removeListener(_syncSocketConnectionState);
    SocketService().socketNotifier.removeListener(_connectRealtime);

    // Stats polling durdur
    if (mounted) {
      context.read<StatsProvider>().stopPolling();
    }

    final socket = SocketService().socket;
    if (socket != null) {
      socket.off("tables:refresh");
      socket.off("new-order");
      socket.off("connect");
      socket.off("disconnect");
      socket.off("reconnect");
      socket.off("connect_error");
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _connectRealtime();
      _syncSocketConnectionState();
      _refreshAfterResume();
    }
  }

  String _formatOpenDuration(DateTime? activeSince) {
    if (activeSince == null) return "";

    final diff = DateTime.now().difference(activeSince);
    if (diff.inMinutes < 1) return "1 dk";

    if (diff.inHours < 1) {
      return "${diff.inMinutes} dk";
    }

    final hours = diff.inHours;
    final minutes = diff.inMinutes % 60;
    if (minutes == 0) {
      return "$hours sa";
    }
    return "$hours sa $minutes dk";
  }

  void _connectRealtime() {
    SocketService().reconnectIfNeeded();
    final socket = SocketService().socket;
    if (socket == null) {
      setState(() => _isSocketConnected = false);
      return;
    }

    socket.off("connect");
    socket.off("reconnect");
    socket.off("disconnect");
    socket.off("connect_error");
    socket.off("tables:refresh");
    socket.off("new-order");

    socket.on("connect", (_) {
      if (!mounted) return;
      setState(() => _isSocketConnected = true);
    });

    socket.on("reconnect", (_) {
      if (!mounted) return;
      setState(() => _isSocketConnected = true);
      _refreshAfterResume();
    });

    socket.on("disconnect", (_) {
      if (!mounted) return;
      setState(() => _isSocketConnected = false);
    });

    socket.on("connect_error", (_) {
      if (!mounted) return;
      setState(() => _isSocketConnected = false);
    });

    socket.on("tables:refresh", (_) {
      if (!mounted) return;
      _reloadTables();
    });

    socket.on("new-order", (_) {
      if (!mounted) return;
      _reloadTables();
    });

    socket.on("menu:refresh", (_) {
      if (!mounted) return;
      _refreshAfterResume();
    });
  }

  void _syncSocketConnectionState() {
    if (!mounted) return;
    setState(() {
      _isSocketConnected = SocketService().isConnected;
    });
  }

  void _refreshAfterResume() {
    if (!mounted) return;
    setState(() {
      _tablesFuture = _fetchTables();
    });
  }

  void _reloadTables() {
    setState(() {
      _tablesFuture = _fetchTables();
      _selectedTable = null;
      _isTransferMode = false;
      _isMergeMode = false;
      _mergeSourceTable = null;
    });
  }

  Future<void> _openPosOrder(TableItem table) async {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 980;

    if (isMobile) {
      await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) =>
              PosOrderScreen(tableId: table.id, tableName: table.label),
        ),
      );
      if (!mounted) return;
      setState(() {
        _selectedTable = null;
        _tablesFuture = _fetchTables();
      });
    } else {
      setState(() {
        _activePosTable = table;
        _showCategoriesSidebar = false;
      });
    }
  }

  void _closePosOrder() {
    setState(() {
      _activePosTable = null;
      _selectedTable = null;
      _showCategoriesSidebar = true;
      _tablesFuture = _fetchTables();
    });
  }

  Future<void> _logout() async {
    await context.read<AuthProvider>().logout();
    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Future<void> _openCreateCustomTableDialog() async {
    final nameController = TextEditingController();
    final capacityController = TextEditingController(text: "4");

    // Get existing zones to populate dropdown
    final List<TableItem> tables = await _fetchTables();
    if (!mounted) return;

    final List<String> existingZones = _buildZoneFilters(tables);
    if (!existingZones.contains("Oyun Salonu")) existingZones.add("Oyun Salonu");

    String selectedZone =
        (_selectedZone != null &&
            _selectedZone != "Hepsi" &&
            existingZones.contains(_selectedZone))
        ? _selectedZone!
        : existingZones.first;

    nameController.text = _calculateNextTableName(selectedZone, tables);

    final created = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dCtx, setS) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          elevation: 0,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 40,
                  spreadRadius: 10,
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF10B981,
                            ).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.add_box_rounded,
                            color: Color(0xFF10B981),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Özel Masa Aç",
                                style: TextStyle(
                                  color: Color(0xFF0F172A),
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              Text(
                                "Yeni bir geçici masa oluşturun",
                                style: TextStyle(
                                  color: Color(0xFF71717A),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Divider(color: Color(0xFFE2E8F0), height: 1),

                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "ALAN SEÇİMİ",
                          style: TextStyle(
                            color: Color(0xFF3F3F46),
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFFFF),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: selectedZone,
                              isExpanded: true,
                              dropdownColor: const Color(0xFFFFFFFF),
                              style: const TextStyle(
                                color: Color(0xFF0F172A),
                                fontWeight: FontWeight.w600,
                              ),
                              icon: const Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: Color(0xFF71717A),
                              ),
                              items: existingZones.map((z) {
                                return DropdownMenuItem(
                                  value: z,
                                  child: Text(z),
                                );
                              }).toList(),
                              onChanged: (v) {
                                if (v != null) {
                                  setS(() {
                                    selectedZone = v;
                                    nameController.text =
                                        _calculateNextTableName(v, tables);
                                  });
                                }
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          "MASA İSMİ",
                          style: TextStyle(
                            color: Color(0xFF3F3F46),
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: nameController,
                          style: const TextStyle(color: Color(0xFF0F172A)),
                          autofocus: true,
                          decoration: InputDecoration(
                            hintText: "Örn: VIP 1",
                            hintStyle: const TextStyle(
                              color: Color(0xFF3F3F46),
                            ),
                            filled: true,
                            fillColor: const Color(0xFFFFFFFF),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Color(0xFFE2E8F0),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Color(0xFFE2E8F0),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Color(0xFF10B981),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          "KAPASİTE",
                          style: TextStyle(
                            color: Color(0xFF3F3F46),
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: capacityController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Color(0xFF0F172A)),
                          decoration: InputDecoration(
                            hintText: "4",
                            hintStyle: const TextStyle(
                              color: Color(0xFF3F3F46),
                            ),
                            filled: true,
                            fillColor: const Color(0xFFFFFFFF),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Color(0xFFE2E8F0),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Color(0xFFE2E8F0),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Color(0xFF10B981),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Divider(color: Color(0xFFE2E8F0), height: 1),

                  // Footer Actions
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Wrap(
                      alignment: WrapAlignment.end,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(dCtx).pop(false),
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF71717A),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                          ),
                          child: const Text(
                            "Vazgeç",
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        FilledButton.icon(
                          onPressed: () async {
                            final displayName = nameController.text.trim();
                            final capacity =
                                int.tryParse(capacityController.text.trim()) ??
                                4;

                            if (displayName.isEmpty) return;

                            try {
                              await ApiClient.dio.post(
                                "/waiter/tables/custom",
                                data: {
                                  "display_name": displayName,
                                  "zone": selectedZone,
                                  "capacity": capacity,
                                },
                              );
                              if (dCtx.mounted) Navigator.of(dCtx).pop(true);
                            } catch (e) {
                              // Error handled by ApiClient interceptor usually
                            }
                          },
                          icon: const Icon(Icons.check_rounded, size: 18),
                          label: const Text("Masa Oluştur"),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFDCFCE7),
                            foregroundColor: const Color(0xFF0F172A),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
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
      ),
    );

    nameController.dispose();
    capacityController.dispose();

    if (!mounted || created != true) return;

    AppFeedbackService.showSuccess("Özel masa açıldı.");
    _reloadTables();
  }

  Future<void> _openAdminPanel() async {
    final unlocked = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AdminPinDialog(),
    );

    if (!mounted || unlocked != true) return;

    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const AdminDashboardScreen()));

    _reloadTables();
  }

  void _toggleTransferMode(TableItem table) {
    setState(() {
      if (_isTransferMode && _selectedTable?.id == table.id) {
        // İptal et
        _isTransferMode = false;
        _selectedTable = null;
      } else if (_isTransferMode &&
          _selectedTable != null &&
          table.id != _selectedTable!.id) {
        // Transfer yap
        _performTransfer(_selectedTable!, table);
      } else {
        // Transfer modu başlat
        _isTransferMode = true;
        _selectedTable = table;
      }
    });
  }

  Future<void> _performTransfer(TableItem fromTable, TableItem toTable) async {
    if (fromTable.status != "OCCUPIED") {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Sadece dolu masalar taşınabilir."),
          backgroundColor: Color(0xFFB91C1C),
        ),
      );
      _cancelTransfer();
      return;
    }

    if (toTable.status != "AVAILABLE") {
      // Hedef masa doluysa otomatik birleştirme yap
      await _performMerge(fromTable, toTable);
      return;
    }

    try {
      await ApiClient.dio.post(
        "/waiter/tables/transfer",
        data: {"from_table_id": fromTable.id, "to_table_id": toTable.id},
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "${fromTable.label} masası ${toTable.label} masasına taşındı.",
            ),
            backgroundColor: const Color(0xFF166534),
          ),
        );
        _cancelTransfer();
        _reloadTables();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Transfer başarısız: ${e.toString()}"),
            backgroundColor: const Color(0xFFB91C1C),
          ),
        );
        _cancelTransfer();
      }
    }
  }

  void _cancelTransfer() {
    setState(() {
      _isTransferMode = false;
      _selectedTable = null;
    });
  }

  void _startMergeMode() {
    setState(() {
      _isMergeMode = true;
      _isTransferMode = false;
      _selectedTable = null;
      _mergeSourceTable = null;
    });
  }

  void _cancelMerge() {
    setState(() {
      _isMergeMode = false;
      _mergeSourceTable = null;
    });
  }

  void _handleMergeTap(TableItem table) {
    if (_mergeSourceTable == null) {
      if (table.status != "OCCUPIED") {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Birleştirme için önce siparişi olan (dolu) bir masa seçin."),
            backgroundColor: Color(0xFFB91C1C),
          ),
        );
        return;
      }
      setState(() => _mergeSourceTable = table);
      return;
    }

    if (_mergeSourceTable!.id == table.id) {
      setState(() => _mergeSourceTable = null);
      return;
    }

    _confirmMerge(_mergeSourceTable!, table);
  }

  Future<void> _confirmMerge(TableItem source, TableItem target) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          width: 420,
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 40,
                spreadRadius: 10,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.merge_type_rounded,
                        color: Color(0xFF8B5CF6),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Masaları Birleştir",
                            style: TextStyle(
                              color: Color(0xFF0F172A),
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                            ),
                          ),
                          Text(
                            "İki masayı tek hesapta birleştir",
                            style: TextStyle(
                              color: Color(0xFF71717A),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(color: Color(0xFFE2E8F0), height: 1),

              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFFFF),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                source.label,
                                style: const TextStyle(
                                  color: Color(0xFFEF4444),
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                ),
                              ),
                              const Icon(
                                Icons.arrow_forward_rounded,
                                color: Color(0xFF71717A),
                                size: 18,
                              ),
                              Text(
                                target.label,
                                style: const TextStyle(
                                  color: Color(0xFF10B981),
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            "Kaynaktaki tüm ürünler hedef masaya aktarılacak ve kaynak masa boşaltılacak.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color(0xFF71717A),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(color: Color(0xFFE2E8F0), height: 1),

              // Footer Actions
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF71717A),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                      child: const Text(
                        "İptal",
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: () => Navigator.pop(ctx, true),
                      icon: const Icon(Icons.merge_type_rounded, size: 18),
                      label: const Text("Birleştir"),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFEDE9FE),
                        foregroundColor: const Color(0xFF0F172A),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (!mounted) return;
    if (confirmed != true) {
      setState(() => _mergeSourceTable = null);
      return;
    }
    await _performMerge(source, target);
  }

  Future<void> _performMerge(
    TableItem sourceTable,
    TableItem targetTable,
  ) async {
    try {
      await ApiClient.dio.post(
        "/waiter/tables/merge",
        data: {
          "source_table_id": sourceTable.id,
          "target_table_id": targetTable.id,
        },
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "${sourceTable.label} → ${targetTable.label} birleştirildi.",
            ),
            backgroundColor: const Color(0xFF6D28D9),
          ),
        );
        _cancelMerge();
        _reloadTables();
      }
    } catch (e) {
      if (mounted) {
        final message =
            e is DioException &&
                e.response?.data is Map<String, dynamic> &&
                (e.response?.data["message"]?.toString().isNotEmpty ?? false)
            ? e.response?.data["message"].toString()
            : e.toString();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Birleştirme başarısız: $message"),
            backgroundColor: const Color(0xFFB91C1C),
          ),
        );
        setState(() => _mergeSourceTable = null);
      }
    }
  }

  Future<List<TableItem>> _fetchTables() async {
    final response = await ApiClient.dio.get("/waiter/tables");
    final data = response.data as Map<String, dynamic>;
    final rawTables = (data["tables"] as List<dynamic>? ?? []);
    final fetchedTables = rawTables
        .whereType<Map<String, dynamic>>()
        .map(TableItem.fromJson)
        .toList();

    final now = DateTime.now();
    return fetchedTables.map((table) {
      final closedAt = _optimisticallyClosedTables[table.id];
      if (closedAt == null) {
        return table;
      }

      final isOverrideExpired =
          now.difference(closedAt) > const Duration(seconds: 10);
      final backendAlreadyCleared =
          table.status != "OCCUPIED" || table.totalAmount <= 0.009;

      if (backendAlreadyCleared || isOverrideExpired) {
        _optimisticallyClosedTables.remove(table.id);
        return table;
      }

      return TableItem(
        id: table.id,
        label: table.label,
        status: "AVAILABLE",
        zone: table.zone,
        activeSince: null,
        totalAmount: 0,
        isCustom: table.isCustom,
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = context.watch<AuthProvider>().currentUser;
    final canOpenAdminPanel = currentUser?.roleId == 1;
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isMobileLayout = screenWidth < 980;
    final isAdminDesktopMasterDetail = canOpenAdminPanel && !isMobileLayout;
    final isCompactDesktop =
        !isMobileLayout && (screenWidth <= 1280 || screenHeight <= 820);

    return Scaffold(
      appBar: _activePosTable != null
          ? null
          : AppBar(
              backgroundColor: const Color(0xFFF8FAFC),
              surfaceTintColor: const Color(0xFFF8FAFC),
              foregroundColor: const Color(0xFF0F172A),
              elevation: 0,
              scrolledUnderElevation: 0,
              title: Text(
                _isMergeMode
                    ? "Masa Birleştirme Modu"
                    : _isTransferMode
                    ? "Masa Taşıma Modu"
                    : _selectedZone == null
                    ? "Masalar"
                    : _selectedZone!,
              ),
              centerTitle: true,
              leading: _selectedZone != null
                  ? IconButton(
                      onPressed: () {
                        setState(() {
                          _selectedZone = null;
                        });
                      },
                      icon: const Icon(Icons.arrow_back),
                    )
                  : null,
              actions: (_isTransferMode || _isMergeMode)
                  ? [
                      TextButton.icon(
                        onPressed: _isTransferMode
                            ? _cancelTransfer
                            : _cancelMerge,
                        icon: const Icon(Icons.close, color: Color(0xFF0F172A)),
                        label: const Text(
                          "İPTAL",
                          style: TextStyle(color: Color(0xFF0F172A)),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ]
                  : [
                      if (isMobileLayout) ...[
                        IconButton(
                          onPressed: () => setState(() {
                            _isTransferMode = true;
                            _isMergeMode = false;
                            _mergeSourceTable = null;
                            _selectedTable = null;
                          }),
                          icon: const Icon(Icons.swap_horiz_rounded),
                          tooltip: "Masa Taşı",
                        ),
                        IconButton(
                          onPressed: _startMergeMode,
                          icon: const Icon(Icons.merge_type_rounded),
                          tooltip: "Masa Birleştir",
                        ),
                        PopupMenuButton<String>(
                          tooltip: "Menü",
                          icon: const Icon(Icons.more_vert_rounded),
                          onSelected: (value) {
                            if (value == "admin") {
                              _openAdminPanel();
                              return;
                            }
                            if (value == "new_table") {
                              _openCreateCustomTableDialog();
                              return;
                            }
                            if (value == "logout") {
                              _logout();
                              return;
                            }
                          },
                          itemBuilder: (context) => [
                            if (canOpenAdminPanel)
                              const PopupMenuItem(
                                value: "admin",
                                child: Text("Yönetici Paneli"),
                              ),
                            const PopupMenuItem(
                              value: "new_table",
                              child: Text("Yeni Özel Masa Aç"),
                            ),
                            const PopupMenuItem(
                              value: "logout",
                              child: Text("Çıkış Yap"),
                            ),
                          ],
                        ),
                        const SizedBox(width: 4),
                      ] else ...[
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (canOpenAdminPanel) ...[
                                FilledButton.icon(
                                  onPressed: _openAdminPanel,
                                  icon: const Icon(
                                    Icons.admin_panel_settings_rounded,
                                    size: 18,
                                  ),
                                  label: const Text("Yönetici Paneli"),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFFDBEAFE),
                                    foregroundColor: const Color(0xFF0F172A),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 10,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      side: const BorderSide(
                                        color: Color(0xFFE2E8F0),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                              OutlinedButton.icon(
                                onPressed: _logout,
                                icon: const Icon(
                                  Icons.logout_rounded,
                                  size: 18,
                                ),
                                label: const Text("Çıkış Yap"),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFFEF4444),
                                  side: BorderSide(
                                    color: const Color(
                                      0xFFEF4444,
                                    ).withValues(alpha: 0.35),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  textStyle: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ],
            ),
      body: SafeArea(
        top: _activePosTable != null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: _isSocketConnected
                  ? const SizedBox.shrink()
                  : Container(
                      key: const ValueKey("socket-disconnected-bar"),
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      color: const Color(0xFFFEE2E2),
                      child: const Text(
                        "Bağlantı Bekleniyor...",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF0F172A),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
            ),
            Expanded(
              child: FutureBuilder<List<TableItem>>(
                future: _tablesFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    final error = snapshot.error;
                    final message = error is DioException
                        ? (error.response?.data is Map<String, dynamic>
                              ? (error.response?.data["message"]?.toString() ??
                                    "Masalar alinamadi.")
                              : "Masalar alinamadi.")
                        : "Masalar alinamadi.";
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          message,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Color(0xFFFCA5A5)),
                        ),
                      ),
                    );
                  }

                  final tables = snapshot.data ?? [];
                  final occupiedTables = _buildOrderedTables(
                    tables.where((t) => t.status == "OCCUPIED").toList(),
                  );
                  final zoneFilters = _buildZoneFilters(tables);
                  final zoneStats = {
                    for (final zone in zoneFilters)
                      zone: _ZoneTableStats.fromTables(
                        tables.where((t) => t.zone == zone).toList(),
                      ),
                  };

                  // Tablet (SAM4S) optimizasyonu: 1280x800 ve benzeri çözünürlükler için Master-Detail layout'u ferahlatıyoruz.
                  final bool isTabletWidth =
                      screenWidth >= 1000 && screenWidth <= 1300;
                  final double leftPaneWidth = isCompactDesktop
                      ? (screenWidth * 0.21).clamp(200.0, 242.0).toDouble()
                      : (isTabletWidth
                            ? (screenWidth * 0.21)
                                  .clamp(214.0, 252.0)
                                  .toDouble()
                            : (screenWidth * 0.22)
                                  .clamp(228.0, 288.0)
                                  .toDouble());
                  if (isMobileLayout) {
                    return SafeArea(child: _buildCenterContent(tables));
                  }

                  if (isAdminDesktopMasterDetail) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Sol Panel: Hamburger Menu (Dinamik - Toggle)
                        if (_activePosTable != null && !_showCategoriesSidebar)
                          SizedBox(
                            width: 50,
                            child: Container(
                              color: const Color(0xFFF8FAFC),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 8),
                                  IconButton(
                                    icon: const Icon(Icons.menu_rounded),
                                    tooltip: "Kategorileri Göster",
                                    onPressed: () {
                                      setState(() {
                                        _showCategoriesSidebar = true;
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          SizedBox(
                            width: leftPaneWidth,
                            child: _LeftSidebar(
                              occupiedTables: occupiedTables,
                              isTransferMode: _isTransferMode,
                              isMergeMode: _isMergeMode,
                              selectedTransferTable: _isTransferMode
                                  ? _selectedTable
                                  : null,
                              mergeSourceTable: _mergeSourceTable,
                              formatDuration: _formatOpenDuration,
                              onOccupiedTableTap: (table) {
                                if (_isTransferMode) {
                                  _toggleTransferMode(table);
                                } else if (_isMergeMode) {
                                  _handleMergeTap(table);
                                } else {
                                  _openPosOrder(table);
                                }
                              },
                              onStartTransfer: () => setState(() {
                                _isTransferMode = true;
                                _isMergeMode = false;
                                _mergeSourceTable = null;
                                _selectedTable = null;
                              }),
                              onCancelTransfer: _cancelTransfer,
                              onStartMerge: _startMergeMode,
                              onCancelMerge: _cancelMerge,
                              onOpenCreateCustomTable:
                                  _openCreateCustomTableDialog,
                              zoneFilters: zoneFilters,
                              zoneStats: zoneStats,
                              zoneCardBuilder: (zone, stats) =>
                                  _buildSquareZoneCard(
                                    zone: zone,
                                    stats: stats,
                                    compact: true,
                                  ),
                              showHideCategoriesButton: _activePosTable != null,
                              onHideCategories: () {
                                setState(() {
                                  _showCategoriesSidebar = false;
                                });
                              },
                            ),
                          ),

                        // Orta Panel: Aktif Servis & Kategoriler (Genişletildi)
                        Expanded(
                          child: Container(
                            decoration: const BoxDecoration(
                              border: Border(
                                left: BorderSide(color: Color(0xFFE2E8F0)),
                                right: BorderSide(color: Color(0xFFE2E8F0)),
                              ),
                            ),
                            child: _activePosTable != null
                                ? Stack(
                                    children: [
                                      PosOrderScreen(
                                        key: ValueKey(_activePosTable!.id),
                                        tableId: _activePosTable!.id,
                                        tableName: _activePosTable!.label,
                                        embedded: true,
                                        onClose: _closePosOrder,
                                        onPaymentMade: () {
                                          final table = _activePosTable;
                                          if (table != null) {
                                            _handlePaymentFinished(table, true);
                                          }
                                        },
                                        onPaymentFinished: (tableClosed) {
                                          // Artık onPaymentMade içinde handle ediliyor
                                        },
                                      ),
                                    ],
                                  )
                                : _buildCenterContent(tables),
                          ),
                        ),
                      ],
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Sol Panel: Hamburger Menu (Dinamik - Toggle)
                      if (_activePosTable != null && !_showCategoriesSidebar)
                        SizedBox(
                          width: 50,
                          child: Container(
                            color: const Color(0xFFF8FAFC),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                const SizedBox(height: 8),
                                IconButton(
                                  icon: const Icon(Icons.menu_rounded),
                                  tooltip: "Kategorileri Göster",
                                  onPressed: () {
                                    setState(() {
                                      _showCategoriesSidebar = true;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        SizedBox(
                          width: leftPaneWidth,
                          child: _LeftSidebar(
                            occupiedTables: occupiedTables,
                            isTransferMode: _isTransferMode,
                            isMergeMode: _isMergeMode,
                            selectedTransferTable: _isTransferMode
                                ? _selectedTable
                                : null,
                            mergeSourceTable: _mergeSourceTable,
                            formatDuration: _formatOpenDuration,
                            onOccupiedTableTap: (table) {
                              if (_isTransferMode) {
                                _toggleTransferMode(table);
                              } else if (_isMergeMode) {
                                _handleMergeTap(table);
                              } else {
                                _openPosOrder(table);
                              }
                            },
                            onStartTransfer: () => setState(() {
                              _isTransferMode = true;
                              _isMergeMode = false;
                              _mergeSourceTable = null;
                              _selectedTable = null;
                            }),
                            onCancelTransfer: _cancelTransfer,
                            onStartMerge: _startMergeMode,
                            onCancelMerge: _cancelMerge,
                            onOpenCreateCustomTable:
                                _openCreateCustomTableDialog,
                            zoneFilters: zoneFilters,
                            zoneStats: zoneStats,
                            zoneCardBuilder: (zone, stats) =>
                                _buildSquareZoneCard(
                                  zone: zone,
                                  stats: stats,
                                  compact: true,
                                ),
                            showHideCategoriesButton: _activePosTable != null,
                            onHideCategories: () {
                              setState(() {
                                _showCategoriesSidebar = false;
                              });
                            },
                          ),
                        ),
                      Container(width: 1, color: const Color(0xFFFFFFFF)),
                      Expanded(
                        child: _activePosTable != null
                            ? Stack(
                                children: [
                                  PosOrderScreen(
                                    key: ValueKey(_activePosTable!.id),
                                    tableId: _activePosTable!.id,
                                    tableName: _activePosTable!.label,
                                    embedded: true,
                                    onClose: _closePosOrder,
                                    onPaymentMade: () {
                                      final table = _activePosTable;
                                      if (table != null) {
                                        _handlePaymentFinished(table, true);
                                      }
                                    },
                                    onPaymentFinished: (tableClosed) {
                                      // State already reset in onPaymentMade
                                    },
                                  ),
                                ],
                              )
                            : _buildCenterContent(tables),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTableCard(
    TableItem table, {
    required double tileWidth,
    required double tileHeight,
  }) {
    final isCompact = tileWidth < 160 || tileHeight < 132;
    final isUltraCompact = tileWidth < 132 || tileHeight < 112;
    final isOccupied = table.status == "OCCUPIED";
    final isTransferSelected =
        _isTransferMode && _selectedTable?.id == table.id;
    final isMergeSource = _isMergeMode && _mergeSourceTable?.id == table.id;
    final bool isHighlighted = isTransferSelected || isMergeSource;

    List<Color> gradient;
    if (isTransferSelected) {
      gradient = [const Color(0xFFDBEAFE), const Color(0xFFBFDBFE)];
    } else if (isMergeSource) {
      gradient = [const Color(0xFFEDE9FE), const Color(0xFFDDD6FE)];
    } else if (isOccupied) {
      gradient = [const Color(0xFFFEE2E2), const Color(0xFFFECACA)];
    } else {
      gradient = [const Color(0xFFDCFCE7), const Color(0xFFBBF7D0)];
    }

    String? modeLabel;
    if (_isTransferMode) {
      modeLabel = isTransferSelected
          ? "HEDEF SEÇİN"
          : (isOccupied ? "TAŞI" : "HEDEF");
    } else if (_isMergeMode) {
      if (isOccupied) {
        modeLabel = isMergeSource ? "HEDEF SEÇİN" : "BİRLEŞTİR";
      }
    }

    return InkWell(
      borderRadius: BorderRadius.circular(isUltraCompact ? 14 : 18),
      onTap: () {
        if (_isTransferMode) {
          _toggleTransferMode(table);
        } else if (_isMergeMode) {
          _handleMergeTap(table);
        } else {
          _openPosOrder(table);
        }
      },
      onSecondaryTap: null,
      onLongPress: (!_isTransferMode && !_isMergeMode && isOccupied)
          ? () => _toggleTransferMode(table)
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(isUltraCompact ? 14 : 18),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradient,
          ),
          border: Border.all(
            color: isHighlighted
                ? const Color(0xFF3B82F6)
                : (isOccupied
                      ? const Color(0xFFEF4444)
                      : const Color(0xFF10B981)),
            width: isHighlighted ? 2 : 1,
          ),
          boxShadow: [
            if (isOccupied || isHighlighted)
              BoxShadow(
                color: gradient[0].withValues(alpha: 0.3),
                blurRadius: isUltraCompact ? 8 : 12,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(isUltraCompact ? 14 : 18),
          child: Stack(
            children: [
              Positioned(
                right: isUltraCompact ? -10 : -12,
                bottom: isUltraCompact ? -10 : -12,
                child: Icon(
                  Icons.table_restaurant_rounded,
                  size: isUltraCompact ? 42 : (isCompact ? 50 : 58),
                  color: const Color(0xFF0F172A).withValues(alpha: 0.06),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(
                  isUltraCompact ? 6 : (isCompact ? 8 : 10),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (!_isTransferMode && !_isMergeMode)
                      Container(
                        width: isUltraCompact ? 6 : 8,
                        height: isUltraCompact ? 6 : 8,
                        margin: EdgeInsets.only(bottom: isUltraCompact ? 4 : 6),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isOccupied
                              ? const Color(0xFFEF4444)
                              : const Color(0xFF10B981),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  (isOccupied
                                          ? const Color(0xFFEF4444)
                                          : const Color(0xFF10B981))
                                      .withValues(alpha: 0.5),
                              blurRadius: 4,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                    Text(
                      table.label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: isUltraCompact ? 11.5 : (isCompact ? 13 : 15),
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF0F172A),
                        letterSpacing: -0.5,
                        height: 1,
                      ),
                    ),
                    if (isOccupied &&
                        table.activeSince != null &&
                        !_isTransferMode &&
                        !_isMergeMode) ...[
                      SizedBox(
                        height: isUltraCompact ? 3 : (isCompact ? 5 : 8),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isUltraCompact ? 6 : 7,
                          vertical: isUltraCompact ? 2 : 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFFFF),
                          borderRadius: BorderRadius.circular(7),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Text(
                          _formatOpenDuration(table.activeSince),
                          style: TextStyle(
                            fontSize: isUltraCompact ? 9.5 : 11,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      if (table.totalAmount > 0) ...[
                        SizedBox(
                          height: isUltraCompact ? 2 : (isCompact ? 4 : 6),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: isUltraCompact ? 6 : 8,
                            vertical: isUltraCompact ? 2 : 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFFFF),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(0xFFE2E8F0),
                              width: 1,
                            ),
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              "${table.totalAmount.toStringAsFixed(2)} ₺",
                              style: TextStyle(
                                fontSize: isUltraCompact ? 10 : 12,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF0F172A),
                                letterSpacing: -0.5,
                                height: 1,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                    if (modeLabel != null) ...[
                      SizedBox(
                        height: isUltraCompact ? 3 : (isCompact ? 5 : 8),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isUltraCompact ? 6 : 7,
                          vertical: isUltraCompact ? 3 : 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Text(
                          modeLabel,
                          style: TextStyle(
                            fontSize: isUltraCompact ? 8.5 : 9.5,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0F172A),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCenterContent(List<TableItem> tables) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isMobileLayout = screenWidth < 980;
    final isCompactDesktop =
        !isMobileLayout && (screenWidth <= 1280 || screenHeight <= 820);

    if (_selectedZone == null) {
      final zoneFilters = _buildZoneFilters(tables);
      final zoneStats = {
        for (final zone in zoneFilters)
          zone: _ZoneTableStats.fromTables(
            tables.where((table) => table.zone == zone).toList(),
          ),
      };
      final occupiedTables = _buildOrderedTables(
        tables.where((table) => table.status == "OCCUPIED").toList(),
      );

      if (zoneFilters.isEmpty) {
        return const Center(
          child: Text(
            "Gösterilecek aktif alan bulunamadı.",
            style: TextStyle(color: Color(0xFF64748B)),
          ),
        );
      }

      // Mobil düzende yatay kategoriler kalsın
      if (isMobileLayout) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(left: 2, bottom: 8),
                child: Text(
                  "Kategoriler",
                  style: TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              SizedBox(
                height: 110,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: zoneFilters.length,
                  itemBuilder: (context, index) {
                    final zone = zoneFilters[index];
                    final stats = zoneStats[zone] ?? const _ZoneTableStats();
                    return Padding(
                      padding: EdgeInsets.only(
                        right: index == zoneFilters.length - 1 ? 0 : 10,
                      ),
                      child: _buildCompactZoneCard(zone: zone, stats: stats),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              Expanded(child: _buildOpenTablesDashboardSection(occupiedTables)),
            ],
          ),
        );
      }

      // Desktop düzende sadece Aktif Servis (Kategoriler sola taşındı)
      return Padding(
        padding: EdgeInsets.fromLTRB(
          isCompactDesktop ? 14 : 20,
          isCompactDesktop ? 12 : 16,
          isCompactDesktop ? 14 : 20,
          isCompactDesktop ? 14 : 20,
        ),
        child: _buildOpenTablesDashboardSection(occupiedTables),
      );
    }

    // Table grid
    final filteredTables = tables
        .where((t) => t.zone == _selectedZone)
        .toList();
    final orderedTables = _buildOrderedTables(filteredTables);
    if (orderedTables.isEmpty) {
      return const Center(child: Text("Bu kategoride gösterilecek masa yok."));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Zone Header
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _selectedZone!,
                style: const TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: Color(0xFF10B981),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    "${orderedTables.length} Toplam Masa",
                    style: const TextStyle(
                      color: Color(0xFF71717A),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              const gridPadding = 12.0;
              const spacing = 8.0;
              final availableWidth = constraints.maxWidth - (gridPadding * 2);
              final availableHeight = constraints.maxHeight - (gridPadding * 2);
              final tableCount = orderedTables.length;

              var bestCrossAxisCount = 1;
              var bestTileWidth = availableWidth;
              var bestTileHeight = availableHeight;
              var bestScore = -1.0;

              final maxColumns = tableCount < 12 ? tableCount : 12;
              for (var columns = 1; columns <= maxColumns; columns++) {
                final rows = (tableCount / columns).ceil();
                final tileWidth =
                    (availableWidth - ((columns - 1) * spacing)) / columns;
                final tileHeight =
                    (availableHeight - ((rows - 1) * spacing)) / rows;

                if (tileWidth <= 0 || tileHeight <= 0) continue;

                final score = tileWidth < tileHeight * 1.8
                    ? tileWidth
                    : tileHeight * 1.8;

                if (score > bestScore) {
                  bestScore = score;
                  bestCrossAxisCount = columns;
                  bestTileWidth = tileWidth;
                  bestTileHeight = tileHeight;
                }
              }

              return GridView.builder(
                padding: const EdgeInsets.all(gridPadding),
                physics: const NeverScrollableScrollPhysics(),
                itemCount: orderedTables.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: bestCrossAxisCount,
                  mainAxisSpacing: spacing,
                  crossAxisSpacing: spacing,
                  childAspectRatio: bestTileWidth / bestTileHeight,
                ),
                itemBuilder: (context, index) {
                  return _buildTableCard(
                    orderedTables[index],
                    tileWidth: bestTileWidth,
                    tileHeight: bestTileHeight,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSquareZoneCard({
    required String zone,
    required _ZoneTableStats stats,
    bool compact = false,
  }) {
    final zoneStyle = _getZoneVisualStyle(zone);

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => setState(() {
        _selectedZone = zone;
        _activePosTable = null;
      }),
      child: Container(
        height: compact ? 104 : 118,
        padding: EdgeInsets.all(compact ? 10 : 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: zoneStyle.gradientColors,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: zoneStyle.borderColor, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: zoneStyle.shadowColor.withValues(alpha: 0.26),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: compact ? 24 : 28,
                  height: compact ? 24 : 28,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFFFF).withValues(alpha: 0.82),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: zoneStyle.borderColor.withValues(alpha: 0.9),
                    ),
                  ),
                  child: Icon(
                    zoneStyle.icon,
                    size: compact ? 14 : 16,
                    color: zoneStyle.accentColor,
                  ),
                ),
                SizedBox(width: compact ? 6 : 8),
                Expanded(
                  child: Text(
                    zone,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Color(0xFF0F172A),
                      fontSize: compact ? 12.5 : 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: compact ? 1 : 3),
            Text(
              "${stats.occupiedCount}/${stats.totalCount} Dolu",
              style: TextStyle(
                color: zoneStyle.accentColor,
                fontSize: compact ? 10 : 11,
                fontWeight: FontWeight.w800,
              ),
            ),
            const Spacer(),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: stats.totalCount > 0
                    ? stats.occupiedCount / stats.totalCount
                    : 0,
                backgroundColor: const Color(
                  0xFFFFFFFF,
                ).withValues(alpha: 0.55),
                valueColor: AlwaysStoppedAnimation<Color>(
                  zoneStyle.accentColor,
                ),
                minHeight: compact ? 5 : 6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactZoneCard({
    required String zone,
    required _ZoneTableStats stats,
  }) {
    final zoneStyle = _getZoneVisualStyle(zone);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => setState(() {
        _selectedZone = zone;
        _activePosTable = null;
      }),
      child: Container(
        width: 132,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: zoneStyle.gradientColors,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: zoneStyle.borderColor),
          boxShadow: [
            BoxShadow(
              color: zoneStyle.shadowColor.withValues(alpha: 0.22),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(zoneStyle.icon, size: 13, color: zoneStyle.accentColor),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    zone,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF0F172A),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              "${stats.occupiedCount}/${stats.totalCount} Dolu",
              style: TextStyle(
                color: zoneStyle.accentColor,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 5),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: stats.totalCount > 0
                    ? stats.occupiedCount / stats.totalCount
                    : 0,
                backgroundColor: const Color(
                  0xFFFFFFFF,
                ).withValues(alpha: 0.58),
                valueColor: AlwaysStoppedAnimation<Color>(
                  zoneStyle.accentColor,
                ),
                minHeight: 4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  _ZoneVisualStyle _getZoneVisualStyle(String zone) {
    final normalized = zone.trim().toLowerCase();

    if (normalized.contains("balkon")) {
      return const _ZoneVisualStyle(
        icon: Icons.deck_rounded,
        gradientColors: [Color(0xFFE0F2FE), Color(0xFFBAE6FD)],
        shadowColor: Color(0xFF0284C7),
        borderColor: Color(0xFF7DD3FC),
        accentColor: Color(0xFF0369A1),
      );
    }

    if (normalized.contains("oyun salonu")) {
      return const _ZoneVisualStyle(
        icon: Icons.sports_esports_rounded,
        gradientColors: [Color(0xFFEDE9FE), Color(0xFFDDD6FE)],
        shadowColor: Color(0xFF7C3AED),
        borderColor: Color(0xFFC4B5FD),
        accentColor: Color(0xFF5B21B6),
      );
    }

    if (normalized.contains("vip")) {
      return const _ZoneVisualStyle(
        icon: Icons.workspace_premium_rounded,
        gradientColors: [Color(0xFFFFEDD5), Color(0xFFFED7AA)],
        shadowColor: Color(0xFFEA580C),
        borderColor: Color(0xFFFDBA74),
        accentColor: Color(0xFF9A3412),
      );
    }

    if (normalized.contains("salon")) {
      return const _ZoneVisualStyle(
        icon: Icons.weekend_rounded,
        gradientColors: [Color(0xFFDCFCE7), Color(0xFFBBF7D0)],
        shadowColor: Color(0xFF16A34A),
        borderColor: Color(0xFF86EFAC),
        accentColor: Color(0xFF15803D),
      );
    }

    return const _ZoneVisualStyle(
      icon: Icons.location_on_rounded,
      gradientColors: [Color(0xFFF1F5F9), Color(0xFFE2E8F0)],
      shadowColor: Color(0xFF475569),
      borderColor: Color(0xFFCBD5E1),
      accentColor: Color(0xFF334155),
    );
  }

  Widget _buildOpenTablesDashboardSection(List<TableItem> occupiedTables) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Başlık Alanı
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFE4E6), Color(0xFFFECDD3)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0xFF0F172A).withValues(alpha: 0.06),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.local_fire_department_rounded,
                    color: Color(0xFF0F172A),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Aktif Servis",
                        style: TextStyle(
                          color: Color(0xFF0F172A),
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                      Text(
                        "Şu an hizmette olanlar",
                        style: TextStyle(
                          color: Color(0xFF71717A),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFFFF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Text(
                    "${occupiedTables.length}",
                    style: const TextStyle(
                      color: Color(0xFFF43F5E),
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Divider(color: Color(0xFFE2E8F0), height: 1),
          ),

          // Liste Alanı
          Expanded(
            child: occupiedTables.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.restaurant_rounded,
                          color: const Color(0xFFCBD5E1),
                          size: 48,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          "Tüm masalar müsait",
                          style: TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(10),
                    itemCount: occupiedTables.length,
                    itemBuilder: (context, index) {
                      final table = occupiedTables[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: InkWell(
                          onTap: () {
                            if (_isTransferMode) {
                              _toggleTransferMode(table);
                              return;
                            }
                            if (_isMergeMode) {
                              _handleMergeTap(table);
                              return;
                            }

                            _openPosOrder(table);
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFFFFF),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                // Masa No/Harf İkonu
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: const Color(0xFFE2E8F0),
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      table.label.substring(0, 1).toUpperCase(),
                                      style: const TextStyle(
                                        color: Color(0xFF0F172A),
                                        fontSize: 16,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                // Masa Detayları
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        table.label,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        softWrap: false,
                                        style: const TextStyle(
                                          color: Color(0xFF0F172A),
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: -0.2,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.access_time_filled_rounded,
                                            size: 12,
                                            color: Color(0xFFD97706),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            _formatOpenDuration(
                                              table.activeSince,
                                            ),
                                            style: const TextStyle(
                                              color: Color(0xFFD97706),
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                // Fiyat Etiketi
                                if (table.totalAmount > 0)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        0xFF10B981,
                                      ).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      "${table.totalAmount.toStringAsFixed(0)}₺",
                                      style: const TextStyle(
                                        color: Color(0xFF059669),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
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

class _ZoneTableStats {
  final int occupiedCount;
  final int totalCount;

  const _ZoneTableStats({this.occupiedCount = 0, this.totalCount = 0});

  factory _ZoneTableStats.fromTables(List<TableItem> tables) {
    return _ZoneTableStats(
      occupiedCount: tables.where((table) => table.status == "OCCUPIED").length,
      totalCount: tables.length,
    );
  }

  double get occupancyRate => totalCount == 0 ? 0 : occupiedCount / totalCount;

  Color get badgeBackgroundColor {
    if (occupancyRate >= 0.75) return const Color(0xFF7F1D1D);
    if (occupancyRate >= 0.4) return const Color(0xFF78350F);
    return const Color(0xFF14532D);
  }

  Color get badgeBorderColor {
    if (occupancyRate >= 0.75) return const Color(0xFFEF4444);
    if (occupancyRate >= 0.4) return const Color(0xFFF59E0B);
    return const Color(0xFF22C55E);
  }

  Color get badgeTextColor {
    if (occupancyRate >= 0.75) return const Color(0xFFFECACA);
    if (occupancyRate >= 0.4) return const Color(0xFFFDE68A);
    return const Color(0xFFBBF7D0);
  }
}

class _ZoneVisualStyle {
  final IconData icon;
  final List<Color> gradientColors;
  final Color shadowColor;
  final Color borderColor;
  final Color accentColor;

  const _ZoneVisualStyle({
    required this.icon,
    required this.gradientColors,
    required this.shadowColor,
    required this.borderColor,
    required this.accentColor,
  });
}

class TableOrderPreview {
  final int orderId;
  final bool hasActiveOrder;
  final double subtotal;
  final double discountTotal;
  final double grandTotal;
  final List<TableOrderPreviewItem> items;

  const TableOrderPreview({
    required this.orderId,
    required this.hasActiveOrder,
    required this.subtotal,
    required this.discountTotal,
    required this.grandTotal,
    required this.items,
  });

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse((value ?? "").toString()) ?? 0;
  }

  factory TableOrderPreview.fromApi(Map<String, dynamic> json) {
    final activeOrder = json["active_order"] as Map<String, dynamic>?;
    if (activeOrder == null) {
      return const TableOrderPreview(
        orderId: 0,
        hasActiveOrder: false,
        subtotal: 0,
        discountTotal: 0,
        grandTotal: 0,
        items: [],
      );
    }

    final rawItems = (json["items"] as List<dynamic>? ?? []);
    return TableOrderPreview(
      orderId: int.tryParse((activeOrder["id"] ?? "").toString()) ?? 0,
      hasActiveOrder: true,
      subtotal: _toDouble(activeOrder["subtotal"]),
      discountTotal: _toDouble(activeOrder["discount_total"]),
      grandTotal: _toDouble(activeOrder["grand_total"]),
      items: rawItems
          .whereType<Map<String, dynamic>>()
          .map(TableOrderPreviewItem.fromJson)
          .toList(),
    );
  }
}

// ─── Left Sidebar ────────────────────────────────────────────────────────────

class _LeftSidebar extends StatelessWidget {
  final List<TableItem> occupiedTables;
  final bool isTransferMode;
  final bool isMergeMode;
  final TableItem? selectedTransferTable;
  final TableItem? mergeSourceTable;
  final String Function(DateTime?) formatDuration;
  final void Function(TableItem) onOccupiedTableTap;
  final VoidCallback onStartTransfer;
  final VoidCallback onCancelTransfer;
  final VoidCallback onStartMerge;
  final VoidCallback onCancelMerge;
  final VoidCallback onOpenCreateCustomTable;
  final List<String> zoneFilters;
  final Map<String, _ZoneTableStats> zoneStats;
  final Widget Function(String zone, _ZoneTableStats stats) zoneCardBuilder;
  final bool showHideCategoriesButton;
  final VoidCallback? onHideCategories;

  const _LeftSidebar({
    required this.occupiedTables,
    required this.isTransferMode,
    required this.isMergeMode,
    required this.selectedTransferTable,
    required this.mergeSourceTable,
    required this.formatDuration,
    required this.onOccupiedTableTap,
    required this.onStartTransfer,
    required this.onCancelTransfer,
    required this.onStartMerge,
    required this.onCancelMerge,
    required this.onOpenCreateCustomTable,
    required this.zoneFilters,
    required this.zoneStats,
    required this.zoneCardBuilder,
    this.showHideCategoriesButton = false,
    this.onHideCategories,
  });

  String get _transferStatusText {
    if (!isTransferMode) return "Siparişi başka masaya taşı";
    if (selectedTransferTable != null) {
      return "${selectedTransferTable!.label} seçildi — hedef seçin";
    }
    return "Taşınacak masayı seçin";
  }

  String get _mergeStatusText {
    if (!isMergeMode) return "İki masanın adisyonunu birleştir";
    if (mergeSourceTable != null) {
      return "${mergeSourceTable!.label} seçildi — hedef seçin";
    }
    return "Kaynak masayı seçin";
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF8FAFC),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Sabit Kategoriler Paneli
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 8,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.grid_view_rounded,
                              size: 14,
                              color: Color(0xFF64748B),
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              "KATEGORİLER",
                              style: TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const Spacer(),
                            if (showHideCategoriesButton)
                              IconButton(
                                icon: const Icon(Icons.close_rounded, size: 18),
                                tooltip: "Kategorileri Gizle",
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints.tightFor(
                                  width: 28,
                                  height: 28,
                                ),
                                onPressed: onHideCategories,
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (int i = 0; i < zoneFilters.length; i++) ...[
                              zoneCardBuilder(
                                zoneFilters[i],
                                zoneStats[zoneFilters[i]] ??
                                    const _ZoneTableStats(),
                              ),
                              if (i < zoneFilters.length - 1)
                                const SizedBox(height: 8),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),

                  const Divider(color: Color(0xFFE2E8F0), height: 24),

                  // Alt Butonlar
                  _ModeCard(
                    title: "Masa Taşı",
                    icon: Icons.swap_horiz_rounded,
                    accentColor: const Color(0xFF3B82F6),
                    isActive: isTransferMode,
                    statusText: _transferStatusText,
                    onStart: onStartTransfer,
                    onCancel: onCancelTransfer,
                  ),
                  const SizedBox(height: 8),
                  _ModeCard(
                    title: "Masa Birleştirme",
                    icon: Icons.call_merge_rounded,
                    accentColor: const Color(0xFF8B5CF6),
                    isActive: isMergeMode,
                    statusText: _mergeStatusText,
                    onStart: onStartMerge,
                    onCancel: onCancelMerge,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton.icon(
                      onPressed: onOpenCreateCustomTable,
                      icon: const Icon(Icons.add_box_rounded, size: 20),
                      label: const Text(
                        "Yeni Masa Oluştur",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFDCFCE7),
                        foregroundColor: const Color(0xFF0F172A),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: const BorderSide(color: Color(0xFFBBF7D0)),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Mode Action Card ─────────────────────────────────────────────────────────

class _ModeCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color accentColor;
  final bool isActive;
  final String statusText;
  final VoidCallback onStart;
  final VoidCallback onCancel;

  const _ModeCard({
    required this.title,
    required this.icon,
    required this.accentColor,
    required this.isActive,
    required this.statusText,
    required this.onStart,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isActive ? onCancel : onStart,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: accentColor.withValues(alpha: 0.35)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isActive ? Icons.close_rounded : icon,
                      color: accentColor,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                statusText,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
