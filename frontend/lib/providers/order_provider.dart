import "package:flutter/foundation.dart";
import "package:dio/dio.dart";

import "../services/api_client.dart";
import "../services/local_db_service.dart";
import "../services/socket_service.dart";

int _safeInt(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse((value ?? "").toString()) ?? fallback;
}

double _safeDouble(dynamic value, {double fallback = 0}) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  final raw = (value ?? "").toString().trim();
  if (raw.isEmpty) return fallback;
  // Backend/depo farkli formatlardan gelebilir: "12,5" veya "12.5"
  return double.tryParse(raw.replaceAll(",", ".")) ?? fallback;
}

double _roundMoney(double value) {
  return ((value * 100).roundToDouble()) / 100;
}

dynamic _pickFirst(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    if (json.containsKey(key) && json[key] != null) {
      return json[key];
    }
  }
  return null;
}

String _normalizedText(dynamic value) {
  return (value ?? "").toString().trim();
}

String _normalizeCategory(String value) {
  return value.trim().toUpperCase();
}

Map<String, dynamic>? _optionalUnitPricePayload(double? unitPrice) {
  return unitPrice == null ? null : {"unit_price": unitPrice};
}

List<Map<String, dynamic>> _extractProductRows(dynamic payload) {
  dynamic raw;
  if (payload is Map<String, dynamic>) {
    raw = payload["products"];
    if (raw == null && payload["data"] is Map) {
      final dataMap = Map<String, dynamic>.from(payload["data"] as Map);
      raw = dataMap["products"] ?? dataMap["items"];
    }
    raw ??= payload["items"];
  } else {
    raw = payload;
  }

  if (raw is! List) return const [];

  return raw
      .whereType<Map>()
      .map((row) => Map<String, dynamic>.from(row))
      .toList();
}

Map<String, dynamic> _extractMap(dynamic payload) {
  if (payload is Map<String, dynamic>) return payload;
  if (payload is Map) return Map<String, dynamic>.from(payload);
  return const <String, dynamic>{};
}

List<Map<String, dynamic>> _extractMapList(dynamic payload) {
  if (payload is! List) return const <Map<String, dynamic>>[];
  return payload
      .whereType<Map>()
      .map((row) => Map<String, dynamic>.from(row))
      .toList();
}

Map<String, dynamic> _extractActiveOrderContainer(dynamic payload) {
  final root = _extractMap(payload);
  if (root.isEmpty) return root;

  final data = _extractMap(root["data"]);
  final payloadMap = _extractMap(root["payload"]);

  if (data.isNotEmpty) return data;
  if (payloadMap.isNotEmpty) return payloadMap;
  return root;
}

Map<String, dynamic>? _extractActiveOrder(dynamic payload) {
  final container = _extractActiveOrderContainer(payload);
  if (container.isEmpty) return null;

  final rawActiveOrder =
      container["active_order"] ??
      container["activeOrder"] ??
      container["order"] ??
      container["active"];
  final activeOrder = _extractMap(rawActiveOrder);
  if (activeOrder.isNotEmpty) return activeOrder;

  if (container.containsKey("id") || container.containsKey("order_id")) {
    return container;
  }
  return null;
}

List<Map<String, dynamic>> _extractActiveOrderItems(dynamic payload) {
  final container = _extractActiveOrderContainer(payload);
  final activeOrder = _extractActiveOrder(payload) ?? const <String, dynamic>{};

  final items =
      _extractMapList(container["items"]) +
      _extractMapList(container["order_items"]) +
      _extractMapList(container["orderItems"]) +
      _extractMapList(container["lines"]) +
      _extractMapList(container["order_lines"]) +
      _extractMapList(activeOrder["items"]) +
      _extractMapList(activeOrder["order_items"]) +
      _extractMapList(activeOrder["orderItems"]) +
      _extractMapList(activeOrder["lines"]) +
      _extractMapList(activeOrder["order_lines"]);

  if (items.isNotEmpty) return items;
  return const <Map<String, dynamic>>[];
}

class MenuProduct {
  final int id;
  final String name;
  final double price;
  final double vatRate;
  final int categoryId;
  final String categoryName;
  final String categoryImagePath;

  const MenuProduct({
    required this.id,
    required this.name,
    required this.price,
    required this.vatRate,
    required this.categoryId,
    required this.categoryName,
    required this.categoryImagePath,
  });

  factory MenuProduct.fromJson(Map<String, dynamic> json) {
    final id = _safeInt(
      _pickFirst(json, const [
        "id",
        "product_id",
        "productId",
        "menu_product_id",
      ]),
    );
    final name = _normalizedText(
      _pickFirst(json, const ["name", "product_name", "productName", "ad"]),
    );
    final price = _safeDouble(
      _pickFirst(json, const [
        "price",
        "unit_price",
        "unitPrice",
        "fiyat",
        "sale_price",
      ]),
    );
    final vatRate = _safeDouble(
      _pickFirst(json, const ["vat_rate", "vatRate", "kdv", "kdv_rate"]),
      fallback: 10,
    );
    final categoryId = _safeInt(
      _pickFirst(json, const ["category_id", "categoryId", "menu_category_id"]),
    );
    final categoryName = _normalizedText(
      _pickFirst(json, const [
        "category_name",
        "categoryName",
        "category",
        "kategori",
      ]),
    );
    final categoryImagePath = _normalizedText(
      _pickFirst(json, const [
        "category_image_path",
        "categoryImagePath",
        "image_path",
        "imagePath",
      ]),
    );

    return MenuProduct(
      id: id,
      name: name,
      price: _roundMoney(price),
      vatRate: vatRate,
      categoryId: categoryId,
      categoryName: categoryName.isEmpty ? "DIGER" : categoryName,
      categoryImagePath: categoryImagePath,
    );
  }
}

class CartLine {
  final MenuProduct product;
  final double unitPrice;
  final double existingQuantity;
  final double newQuantity;
  final double existingLineTotal;
  final String note;

  const CartLine({
    required this.product,
    required this.unitPrice,
    required this.existingQuantity,
    required this.newQuantity,
    required this.existingLineTotal,
    required this.note,
  });

  double get quantity => existingQuantity + newQuantity;
  double get lineTotal =>
      _roundMoney(existingLineTotal + (unitPrice * newQuantity));
}

class _IndexedCartLine {
  final CartLine line;
  final int index;

  const _IndexedCartLine({required this.line, required this.index});
}

class ActiveOrderItem {
  final int productId;
  final String name;
  final double unitPrice;
  final double quantity;
  final double lineTotal;
  final String note;

  const ActiveOrderItem({
    required this.productId,
    required this.name,
    required this.unitPrice,
    required this.quantity,
    required this.lineTotal,
    required this.note,
  });

  factory ActiveOrderItem.fromJson(Map<String, dynamic> json) {
    return ActiveOrderItem(
      productId: _safeInt(
        _pickFirst(json, const [
          "product_id",
          "productId",
          "menu_product_id",
          "id",
        ]),
      ),
      name: _normalizedText(
        _pickFirst(json, const [
          "name",
          "product_name",
          "productName",
          "product_name_snapshot",
          "menu_product_name",
        ]),
      ),
      unitPrice: _safeDouble(
        _pickFirst(json, const [
          "unit_price",
          "unitPrice",
          "unit_price_snapshot",
          "price",
          "sale_price",
        ]),
      ),
      quantity: _safeDouble(
        _pickFirst(json, const ["quantity", "qty", "amount"]),
      ),
      lineTotal: _safeDouble(
        _pickFirst(json, const ["line_total", "lineTotal", "total"]),
      ),
      note: _normalizedText(
        _pickFirst(json, const ["note", "line_note", "item_note"]),
      ),
    );
  }
}

class OrderProvider extends ChangeNotifier {
  final int tableId;
  bool _disposed = false;

  OrderProvider(this.tableId) {
    _initSocket();
    SocketService().socketNotifier.addListener(_initSocket);
  }

  void _initSocket() {
    final socket = SocketService().socket;
    if (socket == null) return;

    socket.off("tables:refresh");
    socket.off("new-order");
    socket.off("menu:refresh");

    socket.on("tables:refresh", (_) {
      if (_disposed) return;
      _onSocketRefresh();
    });
    socket.on("new-order", (_) {
      if (_disposed) return;
      _onSocketRefresh();
    });
    socket.on("menu:refresh", (_) {
      if (_disposed) return;
      loadInitialData();
    });
  }

  void _onSocketRefresh() {
    if (!_isPaymentSessionActive && !isBusy && hasActiveOrder) {
      loadActiveOrderOnly();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    SocketService().socketNotifier.removeListener(_initSocket);
    final socket = SocketService().socket;
    if (socket != null) {
      socket.off("tables:refresh");
      socket.off("new-order");
      socket.off("menu:refresh");
    }
    super.dispose();
  }

  void _notifyIfAlive() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }

  bool _isLoadingProducts = false;
  bool _isLoadingActiveOrder = false;
  bool _isSubmitting = false;
  bool _isCheckingOut = false;
  bool _isPaymentSessionActive = false;
  bool _isPrintingReceipt = false;
  String? _errorMessage;
  final List<MenuProduct> _products = [];
  final Map<int, double> _existingItems = {};
  final Map<int, String> _existingNames = {};
  final Map<int, double> _existingPrices = {};
  final Map<int, double> _existingLineTotals = {};
  final Map<int, double> _linePriceOverrides = {};
  final Map<int, String> _existingNotes = {};
  final Map<int, double> _cart = {};
  final Map<int, String> _cartNotes = {};
  final Map<int, Map<String, double>> _cartVariantNotes = {};
  final Map<int, List<String>> _cartVariantSequence = {};
  final Set<int> _lastSentProductIds = <int>{};
  int? _lastAddedProductId;
  String? _activeOrderId;
  DateTime? _lastSentAt;
  DateTime? _lastAddedAt;
  int _guestCount = 1;
  String _tableNote = "";
  String _selectedCategory = "";
  String _searchQuery = "";
  double _totalPaid = 0;
  double _amountPaymentPaid = 0;
  double _discountTotal = 0;

  bool get isLoadingProducts => _isLoadingProducts;
  bool get isLoadingActiveOrder => _isLoadingActiveOrder;
  bool get isBusy => _isLoadingProducts || _isLoadingActiveOrder;
  bool get isSubmitting => _isSubmitting;
  bool get isCheckingOut => _isCheckingOut;
  bool get isPaymentSessionActive => _isPaymentSessionActive;
  bool get isPrintingReceipt => _isPrintingReceipt;
  String? get errorMessage => _errorMessage;
  List<MenuProduct> get products => List.unmodifiable(_products);
  String? get activeOrderId => _activeOrderId;
  bool get hasActiveOrder => _activeOrderId != null;
  int get guestCount => _guestCount;
  String get tableNote => _tableNote;
  String get selectedCategory => _selectedCategory;
  String get searchQuery => _searchQuery;
  double get totalPaid => _totalPaid;
  double get amountPaymentPaid => _amountPaymentPaid;
  double get discountTotal => _discountTotal;
  Set<int> get lastSentProductIds => Set.unmodifiable(_lastSentProductIds);
  DateTime? get lastSentAt => _lastSentAt;
  DateTime? get lastAddedAt => _lastAddedAt;

  List<String> get categories {
    final set = <String>{};
    for (final p in _products) {
      set.add(p.categoryName);
    }
    return set.toList();
  }

  String? categoryImagePathFor(String categoryName) {
    for (final product in _products) {
      if (_normalizeCategory(product.categoryName) ==
          _normalizeCategory(categoryName)) {
        final path = product.categoryImagePath.trim();
        if (path.isNotEmpty) return path;
      }
    }
    return null;
  }

  CartLine? get lastAddedCartLine {
    final productId = _lastAddedProductId;
    if (productId == null) return null;

    for (final line in cartLines) {
      if (line.product.id == productId && line.newQuantity > 0.0001) {
        return line;
      }
    }

    return null;
  }

  void _rememberLastAddedProduct(int productId) {
    _lastAddedProductId = productId;
    _lastAddedAt = DateTime.now();
  }

  void _syncLastAddedProduct() {
    final currentProductId = _lastAddedProductId;
    if (currentProductId != null && (_cart[currentProductId] ?? 0) > 0.0001) {
      return;
    }

    _lastAddedProductId = null;
    _lastAddedAt = null;

    final entries = _cart.entries.toList();
    for (var index = entries.length - 1; index >= 0; index--) {
      final entry = entries[index];
      if (entry.value > 0.0001) {
        _lastAddedProductId = entry.key;
        break;
      }
    }
  }

  List<MenuProduct> get filteredProducts {
    final query = _searchQuery.trim().toLowerCase();
    final selectedCategoryNorm = _normalizeCategory(_selectedCategory);
    return _products.where((p) {
      final categoryOk =
          selectedCategoryNorm.isEmpty ||
          _normalizeCategory(p.categoryName) == selectedCategoryNorm;
      if (!categoryOk) return false;
      if (query.isEmpty) return true;
      return p.name.toLowerCase().contains(query);
    }).toList();
  }

  List<CartLine> get cartLines {
    final productById = <int, MenuProduct>{for (final p in _products) p.id: p};
    final allIds = <int>{..._existingItems.keys, ..._cart.keys};
    final lines = allIds
        .map((id) {
          var product = productById[id];
          if (product == null) {
            // Eğer ürün ana listede yoksa (pasif edilmiş olabilir),
            // siparişten gelen snapshot verisiyle "sanal" bir ürün oluşturalım.
            if (_existingItems.containsKey(id)) {
              product = MenuProduct(
                id: id,
                name: _existingNames[id] ?? "Bilinmeyen Ürün",
                price: _roundMoney(_existingPrices[id] ?? 0.0),
                vatRate: 10,
                categoryId: 0,
                categoryName: "Eski Sipariş",
                categoryImagePath: "",
              );
            } else {
              return null;
            }
          }

          final existingQty = _existingItems[id] ?? 0;
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
          );
        })
        .whereType<CartLine>()
        .where((line) => line.quantity > 0.0001)
        .toList();

    final indexedLines = <_IndexedCartLine>[
      for (var i = 0; i < lines.length; i++)
        _IndexedCartLine(line: lines[i], index: i),
    ];
    final lastAddedProductId = _lastAddedProductId;

    indexedLines.sort((a, b) {
      final aHasPending = a.line.newQuantity > 0.0001;
      final bHasPending = b.line.newQuantity > 0.0001;
      if (aHasPending != bHasPending) {
        return aHasPending ? -1 : 1;
      }

      final aIsLastAddedPending =
          aHasPending && a.line.product.id == lastAddedProductId;
      final bIsLastAddedPending =
          bHasPending && b.line.product.id == lastAddedProductId;
      if (aIsLastAddedPending != bIsLastAddedPending) {
        return aIsLastAddedPending ? -1 : 1;
      }

      return a.index.compareTo(b.index);
    });

    return indexedLines.map((entry) => entry.line).toList();
  }

  double get totalAmount => _roundMoney(
    (cartLines.fold<double>(0, (sum, line) => sum + line.lineTotal) -
            _discountTotal)
        .clamp(0, double.infinity)
        .toDouble(),
  );

  bool get hasItems => _cart.values.any((qty) => qty > 0.0001);

  double _normalizeStepQty(double value) {
    final normalized = (value * 10).roundToDouble() / 10;
    return normalized < 0.0001 ? 0 : normalized;
  }

  String formatQuantity(double value) {
    final normalized = _normalizeStepQty(value);
    if ((normalized - normalized.roundToDouble()).abs() < 0.001) {
      return normalized.toStringAsFixed(0);
    }
    return normalized.toStringAsFixed(1);
  }

  String _normalizeNote(String? value) => value?.trim() ?? "";

  String _resolveNote(int productId) {
    final hasPending = (_cart[productId] ?? 0) > 0.0001;
    final noteParts = <String>[];

    // Önce manual notu kontrol et
    final cartNote = _normalizeNote(_cartNotes[productId]);
    if (cartNote.isNotEmpty) {
      noteParts.add(cartNote);
    }

    // Variant notlarını kontrol et - aynı ürüne farklı notlarla eklenmişse "demli 1" gibi göster
    final variantSummary = _buildVariantSummaryNote(productId);
    if (variantSummary.isNotEmpty && variantSummary != cartNote) {
      noteParts.add(variantSummary);
    }

    // Eğer cartNote varsa onu alt alta göster
    if (noteParts.isNotEmpty) {
      return noteParts.join("\n");
    }

    // Sepette bu urun icin yeni ekleme varsa (notsuz dahil),
    // mevcut siparis notuna dusmeyelim.
    if (hasPending) {
      return "";
    }

    // Yoksa mevcut siparişte bu ürünün notunu göster
    return _normalizeNote(_existingNotes[productId]);
  }

  String _buildVariantSummaryNote(int productId) {
    final variants = _cartVariantNotes[productId];
    if (variants == null || variants.isEmpty) {
      return "";
    }

    // Variant notlarını giriş sırasına göre göster: "açık 2\ndemli 1"
    final orderedKeys = <String>[];
    final seen = <String>{};
    final sequence = _cartVariantSequence[productId] ?? const <String>[];

    for (final key in sequence) {
      if (!seen.contains(key)) {
        seen.add(key);
        orderedKeys.add(key);
      }
    }

    for (final key in variants.keys) {
      if (!seen.contains(key)) {
        seen.add(key);
        orderedKeys.add(key);
      }
    }

    final parts = orderedKeys
        .map((key) => MapEntry(key, variants[key] ?? 0))
        .where((entry) => entry.value > 0.0001)
        .where((entry) => entry.key.trim().isNotEmpty)
        .map((entry) => "${entry.key} ${formatQuantity(entry.value)}")
        .toList();

    if (parts.isEmpty) {
      return "";
    }

    return parts.join("\n");
  }

  void addProductWithVariant(
    MenuProduct product,
    String variant, {
    double amount = 1,
  }) {
    if (amount <= 0) return;
    if (product.id <= 0) {
      _errorMessage = "Urun id gecersiz. Lutfen urun listesini yenileyin.";
      notifyListeners();
      return;
    }

    final normalizedVariant = _normalizeNote(variant);

    final existingCartNote = _normalizeNote(_cartNotes[product.id]);
    final previousSummary = _buildVariantSummaryNote(product.id);

    _errorMessage = null;

    _cart.update(
      product.id,
      (qty) => _normalizeStepQty(qty + amount),
      ifAbsent: () => _normalizeStepQty(amount),
    );
    _rememberLastAddedProduct(product.id);

    final variantMap = _cartVariantNotes.putIfAbsent(
      product.id,
      () => <String, double>{},
    );
    variantMap.update(
      normalizedVariant,
      (qty) => _normalizeStepQty(qty + amount),
      ifAbsent: () => _normalizeStepQty(amount),
    );

    final sequence = _cartVariantSequence.putIfAbsent(
      product.id,
      () => <String>[],
    );
    sequence.add(normalizedVariant);

    final updatedSummary = _buildVariantSummaryNote(product.id);
    // Manual not yazılmışsa koru; not boşsa veya önceki auto-summary ise güncelle.
    if (existingCartNote.isEmpty || existingCartNote == previousSummary) {
      _cartNotes[product.id] = updatedSummary;
    }
    _rememberLastAddedProduct(product.id);
    notifyListeners();
  }

  String noteForProduct(int productId) => _resolveNote(productId);

  void clearExistingItemNoteIfAny(int productId) {
    final existingNote = _normalizeNote(_existingNotes[productId]);
    final hasExisting = (_existingItems[productId] ?? 0) > 0;
    if (!hasExisting || existingNote.isEmpty) {
      return;
    }

    _existingNotes.remove(productId);
    notifyListeners();

    final orderId = _activeOrderId;
    if (orderId == null) {
      return;
    }

    ApiClient.dio
        .post(
          "/waiter/orders/$orderId/item-note",
          data: {"product_id": productId, "note": ""},
          options: Options(extra: {"showGlobalError": false}),
        )
        .then((_) {})
        .onError((e, _) {
          debugPrint("clearExistingItemNoteIfAny error for $productId: $e");
        });
  }

  double _resolveUnitPrice(int productId, double fallbackPrice) {
    final override = _linePriceOverrides[productId];
    if (override != null) return override;

    final existing = _existingPrices[productId];
    if (existing != null && existing >= 0) return existing;

    return fallbackPrice;
  }

  Future<bool> updateLinePrice(int productId, double unitPrice) async {
    if (unitPrice < 0) {
      _errorMessage = "Fiyat 0 veya daha buyuk olmali.";
      notifyListeners();
      return false;
    }

    final hasExisting = (_existingItems[productId] ?? 0) > 0;
    final hasCart = (_cart[productId] ?? 0) > 0;
    if (!hasExisting && !hasCart) {
      _errorMessage = "Fiyati degisecek urun bulunamadi.";
      notifyListeners();
      return false;
    }

    _linePriceOverrides[productId] = unitPrice;
    if (hasExisting) {
      final orderId = _activeOrderId;
      if (orderId == null) {
        _errorMessage = "Aktif siparis bulunamadi.";
        notifyListeners();
        return false;
      }

      _isSubmitting = true;
      notifyListeners();
      try {
        await ApiClient.dio.post(
          "/waiter/orders/$orderId/item-price",
          data: {"product_id": productId, "unit_price": unitPrice},
          options: Options(extra: {"showGlobalError": false}),
        );
        _existingPrices[productId] = unitPrice;
      } catch (e) {
        _isSubmitting = false;
        if (e is DioException &&
            e.response?.data is Map<String, dynamic> &&
            (e.response?.data["message"]?.toString().isNotEmpty ?? false)) {
          _errorMessage = e.response?.data["message"].toString();
        } else {
          _errorMessage = "Fiyat degisikligi kaydedilemedi.";
        }
        _linePriceOverrides.remove(productId);
        notifyListeners();
        return false;
      }
      _isSubmitting = false;
    }
    _errorMessage = null;
    notifyListeners();
    return true;
  }

  Future<void> loadInitialData() async {
    _isLoadingProducts = true;
    _isLoadingActiveOrder = true;
    _errorMessage = null;
    notifyListeners();

    final localDb = LocalDbService();

    try {
      // Çevrimdışı olsa bile ürünleri önce yerelden yükleyelim (hızlı UI için)
      try {
        final cachedProducts = await localDb.getProducts();
        if (cachedProducts.isNotEmpty) {
          final parsedProducts = cachedProducts
              .map(MenuProduct.fromJson)
              .where((p) => p.id > 0 && p.name.trim().isNotEmpty)
              .toList();

          _products
            ..clear()
            ..addAll(parsedProducts);
          notifyListeners();
        }
      } catch (e) {
        debugPrint("loadInitialData local cache read error: $e");
      }

      // Ürünleri ve aktif siparişi paralel çekelim
      final results = await Future.wait([
        ApiClient.dio.get("/waiter/products"),
        ApiClient.dio.get("/waiter/tables/$tableId/active-order"),
      ]);

      final rawProducts = _extractProductRows(results[0].data);

      if (rawProducts.isNotEmpty) {
        final parsedProducts = rawProducts
            .map(MenuProduct.fromJson)
            .where((p) => p.id > 0 && p.name.trim().isNotEmpty)
            .toList();

        _products
          ..clear()
          ..addAll(parsedProducts);

        if (parsedProducts.isEmpty) {
          _errorMessage =
              "Urun verisi gecersiz formatta geldi (id/name/price).";
        }

        // Yerel veritabanına yedekle — hata olsa bile aktif siparişi engelleme
        try {
          await localDb.saveProducts(rawProducts);
        } catch (e) {
          debugPrint("loadInitialData saveProducts error (non-fatal): $e");
        }
      }

      // Aktif siparişi yükle — lokalDB hatası bu bloğu etkilemez
      final activeOrderData = Map<String, dynamic>.from(
        (results[1].data as Map?) ?? const <String, dynamic>{},
      );
      _updateFromActiveOrderData(activeOrderData);
    } catch (e) {
      // Eğer hata varsa ve ürünler hala boşsa hata mesajı göster
      if (_products.isEmpty) {
        _errorMessage = "Veriler alınamadı. Lütfen bağlantıyı kontrol edin.";
      }
      debugPrint("loadInitialData error: $e");
    } finally {
      _isLoadingProducts = false;
      _isLoadingActiveOrder = false;
      notifyListeners();
    }
  }

  Future<void> loadActiveOrderOnly() async {
    if (_isLoadingActiveOrder || _isPaymentSessionActive) return;
    _isLoadingActiveOrder = true;
    notifyListeners();

    try {
      final response = await ApiClient.dio.get(
        "/waiter/tables/$tableId/active-order",
      );
      final activeOrderData = Map<String, dynamic>.from(
        (response.data as Map?) ?? const <String, dynamic>{},
      );
      _updateFromActiveOrderData(activeOrderData);
    } catch (e) {
      debugPrint("loadActiveOrderOnly error: $e");
    } finally {
      _isLoadingActiveOrder = false;
      notifyListeners();
    }
  }

  void _updateFromActiveOrderData(Map<String, dynamic> activeOrderData) {
    final activeOrder = _extractActiveOrder(activeOrderData);

    _activeOrderId = _pickFirst(
      activeOrder ?? const <String, dynamic>{},
      const ["id", "order_id"],
    )?.toString();
    _guestCount = _safeInt(activeOrder?["guest_count"], fallback: 1);
    if (_guestCount <= 0) _guestCount = 1;
    _tableNote = (activeOrder?["table_note"] ?? "").toString();
    _totalPaid = _safeDouble(activeOrder?["total_paid"]);
    _amountPaymentPaid = _safeDouble(activeOrder?["amount_payment_paid"]);
    _discountTotal = _safeDouble(activeOrder?["discount_total"]);

    if (_activeOrderId == null) {
      _lastSentProductIds.clear();
      _lastSentAt = null;
    }

    _existingItems.clear();
    _existingNames.clear();
    _existingPrices.clear();
    _existingLineTotals.clear();
    _existingNotes.clear();
    _linePriceOverrides.clear();
    _cartVariantNotes.clear();
    _cartVariantSequence.clear();

    final rawItems = _extractActiveOrderItems(activeOrderData);
    for (final raw in rawItems) {
      final item = ActiveOrderItem.fromJson(raw);
      if (item.productId <= 0 || item.name.isEmpty || item.quantity <= 0) {
        continue;
      }
      _existingItems.update(
        item.productId,
        (v) => v + item.quantity,
        ifAbsent: () => item.quantity,
      );
      final normalizedLineTotal = item.lineTotal > 0
          ? _roundMoney(item.lineTotal)
          : _roundMoney(item.unitPrice * item.quantity);
      _existingLineTotals.update(
        item.productId,
        (v) => v + normalizedLineTotal,
        ifAbsent: () => normalizedLineTotal,
      );
      _existingNames[item.productId] = item.name;
      final totalQty = _existingItems[item.productId] ?? 0;
      final totalLine = _existingLineTotals[item.productId] ?? 0;
      _existingPrices[item.productId] = totalQty > 0
          ? (totalLine / totalQty)
          : item.unitPrice;

      if (item.note.isNotEmpty) {
        _existingNotes[item.productId] = item.note;
      }
    }
  }

  Future<bool> beginPaymentSession() async {
    final orderId = _activeOrderId;
    if (orderId == null || _isCheckingOut || _isPaymentSessionActive) {
      return false;
    }

    _isCheckingOut = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await ApiClient.dio.post(
        "/waiter/orders/$orderId/payment-session/start",
        options: Options(extra: {"showGlobalError": false}),
      );
      _isPaymentSessionActive = true;
      _isCheckingOut = false;
      _notifyIfAlive();
      return true;
    } catch (e) {
      _isCheckingOut = false;
      if (e is DioException &&
          e.response?.data is Map<String, dynamic> &&
          (e.response?.data["message"]?.toString().isNotEmpty ?? false)) {
        _errorMessage = e.response?.data["message"].toString();
      } else {
        _errorMessage = "Odeme oturumu baslatilamadi.";
      }
      _notifyIfAlive();
      return false;
    }
  }

  Future<void> endPaymentSession() async {
    final orderId = _activeOrderId;
    if (orderId == null || !_isPaymentSessionActive) {
      _isCheckingOut = false;
      _notifyIfAlive();
      return;
    }

    try {
      await ApiClient.dio.post(
        "/waiter/orders/$orderId/payment-session/end",
        options: Options(extra: {"showGlobalError": false}),
      );
    } catch (_) {
      // Best-effort unlock; backend timeout da temizler.
    } finally {
      _isPaymentSessionActive = false;
      _isCheckingOut = false;
      _notifyIfAlive();
    }
  }

  void increase(MenuProduct product, {double amount = 1}) {
    if (amount <= 0) return;
    if (product.id <= 0) {
      _errorMessage = "Urun id gecersiz. Lutfen urun listesini yenileyin.";
      notifyListeners();
      return;
    }

    final variantSequence = _cartVariantSequence[product.id];
    if (variantSequence != null && variantSequence.isNotEmpty) {
      addProductWithVariant(product, variantSequence.last, amount: amount);
      return;
    }

    _errorMessage = null;

    _cart.update(
      product.id,
      (qty) => _normalizeStepQty(qty + amount),
      ifAbsent: () => _normalizeStepQty(amount),
    );
    _rememberLastAddedProduct(product.id);
    notifyListeners();
  }

  void decrease(MenuProduct product, {double amount = 1}) {
    if (amount <= 0) return;
    final qty = _cart[product.id];
    if (qty == null) return;

    final variantSequence = _cartVariantSequence[product.id];
    final variantMap = _cartVariantNotes[product.id];
    if (variantSequence != null &&
        variantSequence.isNotEmpty &&
        variantMap != null) {
      var remainingToRemove = amount;
      while (remainingToRemove > 0.0001 && variantSequence.isNotEmpty) {
        final lastVariant = variantSequence.removeLast();
        final currentVariantQty = variantMap[lastVariant] ?? 0;
        if (currentVariantQty <= 0.0001) {
          continue;
        }

        final removeQty = currentVariantQty < remainingToRemove
            ? currentVariantQty
            : remainingToRemove;
        final nextVariantQty = _normalizeStepQty(currentVariantQty - removeQty);
        if (nextVariantQty <= 0.0001) {
          variantMap.remove(lastVariant);
        } else {
          variantMap[lastVariant] = nextVariantQty;
        }
        remainingToRemove = _normalizeStepQty(remainingToRemove - removeQty);
      }

      if (variantMap.isEmpty) {
        _cartVariantNotes.remove(product.id);
      }
      if (variantSequence.isEmpty) {
        _cartVariantSequence.remove(product.id);
      }
    }

    final nextQty = _normalizeStepQty(qty - amount);
    if (nextQty <= 0.0001) {
      _cart.remove(product.id);
      _cartVariantNotes.remove(product.id);
      _cartVariantSequence.remove(product.id);
      if ((_existingItems[product.id] ?? 0) <= 0) {
        _cartNotes.remove(product.id);
      }
    } else {
      _cart[product.id] = nextQty;
      // Variant notları kalıyorsa ve manuel not yoksa, variant summary'yi güncelle
      if (_cartVariantNotes.containsKey(product.id) &&
          (_cartNotes[product.id] ?? "").isEmpty) {
        _cartNotes[product.id] = _buildVariantSummaryNote(product.id);
      }
    }
    _syncLastAddedProduct();
    notifyListeners();
  }

  double quantityOf(MenuProduct product) =>
      (_existingItems[product.id] ?? 0) + (_cart[product.id] ?? 0);

  double pendingQuantityOf(MenuProduct product) => _cart[product.id] ?? 0;

  void setSelectedCategory(String category) {
    if (_selectedCategory == category) return;
    _selectedCategory = category;
    notifyListeners();
  }

  void setSearchQuery(String value) {
    if (_searchQuery == value) return;
    _searchQuery = value;
    notifyListeners();
  }

  Future<bool> submitAndConfirmOrder() async {
    if (_isSubmitting) return false;
    if (_cart.isEmpty) {
      _errorMessage = "Sepet bos. Siparis gondermek icin once urun ekleyin.";
      notifyListeners();
      return false;
    }

    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final sentProductIds = _cart.entries
          .where((e) => e.value > 0.0001)
          .map((e) => e.key)
          .toSet();

      final resolvedNotesByProduct = <int, String>{
        for (final e in _cart.entries) e.key: _resolveNote(e.key),
      };

      final items = _cart.entries
          .map(
            (e) => <String, dynamic>{
              "product_id": e.key,
              "quantity": e.value,
              "note": resolvedNotesByProduct[e.key] ?? "",
              ...?_optionalUnitPricePayload(_linePriceOverrides[e.key]),
            },
          )
          .toList();

      final createResponse = await ApiClient.dio.post(
        "/waiter/orders",
        data: {"table_id": tableId, "items": items},
      );

      final createdData = createResponse.data as Map<String, dynamic>;
      final order = createdData["order"] as Map<String, dynamic>? ?? {};
      final orderId = order["id"]?.toString() ?? "";
      if (orderId.isEmpty) {
        throw Exception("Siparis ID alinamadi.");
      }

      await ApiClient.dio.post("/waiter/orders/$orderId/confirm");

      // Notlar tek kullanimliktir: siparis onayindan sonra sistemde kalmasin.
      // Boylece sonraki eklemelerde eski notlar tekrar gorunmez.
      for (final productId in sentProductIds) {
        final hadAnyNote =
            (_existingNotes[productId] ?? "").isNotEmpty ||
            (resolvedNotesByProduct[productId] ?? "").isNotEmpty;
        if (!hadAnyNote) {
          continue;
        }

        try {
          await ApiClient.dio.post(
            "/waiter/orders/$orderId/item-note",
            data: {"product_id": productId, "note": ""},
            options: Options(extra: {"showGlobalError": false}),
          );
        } catch (e) {
          debugPrint("clear item-note error for product $productId: $e");
        }
      }

      for (final entry in _cart.entries) {
        final product = _products.firstWhere(
          (p) => p.id == entry.key,
          orElse: () => MenuProduct(
            id: entry.key,
            name: "Bilinmeyen Ürün",
            price: 0,
            vatRate: 10,
            categoryId: 0,
            categoryName: "",
            categoryImagePath: "",
          ),
        );
        final basePrice = _linePriceOverrides[entry.key] ?? product.price;
        final prevQty = _existingItems[entry.key] ?? 0;
        final prevTotal =
            _existingLineTotals[entry.key] ??
            (prevQty * (_existingPrices[entry.key] ?? basePrice));
        final nextQty = prevQty + entry.value;
        final nextTotal = _roundMoney(prevTotal + (entry.value * basePrice));

        _existingItems[entry.key] = nextQty;
        _existingLineTotals[entry.key] = nextTotal;
        _existingNames[entry.key] = product.name;
        _existingPrices[entry.key] = nextQty > 0
            ? (nextTotal / nextQty)
            : basePrice;

        _existingNotes.remove(entry.key);
      }
      _activeOrderId = orderId;
      _lastSentProductIds
        ..clear()
        ..addAll(sentProductIds);
      _lastSentAt = DateTime.now();
      _lastAddedProductId = null;
      _lastAddedAt = null;
      _cart.clear();
      _cartNotes.clear();
      _cartVariantNotes.clear();
      _cartVariantSequence.clear();
      _isSubmitting = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isSubmitting = false;
      if (e is DioException &&
          e.response?.data is Map<String, dynamic> &&
          (e.response?.data["message"]?.toString().isNotEmpty ?? false)) {
        _errorMessage = e.response?.data["message"].toString();
      } else {
        _errorMessage = "Siparis onaylanamadi.";
      }
      notifyListeners();
      return false;
    }
  }

  /// Ürün İptali (Void) - Admin PIN gerekli
  Future<bool> voidOrderItem(int productId, {num quantity = 1}) async {
    final orderId = _activeOrderId;
    if (orderId == null || _isCheckingOut) return false;

    _isCheckingOut = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await ApiClient.dio.post(
        "/waiter/orders/$orderId/void-item",
        data: {"product_id": productId, "decrease_amount": quantity},
        options: Options(extra: {"showGlobalError": false}),
      );

      final current = _existingItems[productId] ?? 0.0;
      final qtyValue = quantity.toDouble();
      if (current <= qtyValue + 0.0001) {
        _existingItems.remove(productId);
        _existingNames.remove(productId);
        _existingPrices.remove(productId);
        _existingLineTotals.remove(productId);
        _linePriceOverrides.remove(productId);
        _existingNotes.remove(productId);
        _cartVariantNotes.remove(productId);
        _cartVariantSequence.remove(productId);
      } else {
        final nextQty = current - qtyValue;
        final currentTotal = _roundMoney(
          _existingLineTotals[productId] ??
              (current * (_existingPrices[productId] ?? 0)),
        );
        final avgPrice = current > 0 ? (currentTotal / current) : 0;
        final nextTotal = (currentTotal - (avgPrice * qtyValue))
            .clamp(0.0, double.infinity)
            .toDouble();

        _existingItems[productId] = nextQty;
        _existingLineTotals[productId] = nextTotal;
        _existingPrices[productId] = nextQty > 0 ? (nextTotal / nextQty) : 0.0;
      }

      if (_existingItems.isEmpty && _cart.isEmpty) {
        _activeOrderId = null;
        _guestCount = 1;
        _tableNote = "";
        _lastSentProductIds.clear();
        _lastSentAt = null;
        _lastAddedProductId = null;
        _lastAddedAt = null;
      }
      _isCheckingOut = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isCheckingOut = false;
      if (e is DioException &&
          e.response?.data is Map<String, dynamic> &&
          (e.response?.data["message"]?.toString().isNotEmpty ?? false)) {
        _errorMessage = e.response?.data["message"].toString();
      } else {
        _errorMessage = "Ürün iptali başarısız.";
      }
      notifyListeners();
      return false;
    }
  }

  /// Ürün İkramı (Comp) - Admin PIN gerekli
  Future<bool> compOrderItem(int productId) async {
    final orderId = _activeOrderId;
    if (orderId == null || _isCheckingOut) return false;

    _isCheckingOut = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await ApiClient.dio.post(
        "/waiter/orders/$orderId/comp-item",
        data: {"product_id": productId},
      );
      _isCheckingOut = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isCheckingOut = false;
      _errorMessage = "Ürün ikramı başarısız.";
      notifyListeners();
      return false;
    }
  }

  Future<bool> saveItemNote(
    int productId,
    String note, {
    bool silent = false,
    bool applyToExisting = true,
  }) async {
    final normalized = _normalizeNote(note);
    final hasExisting = (_existingItems[productId] ?? 0) > 0;
    final hasCart = (_cart[productId] ?? 0) > 0;

    if (!hasExisting && !hasCart) {
      _errorMessage = "Not eklenecek siparis kalemi bulunamadi.";
      if (!silent) notifyListeners();
      return false;
    }

    if (hasCart) {
      if (normalized.isEmpty) {
        _cartNotes.remove(productId);
      } else {
        _cartNotes[productId] = normalized;
        // Manual not yazıldığında, variant notları sıfırla
        // Çünkü manual not tüm ürün için tek Not olmalı
        _cartVariantNotes.remove(productId);
        _cartVariantSequence.remove(productId);
      }
    }

    if (!hasExisting || !applyToExisting) {
      _errorMessage = null;
      if (!silent) notifyListeners();
      return true;
    }

    final orderId = _activeOrderId;
    if (orderId == null) {
      _errorMessage = "Aktif siparis bulunamadi.";
      if (!silent) notifyListeners();
      return false;
    }

    if (!silent) {
      _isSubmitting = true;
    }
    _errorMessage = null;
    if (!silent) notifyListeners();

    try {
      await ApiClient.dio.post(
        "/waiter/orders/$orderId/item-note",
        data: {"product_id": productId, "note": normalized},
        options: Options(extra: {"showGlobalError": false}),
      );

      if (normalized.isEmpty) {
        _existingNotes.remove(productId);
      } else {
        _existingNotes[productId] = normalized;
      }

      if (!silent) {
        _isSubmitting = false;
        notifyListeners();
      }
      return true;
    } catch (e) {
      if (!silent) {
        _isSubmitting = false;
      }
      if (e is DioException &&
          e.response?.data is Map<String, dynamic> &&
          (e.response?.data["message"]?.toString().isNotEmpty ?? false)) {
        _errorMessage = e.response?.data["message"].toString();
      } else {
        _errorMessage = "Siparis notu kaydedilemedi.";
      }
      if (!silent) notifyListeners();
      return false;
    }
  }

  Future<bool> saveOrderMeta({
    required int guestCount,
    required String tableNote,
  }) async {
    final orderId = _activeOrderId;
    if (orderId == null) {
      _errorMessage = "Aktif siparis bulunamadi.";
      notifyListeners();
      return false;
    }

    final normalizedGuest = guestCount <= 0 ? 1 : guestCount;
    final normalizedNote = tableNote.trim();

    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await ApiClient.dio.post(
        "/waiter/orders/$orderId/meta",
        data: {"guest_count": normalizedGuest, "table_note": normalizedNote},
      );

      _guestCount = normalizedGuest;
      _tableNote = normalizedNote;
      _isSubmitting = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isSubmitting = false;
      if (e is DioException &&
          e.response?.data is Map<String, dynamic> &&
          (e.response?.data["message"]?.toString().isNotEmpty ?? false)) {
        _errorMessage = e.response?.data["message"].toString();
      } else {
        _errorMessage = "Masa bilgileri kaydedilemedi.";
      }
      notifyListeners();
      return false;
    }
  }

  Future<bool> transferItem({
    required int productId,
    required int quantity,
    required int toTableId,
  }) async {
    final orderId = _activeOrderId;
    if (orderId == null) {
      _errorMessage = "Aktif siparis bulunamadi.";
      notifyListeners();
      return false;
    }

    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await ApiClient.dio.post(
        "/waiter/orders/$orderId/transfer-item",
        data: {
          "product_id": productId,
          "quantity": quantity,
          "to_table_id": toTableId,
        },
      );

      await loadInitialData();
      _isSubmitting = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isSubmitting = false;
      if (e is DioException &&
          e.response?.data is Map<String, dynamic> &&
          (e.response?.data["message"]?.toString().isNotEmpty ?? false)) {
        _errorMessage = e.response?.data["message"].toString();
      } else {
        _errorMessage = "Urun transfer islemi basarisiz.";
      }
      notifyListeners();
      return false;
    }
  }

  Future<bool> printCurrentAccount({required String tableName}) async {
    if (_isPrintingReceipt) return false;

    if (!hasActiveOrder) {
      _errorMessage = "Adisyon yazdirmak icin once siparisi onaylayin.";
      notifyListeners();
      return false;
    }

    if (_cart.isNotEmpty) {
      _errorMessage = "Onaylanmamis urunler var. Once 'Siparisi Onayla' yapin.";
      notifyListeners();
      return false;
    }

    if (cartLines.isEmpty) return false;

    _isPrintingReceipt = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final items = cartLines
          .map(
            (line) => {
              "name": line.product.name,
              "quantity": line.quantity,
              "unit_price": line.unitPrice,
              "note": line.note,
            },
          )
          .toList();

      final subtotal = cartLines.fold<double>(
        0,
        (sum, line) => sum + line.lineTotal,
      );

      await ApiClient.dio.post(
        "/waiter/tables/$tableId/print-current-account",
        data: {
          "order_id": _activeOrderId,
          "table_display_name": tableName,
          "guest_count": _guestCount,
          "table_note": _tableNote,
          "items": items,
          "subtotal": subtotal,
          "discount_amount": _discountTotal,
          "total_paid": _totalPaid,
          "remaining_total": totalAmount,
        },
        options: Options(extra: {"showGlobalError": false}),
      );

      _isPrintingReceipt = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isPrintingReceipt = false;
      if (e is DioException &&
          e.response?.data is Map<String, dynamic> &&
          (e.response?.data["message"]?.toString().isNotEmpty ?? false)) {
        _errorMessage = e.response?.data["message"].toString();
      } else {
        _errorMessage = "Adisyon yazdirilamadi.";
      }
      notifyListeners();
      return false;
    }
  }
}
