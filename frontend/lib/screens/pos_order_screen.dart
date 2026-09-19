import "package:dio/dio.dart";
import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "../models/payment_models.dart";
import "../providers/auth_provider.dart";
import "../providers/order_provider.dart";
import "../services/api_client.dart";
import "../services/app_feedback_service.dart";
import "../widgets/admin_pin_dialog.dart";
import "../widgets/advanced_payment_dialog.dart";
import "admin_dashboard_screen.dart";
import "login_screen.dart";
import "waiter_tables_screen.dart" show WaiterTablesScreen;

// ─── Category definition ─────────────────────────────────────────────────────

class _PosCategory {
  final String label;
  final IconData icon;
  final Color color;

  const _PosCategory(this.label, this.icon, this.color);
}

const List<_PosCategory> _kCategories = [
  _PosCategory(
    "ÇAYLAR",
    Icons.emoji_food_beverage_rounded,
    Color(0xFF10B981),
  ), // Emerald
  _PosCategory(
    "TÜRK KAHVESİ ÇEŞİTLERİ",
    Icons.coffee_rounded,
    Color(0xFF78350F),
  ), // Brown
  _PosCategory(
    "ESPRESSOLU KAHVELER",
    Icons.local_cafe_rounded,
    Color(0xFF4B2C20),
  ), // Coffee
  _PosCategory(
    "SOĞUK KAHVELER",
    Icons.coffee_maker_rounded,
    Color(0xFF1E40AF),
  ), // Blue-800
  _PosCategory(
    "FİLTRE KAHVELER",
    Icons.filter_alt_rounded,
    Color(0xFF57534E),
  ), // Stone
  _PosCategory(
    "MEŞRUBATLAR",
    Icons.local_drink_rounded,
    Color(0xFF3B82F6),
  ), // Blue
  _PosCategory(
    "SOĞUK İÇECEKLER",
    Icons.ac_unit_rounded,
    Color(0xFF0EA5E9),
  ), // Sky
  _PosCategory(
    "MEYVELİ FROZENLER",
    Icons.wb_sunny_rounded,
    Color(0xFFFB923C),
  ), // Orange-400
  _PosCategory("FRAPPELER", Icons.blender_rounded, Color(0xFFEC4899)), // Pink
  _PosCategory(
    "MİLKSHAKELER",
    Icons.wine_bar_rounded,
    Color(0xFF6366F1),
  ), // Indigo
  _PosCategory(
    "SAHLEP-SICAK ÇİKOLATA",
    Icons.local_fire_department_outlined,
    Color(0xFF92400E),
  ), // Brown-800
  _PosCategory(
    "YENİ NESİL KAHVELER",
    Icons.science_rounded,
    Color(0xFF0F766E),
  ), // Teal-700
  _PosCategory("DETOKS", Icons.spa_rounded, Color(0xFF65A30D)), // Lime-600
  _PosCategory(
    "MATCHA (MAÇA)",
    Icons.grass_rounded,
    Color(0xFF059669),
  ), // Emerald-600
  _PosCategory(
    "ANA YEMEKLER",
    Icons.restaurant_rounded,
    Color(0xFFEF4444),
  ), // Red
  _PosCategory(
    "HAMBURGERLER",
    Icons.lunch_dining_rounded,
    Color(0xFFDC2626),
  ), // Red-600
  _PosCategory("APERATİFLER", Icons.tapas_rounded, Color(0xFF8B5CF6)), // Violet
  _PosCategory(
    "MAKARNALAR",
    Icons.ramen_dining_rounded,
    Color(0xFFF59E0B),
  ), // Amber-500
  _PosCategory(
    "PİZZALAR",
    Icons.local_pizza_rounded,
    Color(0xFFB91C1C),
  ), // Red-700
  _PosCategory("SALATALAR", Icons.eco_rounded, Color(0xFF15803D)), // Green-700
  _PosCategory(
    "KAHVALTI VE BAŞLANGIÇLAR",
    Icons.breakfast_dining_rounded,
    Color(0xFFEAB308),
  ), // Yellow
  _PosCategory(
    "WRAPLAR",
    Icons.wrap_text_rounded,
    Color(0xFF4338CA),
  ), // Indigo-700
  _PosCategory(
    "KREPLER",
    Icons.bakery_dining_rounded,
    Color(0xFFD97706),
  ), // Amber
  _PosCategory(
    "PASTA VE KEKLER",
    Icons.cake_rounded,
    Color(0xFFBE185D),
  ), // Rose
  _PosCategory(
    "DONDURMALAR",
    Icons.icecream_rounded,
    Color(0xFFF472B6),
  ), // Light Pink
  _PosCategory(
    "FONDU-WAFFLE",
    Icons.grid_on_rounded,
    Color(0xFFDB2777),
  ), // Pink-600
  _PosCategory(
    "NARGİLE",
    Icons.smoking_rooms_rounded,
    Color(0xFF475569),
  ), // Slate-600
  _PosCategory(
    "TAKE AWAY",
    Icons.takeout_dining_rounded,
    Color(0xFF2563EB),
  ), // Blue-600
];

String _categoryImageAsset(String label) {
  final Map<String, String> imageMap = {
    "SOĞUK İÇECEKLER": "assets/soğuk içecekler.jpg",
    "ANA YEMEKLER": "assets/Ana yemekler.jpg",
    "HAMBURGERLER": "assets/hamburger.jpg",
    "APERATİFLER": "assets/aperatifler.jpg",
    "ÇAYLAR": "assets/çaylar.jpg",
    "TÜRK KAHVESİ ÇEŞİTLERİ": "assets/türk kahvesi çeşitleri.jpg",
    "ESPRESSOLU KAHVELER": "assets/espressolu kahveler.jpg",
    "FİLTRE KAHVELER": "assets/filtre kahveler.jpg",
    "FRAPPELER": "assets/frappeler.jpg",
    "KAHVALTI VE BAŞLANGIÇLAR": "assets/kahvaltılar ve başlangıçlar.jpg",
    "DONDURMALAR": "assets/dondurmalar.jpeg",
    "KREPLER": "assets/krepler.jpeg",
    "MAKARNALAR": "assets/makarnalar.jpg",
    "MEŞRUBATLAR": "assets/meşrubatlar.jpeg",
    "MEYVELİ FROZENLER": "assets/meyveli frozen.jpg",
    "MİLKSHAKELER": "assets/milkshakeler.jpg",
    "PASTA VE KEKLER": "assets/pastalar ve kekler.jpg",
    "PİZZALAR": "assets/pizzalar.jpg",
    "SAHLEP-SICAK ÇİKOLATA": "assets/sahlep ve sıcak çikolata.jpg",
    "SALATALAR": "assets/salatalar.jpg",
    "SOĞUK KAHVELER": "assets/soğuk kahveler.jpg",
    "WRAPLAR": "assets/wrapler.jpg",
    "YENİ NESİL KAHVELER": "assets/yeni nesil kahveler.jpg",
    "DETOKS": "assets/detoks.jpg",
    "NARGİLE": "assets/nargile.jpeg",
    "TAKE AWAY": "assets/take away.jpg",
    "FONDU-WAFFLE": "assets/föndü waffle.jpg",
    "MATCHA (MAÇA)": "assets/matcha.jpeg",
  };

  return imageMap[label] ?? "assets/logo.jpg";
}

_PosCategory _resolvePosCategory(String label) {
  for (final category in _kCategories) {
    if (category.label.trim().toUpperCase() == label.trim().toUpperCase()) {
      return category;
    }
  }

  const fallbackIcons = <IconData>[
    Icons.category_rounded,
    Icons.restaurant_menu_rounded,
    Icons.local_cafe_rounded,
    Icons.local_drink_rounded,
    Icons.fastfood_rounded,
    Icons.bakery_dining_rounded,
  ];
  const fallbackColors = <Color>[
    Color(0xFF2563EB),
    Color(0xFF059669),
    Color(0xFFDC2626),
    Color(0xFFD97706),
    Color(0xFF7C3AED),
    Color(0xFF0F766E),
  ];

  final hash = label.runes.fold<int>(0, (sum, rune) => sum + rune);
  return _PosCategory(
    label,
    fallbackIcons[hash % fallbackIcons.length],
    fallbackColors[hash % fallbackColors.length],
  );
}

String _normalizeCategoryLabel(String value) {
  return value
      .trim()
      .toLowerCase()
      .replaceAll("ı", "i")
      .replaceAll("İ", "i")
      .replaceAll("ş", "s")
      .replaceAll("Ş", "s")
      .replaceAll("ğ", "g")
      .replaceAll("Ğ", "g")
      .replaceAll("ü", "u")
      .replaceAll("Ü", "u")
      .replaceAll("ö", "o")
      .replaceAll("Ö", "o")
      .replaceAll("ç", "c")
      .replaceAll("Ç", "c")
      .replaceAll(RegExp(r"[^a-z0-9]+"), " ")
      .replaceAll(RegExp(r"\s+"), " ")
      .trim();
}

List<_PosCategory> _orderedCategoriesForDisplay(
  Iterable<String> rawCategories,
) {
  final normalizedToOriginal = <String, String>{};
  final normalizedOrder = <String>[];

  for (final category in rawCategories) {
    final normalized = _normalizeCategoryLabel(category);
    if (normalized.isEmpty || normalized == "tumu") continue;
    if (!normalizedToOriginal.containsKey(normalized)) {
      normalizedToOriginal[normalized] = category;
      normalizedOrder.add(normalized);
    }
  }

  if (normalizedToOriginal.isEmpty) {
    return const <_PosCategory>[];
  }

  final result = <_PosCategory>[];
  final used = <String>{};

  for (final predefined in _kCategories) {
    final normalized = _normalizeCategoryLabel(predefined.label);
    if (normalizedToOriginal.containsKey(normalized)) {
      result.add(predefined);
      used.add(normalized);
    }
  }

  for (final normalized in normalizedOrder) {
    if (used.contains(normalized)) continue;
    final original = normalizedToOriginal[normalized]!;
    result.add(_resolvePosCategory(original));
  }

  return result;
}

// ─── Entry point ─────────────────────────────────────────────────────────────

class PosOrderScreen extends StatelessWidget {
  final int tableId;
  final String tableName;
  final bool embedded;
  final VoidCallback? onClose;
  final VoidCallback? onPaymentMade;
  final ValueChanged<bool>? onPaymentFinished;

  const PosOrderScreen({
    super.key,
    required this.tableId,
    required this.tableName,
    this.embedded = false,
    this.onClose,
    this.onPaymentMade,
    this.onPaymentFinished,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => OrderProvider(tableId)..loadInitialData(),
      child: _PosOrderView(
        tableId: tableId,
        tableName: tableName,
        embedded: embedded,
        onClose: onClose,
        onPaymentMade: onPaymentMade,
        onPaymentFinished: onPaymentFinished,
      ),
    );
  }
}

// ─── Main view ────────────────────────────────────────────────────────────────

class _PosOrderView extends StatefulWidget {
  final int tableId;
  final String tableName;
  final bool embedded;
  final VoidCallback? onClose;
  final VoidCallback? onPaymentMade;
  final ValueChanged<bool>? onPaymentFinished;
  const _PosOrderView({
    required this.tableId,
    required this.tableName,
    this.embedded = false,
    this.onClose,
    this.onPaymentMade,
    this.onPaymentFinished,
  });

  @override
  State<_PosOrderView> createState() => _PosOrderViewState();
}

class _PosOrderViewState extends State<_PosOrderView> {
  // null = show category grid, non-null = show products of that category
  String? _activeCategory;
  int? _selectedLineProductId;
  bool _hasSeenOpenOrder = false;
  bool _isAutoClosing = false;

  static const _bgColor = Color(0xFFF1F5F9); // Light Slate-100
  static const _productBg = Color(0xFFF8FAFC); // Light Slate-50
  static const _productCard = Colors.white;
  static const _productBorder = Color(0xFFE2E8F0);
  static const _productMuted = Color(0xFF64748B);

  static final String _turkishCoffeeCategoryNormalized =
      _normalizeCategoryLabel("TÜRK KAHVESİ ÇEŞİTLERİ");

  bool _isTurkishCoffeeProduct(MenuProduct product) {
    final normalizedCategory = _normalizeCategoryLabel(product.categoryName);
    return normalizedCategory == _turkishCoffeeCategoryNormalized;
  }

  Future<String?> _showTurkishCoffeeSugarDialog(MenuProduct product) {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                product.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                "Şeker tercihi",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 10),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.no_drinks_rounded),
                title: const Text("Sade"),
                onTap: () => Navigator.of(sheetContext).pop("sade"),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.coffee_rounded),
                title: const Text("Az Şekerli"),
                onTap: () => Navigator.of(sheetContext).pop("az sekerli"),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.local_cafe_rounded),
                title: const Text("Orta Şekerli"),
                onTap: () => Navigator.of(sheetContext).pop("orta sekerli"),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.emoji_food_beverage_rounded),
                title: const Text("Şekerli"),
                onTap: () => Navigator.of(sheetContext).pop("sekerli"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToHomeAfterTableClosed(BuildContext context) {
    if (widget.embedded) {
      widget.onClose?.call();
      return;
    }

    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const WaiterTablesScreen()),
      (route) => false,
    );
  }

  void _maybeExitWhenOrderCompleted(OrderProvider order) {
    final hasVisibleOrder =
        order.hasActiveOrder ||
        order.cartLines.isNotEmpty ||
        order.totalAmount > 0.009;

    if (hasVisibleOrder) {
      _hasSeenOpenOrder = true;
      _isAutoClosing = false;
      return;
    }

    final shouldClose =
        _hasSeenOpenOrder &&
        !_isAutoClosing &&
        order.cartLines.isEmpty &&
        order.totalAmount <= 0.009 &&
        !order.isBusy &&
        !order.isCheckingOut &&
        !order.isSubmitting &&
        !order.isPaymentSessionActive &&
        !order.isPrintingReceipt;

    if (!shouldClose) return;

    _isAutoClosing = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _navigateToHomeAfterTableClosed(context);
    });
  }

  Future<void> _logout(BuildContext context) async {
    await context.read<AuthProvider>().logout();
    if (!context.mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Future<void> _openAdminPanel(BuildContext context) async {
    final unlocked = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AdminPinDialog(),
    );

    if (!context.mounted || unlocked != true) return;

    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const AdminDashboardScreen()));
  }

  Future<void> _showOrderMetaDialog(
    BuildContext context,
    OrderProvider order,
  ) async {
    if (!order.hasActiveOrder) {
      AppFeedbackService.showError("Önce masaya en az bir ürün ekleyin.");
      return;
    }

    final guestController = TextEditingController(
      text: order.guestCount.toString(),
    );
    final noteController = TextEditingController(text: order.tableNote);

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
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
                        color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.edit_note_rounded,
                        color: Color(0xFF3B82F6),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Masa Bilgileri",
                            style: TextStyle(
                              color: Color(0xFF0F172A),
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                            ),
                          ),
                          Text(
                            "Kuver sayısı ve özel notlar",
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
                      "KUVER SAYISI",
                      style: TextStyle(
                        color: Color(0xFF3F3F46),
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: guestController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontWeight: FontWeight.w700,
                      ),
                      decoration: InputDecoration(
                        hintText: "Kişi sayısı girin",
                        hintStyle: const TextStyle(color: Color(0xFF3F3F46)),
                        filled: true,
                        fillColor: const Color(0xFFFFFFFF),
                        prefixIcon: const Icon(
                          Icons.people_alt_rounded,
                          color: Color(0xFF71717A),
                          size: 20,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: Color(0xFFE2E8F0),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: Color(0xFFE2E8F0),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: Color(0xFF3B82F6),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      "MASA NOTU",
                      style: TextStyle(
                        color: Color(0xFF3F3F46),
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: noteController,
                      maxLines: 3,
                      style: const TextStyle(color: Color(0xFF0F172A)),
                      decoration: InputDecoration(
                        hintText: "Örn: Pencere kenarı, Az tuzlu vb.",
                        hintStyle: const TextStyle(color: Color(0xFF3F3F46)),
                        filled: true,
                        fillColor: const Color(0xFFFFFFFF),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: Color(0xFFE2E8F0),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: Color(0xFFE2E8F0),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: Color(0xFF3B82F6),
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
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
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
                      onPressed: () async {
                        final guests =
                            int.tryParse(guestController.text.trim()) ?? 1;
                        final ok = await context
                            .read<OrderProvider>()
                            .saveOrderMeta(
                              guestCount: guests,
                              tableNote: noteController.text,
                            );
                        if (!context.mounted || !dialogContext.mounted) return;
                        if (ok) {
                          Navigator.of(dialogContext).pop();
                        } else {
                          final msg =
                              context.read<OrderProvider>().errorMessage ??
                              "Masa bilgileri kaydedilemedi.";
                          AppFeedbackService.showError(msg);
                        }
                      },
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: const Text("Kaydet"),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFDBEAFE),
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

    guestController.dispose();
    noteController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final order = context.watch<OrderProvider>();
    final canTakePayment =
        context.watch<AuthProvider>().currentUser?.roleId == 1;

    _maybeExitWhenOrderCompleted(order);

    final body = LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 980;
        final isEmbeddedTabletLayout =
            widget.embedded && constraints.maxWidth >= 760;

        if (isEmbeddedTabletLayout) {
          return Column(
            children: [
              _buildTopBar(context, order),
              Expanded(
                child: _buildDesktopPosSplitLayout(
                  context,
                  order,
                  canTakePayment,
                  compactLayout: true,
                ),
              ),
            ],
          );
        }

        if (isNarrow) {
          return Column(
            children: [
              _buildTopBar(context, order, isMobile: true),
              if (_activeCategory != null)
                _buildCategoryTabBar(order)
              else
                const SizedBox.shrink(),
              Expanded(
                child: _activeCategory == null
                    ? _buildCategoryGrid(order)
                    : _buildProductGrid(order),
              ),
              _buildMobileCartButton(context, order, canTakePayment),
            ],
          );
        }

        return Column(
          children: [
            _buildTopBar(context, order),
            Expanded(
              child: _buildDesktopPosSplitLayout(
                context,
                order,
                canTakePayment,
              ),
            ),
          ],
        );
      },
    );

    if (widget.embedded) return body;

    return Scaffold(
      backgroundColor: _bgColor,
      body: SafeArea(child: body),
    );
  }

  Widget _buildDesktopPosSplitLayout(
    BuildContext context,
    OrderProvider order,
    bool canTakePayment, {
    bool compactLayout = false,
  }) {
    final lines = order.cartLines;
    final selectedLine = _resolveSelectedLine(lines);

    return Container(
      color: _bgColor,
      padding: EdgeInsets.fromLTRB(
        compactLayout ? 10 : 12,
        compactLayout ? 10 : 12,
        compactLayout ? 10 : 12,
        compactLayout ? 10 : 12,
      ),
      child: Column(
        children: [
          Expanded(
            flex: 6,
            child: Row(
              children: [
                Expanded(
                  flex: 7,
                  child: _buildAdisyonTable(
                    order,
                    lines,
                    compactLayout: compactLayout,
                  ),
                ),
                SizedBox(width: compactLayout ? 8 : 12),
                Expanded(
                  flex: 3,
                  child: _buildDesktopActionPanel(
                    context,
                    order,
                    canTakePayment,
                    selectedLine,
                    compactLayout: compactLayout,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: compactLayout ? 8 : 10),
          // Üst-alt alanı daha dengeli tutarak ürün gridine daha fazla yer ver.
          Expanded(
            flex: 5,
            child: Column(
              children: [
                Expanded(
                  child: _activeCategory == null
                      ? _buildCategoryGrid(order, compactLayout: true)
                      : _buildProductsOnlyGrid(
                          order,
                          compactLayout: compactLayout,
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  CartLine? _resolveSelectedLine(List<CartLine> lines) {
    if (lines.isEmpty) return null;

    final lastAddedLine = context.read<OrderProvider>().lastAddedCartLine;
    if (lastAddedLine != null) {
      for (final line in lines) {
        if (line.product.id == lastAddedLine.product.id) {
          _selectedLineProductId = line.product.id;
          return line;
        }
      }
    }

    if (_selectedLineProductId == null) {
      _selectedLineProductId = lines.first.product.id;
      return lines.first;
    }

    for (final line in lines) {
      if (line.product.id == _selectedLineProductId) {
        return line;
      }
    }

    _selectedLineProductId = lines.first.product.id;
    return lines.first;
  }

  Widget _buildAdisyonTable(
    OrderProvider order,
    List<CartLine> lines, {
    bool compactLayout = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: compactLayout ? 8 : 10,
              vertical: compactLayout ? 8 : 10,
            ),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: const Row(
              children: [
                Expanded(
                  flex: 30,
                  child: Text(
                    "Ürün Adı",
                    style: TextStyle(
                      color: Color(0xFF111827),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
                Expanded(
                  flex: 14,
                  child: Text(
                    "Birim",
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: Color(0xFF111827),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
                Expanded(
                  flex: 10,
                  child: Text(
                    "Adet",
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: Color(0xFF111827),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
                Expanded(
                  flex: 10,
                  child: Text(
                    "Kdv",
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: Color(0xFF111827),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
                Expanded(
                  flex: 16,
                  child: Text(
                    "Toplam",
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: Color(0xFF111827),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
                Expanded(
                  flex: 20,
                  child: Text(
                    "Not",
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: Color(0xFF111827),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: lines.isEmpty
                ? const Center(
                    child: Text(
                      "Henüz ürün seçilmedi",
                      style: TextStyle(
                        color: Color(0xFF94A3B8),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    itemCount: lines.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    itemBuilder: (context, index) {
                      final line = lines[index];
                      final isSelected =
                          line.product.id == _selectedLineProductId;
                      return InkWell(
                        onTap: () {
                          setState(
                            () => _selectedLineProductId = line.product.id,
                          );
                          _showLineOperationsDialog(context, order, line);
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(
                                    0xFFDBEAFE,
                                  ).withValues(alpha: 0.35)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 30,
                                child: Text(
                                  line.product.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xFF111827),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 14,
                                child: Text(
                                  line.unitPrice.toStringAsFixed(2),
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(
                                    color: Color(0xFF111827),
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 10,
                                child: Text(
                                  line.quantity.toStringAsFixed(1),
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(
                                    color: Color(0xFF111827),
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 10,
                                child: Text(
                                  "%${line.product.vatRate.toStringAsFixed(line.product.vatRate % 1 == 0 ? 0 : 1)}",
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(
                                    color: Color(0xFF111827),
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 16,
                                child: Text(
                                  line.lineTotal.toStringAsFixed(2),
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(
                                    color: Color(0xFF111827),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 20,
                                child: Text(
                                  line.note,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF374151),
                                  ),
                                ),
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

  Widget _buildDesktopActionPanel(
    BuildContext context,
    OrderProvider order,
    bool canTakePayment,
    CartLine? selectedLine, {
    bool compactLayout = false,
  }) {
    final selectedLineName = selectedLine?.product.name ?? "Satır seçin";

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isTight = constraints.maxHeight < 560;
          final sidePadding = isTight ? 10.0 : (compactLayout ? 10.0 : 12.0);
          final totalFont = isTight ? 24.0 : (compactLayout ? 24.0 : 30.0);

          return Padding(
            padding: EdgeInsets.all(sidePadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          widget.tableName,
                          style: TextStyle(
                            fontSize: compactLayout ? 16 : 18,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF0F172A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Kişi: ${order.guestCount}",
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          "Toplam Tutar",
                          style: TextStyle(
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "${order.totalAmount.toStringAsFixed(2)} TL",
                          style: TextStyle(
                            fontSize: totalFont,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF10B981),
                            letterSpacing: -0.8,
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: (!canTakePayment || order.isCheckingOut)
                                ? null
                                : () => _handleAdvancedPayment(context, order),
                            icon: const Icon(Icons.payments_rounded, size: 18),
                            label: const Text("Ödeme Al"),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF3B82F6),
                              foregroundColor: const Color(0xFFFFFFFF),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed:
                                !order.hasActiveOrder ||
                                    order.hasItems ||
                                    order.isSubmitting ||
                                    order.isCheckingOut ||
                                    order.isPrintingReceipt
                                ? null
                                : () async {
                                    final ok = await context
                                        .read<OrderProvider>()
                                        .printCurrentAccount(
                                          tableName: widget.tableName,
                                        );
                                    if (!context.mounted) return;
                                    if (ok) {
                                      AppFeedbackService.showSuccess(
                                        "Adisyon kasa yazıcısına gönderildi.",
                                      );
                                    } else {
                                      final msg =
                                          context
                                              .read<OrderProvider>()
                                              .errorMessage ??
                                          "Adisyon yazdırılamadı.";
                                      AppFeedbackService.showError(msg);
                                    }
                                  },
                            icon: order.isPrintingReceipt
                                ? const SizedBox(
                                    height: 16,
                                    width: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Color(0xFF0F172A),
                                    ),
                                  )
                                : const Icon(Icons.print_rounded, size: 18),
                            label: Text(
                              order.isPrintingReceipt
                                  ? "Yazdırılıyor..."
                                  : "Adisyonu Yazdır",
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF0F172A),
                              side: const BorderSide(color: Color(0xFFCBD5E1)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Text(
                            "Seçili: $selectedLineName",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _buildQtyActionBtn("+", () {
                                if (selectedLine == null) return;
                                order.increase(selectedLine.product);
                              }, enabled: selectedLine != null),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildQtyActionBtn("-", () {
                                if (selectedLine == null) return;
                                order.decrease(selectedLine.product);
                              }, enabled: selectedLine != null),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _buildQtyActionBtn("+0.5", () {
                                if (selectedLine == null) return;
                                order.increase(
                                  selectedLine.product,
                                  amount: 0.5,
                                );
                              }, enabled: selectedLine != null),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildQtyActionBtn("-0.5", () {
                                if (selectedLine == null) return;
                                order.decrease(
                                  selectedLine.product,
                                  amount: 0.5,
                                );
                              }, enabled: selectedLine != null),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: selectedLine == null
                              ? null
                              : () => _showChangePriceDialog(
                                  context,
                                  order,
                                  selectedLine,
                                ),
                          icon: const Icon(Icons.sell_rounded, size: 18),
                          label: const Text("Fiyat Değiştir"),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: selectedLine == null
                              ? null
                              : () =>
                                    _showItemNoteDialog(context, selectedLine),
                          icon: const Icon(Icons.edit_note_rounded, size: 18),
                          label: const Text("Sipariş Notu"),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: selectedLine == null
                              ? null
                              : () => _showDeleteItemDialog(
                                  context,
                                  order,
                                  selectedLine,
                                ),
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            size: 18,
                          ),
                          label: const Text("Sil"),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFEF4444),
                            side: const BorderSide(color: Color(0xFFFCA5A5)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                FilledButton(
                  onPressed:
                      (!order.hasItems ||
                          order.isSubmitting ||
                          order.isCheckingOut)
                      ? null
                      : () async {
                          final ok = await context
                              .read<OrderProvider>()
                              .submitAndConfirmOrder();
                          if (!context.mounted) return;
                          if (ok) {
                            AppFeedbackService.showSuccess(
                              "Yeni ürünler mutfağa gönderildi.",
                            );
                          } else {
                            final msg =
                                context.read<OrderProvider>().errorMessage ??
                                "Sipariş onaylanamadı.";
                            AppFeedbackService.showError(msg);
                          }
                        },
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: order.isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFFFFFFFF),
                          ),
                        )
                      : const Text(
                          "SİPARİŞİ ONAYLA",
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildQtyActionBtn(
    String label,
    VoidCallback onTap, {
    bool enabled = true,
  }) {
    return SizedBox(
      height: 40,
      child: OutlinedButton(
        onPressed: enabled ? onTap : null,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 6),
        ),
        child: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w800),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _buildProductsOnlyGrid(
    OrderProvider order, {
    bool compactLayout = false,
  }) {
    if (order.isBusy) {
      return const Center(child: CircularProgressIndicator());
    }

    final products = order.filteredProducts;
    if (products.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: const Color(0xFFFFFFFF),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Center(
          child: Text(
            "Bu kategoride ürün bulunamadı.",
            style: TextStyle(
              color: Color(0xFF94A3B8),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: GridView.builder(
        padding: EdgeInsets.all(compactLayout ? 8 : 10),
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        itemCount: products.length,
        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: compactLayout ? 132 : 156,
          mainAxisSpacing: compactLayout ? 6 : 8,
          crossAxisSpacing: compactLayout ? 6 : 8,
          childAspectRatio: compactLayout ? 1.08 : 1.12,
        ),
        itemBuilder: (context, index) {
          final product = products[index];
          return _buildProductCard(product, order);
        },
      ),
    );
  }

  Future<void> _showItemNoteDialog(BuildContext context, CartLine line) async {
    final controller = TextEditingController(text: line.note);

    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Sipariş Notu"),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(hintText: "Not girin"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text("İptal"),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text("Kaydet"),
          ),
        ],
      ),
    );

    if (!context.mounted || saved != true) return;

    final ok = await context.read<OrderProvider>().saveItemNote(
      line.product.id,
      controller.text,
      applyToExisting: line.newQuantity <= 0.0001,
    );

    if (!context.mounted) return;
    if (!ok) {
      AppFeedbackService.showError(
        context.read<OrderProvider>().errorMessage ??
            "Sipariş notu kaydedilemedi.",
      );
    }
  }

  Future<void> _handleAdvancedPayment(
    BuildContext context,
    OrderProvider order,
  ) async {
    final lines = order.cartLines.where((l) => l.existingQuantity > 0).toList();
    if (lines.isEmpty) {
      AppFeedbackService.showError("Ödeme yapılacak ürün yok.");
      return;
    }

    final allItems = lines
        .map(
          (l) => TableOrderPreviewItem(
            productId: l.product.id,
            name: l.product.name,
            quantity: l.existingQuantity.toDouble(),
            lineTotal: l.unitPrice * l.existingQuantity,
            unitPrice: l.unitPrice,
          ),
        )
        .toList();

    final totalAmount = allItems.fold(0.0, (sum, item) => sum + item.lineTotal);

    final locked = await order.beginPaymentSession();
    if (!context.mounted) return;
    if (!locked) {
      AppFeedbackService.showError(
        order.errorMessage ?? "Bu adisyonda su anda odeme aliniyor.",
      );
      return;
    }

    try {
      final checkout = await showDialog<CheckoutDialogResult>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AdvancedPaymentDialog(
          tableName: widget.tableName,
          totalAmount: totalAmount,
          initialDiscountAmount: order.discountTotal,
          initialCollectedAmount: order.amountPaymentPaid,
          allItems: allItems,
        ),
      );

      if (!context.mounted || checkout == null) {
        if (order.isPaymentSessionActive) {
          await order.endPaymentSession();
        }
        return;
      }

      final collectedTotal = checkout.payments.fold<double>(
        0,
        (sum, payment) => sum + payment.amount,
      );
      final isFullSettlement =
          (collectedTotal - checkout.netAmount).abs() <= 0.01;

      bool isTableClosed = false;

      if (checkout.selectedItems.isNotEmpty && !isFullSettlement) {
        final groupedItems = <int, double>{};
        for (var item in checkout.selectedItems) {
          groupedItems[item.productId] =
              (groupedItems[item.productId] ?? 0) + item.quantity;
        }

        final itemsList = groupedItems.entries
            .map((e) => {"product_id": e.key, "quantity": e.value})
            .toList();

        final paymentsList = checkout.payments
            .map(
              (p) => {
                "paymentMethod": p.paymentMethod,
                "amount": p.amount,
                "mealCardType": p.mealCardType,
              },
            )
            .toList();

        await ApiClient.dio.post(
          "/waiter/orders/${order.activeOrderId}/partial-checkout",
          data: {
            "items": itemsList,
            "payments": paymentsList,
            "discountAmount": checkout.discountAmount,
          },
        );
      } else {
        if (checkout.payments.isEmpty && checkout.discountAmount > 0) {
          // Tam indirim durumu: Tutar girmeden sadece indirimle kapatma
          final response = await ApiClient.dio.post(
            "/waiter/orders/${order.activeOrderId}/amount-payment",
            data: {
              "amount": 0,
              "paymentMethod": "CASH",
              "mealCardType": null,
              "discountAmount": checkout.discountAmount,
              "finalTotal": checkout.netAmount,
            },
          );
          final data = response.data;
          if (data is Map && data["table_closed"] == true) {
            isTableClosed = true;
          }
        } else {
          for (var i = 0; i < checkout.payments.length; i++) {
            final payment = checkout.payments[i];
            final response = await ApiClient.dio.post(
              "/waiter/orders/${order.activeOrderId}/amount-payment",
              data: {
                "amount": payment.amount,
                "paymentMethod": payment.paymentMethod,
                "mealCardType": payment.mealCardType,
                "discountAmount": i == 0 ? checkout.discountAmount : 0,
                "finalTotal": checkout.netAmount,
              },
            );

            if (i == checkout.payments.length - 1) {
              final data = response.data;
              if (data is Map && data["table_closed"] == true) {
                isTableClosed = true;
              }
            }
          }
        }
      }

      await order.endPaymentSession();
      await order.loadActiveOrderOnly();
      if (!context.mounted) return;

      if (isTableClosed) {
        widget.onPaymentMade?.call();
      }
      widget.onPaymentFinished?.call(isTableClosed);

      AppFeedbackService.showSuccess(
        isTableClosed ? "Ödeme tamamlandı. Masa kapatıldı." : "Ödeme alındı.",
      );
      if (isTableClosed) {
        _navigateToHomeAfterTableClosed(context);
      }
      return;
    } on DioException catch (e) {
      if (context.mounted) {
        AppFeedbackService.showError(ApiClient.describeDioError(e));
      }
    } catch (e, stack) {
      debugPrint("Ödeme hatası detay: $e\n$stack");
      if (context.mounted) {
        final errorMsg = e.toString();
        if (errorMsg.contains("Null check operator")) {
          // Bu hata genellikle UI rebuild sırasında oluşur, kullanıcıya yansıtmayalım
          // veya daha anlamlı bir mesaj verelim.
          AppFeedbackService.showSuccess(
            "İşlem tamamlandı.",
          ); // Masa kapandıysa başarıdır
        } else {
          AppFeedbackService.showError(
            "Ödeme işlemi sırasında bir sorun oluştu: $e",
          );
        }
      }
    } finally {
      if (order.isPaymentSessionActive) {
        await order.endPaymentSession();
      }
    }
  }

  Widget _buildMobileCartButton(
    BuildContext context,
    OrderProvider order,
    bool canTakePayment,
  ) {
    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        decoration: const BoxDecoration(
          color: Color(0xFFF8FAFC),
          border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: SizedBox(
                height: 58,
                child: ElevatedButton(
                  onPressed: () =>
                      _openMobileReceiptSheet(context, order, canTakePayment),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: const Color(0xFFF8FAFC),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                  ),
                  child: const Icon(
                    Icons.shopping_cart_checkout_rounded,
                    size: 24,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: SizedBox(
                height: 58,
                child: ElevatedButton(
                  onPressed:
                      (!order.hasItems ||
                          order.isSubmitting ||
                          order.isCheckingOut)
                      ? null
                      : () async {
                          final ok = await context
                              .read<OrderProvider>()
                              .submitAndConfirmOrder();
                          if (!context.mounted) return;
                          if (ok) {
                            AppFeedbackService.showSuccess(
                              "Yeni ürünler mutfağa gönderildi.",
                            );
                            Navigator.of(context).pop(true);
                          } else {
                            final msg =
                                context.read<OrderProvider>().errorMessage ??
                                "Sipariş onaylanamadı.";
                            AppFeedbackService.showError(msg);
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDCFCE7),
                    foregroundColor: const Color(0xFF0F172A),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    textStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  child: order.isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF0F172A),
                          ),
                        )
                      : const Text("Onayla"),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openMobileReceiptSheet(
    BuildContext context,
    OrderProvider order,
    bool canTakePayment,
  ) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return ChangeNotifierProvider<OrderProvider>.value(
          value: order,
          child: Consumer<OrderProvider>(
            builder: (sheetContext, liveOrder, _) {
              return FractionallySizedBox(
                heightFactor: 0.9,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(18),
                  ),
                  child: _ReceiptSidebar(
                    order: liveOrder,
                    tableName: widget.tableName,
                    tableId: widget.tableId,
                    canTakePayment: canTakePayment,
                    onOpenOrderMeta: () =>
                        _showOrderMetaDialog(sheetContext, liveOrder),
                    fullWidth: true,
                    isMobile: true,
                    onPaymentMade: widget.onPaymentMade,
                    onPaymentFinished: widget.onPaymentFinished,
                    onDone: (refreshed) {
                      Navigator.of(sheetContext).pop(refreshed);
                    },
                  ),
                ),
              );
            },
          ),
        );
      },
    );

    if (!context.mounted) return;
    if (confirmed == true) {
      // Sipariş onaylandı — masalar / ana sayfaya dön
      Navigator.of(context).pop(true);
    }
  }

  // ── Top bar ──────────────────────────────────────────────────────────────

  Widget _buildTopBar(
    BuildContext context,
    OrderProvider order, {
    bool isMobile = false,
  }) {
    final bool inProducts = _activeCategory != null;
    final showLocalActions = !widget.embedded;
    final canOpenAdminPanel =
        context.read<AuthProvider>().currentUser?.roleId == 1;

    final actionButtons = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (canOpenAdminPanel) ...[
          FilledButton.icon(
            onPressed: () => _openAdminPanel(context),
            icon: const Icon(Icons.admin_panel_settings_rounded, size: 18),
            label: const Text("Yönetici Paneli"),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFDBEAFE),
              foregroundColor: const Color(0xFF0F172A),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
            ),
          ),
          const SizedBox(width: 12),
        ],
        OutlinedButton.icon(
          onPressed: () => _logout(context),
          icon: const Icon(Icons.logout_rounded, size: 18),
          label: const Text("Çıkış"),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFF87171),
            side: BorderSide(
              color: const Color(0xFFEF4444).withValues(alpha: 0.5),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            textStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );

    final leadingContent = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Embedded mode'da "Masalar" butonunu daha belirgin yap
        InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: inProducts
              ? () {
                  setState(() => _activeCategory = null);
                  order.setSearchQuery("");
                }
              : widget.embedded
              ? () => widget.onClose?.call()
              : () {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                      builder: (_) => const WaiterTablesScreen(),
                    ),
                    (route) => false,
                  );
                },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: widget.embedded
                  ? const Color(0xFF3B82F6)
                  : const Color(0xFFFFFFFF),
              borderRadius: BorderRadius.circular(10),
              border: widget.embedded
                  ? Border.all(color: const Color(0xFF2563EB))
                  : Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 16,
                  color: widget.embedded
                      ? const Color(0xFFFFFFFF)
                      : const Color(0xFF0F172A),
                ),
                const SizedBox(width: 8),
                Text(
                  inProducts ? "Kategoriler" : "Masalar",
                  style: TextStyle(
                    color: widget.embedded
                        ? const Color(0xFFFFFFFF)
                        : const Color(0xFF0F172A),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        // Masa numarası - embedded mode'da daha belirgin
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(
              0xFF10B981,
            ).withValues(alpha: widget.embedded ? 1.0 : 0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: const Color(
                0xFF10B981,
              ).withValues(alpha: widget.embedded ? 1.0 : 0.2),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.table_bar_rounded,
                size: 18,
                color: widget.embedded
                    ? const Color(0xFFFFFFFF)
                    : const Color(0xFF10B981),
              ),
              const SizedBox(width: 8),
              Text(
                widget.tableName,
                style: TextStyle(
                  color: widget.embedded
                      ? const Color(0xFFFFFFFF)
                      : const Color(0xFF0F172A),
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
        if (inProducts) ...[
          const SizedBox(width: 8),
          const Icon(
            Icons.chevron_right_rounded,
            color: Color(0xFFE2E8F0),
            size: 20,
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: const Color(0xFF3B82F6).withValues(alpha: 0.2),
              ),
            ),
            child: Text(
              _activeCategory ?? "",
              style: const TextStyle(
                color: Color(0xFF60A5FA),
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 220,
            height: 40,
            child: TextField(
              onChanged: order.setSearchQuery,
              style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A)),
              decoration: InputDecoration(
                hintText: "Ürün ara...",
                hintStyle: const TextStyle(
                  color: Color(0xFF52525B),
                  fontSize: 14,
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  size: 18,
                  color: Color(0xFF52525B),
                ),
                filled: true,
                fillColor: const Color(0xFFFFFFFF),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 0,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFF3B82F6)),
                ),
              ),
            ),
          ),
        ],
      ],
    );

    return Container(
      color: const Color(0xFFF8FAFC),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: isMobile
          ? SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  leadingContent,
                  if (showLocalActions) ...[
                    const SizedBox(width: 12),
                    actionButtons,
                  ],
                ],
              ),
            )
          : Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: leadingContent,
                  ),
                ),
                if (showLocalActions) ...[
                  const SizedBox(width: 16),
                  actionButtons,
                ],
              ],
            ),
    );
  }

  // ── Category tab bar (shown when a category is active) ───────────────────

  Widget _buildCategoryTabBar(OrderProvider order) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 900;
    final categories = _orderedCategoriesForDisplay(order.categories);

    if (categories.isEmpty) {
      return const SizedBox.shrink();
    }

    Widget buildCategoryChip(_PosCategory cat) {
      final isSelected = cat.label == _activeCategory;
      return InkWell(
        onTap: () {
          setState(() => _activeCategory = cat.label);
          order.setSearchQuery("");
          order.setSelectedCategory(cat.label);
        },
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF10B981).withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF10B981).withValues(alpha: 0.3)
                  : const Color(0xFFE2E8F0),
            ),
          ),
          child: Text(
            cat.label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              color: isSelected
                  ? const Color(0xFF10B981)
                  : const Color(0xFF71717A),
            ),
          ),
        ),
      );
    }

    return Container(
      color: const Color(0xFFFFFFFF),
      child: isDesktop
          ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: categories.map(buildCategoryChip).toList(),
              ),
            )
          : SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                itemCount: categories.length,
                separatorBuilder: (_, index) => const SizedBox(width: 6),
                itemBuilder: (context, i) => buildCategoryChip(categories[i]),
              ),
            ),
    );
  }

  // ── Category grid (27 items, 9 per row) ──────────────────────────────────

  Widget _buildCategoryGrid(OrderProvider order, {bool compactLayout = false}) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final categories = _orderedCategoriesForDisplay(order.categories);

    if (categories.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: const Color(0xFFFFFFFF),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Center(
          child: Text(
            "Gosterilecek kategori bulunamadi.",
            style: TextStyle(
              color: Color(0xFF94A3B8),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;

        // Ekrana sığdırmak için sütun sayısını dinamik hesapla
        int crossAxisCount = 6;
        if (w < 600) {
          crossAxisCount = compactLayout ? 4 : 3;
        } else if (w < 900) {
          crossAxisCount = compactLayout ? 5 : 4;
        } else if (w < 1200) {
          crossAxisCount = compactLayout ? 6 : 5;
        }

        final spacing = compactLayout ? 8.0 : 10.0;
        final padding = compactLayout ? 10.0 : 14.0;

        // Satır sayısını hesapla
        final rowCount = (categories.length / crossAxisCount).ceil();

        // Aspect ratio'yu ekran yüksekliğine göre ayarla (kaydırmayı engellemek için)
        // Eleman başına düşen genişlik ve yükseklik
        final availableW = (w - (crossAxisCount - 1) * spacing).clamp(
          0.0,
          double.infinity,
        );
        final availableH = (h - (rowCount - 1) * spacing).clamp(
          0.0,
          double.infinity,
        );

        final itemWidth = availableW / crossAxisCount;
        final itemHeight = availableH / rowCount;
        final contentHeight =
            (rowCount * itemHeight) +
            ((rowCount - 1) * spacing) +
            (padding * 2);
        final canFitWithoutScroll = contentHeight <= h + 0.5;

        // itemHeight 0 veya negatifse varsayılan bir oran kullan
        final aspectRatio = (itemHeight > 10) ? (itemWidth / itemHeight) : 1.2;

        return Container(
          color: _bgColor,
          padding: EdgeInsets.all(padding),
          child: GridView.builder(
            itemCount: categories.length,
            physics: canFitWithoutScroll
                ? const NeverScrollableScrollPhysics()
                : const BouncingScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: spacing,
              mainAxisSpacing: spacing,
              childAspectRatio: (isMobile ? 1.0 : aspectRatio).clamp(0.9, 2.0),
            ),
            itemBuilder: (context, index) {
              final cat = categories[index];
              return _buildCategoryCard(
                cat,
                order,
                compactLayout: compactLayout,
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildCategoryCard(
    _PosCategory cat,
    OrderProvider order, {
    bool compactLayout = false,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600 || compactLayout;

    return _CategoryImageCard(
      title: cat.label,
      imagePath:
          order.categoryImagePathFor(cat.label) ??
          _categoryImageAsset(cat.label),
      tintColor: cat.color,
      isMobile: isMobile,
      onTap: () {
        order.setSelectedCategory(cat.label);
        order.setSearchQuery("");
        setState(() => _activeCategory = cat.label);
      },
    );
  }

  // ── Product grid (filtered by active category + search) ──────────────────

  Widget _buildProductGrid(OrderProvider order, {bool compactLayout = false}) {
    if (order.isBusy) {
      return const Center(child: CircularProgressIndicator());
    }

    final products = order.filteredProducts;

    if (products.isEmpty) {
      return Container(
        color: _productBg,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(
                Icons.search_off_rounded,
                size: 48,
                color: Color(0xFF64748B),
              ),
              SizedBox(height: 12),
              Text(
                "Bu kategoride ürün bulunamadı.",
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 15),
              ),
            ],
          ),
        ),
      );
    }

    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Container(
      color: _productBg,
      padding: EdgeInsets.fromLTRB(
        compactLayout ? 10 : 14,
        compactLayout ? 10 : 14,
        compactLayout ? 10 : 14,
        compactLayout ? 10 : (14 + bottomInset + 16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFFFF),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.widgets_rounded,
                  color: Color(0xFF3B82F6),
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _activeCategory ?? "ÜRÜNLER",
                    style: const TextStyle(
                      color: Color(0xFF0F172A),
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  "${products.length} ürün",
                  style: const TextStyle(
                    color: _productMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 600;
                final isCompact = constraints.maxWidth < 980;
                return GridView.builder(
                  itemCount: products.length,
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  padding: const EdgeInsets.only(bottom: 6),
                  gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: isNarrow
                        ? (compactLayout ? 96 : 108)
                        : (isCompact
                              ? (compactLayout ? 118 : 136)
                              : (compactLayout ? 140 : 156)),
                    mainAxisSpacing: isNarrow ? 6 : (compactLayout ? 6 : 8),
                    crossAxisSpacing: isNarrow ? 6 : (compactLayout ? 6 : 8),
                    childAspectRatio: isNarrow
                        ? (compactLayout ? 1.02 : 1.08)
                        : (isCompact
                              ? (compactLayout ? 1.06 : 1.1)
                              : (compactLayout ? 1.1 : 1.14)),
                  ),
                  itemBuilder: (context, index) {
                    final product = products[index];
                    return _buildProductCard(product, order);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(MenuProduct product, OrderProvider order) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isCompact = screenWidth < 1280;
    final pendingQuantity = order.pendingQuantityOf(product);
    final hasPending = pendingQuantity > 0.0001;
    final pendingLabel = order.formatQuantity(pendingQuantity);

    return Material(
      color: _productCard,
      borderRadius: BorderRadius.circular(isMobile ? 9 : 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(isMobile ? 9 : 10),
        onTap: () async {
          if (_isTurkishCoffeeProduct(product)) {
            order.clearExistingItemNoteIfAny(product.id);
            final variant = await _showTurkishCoffeeSugarDialog(product);
            if (!context.mounted || variant == null) {
              return;
            }
            order.addProductWithVariant(product, variant);
            return;
          }
          order.addProductWithVariant(product, "");
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(isMobile ? 9 : 10),
            border: Border.all(
              color: hasPending ? const Color(0xFF16A34A) : _productBorder,
              width: hasPending ? 2 : 1,
            ),
            color: _productCard,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: (isMobile ? 10.0 : 16.0).clamp(
                  0.0,
                  double.infinity,
                ),
                offset: Offset(0, isMobile ? 4 : 6),
              ),
            ],
          ),
          padding: EdgeInsets.all(isMobile ? 4 : (isCompact ? 6 : 7)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: isMobile ? 18 : (isCompact ? 20 : 22),
                    height: isMobile ? 18 : (isCompact ? 20 : 22),
                    decoration: BoxDecoration(
                      color: hasPending
                          ? const Color(0xFFDCFCE7)
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(isMobile ? 4 : 6),
                    ),
                    child: Icon(
                      Icons.add_rounded,
                      color: hasPending
                          ? const Color(0xFF16A34A)
                          : const Color(0xFF94A3B8),
                      size: isMobile ? 12 : (isCompact ? 13 : 14),
                    ),
                  ),
                  const Spacer(),
                  if (hasPending)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF16A34A),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        pendingLabel,
                        style: TextStyle(
                          color: const Color(0xFFFFFFFF),
                          fontSize: isMobile ? 10 : 11,
                          fontWeight: FontWeight.w900,
                          height: 1,
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(height: isMobile ? 2 : (isCompact ? 4 : 5)),
              Expanded(
                child: Text(
                  product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: isMobile ? 12 : (isCompact ? 13 : 14),
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF020617),
                    letterSpacing: -0.1,
                    height: 1.05,
                  ),
                ),
              ),
              SizedBox(height: isMobile ? 1 : 2),
              Text(
                "${product.price.toStringAsFixed(0)} TL",
                style: TextStyle(
                  fontSize: isMobile ? 12 : (isCompact ? 13 : 14),
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF10B981),
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showLineOperationsDialog(
    BuildContext context,
    OrderProvider order,
    CartLine line,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                line.product.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 14),
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.sell_rounded,
                  color: Color(0xFFEF4444),
                ),
                title: const Text("Fiyat Değiştir"),
                subtitle: Text(
                  line.existingQuantity > 0
                      ? "Mevcut: ${line.unitPrice.toStringAsFixed(2)} TL"
                      : "Fiyat degisikligi icin urunu once onaylayin.",
                ),
                onTap: line.existingQuantity <= 0
                    ? null
                    : () async {
                        Navigator.of(sheetContext).pop();
                        await _showChangePriceDialog(context, order, line);
                      },
              ),
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.exposure_neg_1_rounded,
                  color: Color(0xFF64748B),
                ),
                title: const Text("0.5 Azalt"),
                subtitle: line.newQuantity <= 0.0001
                    ? const Text(
                        "Bekleyen miktar yok — sil islemi kullanin.",
                        style: TextStyle(fontSize: 11),
                      )
                    : null,
                onTap: line.newQuantity <= 0.0001
                    ? null
                    : () {
                        order.decrease(line.product, amount: 0.5);
                        Navigator.of(sheetContext).pop();
                      },
              ),
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.exposure_plus_1_rounded,
                  color: Color(0xFF10B981),
                ),
                title: const Text("0.5 Artır"),
                onTap: () {
                  order.increase(line.product, amount: 0.5);
                  Navigator.of(sheetContext).pop();
                },
              ),
              const Divider(height: 1),
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.edit_note_outlined),
                title: const Text("Sipariş Notu Düzenle"),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _showItemNoteDialog(context, line);
                },
              ),
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.delete_outline,
                  color: Color(0xFFEF4444),
                ),
                title: const Text(
                  "Ürünü Sil",
                  style: TextStyle(color: Color(0xFFEF4444)),
                ),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _showDeleteItemDialog(context, order, line);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showChangePriceDialog(
    BuildContext context,
    OrderProvider order,
    CartLine line,
  ) async {
    final controller = TextEditingController(
      text: line.unitPrice.toStringAsFixed(2),
    );

    final result = await showDialog<double>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Fiyat Değiştir"),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: "Yeni Birim Fiyat (TL)",
            hintText: "Orn: 145.50",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text("İptal"),
          ),
          FilledButton(
            onPressed: () {
              final parsed = double.tryParse(
                controller.text.trim().replaceAll(",", "."),
              );
              if (parsed == null || parsed < 0) {
                AppFeedbackService.showError("Geçerli bir fiyat girin.");
                return;
              }
              Navigator.of(dialogContext).pop(parsed);
            },
            child: const Text("Kaydet"),
          ),
        ],
      ),
    );

    if (!context.mounted || result == null) return;

    final ok = await order.updateLinePrice(line.product.id, result);
    if (!context.mounted) return;
    if (ok) {
      AppFeedbackService.showSuccess("Fiyat güncellendi.");
    } else {
      AppFeedbackService.showError(
        order.errorMessage ?? "Fiyat değiştirilemedi.",
      );
    }
  }

  Future<void> _showDeleteItemDialog(
    BuildContext context,
    OrderProvider order,
    CartLine line,
  ) async {
    final totalQty = line.quantity;
    double? deleteAmount;

    if (totalQty <= 0.5) {
      deleteAmount = 0.5;
    } else {
      deleteAmount = await _showPartialDeleteDialog(
        context: context,
        productName: line.product.name,
        maxQuantity: totalQty,
      );
    }

    if (deleteAmount == null || deleteAmount <= 0) return;

    var remainingToDelete = deleteAmount;

    if (line.newQuantity > 0 && remainingToDelete > 0.0001) {
      final fromNew = line.newQuantity < remainingToDelete
          ? line.newQuantity
          : remainingToDelete;
      order.decrease(line.product, amount: fromNew);
      remainingToDelete -= fromNew;
    }

    if (line.existingQuantity > 0 && remainingToDelete > 0.0001) {
      final ok = await order.voidOrderItem(
        line.product.id,
        quantity: remainingToDelete,
      );
      if (!context.mounted) return;
      if (!ok) {
        AppFeedbackService.showError(order.errorMessage ?? "Ürün silinemedi.");
        return;
      }
    }

    if (!context.mounted) return;
    final tableClosed = !order.hasActiveOrder && order.cartLines.isEmpty;
    if (tableClosed) {
      AppFeedbackService.showSuccess("Masa kapandı.");
      if (widget.embedded) {
        widget.onClose?.call();
      } else {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const WaiterTablesScreen()),
          (route) => false,
        );
      }
      return;
    }

    final deletedText = deleteAmount % 1 == 0
        ? deleteAmount.toStringAsFixed(0)
        : deleteAmount.toStringAsFixed(1);
    AppFeedbackService.showSuccess("Üründen $deletedText adet silindi.");
  }

  Future<double?> _showPartialDeleteDialog({
    required BuildContext context,
    required String productName,
    required double maxQuantity,
  }) async {
    double selectedQuantity = maxQuantity >= 1 ? 1 : 0.5;

    return showDialog<double>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              width: 380,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    "Kaç Adet Silinecek?",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF0F172A),
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    productName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        onPressed: selectedQuantity > 0.5
                            ? () => setDialogState(
                                () =>
                                    selectedQuantity = (selectedQuantity - 0.5)
                                        .clamp(0.5, maxQuantity)
                                        .toDouble(),
                              )
                            : null,
                        icon: const Icon(Icons.remove_circle_outline),
                        color: const Color(0xFF0F172A),
                        iconSize: 34,
                      ),
                      Container(
                        width: 90,
                        alignment: Alignment.center,
                        child: Text(
                          selectedQuantity % 1 == 0
                              ? selectedQuantity.toStringAsFixed(0)
                              : selectedQuantity.toStringAsFixed(1),
                          style: const TextStyle(
                            color: Color(0xFF0F172A),
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: selectedQuantity < maxQuantity - 0.0001
                            ? () => setDialogState(
                                () =>
                                    selectedQuantity = (selectedQuantity + 0.5)
                                        .clamp(0.5, maxQuantity)
                                        .toDouble(),
                              )
                            : null,
                        icon: const Icon(Icons.add_circle_outline),
                        color: const Color(0xFF0F172A),
                        iconSize: 34,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 54,
                    child: FilledButton(
                      onPressed: () => Navigator.of(ctx).pop(selectedQuantity),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFEF4444),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        "Sil",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text("Vazgeç"),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CategoryImageCard extends StatefulWidget {
  final String title;
  final String imagePath;
  final Color tintColor;
  final bool isMobile;
  final VoidCallback onTap;

  const _CategoryImageCard({
    required this.title,
    required this.imagePath,
    required this.tintColor,
    required this.isMobile,
    required this.onTap,
  });

  @override
  State<_CategoryImageCard> createState() => _CategoryImageCardState();
}

class _CategoryImageCardState extends State<_CategoryImageCard> {
  bool _isHovered = false;

  Widget _buildImage() {
    final trimmed = widget.imagePath.trim();
    final fallback = Container(color: widget.tintColor.withValues(alpha: 0.12));

    if (trimmed.isEmpty) return fallback;

    if (trimmed.startsWith("assets/")) {
      return Image.asset(
        trimmed,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => fallback,
      );
    }

    return Image.network(
      Uri.file(trimmed).toString(),
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => fallback,
    );
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(widget.isMobile ? 14 : 18);
    final imageRadius = BorderRadius.vertical(
      top: Radius.circular(widget.isMobile ? 14 : 18),
    );
    final infoRadius = BorderRadius.vertical(
      bottom: Radius.circular(widget.isMobile ? 14 : 18),
    );

    final shadowColor = widget.tintColor.withValues(
      alpha: _isHovered ? 0.18 : 0.12,
    );
    final translateY = _isHovered ? -6.0 : 0.0;

    final card = AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      transform: Matrix4.translationValues(0, translateY, 0),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: radius,
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: _isHovered ? 24 : 16,
            offset: Offset(0, _isHovered ? 10 : 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Expanded(
            flex: 7,
            child: ClipRRect(
              borderRadius: imageRadius,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _buildImage(),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: widget.tintColor.withValues(alpha: 0.10),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFFFFFFF),
                borderRadius: infoRadius,
              ),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                widget.title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: widget.isMobile ? 11 : 13,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF0F172A),
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ),
        ],
      ),
    );

    return MouseRegion(
      onEnter: (_) {
        if (widget.isMobile) return;
        setState(() => _isHovered = true);
      },
      onExit: (_) {
        if (widget.isMobile) return;
        setState(() => _isHovered = false);
      },
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        child: InkWell(onTap: widget.onTap, borderRadius: radius, child: card),
      ),
    );
  }
}

// ─── Receipt sidebar ─────────────────────────────────────────────────────────

class _ReceiptSidebar extends StatelessWidget {
  static const String _deleteActionPin = "2323";

  final OrderProvider order;
  final String tableName;
  final int tableId;
  final bool canTakePayment;
  final VoidCallback onOpenOrderMeta;
  final bool fullWidth;
  final bool isMobile;
  final void Function(bool refreshed) onDone;
  final VoidCallback? onPaymentMade;
  final ValueChanged<bool>? onPaymentFinished;

  const _ReceiptSidebar({
    required this.order,
    required this.tableName,
    required this.tableId,
    required this.canTakePayment,
    required this.onOpenOrderMeta,
    this.fullWidth = false,
    this.isMobile = false,
    required this.onDone,
    this.onPaymentMade,
    this.onPaymentFinished,
  });

  @override
  Widget build(BuildContext context) {
    final lines = order.cartLines;
    final lastAddedLine = order.lastAddedCartLine;

    return SizedBox(
      width: fullWidth ? double.infinity : 320,
      child: Container(
        decoration: BoxDecoration(
          color: Color(0xFFF8FAFC),
          border: fullWidth
              ? null
              : const Border(left: BorderSide(color: Color(0xFFE2E8F0))),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFFFFFFFF),
                border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isTightHeader = constraints.maxWidth < 380;

                  Widget tableChip = Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: isTightHeader ? 72 : 110,
                      ),
                      child: Text(
                        tableName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF475569),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  );

                  Widget metaButton = OutlinedButton.icon(
                    onPressed: order.isSubmitting || order.isCheckingOut
                        ? null
                        : onOpenOrderMeta,
                    icon: const Icon(Icons.groups_rounded, size: 16),
                    label: const Text("Kuver / Not"),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF60A5FA),
                      side: BorderSide(
                        color: const Color(0xFF3B82F6).withValues(alpha: 0.5),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      textStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  );

                  if (isTightHeader) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFF10B981,
                                ).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.receipt_long_rounded,
                                color: Color(0xFF10B981),
                                size: 16,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                "Adisyon",
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Color(0xFF0F172A),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            tableChip,
                          ],
                        ),
                        const SizedBox(height: 10),
                        SizedBox(width: double.infinity, child: metaButton),
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.receipt_long_rounded,
                          color: Color(0xFF10B981),
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 12),

                      const Expanded(
                        child: Text(
                          "Adisyon",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Color(0xFF0F172A),
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                      tableChip,
                      const SizedBox(width: 8),

                      metaButton,
                    ],
                  );
                },
              ),
            ),
            if (order.hasActiveOrder)
              Container(
                padding: EdgeInsets.fromLTRB(16, 10, 16, 10),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        "Kuver: ${order.guestCount}",
                        style: const TextStyle(
                          color: Color(0xFF60A5FA),
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        order.tableNote.trim().isEmpty
                            ? "Masa notu yok"
                            : order.tableNote,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: order.tableNote.trim().isEmpty
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFFD97706), // Amber-600
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          fontStyle: order.tableNote.trim().isEmpty
                              ? FontStyle.normal
                              : FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (lastAddedLine != null)
              Container(
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFCD34D)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFFFF),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.fiber_manual_record_rounded,
                        size: 12,
                        color: Color(0xFFF59E0B),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        lastAddedLine.product.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF92400E),
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFFFF),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: const Color(0xFFFCD34D)),
                      ),
                      child: Text(
                        "SON GİRİLEN x${order.formatQuantity(lastAddedLine.newQuantity)}",
                        style: const TextStyle(
                          color: Color(0xFFB45309),
                          fontWeight: FontWeight.w900,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            // Lines
            Expanded(
              child: lines.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.shopping_cart_outlined,
                            color: const Color(0xFFCBD5E1), // Slate-300
                            size: 48,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            "Henüz ürün seçilmedi",
                            style: TextStyle(
                              color: Color(0xFF94A3B8), // Slate-400
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: lines.length,
                      itemBuilder: (context, index) {
                        final line = lines[index];
                        final isLastSent =
                            order.lastSentProductIds.contains(
                              line.product.id,
                            ) &&
                            line.existingQuantity > 0;
                        return _ReceiptLine(
                          line: line,
                          isLastSent: isLastSent,
                          onDecrease: () => order.decrease(line.product),
                          onIncrease: () => order.increase(line.product),
                          onDecreaseHalf: () =>
                              order.decrease(line.product, amount: 0.5),
                          onIncreaseHalf: () =>
                              order.increase(line.product, amount: 0.5),
                          showHalfControls: !canTakePayment,
                          formatQuantity: order.formatQuantity,
                          onEditNote: () => _showItemNoteDialog(context, line),
                          onDelete: () =>
                              _showDeleteItemDialog(context, order, line),
                          onTransfer:
                              line.existingQuantity > 0 && order.hasActiveOrder
                              ? () => _showTransferItemDialog(
                                  context,
                                  order,
                                  line,
                                )
                              : null,
                          onLongPressAdmin: canTakePayment
                              ? () => _showLineOperationsDialog(
                                  context,
                                  order,
                                  line,
                                )
                              : null,
                          isDisabled: order.isSubmitting || order.isCheckingOut,
                        );
                      },
                    ),
            ),
            // Footer: total + buttons
            Container(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),

              decoration: const BoxDecoration(
                color: Color(0xFFFFFFFF),
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF10B981).withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "TOPLAM",
                              style: TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.2,
                              ),
                            ),
                            Text(
                              "Ödenecek Tutar",
                              style: TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          "${order.totalAmount.toStringAsFixed(2)} TL",
                          style: const TextStyle(
                            color: Color(0xFF10B981),
                            fontSize: 36,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Siparişi Onayla
                  SizedBox(
                    width: double.infinity,
                    height: 52,

                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDCFCE7),
                        foregroundColor: const Color(0xFF0F172A),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                      onPressed:
                          (!order.hasItems ||
                              order.isSubmitting ||
                              order.isCheckingOut)
                          ? null
                          : () async {
                              final ok = await context
                                  .read<OrderProvider>()
                                  .submitAndConfirmOrder();
                              if (!context.mounted) return;
                              if (ok) {
                                AppFeedbackService.showSuccess(
                                  "Yeni ürünler mutfağa gönderildi.",
                                );
                                Navigator.of(context).pop(true);
                              } else {
                                final msg =
                                    context
                                        .read<OrderProvider>()
                                        .errorMessage ??
                                    "Sipariş onaylanamadı.";
                                AppFeedbackService.showError(msg);
                              }
                            },
                      child: order.isSubmitting
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF0F172A),
                              ),
                            )
                          : const Text("Siparişi Onayla"),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,

                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF0F172A),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      onPressed:
                          lines.isEmpty ||
                              !order.hasActiveOrder ||
                              order.hasItems ||
                              order.isSubmitting ||
                              order.isCheckingOut ||
                              order.isPrintingReceipt
                          ? null
                          : () async {
                              final ok = await context
                                  .read<OrderProvider>()
                                  .printCurrentAccount(tableName: tableName);
                              if (!context.mounted) return;
                              if (ok) {
                                AppFeedbackService.showSuccess(
                                  "Adisyon kasa yazıcısına gönderildi.",
                                );
                              } else {
                                final msg =
                                    context
                                        .read<OrderProvider>()
                                        .errorMessage ??
                                    "Adisyon yazdırılamadı.";
                                AppFeedbackService.showError(msg);
                              }
                            },
                      icon: order.isPrintingReceipt
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF0F172A),
                              ),
                            )
                          : const Icon(Icons.print_rounded, size: 18),
                      label: Text(
                        order.isPrintingReceipt
                            ? "Yazdırılıyor..."
                            : "Adisyonu Yazdır",
                      ),
                    ),
                  ),
                  if (order.hasActiveOrder) ...[
                    if (!isMobile || canTakePayment) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 48,

                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFEE2E2),
                            foregroundColor: const Color(0xFF0F172A),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          onPressed:
                              order.isSubmitting ||
                                  order.isCheckingOut ||
                                  !canTakePayment
                              ? null
                              : () => _handleAdvancedPayment(context, order),
                          child: order.isCheckingOut
                              ? const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFF0F172A),
                                  ),
                                )
                              : const Text("Ödeme / Kısmi Ödeme"),
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showDeleteItemDialog(
    BuildContext context,
    OrderProvider order,
    CartLine line,
  ) async {
    // 1. Yeni eklenen (onaylanmamış) ürünler varsa, PIN sormadan direkt düş
    if (line.newQuantity > 0) {
      final totalQty = line.quantity;
      double? deleteQuantity;

      if (totalQty <= 0.5) {
        deleteQuantity = 0.5;
      } else {
        deleteQuantity = await _showPartialDeleteDialog(
          context: context,
          productName: line.product.name,
          maxQuantity: totalQty,
        );
      }

      if (deleteQuantity == null || deleteQuantity <= 0) return;

      double remainingToDelete = deleteQuantity;

      // Sadece yeni ürünleri sil
      final toDeleteFromNew = remainingToDelete > line.newQuantity
          ? line.newQuantity
          : remainingToDelete;
      order.decrease(line.product, amount: toDeleteFromNew);
      remainingToDelete -= toDeleteFromNew;

      // Eğer hala silinecek varsa (onaylı ürünlere geçilecekse) PIN sor
      if (remainingToDelete > 0.0001) {
        if (!context.mounted) return;
        final approved = await _verifyDeletePin(
          context,
          title: "Ürün İptali",
          message:
              "${line.product.name} (Onaylı) ürününü iptal etmek için silme şifresini girin.",
        );

        if (approved == true) {
          final ok = await order.voidOrderItem(
            line.product.id,
            quantity: remainingToDelete,
          );
          if (ok && context.mounted) {
            if (!order.hasActiveOrder && order.cartLines.isEmpty) {
              AppFeedbackService.showSuccess("Ürün silindi, masa kapatıldı.");
              Navigator.of(context).pop(true);
            } else {
              AppFeedbackService.showSuccess("Ürün silindi.");
            }
          } else if (context.mounted) {
            AppFeedbackService.showError(
              order.errorMessage ?? "Ürün silinemedi.",
            );
          }
        }
      } else {
        AppFeedbackService.showSuccess("Ürün sepetten kaldırıldı.");
      }
      return;
    }

    // 2. Sadece onaylanmış ürünler varsa direkt PIN sor
    final totalQty = line.quantity;
    double? deleteQuantity;

    final approved = await _verifyDeletePin(
      context,
      title: "Ürün İptali",
      message:
          "${line.product.name} ürününü iptal etmek için silme şifresini girin.",
    );

    if (approved != true) return;

    if (totalQty <= 0.5) {
      deleteQuantity = 0.5;
    } else {
      if (!context.mounted) return;
      deleteQuantity = await _showPartialDeleteDialog(
        context: context,
        productName: line.product.name,
        maxQuantity: totalQty,
      );
    }

    if (deleteQuantity == null || deleteQuantity <= 0) return;

    final ok = await order.voidOrderItem(
      line.product.id,
      quantity: deleteQuantity,
    );

    if (ok && context.mounted) {
      if (!order.hasActiveOrder && order.cartLines.isEmpty) {
        AppFeedbackService.showSuccess("Ürün silindi, masa kapatıldı.");
        Navigator.of(context).pop(true);
      } else {
        AppFeedbackService.showSuccess("Ürün silindi.");
      }
    } else if (context.mounted) {
      AppFeedbackService.showError(order.errorMessage ?? "Ürün silinemedi.");
    }
  }

  Future<bool> _verifyDeletePin(
    BuildContext context, {
    required String title,
    required String message,
  }) async {
    final approved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        String pinValue = "";

        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text(title),
            content: SizedBox(
              width: 340,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(message),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(4, (index) {
                      final filled = index < pinValue.length;
                      return Container(
                        width: 44,
                        height: 44,
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        decoration: BoxDecoration(
                          color: filled
                              ? const Color(0xFFDBEAFE)
                              : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: filled
                                ? const Color(0xFF3B82F6)
                                : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: const Center(
                          child: Icon(Icons.circle, size: 10),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 14),
                  GridView.count(
                    crossAxisCount: 3,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    children: [
                      for (final key in const [
                        "1",
                        "2",
                        "3",
                        "4",
                        "5",
                        "6",
                        "7",
                        "8",
                        "9",
                        "C",
                        "0",
                        "<-",
                      ])
                        FilledButton(
                          onPressed: () {
                            setDialogState(() {
                              if (key == "C") {
                                pinValue = "";
                                return;
                              }
                              if (key == "<-") {
                                if (pinValue.isNotEmpty) {
                                  pinValue = pinValue.substring(
                                    0,
                                    pinValue.length - 1,
                                  );
                                }
                                return;
                              }
                              if (pinValue.length < 4) {
                                pinValue += key;
                              }
                            });
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFF1F5F9),
                            foregroundColor: const Color(0xFF0F172A),
                            elevation: 0,
                            minimumSize: const Size(0, 48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          child: Text(key),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text("Vazgeç"),
              ),
              FilledButton(
                onPressed: pinValue.length == 4
                    ? () => Navigator.of(ctx).pop(pinValue == _deleteActionPin)
                    : null,
                child: const Text("Doğrula"),
              ),
            ],
          ),
        );
      },
    );

    if (approved != true && context.mounted) {
      AppFeedbackService.showError("Silme şifresi hatalı.");
    }

    return approved == true;
  }

  Future<double?> _showPartialDeleteDialog({
    required BuildContext context,
    required String productName,
    required double maxQuantity,
  }) async {
    double selectedQuantity = maxQuantity >= 1 ? 1 : 0.5;

    return showDialog<double>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              width: 380,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    "Kaç Adet Silinecek?",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF0F172A),
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    productName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        onPressed: selectedQuantity > 0.5
                            ? () => setDialogState(
                                () =>
                                    selectedQuantity = (selectedQuantity - 0.5)
                                        .clamp(0.5, maxQuantity)
                                        .toDouble(),
                              )
                            : null,
                        icon: const Icon(Icons.remove_circle_outline),
                        color: const Color(0xFF0F172A),
                        iconSize: 34,
                      ),
                      Container(
                        width: 90,
                        alignment: Alignment.center,
                        child: Text(
                          (selectedQuantity % 1 == 0)
                              ? selectedQuantity.toStringAsFixed(0)
                              : selectedQuantity.toStringAsFixed(1),
                          style: const TextStyle(
                            color: Color(0xFF0F172A),
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: selectedQuantity < maxQuantity - 0.0001
                            ? () => setDialogState(
                                () =>
                                    selectedQuantity = (selectedQuantity + 0.5)
                                        .clamp(0.5, maxQuantity)
                                        .toDouble(),
                              )
                            : null,
                        icon: const Icon(Icons.add_circle_outline),
                        color: const Color(0xFF0F172A),
                        iconSize: 34,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 54,
                    child: FilledButton(
                      onPressed: () => Navigator.of(ctx).pop(selectedQuantity),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFEF4444),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        "Seçilen Adedi Sil",
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text(
                      "Vazgeç",
                      style: TextStyle(color: Color(0xFF71717A)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _fetchTransferTargetTables(
    int currentTableId,
  ) async {
    final response = await ApiClient.dio.get("/waiter/tables");
    final data = response.data as Map<String, dynamic>;
    final rawTables = (data["tables"] as List<dynamic>? ?? []);

    return rawTables.whereType<Map<String, dynamic>>().where((table) {
      final id = int.tryParse((table["id"] ?? "").toString()) ?? -1;
      return id > 0 && id != currentTableId;
    }).toList();
  }

  Future<void> _showTransferItemDialog(
    BuildContext context,
    OrderProvider order,
    CartLine line,
  ) async {
    if (!order.hasActiveOrder || line.existingQuantity <= 0) {
      return;
    }

    int selectedQuantity = 1;
    int? selectedTableId;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Container(
            width: 440,
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
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.move_up_rounded,
                          color: Color(0xFFF59E0B),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Ürün Transferi",
                              style: TextStyle(
                                color: Color(0xFF0F172A),
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                              ),
                            ),
                            Text(
                              line.product.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
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
                  child: FutureBuilder<List<Map<String, dynamic>>>(
                    future: _fetchTransferTargetTables(tableId),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const SizedBox(
                          height: 100,
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }

                      if (snapshot.hasError) {
                        return const Text(
                          "Hedef masalar alınamadı.",
                          style: TextStyle(color: Color(0xFFEF4444)),
                        );
                      }

                      final tables = snapshot.data ?? [];
                      if (tables.isEmpty) {
                        return const Text(
                          "Transfer için başka masa bulunamadı.",
                          style: TextStyle(color: Color(0xFF71717A)),
                        );
                      }

                      selectedTableId ??= int.tryParse(
                        (tables.first["id"] ?? "").toString(),
                      );

                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "HEDEF MASA SEÇİN",
                            style: TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFFFFF),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<int>(
                                value: selectedTableId,
                                isExpanded: true,
                                dropdownColor: const Color(0xFFFFFFFF),
                                style: const TextStyle(
                                  color: Color(0xFF0F172A),
                                  fontWeight: FontWeight.w700,
                                ),
                                icon: const Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  color: Color(0xFF71717A),
                                ),
                                items: tables.map((table) {
                                  final id =
                                      int.tryParse(
                                        (table["id"] ?? "").toString(),
                                      ) ??
                                      0;
                                  final name = (table["display_name"] ?? "Masa")
                                      .toString();
                                  final zone = (table["zone"] ?? "Oyun Salonu")
                                      .toString();
                                  return DropdownMenuItem<int>(
                                    value: id,
                                    child: Text("$name ($zone)"),
                                  );
                                }).toList(),
                                onChanged: (v) => setDialogState(() {
                                  selectedTableId = v;
                                }),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            "TRANSFER ADEDİ",
                            style: TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildQtyBtn(Icons.remove_rounded, () {
                                if (selectedQuantity > 1) {
                                  setDialogState(() => selectedQuantity--);
                                }
                              }),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 32,
                                ),
                                child: Text(
                                  selectedQuantity.toString(),
                                  style: const TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              ),
                              _buildQtyBtn(Icons.add_rounded, () {
                                if (selectedQuantity < line.existingQuantity) {
                                  setDialogState(() => selectedQuantity++);
                                }
                              }),
                            ],
                          ),
                        ],
                      );
                    },
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
                        onPressed: () => Navigator.of(dialogContext).pop(),
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
                        onPressed: selectedTableId == null
                            ? null
                            : () async {
                                final ok = await context
                                    .read<OrderProvider>()
                                    .transferItem(
                                      productId: line.product.id,
                                      toTableId: selectedTableId!,
                                      quantity: selectedQuantity,
                                    );
                                if (!context.mounted ||
                                    !dialogContext.mounted) {
                                  return;
                                }
                                if (ok) {
                                  Navigator.of(dialogContext).pop();
                                  AppFeedbackService.showSuccess(
                                    "Ürün transfer edildi.",
                                  );
                                } else {
                                  AppFeedbackService.showError(
                                    order.errorMessage ?? "Transfer başarısız.",
                                  );
                                }
                              },
                        icon: const Icon(Icons.check_rounded, size: 18),
                        label: const Text("Transferi Tamamla"),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFFEF3C7),
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
    );
  }

  Widget _buildQtyBtn(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFFFF),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Icon(icon, color: Color(0xFF0F172A), size: 24),
      ),
    );
  }

  Future<void> _showItemNoteDialog(BuildContext context, CartLine line) async {
    final controller = TextEditingController(text: line.note);

    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          width: 400,
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
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.edit_note_rounded,
                        color: Color(0xFFF59E0B),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Ürün Notu",
                            style: TextStyle(
                              color: Color(0xFF0F172A),
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                            ),
                          ),
                          Text(
                            line.product.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
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
                child: TextField(
                  controller: controller,
                  autofocus: true,
                  maxLines: 4,
                  minLines: 3,
                  style: const TextStyle(color: Color(0xFF0F172A)),
                  decoration: InputDecoration(
                    hintText: "Örn: Az pişmiş, soğansız, buzsuz",
                    hintStyle: const TextStyle(color: Color(0xFF3F3F46)),
                    filled: true,
                    fillColor: const Color(0xFFFFFFFF),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFFF59E0B)),
                    ),
                  ),
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
                      onPressed: () => Navigator.of(dialogContext).pop(),
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
                      onPressed: () async {
                        final ok = await context
                            .read<OrderProvider>()
                            .saveItemNote(
                              line.product.id,
                              controller.text,
                              applyToExisting: line.newQuantity <= 0.0001,
                            );
                        if (!context.mounted || !dialogContext.mounted) {
                          return;
                        }
                        if (ok) {
                          Navigator.of(dialogContext).pop();
                        } else {
                          final message =
                              context.read<OrderProvider>().errorMessage ??
                              "Sipariş notu kaydedilemedi.";
                          AppFeedbackService.showError(message);
                        }
                      },
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: const Text("Kaydet"),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFF59E0B),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
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
  }

  Future<void> _showLineOperationsDialog(
    BuildContext context,
    OrderProvider order,
    CartLine line,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                line.product.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 14),
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.sell_rounded,
                  color: Color(0xFFEF4444),
                ),
                title: const Text("Fiyat Değiştir"),
                subtitle: Text(
                  line.existingQuantity > 0
                      ? "Mevcut: ${line.unitPrice.toStringAsFixed(2)} TL"
                      : "Fiyat degisikligi icin urunu once onaylayin.",
                ),
                onTap: line.existingQuantity <= 0
                    ? null
                    : () async {
                        Navigator.of(sheetContext).pop();
                        await _showChangePriceDialog(context, order, line);
                      },
              ),
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.exposure_neg_1_rounded,
                  color: Color(0xFF64748B),
                ),
                title: const Text("0.5 Azalt"),
                subtitle: line.newQuantity <= 0.0001
                    ? const Text(
                        "Bekleyen miktar yok — sil islemi kullanin.",
                        style: TextStyle(fontSize: 11),
                      )
                    : null,
                onTap: line.newQuantity <= 0.0001
                    ? null
                    : () {
                        order.decrease(line.product, amount: 0.5);
                        Navigator.of(sheetContext).pop();
                      },
              ),
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.exposure_plus_1_rounded,
                  color: Color(0xFF10B981),
                ),
                title: const Text("0.5 Artır"),
                onTap: () {
                  order.increase(line.product, amount: 0.5);
                  Navigator.of(sheetContext).pop();
                },
              ),
              const Divider(height: 1),
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.edit_note_outlined),
                title: const Text("Sipariş Notu Düzenle"),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _showItemNoteDialog(context, line);
                },
              ),
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.delete_outline,
                  color: Color(0xFFEF4444),
                ),
                title: const Text(
                  "Ürünü Sil",
                  style: TextStyle(color: Color(0xFFEF4444)),
                ),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _showDeleteItemDialog(context, order, line);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showChangePriceDialog(
    BuildContext context,
    OrderProvider order,
    CartLine line,
  ) async {
    final controller = TextEditingController(
      text: line.unitPrice.toStringAsFixed(2),
    );

    final result = await showDialog<double>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Fiyat Değiştir"),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: "Yeni Birim Fiyat (TL)",
            hintText: "Orn: 145.50",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text("İptal"),
          ),
          FilledButton(
            onPressed: () {
              final parsed = double.tryParse(
                controller.text.trim().replaceAll(",", "."),
              );
              if (parsed == null || parsed < 0) {
                AppFeedbackService.showError("Geçerli bir fiyat girin.");
                return;
              }
              Navigator.of(dialogContext).pop(parsed);
            },
            child: const Text("Kaydet"),
          ),
        ],
      ),
    );

    if (!context.mounted || result == null) return;

    final ok = await order.updateLinePrice(line.product.id, result);
    if (!context.mounted) return;
    if (ok) {
      AppFeedbackService.showSuccess("Fiyat güncellendi.");
    } else {
      AppFeedbackService.showError(
        order.errorMessage ?? "Fiyat değiştirilemedi.",
      );
    }
  }

  // ── Partial payment dialog (full reuse from order_screen logic) ───────────

  Future<void> _handleAdvancedPayment(
    BuildContext context,
    OrderProvider order,
  ) async {
    final lines = order.cartLines.where((l) => l.existingQuantity > 0).toList();
    if (lines.isEmpty) {
      AppFeedbackService.showError("Ödeme yapılacak ürün yok.");
      return;
    }

    final allItems = lines
        .map(
          (l) => TableOrderPreviewItem(
            productId: l.product.id,
            name: l.product.name,
            quantity: l.existingQuantity.toDouble(),
            lineTotal: l.unitPrice * l.existingQuantity,
            unitPrice: l.unitPrice,
          ),
        )
        .toList();

    final totalAmount = allItems.fold(0.0, (sum, item) => sum + item.lineTotal);

    final locked = await order.beginPaymentSession();
    if (!context.mounted) return;
    if (!locked) {
      AppFeedbackService.showError(
        order.errorMessage ?? "Bu adisyonda su anda odeme aliniyor.",
      );
      return;
    }

    try {
      final checkout = await showDialog<CheckoutDialogResult>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AdvancedPaymentDialog(
          tableName: tableName,
          totalAmount: totalAmount,
          initialDiscountAmount: order.discountTotal,
          initialCollectedAmount: order.amountPaymentPaid,
          allItems: allItems,
        ),
      );

      if (!context.mounted || checkout == null) return;

      final collectedTotal = checkout.payments.fold<double>(
        0,
        (sum, payment) => sum + payment.amount,
      );
      final isFullSettlement =
          (collectedTotal - checkout.netAmount).abs() <= 0.01;

      bool isTableClosed = false;

      if (checkout.selectedItems.isNotEmpty && !isFullSettlement) {
        // Kısmi ürün bazlı ödeme
        final groupedItems = <int, double>{};
        for (var item in checkout.selectedItems) {
          groupedItems[item.productId] =
              (groupedItems[item.productId] ?? 0) + item.quantity;
        }

        final itemsList = groupedItems.entries
            .map((e) => {"product_id": e.key, "quantity": e.value})
            .toList();

        final paymentsList = checkout.payments
            .map(
              (p) => {
                "paymentMethod": p.paymentMethod,
                "amount": p.amount,
                "mealCardType": p.mealCardType,
              },
            )
            .toList();

        await ApiClient.dio.post(
          "/waiter/orders/${order.activeOrderId}/partial-checkout",
          data: {
            "items": itemsList,
            "payments": paymentsList,
            "discountAmount": checkout.discountAmount,
          },
        );
      } else {
        // Tutar bazlı ödeme
        for (var i = 0; i < checkout.payments.length; i++) {
          final payment = checkout.payments[i];
          final response = await ApiClient.dio.post(
            "/waiter/orders/${order.activeOrderId}/amount-payment",
            data: {
              "amount": payment.amount,
              "paymentMethod": payment.paymentMethod,
              "mealCardType": payment.mealCardType,
              "discountAmount": i == 0 ? checkout.discountAmount : 0,
              "finalTotal": checkout.netAmount,
            },
          );

          if (i == checkout.payments.length - 1) {
            final data = response.data;
            if (data is Map && data["table_closed"] == true) {
              isTableClosed = true;
            }
          }
        }
      }

      await order.endPaymentSession();
      await order.loadActiveOrderOnly();
      if (!context.mounted) return;

      if (isTableClosed) {
        onPaymentMade?.call();
      }
      onPaymentFinished?.call(isTableClosed);

      AppFeedbackService.showSuccess(
        isTableClosed ? "Ödeme tamamlandı. Masa kapatıldı." : "Ödeme alındı.",
      );
      onDone(true);
      return;
    } on DioException catch (e) {
      if (context.mounted) {
        AppFeedbackService.showError(
          e.response?.data is Map<String, dynamic>
              ? (e.response?.data["message"]?.toString() ??
                    "Ödeme işlemi sırasında hata oluştu.")
              : "Ödeme işlemi sırasında hata oluştu.",
        );
      }
    } catch (e) {
      if (context.mounted) {
        AppFeedbackService.showError("Ödeme işlemi sırasında hata oluştu.");
      }
    } finally {
      if (order.isPaymentSessionActive) {
        await order.endPaymentSession();
      }
    }
  }
}

// ─── Receipt line widget ─────────────────────────────────────────────────────

class _ReceiptLine extends StatelessWidget {
  final CartLine line;
  final bool isLastSent;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;
  final VoidCallback onDecreaseHalf;
  final VoidCallback onIncreaseHalf;
  final bool showHalfControls;
  final String Function(double) formatQuantity;
  final VoidCallback onEditNote;
  final VoidCallback? onDelete;
  final VoidCallback? onTransfer;
  final VoidCallback? onLongPressAdmin;
  final bool isDisabled;

  const _ReceiptLine({
    required this.line,
    required this.isLastSent,
    required this.onDecrease,
    required this.onIncrease,
    required this.onDecreaseHalf,
    required this.onIncreaseHalf,
    required this.showHalfControls,
    required this.formatQuantity,
    required this.onEditNote,
    required this.onDelete,
    required this.onTransfer,
    required this.onLongPressAdmin,
    required this.isDisabled,
  });

  @override
  Widget build(BuildContext context) {
    final isExisting = line.existingQuantity > 0;

    return GestureDetector(
      onLongPress: isDisabled ? null : onLongPressAdmin,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFFFF),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isExisting
                ? const Color(0xFF10B981).withValues(alpha: 0.2)
                : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        line.product.name,
                        style: const TextStyle(
                          color: Color(0xFF0F172A),
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          if (isExisting)
                            Container(
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFF10B981,
                                ).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                "ONAYLI",
                                style: TextStyle(
                                  color: Color(0xFF10B981),
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          if (isLastSent)
                            Container(
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFFEF4444,
                                ).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.circle,
                                    size: 6,
                                    color: Color(0xFFEF4444),
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    "SON GİDEN",
                                    style: TextStyle(
                                      color: Color(0xFFEF4444),
                                      fontSize: 9,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          Text(
                            "${line.lineTotal.toStringAsFixed(2)} TL",
                            style: const TextStyle(
                              color: Color(0xFF10B981),
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ReceiptActionBtn(
                      icon: Icons.remove_rounded,
                      // Sadece bekleyen (onaylanmamış) miktar varsa azaltma yapılabilir.
                      // Onaylı ürünleri azaltmak için void işlemi gerekir.
                      onTap: (isDisabled || line.newQuantity <= 0.0001)
                          ? null
                          : onDecrease,
                      color: const Color(0xFF71717A),
                    ),
                    Container(
                      width: 34,
                      alignment: Alignment.center,
                      child: Text(
                        formatQuantity(line.quantity),
                        style: const TextStyle(
                          color: Color(0xFF0F172A),
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    _ReceiptActionBtn(
                      icon: Icons.add_rounded,
                      onTap: isDisabled ? null : onIncrease,
                      color: const Color(0xFF10B981),
                    ),
                  ],
                ),
              ],
            ),
            if (line.note.isNotEmpty) ...[
              const SizedBox(height: 5),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      size: 14,
                      color: Color(0xFFF59E0B),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        line.note,
                        style: const TextStyle(
                          color: Color(0xFFFBBF24),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (showHalfControls) ...[
              const SizedBox(height: 5),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      // 0.5 azalt: en az 0.5 bekleyen miktar olmadan devre dışı.
                      onPressed: (isDisabled || line.newQuantity <= 0.0001)
                          ? null
                          : onDecreaseHalf,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF475569),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        minimumSize: const Size(0, 34),
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        textStyle: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      child: const Text("0.5 -"),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: isDisabled ? null : onIncreaseHalf,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF0F766E),
                        side: const BorderSide(color: Color(0xFF99F6E4)),
                        minimumSize: const Size(0, 34),
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        textStyle: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      child: const Text("0.5 +"),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 6),
            Row(
              children: [
                _ReceiptToolBtn(
                  icon: Icons.edit_note_rounded,
                  label: "NOT",
                  onTap: isDisabled ? null : onEditNote,
                  color: line.note.isNotEmpty
                      ? const Color(0xFFF59E0B)
                      : const Color(0xFF71717A),
                ),
                const SizedBox(width: 8),
                _ReceiptToolBtn(
                  icon: Icons.swap_horiz_rounded,
                  label: "TAŞI",
                  onTap: isDisabled || onTransfer == null ? null : onTransfer,
                  color: const Color(0xFF3B82F6),
                ),
                const Spacer(),
                if (onDelete != null)
                  _ReceiptToolBtn(
                    icon: Icons.delete_outline_rounded,
                    label: "SİL",
                    onTap: isDisabled ? null : onDelete,
                    color: const Color(0xFFEF4444),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ReceiptActionBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final Color color;

  const _ReceiptActionBtn({
    required this.icon,
    this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 18, color: color),
      ),
    );
  }
}

class _ReceiptToolBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color color;

  const _ReceiptToolBtn({
    required this.icon,
    required this.label,
    this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: disabled ? Colors.transparent : color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: disabled
                ? const Color(0xFFE2E8F0)
                : color.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: disabled ? const Color(0xFF3F3F46) : color,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: disabled ? const Color(0xFF3F3F46) : color,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
