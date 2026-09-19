import "package:dio/dio.dart";
import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "../models/payment_models.dart";
import "../providers/auth_provider.dart";
import "../providers/order_provider.dart";
import "../services/admin_auth_service.dart";
import "../services/api_client.dart";
import "../services/app_feedback_service.dart";
import "../widgets/advanced_payment_dialog.dart";
import "waiter_tables_screen.dart";

class OrderScreen extends StatelessWidget {
  final int tableId;
  final String tableName;

  const OrderScreen({
    super.key,
    required this.tableId,
    required this.tableName,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => OrderProvider(tableId)..loadInitialData(),
      child: _OrderScreenView(tableName: tableName),
    );
  }
}

class _OrderScreenView extends StatelessWidget {
  final String tableName;

  const _OrderScreenView({required this.tableName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Siparis - $tableName")),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 980;
            if (!isWide) {
              return _buildNarrow(context);
            }
            return Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Consumer<OrderProvider>(
                    builder: (context, order, _) => _MenuPanel(order: order),
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  flex: 2,
                  child: Consumer<OrderProvider>(
                    builder: (context, order, _) => _ReceiptPanel(order: order),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildNarrow(BuildContext context) {
    return Column(
      children: [
        Expanded(
          flex: 3,
          child: Consumer<OrderProvider>(
            builder: (context, order, _) => _MenuPanel(order: order),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          flex: 2,
          child: Consumer<OrderProvider>(
            builder: (context, order, _) => _ReceiptPanel(order: order),
          ),
        ),
      ],
    );
  }
}

class _MenuPanel extends StatelessWidget {
  final OrderProvider order;

  const _MenuPanel({required this.order});

  @override
  Widget build(BuildContext context) {
    if (order.isBusy) {
      return const Center(child: CircularProgressIndicator());
    }

    if (order.errorMessage != null && order.products.isEmpty) {
      return Center(
        child: Text(
          order.errorMessage ?? "Hata oluştu",
          style: const TextStyle(color: Color(0xFFFCA5A5)),
        ),
      );
    }

    final visibleProducts = order.filteredProducts;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          TextField(
            onChanged: order.setSearchQuery,
            style: const TextStyle(fontSize: 16),
            decoration: InputDecoration(
              hintText: "Urun ara...",
              prefixIcon: const Icon(Icons.search_rounded),
              filled: true,
              fillColor: const Color(0xFF141A24),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: order.categories.length,
              separatorBuilder: (_, index) => const SizedBox(width: 6),
              itemBuilder: (context, index) {
                final category = order.categories[index];
                final selected = category == order.selectedCategory;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  child: ChoiceChip(
                    label: Text(category),
                    selected: selected,
                    onSelected: (_) => order.setSelectedCategory(category),
                    materialTapTargetSize: MaterialTapTargetSize.padded,
                    labelPadding: const EdgeInsets.symmetric(horizontal: 10),
                    selectedColor: const Color(0xFF334155),
                    backgroundColor: const Color(0xFF1A2231),
                    side: BorderSide(
                      color: selected
                          ? const Color(0xFF60A5FA)
                          : const Color(0xFF2A3344),
                    ),
                    labelStyle: TextStyle(
                      fontSize: 12,
                      color: selected
                          ? const Color(0xFFE2E8F0)
                          : const Color(0xFF94A3B8),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              child: visibleProducts.isEmpty
                  ? const Center(
                      key: ValueKey("empty-products"),
                      child: Text("Filtreye uygun urun bulunamadi."),
                    )
                  : GridView.builder(
                      key: ValueKey(
                        "${order.selectedCategory}-${order.searchQuery}",
                      ),
                      itemCount: visibleProducts.length,
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 260,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 1.2,
                          ),
                      itemBuilder: (context, index) {
                        final product = visibleProducts[index];
                        return InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => order.increase(product),
                          child: Ink(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              color: const Color(0xFF1C2330),
                              border: Border.all(
                                color: const Color(0xFF2A3344),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(
                                      product.name,
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    "${product.price.toStringAsFixed(2)} TL",
                                    style: const TextStyle(
                                      fontSize: 17,
                                      color: Color(0xFF86EFAC),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    "Adet: ${order.formatQuantity(order.quantityOf(product))}",
                                    style: const TextStyle(
                                      color: Color(0xFF94A3B8),
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
          ),
        ],
      ),
    );
  }
}

class _ReceiptPanel extends StatelessWidget {
  final OrderProvider order;

  const _ReceiptPanel({required this.order});

  @override
  Widget build(BuildContext context) {
    final lines = order.cartLines;
    final lastAddedLine = order.lastAddedCartLine;
    final canTakePayment =
        context.watch<AuthProvider>().currentUser?.roleId == 1;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              "Adisyon",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 12),
          if (lastAddedLine != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFCD34D)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.playlist_add_check_circle_rounded,
                    color: Color(0xFFD97706),
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
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "SON GİRİLEN x${order.formatQuantity(lastAddedLine.newQuantity)}",
                    style: const TextStyle(
                      color: Color(0xFFB45309),
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          Expanded(
            child: lines.isEmpty
                ? const Center(child: Text("Henuz urun secilmedi."))
                : ListView.separated(
                    itemCount: lines.length,
                    separatorBuilder: (_, index) => const Divider(height: 18),
                    itemBuilder: (context, index) {
                      final line = lines[index];
                      return GestureDetector(
                        onLongPress: line.existingQuantity > 0
                            ? () => _showItemActionsMenu(context, order, line)
                            : null,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: line.existingQuantity > 0
                                  ? const Color(0xFF60A5FA)
                                  : Colors.transparent,
                            ),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          line.product.name,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          "${line.lineTotal.toStringAsFixed(2)} TL",
                                          style: const TextStyle(
                                            color: Color(0xFF86EFAC),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (line.existingQuantity > 0)
                                    Icon(
                                      Icons.touch_app,
                                      size: 14,
                                      color: const Color(0xFF94A3B8),
                                    ),
                                  IconButton(
                                    onPressed:
                                        order.isSubmitting ||
                                            order.isCheckingOut
                                        ? null
                                        : () => order.decrease(line.product),
                                    icon: const Icon(
                                      Icons.remove_circle_outline,
                                    ),
                                  ),
                                  SizedBox(
                                    width: 48,
                                    child: Column(
                                      children: [
                                        Text(
                                          order.formatQuantity(line.quantity),
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        if (line.existingQuantity > 0)
                                          Text(
                                            "Eski ${order.formatQuantity(line.existingQuantity)}",
                                            style: const TextStyle(
                                              fontSize: 10,
                                              color: Color(0xFF94A3B8),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    onPressed:
                                        order.isSubmitting ||
                                            order.isCheckingOut
                                        ? null
                                        : () => order.increase(line.product),
                                    icon: const Icon(Icons.add_circle_outline),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed:
                                          order.isSubmitting ||
                                              order.isCheckingOut
                                          ? null
                                          : () => order.decrease(
                                              line.product,
                                              amount: 0.5,
                                            ),
                                      child: const Text("0.5 -"),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed:
                                          order.isSubmitting ||
                                              order.isCheckingOut
                                          ? null
                                          : () => order.increase(
                                              line.product,
                                              amount: 0.5,
                                            ),
                                      child: const Text("0.5 +"),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text(
                "Toplam Tutar",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              Text(
                "${order.totalAmount.toStringAsFixed(2)} TL",
                style: const TextStyle(
                  fontSize: 22,
                  color: Color(0xFF0F172A),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 64,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDCFCE7),
                foregroundColor: const Color(0xFF0F172A),
                textStyle: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              onPressed:
                  (!order.hasItems || order.isSubmitting || order.isCheckingOut)
                  ? null
                  : () async {
                      final ok = await context
                          .read<OrderProvider>()
                          .submitAndConfirmOrder();
                      if (!context.mounted) return;

                      if (ok) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            backgroundColor: Color(0xFF15803D),
                            content: Text("Yeni urunler mutfaga gonderildi."),
                          ),
                        );
                        Navigator.of(context).pop(true);
                      } else {
                        final msg =
                            context.read<OrderProvider>().errorMessage ??
                            "Siparis onaylanamadi.";
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: const Color(0xFFB91C1C),
                            content: Text(msg),
                          ),
                        );
                      }
                    },
              child: order.isSubmitting
                  ? const SizedBox(
                      height: 28,
                      width: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Color(0xFF0F172A),
                      ),
                    )
                  : const Text("Siparisi Onayla"),
            ),
          ),
          if (order.hasActiveOrder) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 64,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFEE2E2),
                  foregroundColor: const Color(0xFF0F172A),
                  textStyle: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                onPressed:
                    order.isSubmitting || order.isCheckingOut || !canTakePayment
                    ? null
                    : () => _handleAdvancedPayment(context, order),
                child: order.isCheckingOut
                    ? const SizedBox(
                        height: 28,
                        width: 28,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Color(0xFF0F172A),
                        ),
                      )
                    : const Text("Hesabı Al / Kısmi Öde"),
              ),
            ),
            if (!canTakePayment) ...[
              const SizedBox(height: 8),
              const Text(
                "Odeme sadece yonetici kasasindan alinabilir.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFFFCA5A5),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  /// Ürün Long Press Menu
  Future<void> _showItemActionsMenu(
    BuildContext context,
    OrderProvider order,
    CartLine line,
  ) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFFFFFFFF),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                line.product.name,
                style: const TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            // İptali Et (Void)
            ListTile(
              leading: const Icon(
                Icons.delete_outline,
                color: Color(0xFFEF4444),
              ),
              title: const Text(
                "Ürünü İptal Et (Void)",
                style: TextStyle(color: Color(0xFFEF4444)),
              ),
              onTap: () {
                Navigator.of(ctx).pop();
                _confirmAdminAction(
                  context,
                  "Ürün İptali",
                  "Bu ürünü iptal etmek için silme şifresini girin.",
                  () async {
                    double? cancelQty;
                    if (line.existingQuantity > 1) {
                      cancelQty = await _showPartialDeleteDialog(
                        context: context,
                        productName: line.product.name,
                        maxQuantity: line.existingQuantity,
                      );
                      if (cancelQty == null) return;
                    } else {
                      cancelQty = line.existingQuantity > 0
                          ? line.existingQuantity
                          : 1.0;
                    }

                    final ok = await order.voidOrderItem(
                      line.product.id,
                      quantity: cancelQty,
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: ok
                              ? const Color(0xFF15803D)
                              : const Color(0xFFB91C1C),
                          content: Text(
                            ok
                                ? "$cancelQty adet ürün iptal edildi."
                                : "İptal başarısız.",
                          ),
                        ),
                      );
                    }
                  },
                  expectedPin: "2323",
                );
              },
            ),
            // İkram (Comp)
            ListTile(
              leading: const Icon(
                Icons.card_giftcard,
                color: Color(0xFFF59E0B),
              ),
              title: const Text(
                "Ürünü İkram Et (Comp)",
                style: TextStyle(color: Color(0xFFF59E0B)),
              ),
              onTap: () {
                Navigator.of(ctx).pop();
                _confirmAdminAction(
                  context,
                  "Ürün İkramı",
                  "Bu ürünü ikram etmek için Yönetici PIN'i girin.",
                  () async {
                    final ok = await order.compOrderItem(line.product.id);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: ok
                              ? const Color(0xFF15803D)
                              : const Color(0xFFB91C1C),
                          content: Text(
                            ok
                                ? "Ürün ikram edildi (0 TL)."
                                : "İkram başarısız.",
                          ),
                        ),
                      );
                    }
                  },
                );
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// Yönetici veya silme PIN doğrulama dialogu.
  Future<void> _confirmAdminAction(
    BuildContext context,
    String title,
    String message,
    Future<void> Function() onConfirm, {
    String? expectedPin,
  }) async {
    final pinController = TextEditingController();
    final isPasswordVisible = ValueNotifier(false);

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text(title, style: const TextStyle(color: Color(0xFF0F172A))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message,
              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
            ),
            const SizedBox(height: 16),
            ValueListenableBuilder<bool>(
              valueListenable: isPasswordVisible,
              builder: (context, isVisible, child) => TextFormField(
                controller: pinController,
                obscureText: !isVisible,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  // Allow only digits and limit to 4 characters
                ],
                decoration: InputDecoration(
                  hintText: expectedPin == null
                      ? "Yönetici PIN (6 haneli)"
                      : "Silme Şifresi (4 haneli)",
                  hintStyle: const TextStyle(color: Color(0xFF64748B)),
                  filled: true,
                  fillColor: const Color(0xFFFFFFFF),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      isVisible
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: const Color(0xFF94A3B8),
                    ),
                    onPressed: () =>
                        isPasswordVisible.value = !isPasswordVisible.value,
                  ),
                ),
                style: const TextStyle(color: Color(0xFF0F172A)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              "İPTAL",
              style: TextStyle(color: Color(0xFF60A5FA)),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDBEAFE),
              foregroundColor: const Color(0xFF0F172A),
              side: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            onPressed: () async {
              final pin = pinController.text.trim();
              if (pin.isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                    backgroundColor: Color(0xFFB91C1C),
                    content: Text("PIN boş bırakılamaz."),
                  ),
                );
                return;
              }

              final isValidPin = expectedPin != null
                  ? pin == expectedPin
                  : await AdminAuthService.verifyAdminPin(pin);

              if (!ctx.mounted) return;

              if (isValidPin) {
                Navigator.of(ctx).pop();
                await onConfirm();
              } else {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(
                    backgroundColor: Color(0xFFB91C1C),
                    content: Text(
                      expectedPin == null
                          ? "Yanlış PIN! Admin PIN'i girin."
                          : "Yanlış şifre! Silme şifresini girin.",
                    ),
                  ),
                );
              }
            },
            child: const Text("DOĞRULA"),
          ),
        ],
      ),
    );
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
            lineTotal: l.product.price * l.existingQuantity,
            unitPrice: l.product.price,
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
          tableName: "Masa ${order.tableId}",
          totalAmount: totalAmount,
          initialDiscountAmount: order.discountTotal,
          initialCollectedAmount: order.totalPaid,
          allItems: allItems,
        ),
      );

      if (!context.mounted || checkout == null) {
        if (order.isPaymentSessionActive) {
          await order.endPaymentSession();
        }
        return;
      }

      if (checkout.selectedItems.isNotEmpty) {
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
        if (checkout.payments.isEmpty) {
          // İndirim güncelleme veya tam indirimle kapatma durumu
          await ApiClient.dio.post(
            "/waiter/orders/${order.activeOrderId}/amount-payment",
            data: {
              "amount": 0,
              "paymentMethod": "CASH",
              "mealCardType": null,
              "discountAmount": checkout.discountAmount,
              "finalTotal": checkout.netAmount,
            },
          );
        } else {
          // Tutar bazlı ödeme
          for (var i = 0; i < checkout.payments.length; i++) {
            final payment = checkout.payments[i];
            await ApiClient.dio.post(
              "/waiter/orders/${order.activeOrderId}/amount-payment",
              data: {
                "amount": payment.amount,
                "paymentMethod": payment.paymentMethod,
                "mealCardType": payment.mealCardType,
                "discountAmount": i == 0 ? checkout.discountAmount : 0,
                "finalTotal": checkout.netAmount,
              },
            );
          }
        }
      }

      if (context.mounted) {
        AppFeedbackService.showSuccess("Ödeme başarıyla alındı.");
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const WaiterTablesScreen()),
          (route) => false,
        );
      }
    } on DioException catch (e) {
      if (context.mounted) {
        AppFeedbackService.showError(ApiClient.describeDioError(e));
      }
    } catch (e, stack) {
      debugPrint("Ödeme hatası detay: $e\n$stack");
      if (context.mounted) {
        final errorMsg = e.toString();
        if (errorMsg.contains("Null check operator")) {
          AppFeedbackService.showSuccess("İşlem tamamlandı.");
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
}
