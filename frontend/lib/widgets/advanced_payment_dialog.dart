import "package:flutter/material.dart";
import "../models/payment_models.dart";

class AdvancedPaymentDialog extends StatefulWidget {
  final String tableName;
  final double totalAmount;
  final double initialDiscountAmount;
  final double initialCollectedAmount;
  final List<TableOrderPreviewItem> allItems;

  const AdvancedPaymentDialog({
    super.key,
    required this.tableName,
    required this.totalAmount,
    this.initialDiscountAmount = 0,
    this.initialCollectedAmount = 0,
    required this.allItems,
  });

  @override
  State<AdvancedPaymentDialog> createState() => _AdvancedPaymentDialogState();
}

class _AdvancedPaymentDialogState extends State<AdvancedPaymentDialog> {
  late final TextEditingController discountController;
  late final TextEditingController paymentAmountController;
  String discountType = "AMOUNT";
  final List<CollectedPayment> alinanOdemeler = [];
  final List<TableOrderPreviewItem> selectedItemsForPayment = [];
  final List<TableOrderPreviewItem> allPaidItemsInThisSession = [];
  final List<List<TableOrderPreviewItem>> _itemsPerPayment = [];
  final List<double> _discountPerPayment = [];
  final Map<int, double> paidQuantities =
      {}; // productId -> already paid quantity
  double _discountAppliedSoFar = 0;
  String? validationMessage;

  @override
  void initState() {
    super.initState();
    final initialDiscount = roundMoney(
      widget.initialDiscountAmount.clamp(0, widget.totalAmount).toDouble(),
    );
    discountController = TextEditingController(
      text: initialDiscount > 0 ? initialDiscount.toStringAsFixed(2) : "",
    );
    // Tahsilat tutarı ürün seçimiyle hesaplanır.
    paymentAmountController = TextEditingController(text: "0.00");
  }

  @override
  void dispose() {
    discountController.dispose();
    paymentAmountController.dispose();
    super.dispose();
  }

  double roundMoney(double value) {
    return (value * 100).roundToDouble() / 100;
  }

  void _updateAmountFromSelection() {
    final rawInput =
        double.tryParse(discountController.text.trim().replaceAll(",", ".")) ??
        0;

    double discountAmount;
    if (discountType == "PERCENT") {
      discountAmount = widget.totalAmount * (rawInput.clamp(0, 100) / 100);
    } else {
      discountAmount = rawInput.clamp(0, widget.totalAmount).toDouble();
    }
    discountAmount = roundMoney(discountAmount);

    if (selectedItemsForPayment.isNotEmpty) {
      final selectedTotal = selectedItemsForPayment.fold(
        0.0,
        (sum, si) => sum + si.lineTotal,
      );
      final remainingDiscount = (discountAmount - _discountAppliedSoFar)
          .clamp(0.0, discountAmount)
          .toDouble();
      final discountForSelection = selectedTotal < remainingDiscount
          ? selectedTotal
          : remainingDiscount;
      final finalSelectedAmount = roundMoney(
        selectedTotal - discountForSelection,
      );
      paymentAmountController.text =
          (finalSelectedAmount > 0 ? finalSelectedAmount : 0).toStringAsFixed(
            2,
          );
    } else {
      // Hiçbir ürün seçili değilse 0.00 göster (Alman usulü için en doğrusu)
      paymentAmountController.text = "0.00";
    }
  }

  void _removePaymentAt(int index) {
    final itemsToRestore = _itemsPerPayment.removeAt(index);
    _discountAppliedSoFar = (_discountAppliedSoFar -
            _discountPerPayment.removeAt(index))
        .clamp(0.0, double.infinity)
        .toDouble();
    alinanOdemeler.removeAt(index);

    for (final item in itemsToRestore) {
      final restoredQuantity =
          (paidQuantities[item.productId] ?? 0) - item.quantity;
      if (restoredQuantity <= 0.009) {
        paidQuantities.remove(item.productId);
      } else {
        paidQuantities[item.productId] = restoredQuantity;
      }
      allPaidItemsInThisSession.remove(item);
      final selectedIndex = selectedItemsForPayment.indexWhere(
        (selected) => selected.productId == item.productId,
      );
      if (selectedIndex < 0) {
        selectedItemsForPayment.add(item);
      } else {
        final existing = selectedItemsForPayment[selectedIndex];
        final quantity = existing.quantity + item.quantity;
        selectedItemsForPayment[selectedIndex] = existing.copyWith(
          quantity: quantity,
          lineTotal: quantity * existing.unitPrice,
        );
      }
    }

    _updateAmountFromSelection();
  }

  void _recordPayment(String paymentMethod, double amount) {
    final selectedItems = List<TableOrderPreviewItem>.from(
      selectedItemsForPayment,
    );
    final selectedTotal = selectedItems.fold<double>(
      0,
      (sum, item) => sum + item.lineTotal,
    );
    final appliedDiscount = roundMoney(
      (selectedTotal - amount).clamp(0.0, selectedTotal).toDouble(),
    );

    setState(() {
      alinanOdemeler.add(
        CollectedPayment(
          paymentMethod: paymentMethod,
          amount: roundMoney(amount),
        ),
      );
      _itemsPerPayment.add(selectedItems);
      _discountPerPayment.add(appliedDiscount);
      _discountAppliedSoFar += appliedDiscount;

      for (final item in selectedItems) {
        paidQuantities[item.productId] =
            (paidQuantities[item.productId] ?? 0) + item.quantity;
        allPaidItemsInThisSession.add(item);
      }
      selectedItemsForPayment.clear();
      _updateAmountFromSelection();
      validationMessage = null;
    });
  }

  List<TableOrderPreviewItem> _remainingItemsForSelection() {
    final items = <TableOrderPreviewItem>[];
    for (final item in widget.allItems) {
      final alreadyPaidQty = paidQuantities[item.productId] ?? 0;
      final remainingQty = item.quantity - alreadyPaidQty;
      if (remainingQty <= 0.009) continue;
      items.add(
        item.copyWith(
          quantity: remainingQty,
          lineTotal: remainingQty * item.unitPrice,
        ),
      );
    }
    return items;
  }

  bool _isAllRemainingSelected() {
    final remainingItems = _remainingItemsForSelection();
    if (remainingItems.isEmpty) return false;
    if (selectedItemsForPayment.length != remainingItems.length) return false;

    for (final remaining in remainingItems) {
      final selected = selectedItemsForPayment.where(
        (si) => si.productId == remaining.productId,
      );
      if (selected.isEmpty) return false;
      final picked = selected.first;
      if ((picked.quantity - remaining.quantity).abs() > 0.009) return false;
    }
    return true;
  }

  void _toggleSelectAll() {
    setState(() {
      if (_isAllRemainingSelected()) {
        selectedItemsForPayment.clear();
      } else {
        selectedItemsForPayment
          ..clear()
          ..addAll(_remainingItemsForSelection());
      }
      _updateAmountFromSelection();
    });
  }

  Future<double?> _showQuantityPicker(
    BuildContext context,
    String productName,
    double maxQty,
  ) async {
    double selectedQty = 1.0;
    return showDialog<double>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text("$productName - Adet Seç"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Ödenecek miktar (Maks: ${maxQty.toStringAsFixed(2)})"),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: () {
                      if (selectedQty > 1) {
                        setDialogState(() => selectedQty--);
                      }
                    },
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                  SizedBox(
                    width: 60,
                    child: Text(
                      selectedQty.toStringAsFixed(0),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      if (selectedQty < maxQty) {
                        setDialogState(() => selectedQty++);
                      }
                    },
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Vazgeç"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, maxQty),
              child: const Text("Tümünü Seç"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, selectedQty),
              child: const Text("Seç"),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rawInput =
        double.tryParse(discountController.text.trim().replaceAll(",", ".")) ??
        0;

    double discountAmount;
    if (discountType == "PERCENT") {
      final percent = rawInput.clamp(0, 100);
      discountAmount = widget.totalAmount * (percent / 100);
    } else {
      discountAmount = rawInput.clamp(0, widget.totalAmount).toDouble();
    }

    discountAmount = (discountAmount * 100).roundToDouble() / 100;
    final payableAmount = roundMoney(widget.totalAmount - discountAmount);
    final oncekiTahsilat = roundMoney(
      widget.initialCollectedAmount.clamp(0, payableAmount).toDouble(),
    );
    final alinanToplam = roundMoney(
      alinanOdemeler.fold(0.0, (sum, p) => sum + p.amount),
    );
    final kalanTutar = roundMoney(
      payableAmount - oncekiTahsilat - alinanToplam,
    );
    final isOverPaid = kalanTutar < -0.009;
    final isZeroBalance = kalanTutar.abs() <= 0.009;
    final isFullyCollected =
        isZeroBalance && (alinanOdemeler.isNotEmpty || payableAmount <= 0);
    final isPartialPayment =
        alinanOdemeler.isNotEmpty && !isFullyCollected && !isOverPaid;

    final initialDiscount = roundMoney(
      widget.initialDiscountAmount.clamp(0, widget.totalAmount).toDouble(),
    );
    final hasDiscountChanged = (discountAmount - initialDiscount).abs() > 0.009;
    final isPaymentCompletion =
        isFullyCollected || isPartialPayment || isZeroBalance;
    final canCompleteCheckout = isPaymentCompletion || hasDiscountChanged;

    if (paymentAmountController.text.trim().isEmpty) {
      paymentAmountController.text = "0.00";
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        width: 900,
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 30,
              spreadRadius: 8,
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // SOL TARAF: Ürün Listesi
            Expanded(
              flex: 4,
              child: Container(
                decoration: const BoxDecoration(
                  border: Border(right: BorderSide(color: Color(0xFFFFFFFF))),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "ÖDENMEMİŞ ÜRÜNLER",
                            style: TextStyle(
                              color: Color(0xFF71717A),
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Ödeme yapmak istediğiniz ürünleri seçin",
                            style: TextStyle(
                              color: const Color(
                                0xFF71717A,
                              ).withValues(alpha: 0.7),
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              OutlinedButton.icon(
                                onPressed: _toggleSelectAll,
                                icon: Icon(
                                  _isAllRemainingSelected()
                                      ? Icons.deselect_rounded
                                      : Icons.select_all_rounded,
                                  size: 16,
                                ),
                                label: Text(
                                  _isAllRemainingSelected()
                                      ? "Seçimi Temizle"
                                      : "Tümünü Seç",
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF0F172A),
                                  side: const BorderSide(
                                    color: Color(0xFFE2E8F0),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  textStyle: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: widget.allItems.length,
                        separatorBuilder: (context, index) =>
                            const Divider(color: Color(0xFFFFFFFF), height: 1),
                        itemBuilder: (context, index) {
                          final item = widget.allItems[index];
                          final alreadyPaidQty =
                              paidQuantities[item.productId] ?? 0;
                          final remainingQty = item.quantity - alreadyPaidQty;
                          final isFullyPaid = remainingQty <= 0.009;

                          final isSelected = selectedItemsForPayment.any(
                            (si) => si.productId == item.productId,
                          );

                          if (isFullyPaid) {
                            return const SizedBox.shrink();
                          }

                          return InkWell(
                            onTap: () async {
                              if (remainingQty > 1.009) {
                                final pickQty = await _showQuantityPicker(
                                  context,
                                  item.name,
                                  remainingQty,
                                );
                                if (pickQty == null || pickQty <= 0) return;

                                setState(() {
                                  selectedItemsForPayment.removeWhere(
                                    (si) => si.productId == item.productId,
                                  );
                                  selectedItemsForPayment.add(
                                    item.copyWith(
                                      quantity: pickQty,
                                      lineTotal: pickQty * item.unitPrice,
                                    ),
                                  );
                                  _updateAmountFromSelection();
                                });
                              } else {
                                setState(() {
                                  if (isSelected) {
                                    selectedItemsForPayment.removeWhere(
                                      (si) => si.productId == item.productId,
                                    );
                                  } else {
                                    selectedItemsForPayment.add(
                                      item.copyWith(
                                        quantity: remainingQty,
                                        lineTotal:
                                            remainingQty * item.unitPrice,
                                      ),
                                    );
                                  }
                                  _updateAmountFromSelection();
                                });
                              }
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                vertical: 16,
                                horizontal: 12,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(
                                        0xFF10B981,
                                      ).withValues(alpha: 0.08)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 20,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? const Color(0xFFDCFCE7)
                                          : Colors.transparent,
                                      border: Border.all(
                                        color: isSelected
                                            ? const Color(0xFF10B981)
                                            : const Color(0xFF3F3F46),
                                        width: 2,
                                      ),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: isSelected
                                        ? const Icon(
                                            Icons.check,
                                            size: 14,
                                            color: Color(0xFF0F172A),
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.name,
                                          style: const TextStyle(
                                            color: Color(0xFF0F172A),
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        Text(
                                          isSelected
                                              ? "${selectedItemsForPayment.firstWhere((si) => si.productId == item.productId).quantity.toStringAsFixed(2)} / ${item.quantity.toStringAsFixed(2)} Adet"
                                              : "${remainingQty.toStringAsFixed(2)} Adet Kaldı",
                                          style: const TextStyle(
                                            color: Color(0xFF71717A),
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    isSelected
                                        ? "${(selectedItemsForPayment.firstWhere((si) => si.productId == item.productId).lineTotal).toStringAsFixed(2)} ₺"
                                        : "${(remainingQty * item.unitPrice).toStringAsFixed(2)} ₺",
                                    style: TextStyle(
                                      color: isSelected
                                          ? const Color(0xFF10B981)
                                          : const Color(0xFF0F172A),
                                      fontWeight: FontWeight.w900,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    if (alinanOdemeler.isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.fromLTRB(24, 16, 24, 8),
                        child: Text(
                          "TAHSİLATLAR",
                          style: TextStyle(
                            color: Color(0xFF71717A),
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                        constraints: const BoxConstraints(maxHeight: 180),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFFFF),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          itemCount: alinanOdemeler.length,
                          separatorBuilder: (context, index) => const Divider(
                            color: Color(0xFFF1F5F9),
                            height: 1,
                          ),
                          itemBuilder: (context, index) {
                            final payment = alinanOdemeler[index];
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 4,
                              ),
                              leading: Icon(
                                payment.paymentMethod == 'CASH'
                                    ? Icons.payments_rounded
                                    : Icons.credit_card_rounded,
                                size: 18,
                                color: const Color(0xFF10B981),
                              ),
                              title: Text(
                                payment.paymentMethod == 'CASH'
                                    ? 'Nakit Ödeme'
                                    : 'Kredi Kartı',
                                style: const TextStyle(
                                  color: Color(0xFF0F172A),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    "${payment.amount.toStringAsFixed(2)} TL",
                                    style: const TextStyle(
                                      color: Color(0xFF0F172A),
                                      fontWeight: FontWeight.w900,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.remove_circle_outline_rounded,
                                      color: Color(0xFFFCA5A5),
                                      size: 18,
                                    ),
                                    onPressed: () {
                                      setState(() => _removePaymentAt(index));
                                    },
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // SAĞ TARAF: Ödeme Paneli
            Expanded(
              flex: 5,
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              widget.tableName,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Color(0xFF0F172A),
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "ÖDENECEK KALAN",
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Color(0xFF71717A),
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              "${kalanTutar.toStringAsFixed(2)} TL",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: kalanTutar < -0.009
                                    ? const Color(0xFFEF4444)
                                    : const Color(0xFF10B981),
                                fontSize: 34,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -1,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildDialogToggle(
                                    label: "Tutar İndirimi",
                                    selected: discountType == "AMOUNT",
                                    enabled: alinanOdemeler.isEmpty,
                                    onTap: () {
                                      setState(() {
                                        discountType = "AMOUNT";
                                        discountController.clear();
                                      });
                                    },
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _buildDialogToggle(
                                    label: "Yüzde İndirimi",
                                    selected: discountType == "PERCENT",
                                    enabled: alinanOdemeler.isEmpty,
                                    onTap: () {
                                      setState(() {
                                        discountType = "PERCENT";
                                        discountController.clear();
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: discountController,
                              readOnly: alinanOdemeler.isNotEmpty,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              onChanged: (_) {
                                setState(() {
                                  _updateAmountFromSelection();
                                });
                              },
                              style: const TextStyle(
                                color: Color(0xFF0F172A),
                                fontWeight: FontWeight.bold,
                              ),
                              decoration: InputDecoration(
                                hintText: discountType == "PERCENT"
                                    ? "İndirim Yüzdesi (%)"
                                    : "İndirim Tutarı (₺)",
                                prefixIcon: Icon(
                                  discountType == "PERCENT"
                                      ? Icons.percent_rounded
                                      : Icons.sell_rounded,
                                  size: 20,
                                  color: const Color(0xFF71717A),
                                ),
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
                                    color: Color(0xFF10B981),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFFFFF),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isOverPaid
                                      ? const Color(0xFFEF4444)
                                      : const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: Column(
                                children: [
                                  _buildSummaryRow(
                                    "Yeni Toplam",
                                    "${payableAmount.toStringAsFixed(2)} TL",
                                    const Color(0xFF10B981),
                                  ),
                                  const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 12),
                                    child: Divider(
                                      color: Color(0xFFE2E8F0),
                                      height: 1,
                                    ),
                                  ),
                                  _buildSummaryRow(
                                    "Kalan Tutar",
                                    "${kalanTutar.toStringAsFixed(2)} TL",
                                    kalanTutar < -0.009
                                        ? const Color(0xFFEF4444)
                                        : const Color(0xFFF59E0B),
                                    isLarge: true,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0FDF4),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: const Color(0xFF3B82F6), width: 1.5),
                              ),
                              child: Column(mainAxisSize: MainAxisSize.min, children: [
                                const Text(
                                  "Seçilen Ürünlerin Tutarı",
                                  style: TextStyle(color: Color(0xFF059669), fontSize: 14, fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  "${paymentAmountController.text} TL",
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Color(0xFF0F172A), fontSize: 28, fontWeight: FontWeight.w900),
                                ),
                                const Text(
                                  "Tutar, soldan seçtiğiniz ürün ve adetlere göre hesaplanır.",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                                ),
                              ]),
                            ),
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                SizedBox(
                                  width: 140,
                                  child: _buildDialogPaymentOption(
                                    label: "💵 NAKİT AL",
                                    selected: false,
                                    onTap: () {
                                      final amount =
                                          double.tryParse(
                                            paymentAmountController.text
                                                .trim()
                                                .replaceAll(",", "."),
                                          ) ??
                                          0;
                                      if (selectedItemsForPayment.isEmpty) {
                                        setState(() {
                                          validationMessage =
                                              "Tahsilat için soldan ürün seçin.";
                                        });
                                        return;
                                      }
                                      if (amount <= 0) {
                                        setState(() {
                                          validationMessage =
                                              "Geçerli bir tutar girin.";
                                        });
                                        return;
                                      }
                                      if (amount > kalanTutar + 0.009) {
                                        setState(() {
                                          validationMessage =
                                              "Tutar kalandan büyük olamaz.";
                                        });
                                        return;
                                      }
                                      _recordPayment("CASH", amount);
                                    },
                                  ),
                                ),
                                SizedBox(
                                  width: 140,
                                  child: _buildDialogPaymentOption(
                                    label: "💳 KART AL",
                                    selected: false,
                                    onTap: () {
                                      final amount =
                                          double.tryParse(
                                            paymentAmountController.text
                                                .trim()
                                                .replaceAll(",", "."),
                                          ) ??
                                          0;
                                      if (selectedItemsForPayment.isEmpty) {
                                        setState(() {
                                          validationMessage =
                                              "Tahsilat için soldan ürün seçin.";
                                        });
                                        return;
                                      }
                                      if (amount <= 0) {
                                        setState(() {
                                          validationMessage =
                                              "Geçerli bir tutar girin.";
                                        });
                                        return;
                                      }
                                      if (amount > kalanTutar + 0.009) {
                                        setState(() {
                                          validationMessage =
                                              "Tutar kalandan büyük olamaz.";
                                        });
                                        return;
                                      }
                                      _recordPayment("CARD", amount);
                                    },
                                  ),
                                ),
                              ],
                            ),
                            if (validationMessage != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: Text(
                                  validationMessage!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Color(0xFFEF4444),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFF71717A),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: const Text(
                              "Vazgeç",
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 3,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: isPaymentCompletion
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFFFFFFFF),
                              foregroundColor: isPaymentCompletion
                                  ? Colors.white
                                  : const Color(0xFF0F172A),
                              disabledBackgroundColor: const Color(0xFFF8FAFC),
                              disabledForegroundColor: const Color(0xFF64748B),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(
                                  color: isPaymentCompletion
                                      ? Colors.transparent
                                      : const Color(0xFFE2E8F0),
                                ),
                              ),
                            ),
                            onPressed: canCompleteCheckout
                                ? () {
                                    final finalItems = <TableOrderPreviewItem>[
                                      ...allPaidItemsInThisSession,
                                    ];
                                    for (final si in selectedItemsForPayment) {
                                      if (!finalItems.any(
                                        (fi) => fi.productId == si.productId,
                                      )) {
                                        finalItems.add(si);
                                      }
                                    }

                                    Navigator.of(context).pop(
                                      CheckoutDialogResult(
                                        payments: List<CollectedPayment>.from(
                                          alinanOdemeler,
                                        ),
                                        discountAmount: discountAmount,
                                        netAmount: payableAmount,
                                        selectedItems: finalItems,
                                      ),
                                    );
                                  }
                                : null,
                            child: Text(
                              isFullyCollected || isZeroBalance
                                  ? "ÖDEMEYİ TAMAMLA VE KAPAT"
                                  : isPartialPayment
                                  ? "KISMİ TAHSİLAT YAP"
                                  : hasDiscountChanged
                                  ? "İNDİRİMİ UYGULA"
                                  : "KALAN: ${kalanTutar.toStringAsFixed(2)} ₺",
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(
    String label,
    String value,
    Color color, {
    bool isLarge = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: const Color(0xFF71717A),
            fontSize: isLarge ? 14 : 12,
            fontWeight: isLarge ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: isLarge ? 18 : 14,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  Widget _buildDialogToggle({
    required String label,
    required bool selected,
    bool enabled = true,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: !enabled
              ? const Color(0xFFF1F5F9)
              : selected
              ? const Color(0xFF10B981)
              : const Color(0xFFFFFFFF),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: !enabled
                ? const Color(0xFFCBD5E1)
                : selected
                ? const Color(0xFF10B981)
                : const Color(0xFFE2E8F0),
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: !enabled
                ? const Color(0xFF94A3B8)
                : selected
                ? Colors.white
                : const Color(0xFF0F172A),
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _buildDialogPaymentOption({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return FilledButton(
      onPressed: onTap,
      style: FilledButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
      ),
    );
  }
}
