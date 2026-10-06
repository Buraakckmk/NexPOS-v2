import sys

with open(r'c:\Projects\nexpos-v2\frontend\lib\providers\order_provider.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Add _activeOrderCreatedAt variable
var_old = "DateTime? _lastSentAt;"
var_new = "DateTime? _activeOrderCreatedAt;\n  DateTime? _lastSentAt;"
content = content.replace(var_old, var_new)

# 2. Add parser logic for _activeOrderCreatedAt in _updateFromActiveOrderData
update_old = '''    if (_activeOrderId == null) {
      _lastSentProductIds.clear();
      _lastSentAt = null;
    }'''
update_new = '''    if (activeOrder != null && activeOrder["created_at"] != null) {
      _activeOrderCreatedAt = DateTime.tryParse(activeOrder["created_at"].toString())?.toLocal();
    } else {
      _activeOrderCreatedAt = null;
    }

    if (_activeOrderId == null) {
      _lastSentProductIds.clear();
      _lastSentAt = null;
      _activeOrderCreatedAt = null;
    }'''
content = content.replace(update_old, update_new)

# 3. Intercept CartLine creation
cart_line_old = '''          final existingQty = _existingItems[id] ?? 0;
          final newQty = _cart[id] ?? 0;
          final resolvedPrice = _resolveUnitPrice(id, product.price);
          final existingLineTotal =
              _existingLineTotals[id] ??
              (existingQty * (_existingPrices[id] ?? product.price));
          final displayUnitPrice = (newQty <= 0.0001 && existingQty > 0.0001)
              ? (existingLineTotal / existingQty)
              : resolvedPrice;

          return CartLine(
            product: product,
            unitPrice: displayUnitPrice,
            existingQuantity: existingQty,
            newQuantity: newQty,
            existingLineTotal: existingLineTotal,
            note: _resolveNote(id),
          );'''
cart_line_new = '''          final existingQty = _existingItems[id] ?? 0;
          final newQty = _cart[id] ?? 0;
          var resolvedPrice = _resolveUnitPrice(id, product.price);
          var existingLineTotal =
              _existingLineTotals[id] ??
              (existingQty * (_existingPrices[id] ?? product.price));

          // ── PLAYSTATION SINIRSIZ LOGIC ──
          if (product.name.trim().toLowerCase() == "sınırsız" && _activeOrderCreatedAt != null) {
            final diff = DateTime.now().difference(_activeOrderCreatedAt!);
            final hours = (diff.inMinutes / 60.0).clamp(1.0, 999.0); // minimum 1 saat
            resolvedPrice = (hours * 200.0).roundToDouble();
            if (existingQty > 0.0001) {
              existingLineTotal = (existingQty * resolvedPrice);
            }
          }
          // ───────────────────────────────

          final displayUnitPrice = (newQty <= 0.0001 && existingQty > 0.0001)
              ? (existingLineTotal / existingQty)
              : resolvedPrice;

          return CartLine(
            product: product,
            unitPrice: displayUnitPrice,
            existingQuantity: existingQty,
            newQuantity: newQty,
            existingLineTotal: existingLineTotal,
            note: _resolveNote(id),
          );'''
content = content.replace(cart_line_old, cart_line_new)

with open(r'c:\Projects\nexpos-v2\frontend\lib\providers\order_provider.dart', 'w', encoding='utf-8') as f:
    f.write(content)
print("Applied logic to order_provider.dart")
