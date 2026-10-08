import "dart:async";

import "package:flutter/material.dart";
import "package:dio/dio.dart";
import "package:file_picker/file_picker.dart";
import "package:flutter/services.dart";

import "../services/admin_auth_service.dart";
import "../services/admin_menu_service.dart";

class AdminMenuManagementScreen extends StatefulWidget {
  const AdminMenuManagementScreen({super.key});

  @override
  State<AdminMenuManagementScreen> createState() =>
      _AdminMenuManagementScreenState();
}

class _AdminMenuManagementScreenState extends State<AdminMenuManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _categoryNameController = TextEditingController();

  List<AdminMenuCategory> _categories = const [];
  List<AdminMenuProduct> _products = const [];
  int? _selectedCategoryFilter;
  bool _isLoading = true;
  bool _isSubmitting = false;
  Timer? _searchDebounce;

  bool _isAssetPath(String path) => path.trim().startsWith("assets/");

  Widget _buildImagePreview(String imagePath) {
    final trimmed = imagePath.trim();
    if (trimmed.isEmpty) {
      return const Icon(Icons.image_outlined, color: Color(0xFF64748B));
    }

    if (_isAssetPath(trimmed)) {
      return Image.asset(
        trimmed,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            const Icon(Icons.broken_image_outlined, color: Color(0xFFEF4444)),
      );
    }

    return Image.network(
      Uri.file(trimmed).toString(),
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) =>
          const Icon(Icons.broken_image_outlined, color: Color(0xFFEF4444)),
    );
  }

  Future<String?> _pickCategoryImagePath() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowMultiple: false,
        allowedExtensions: const ["jpg", "jpeg", "png", "webp"],
      );
      if (result == null || result.files.isEmpty) return null;
      final path = result.files.single.path?.trim();
      if (path == null || path.isEmpty) return null;
      return path;
    } catch (_) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    setState(() => _isLoading = true);
    try {
      final categories = await AdminMenuService.fetchCategories();
      final products = await AdminMenuService.fetchProducts();
      if (!mounted) return;
      setState(() {
        _categories = categories;
        _products = products;
      });
    } catch (e) {
      if (!mounted) return;
      _showError("Ürünler yüklenemedi: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<DropdownMenuItem<int>> _buildCategoryDropdownItems() {
    final List<DropdownMenuItem<int>> items = [];
    for (final parent in _categories.where((c) => c.parentCategoryId == null)) {
      items.add(DropdownMenuItem<int>(value: parent.id, child: Text(parent.name, style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w700))));
      for (final child in _categories.where((c) => c.parentCategoryId == parent.id)) {
        items.add(DropdownMenuItem<int>(value: child.id, child: Text("  ↳ ${child.name}", style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w500))));
      }
    }
    final includedIds = items.map((item) => item.value).toSet();
    for (final category in _categories) {
      if (includedIds.contains(category.id)) continue;
      items.add(
        DropdownMenuItem<int>(
          value: category.id,
          child: Text(
            "↳ ${category.name}",
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );
    }
    return items;
  }

  Future<void> _refreshProducts() async {
    try {
      final products = await AdminMenuService.fetchProducts(
        search: _searchController.text.trim(),
        categoryId: _selectedCategoryFilter,
      );
      if (!mounted) return;
      setState(() => _products = products);
    } catch (e) {
      if (!mounted) return;
      _showError("Liste yenilenemedi: $e");
    }
  }

  void _onSearchChanged(String _) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), _refreshProducts);
  }

  Future<void> _refreshCategories({int? selectedCategoryId}) async {
    try {
      final categories = await AdminMenuService.fetchCategories();
      if (!mounted) return;
      setState(() {
        _categories = categories;
        if (selectedCategoryId != null &&
            categories.any((c) => c.id == selectedCategoryId)) {
          _selectedCategoryFilter = selectedCategoryId;
        } else if (_selectedCategoryFilter != null &&
            !categories.any((c) => c.id == _selectedCategoryFilter)) {
          _selectedCategoryFilter = null;
        }
      });
    } catch (e) {
      if (!mounted) return;
      _showError(_humanizeError(e, fallback: "Kategoriler yenilenemedi."));
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFB91C1C),
      ),
    );
  }

  String _humanizeError(Object error, {String fallback = "İşlem başarısız."}) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map<String, dynamic>) {
        final message = data["message"]?.toString().trim();
        if (message != null && message.isNotEmpty) return message;
      }
      final message = error.message?.trim();
      if (message != null && message.isNotEmpty) return message;
    }
    final text = error.toString().trim();
    if (text.isNotEmpty) return text;
    return fallback;
  }

  Future<void> _openCreateDialog() async {
    _nameController.clear();
    _priceController.clear();
    int? selectedCategoryId = _categories.isNotEmpty
        ? _categories.first.id
        : null;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) => AlertDialog(
            title: const Text("Yeni Ürün Ekle"),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: "Ürün Adı"),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _priceController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: "Fiyat"),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: selectedCategoryId,
                    dropdownColor: Colors.white,
                    style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
                    decoration: const InputDecoration(labelText: "Kategori"),
                    items: _buildCategoryDropdownItems(),
                    onChanged: (value) =>
                        setModalState(() => selectedCategoryId = value),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: _isSubmitting ? null : () => Navigator.of(ctx).pop(),
                child: const Text("İptal"),
              ),
              FilledButton(
                onPressed: _isSubmitting
                    ? null
                    : () async {
                        final name = _nameController.text.trim();
                        final price = double.tryParse(
                          _priceController.text.trim().replaceAll(",", "."),
                        );
                        if (name.isEmpty ||
                            price == null ||
                            selectedCategoryId == null) {
                          _showError("Ad, fiyat ve kategori zorunludur.");
                          return;
                        }

                        setState(() => _isSubmitting = true);
                        try {
                          await AdminMenuService.createProduct(
                            name: name,
                            price: price,
                            categoryId: selectedCategoryId!,
                          );
                          if (!mounted || !ctx.mounted) return;
                          Navigator.of(ctx).pop();
                          await _refreshCategories();
                          await _refreshProducts();
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Ürün eklendi.")),
                          );
                        } catch (e) {
                          if (!mounted) return;
                          _showError("Ürün eklenemedi: $e");
                        } finally {
                          if (mounted) setState(() => _isSubmitting = false);
                        }
                      },
                child: const Text("Kaydet"),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openCreateCategoryDialog() async {
    _categoryNameController.clear();
    String selectedImagePath = "";
    int? selectedParentCategoryId;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          title: const Text("Yeni Kategori Ekle"),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _categoryNameController,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: "Kategori Adı"),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int?>(
                  initialValue: selectedParentCategoryId,
                  decoration: const InputDecoration(labelText: "Üst Kategori (Opsiyonel)"),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text("Yok (Ana Kategori)"),
                    ),
                    ..._categories.where((c) => c.parentCategoryId == null).map(
                      (c) => DropdownMenuItem<int?>(
                        value: c.id,
                        child: Text(c.name, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                  ],
                  onChanged: _isSubmitting ? null : (val) {
                    setModalState(() => selectedParentCategoryId = val);
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isSubmitting
                            ? null
                            : () async {
                                final picked = await _pickCategoryImagePath();
                                if (picked == null) return;
                                setModalState(() => selectedImagePath = picked);
                              },
                        icon: const Icon(Icons.upload_file_rounded),
                        label: const Text("Cihazdan Görsel Seç"),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: "Temizle",
                      onPressed: _isSubmitting
                          ? null
                          : () => setModalState(() => selectedImagePath = ""),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  selectedImagePath.isEmpty
                      ? "Görsel seçilmedi"
                      : selectedImagePath,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: double.infinity,
                    height: 132,
                    color: const Color(0xFFF8FAFC),
                    child: Center(child: _buildImagePreview(selectedImagePath)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: _isSubmitting ? null : () => Navigator.of(ctx).pop(),
              child: const Text("İptal"),
            ),
            FilledButton(
              onPressed: _isSubmitting
                  ? null
                  : () async {
                      final name = _categoryNameController.text.trim();
                      if (name.isEmpty) {
                        _showError("Kategori adı zorunludur.");
                        return;
                      }

                      setState(() => _isSubmitting = true);
                      try {
                        await AdminMenuService.createCategory(
                          name: name,
                          imagePath: selectedImagePath,
                          parentCategoryId: selectedParentCategoryId,
                        );
                        if (!mounted || !ctx.mounted) return;
                        Navigator.of(ctx).pop();
                        await _refreshCategories();
                        await _refreshProducts();
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Kategori eklendi.")),
                        );
                      } catch (e) {
                        if (!mounted) return;
                        _showError(
                          _humanizeError(e, fallback: "Kategori eklenemedi."),
                        );
                      } finally {
                        if (mounted) setState(() => _isSubmitting = false);
                      }
                    },
              child: const Text("Kaydet"),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openEditDialog(AdminMenuProduct product) async {
    _nameController.text = product.name;
    _priceController.text = product.price.toStringAsFixed(2);
    int? selectedCategoryId = product.categoryId;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) => AlertDialog(
            title: const Text("Ürün Düzenle"),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: "Ürün Adı"),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _priceController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: "Fiyat"),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: selectedCategoryId,
                    dropdownColor: Colors.white,
                    style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
                    decoration: const InputDecoration(labelText: "Kategori"),
                    items: _buildCategoryDropdownItems(),
                    onChanged: (value) =>
                        setModalState(() => selectedCategoryId = value),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: _isSubmitting ? null : () => Navigator.of(ctx).pop(),
                child: const Text("İptal"),
              ),
              FilledButton(
                onPressed: _isSubmitting
                    ? null
                    : () async {
                        final name = _nameController.text.trim();
                        final price = double.tryParse(
                          _priceController.text.trim().replaceAll(",", "."),
                        );
                        if (name.isEmpty ||
                            price == null ||
                            selectedCategoryId == null) {
                          _showError("Ad, fiyat ve kategori zorunludur.");
                          return;
                        }

                        setState(() => _isSubmitting = true);
                        try {
                          await AdminMenuService.updateProduct(
                            productId: product.id,
                            name: name,
                            price: price,
                            categoryId: selectedCategoryId!,
                          );
                          if (!mounted || !ctx.mounted) return;
                          Navigator.of(ctx).pop();
                          await _refreshCategories();
                          await _refreshProducts();
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Ürün güncellendi.")),
                          );
                        } catch (e) {
                          if (!mounted) return;
                          _showError("Ürün güncellenemedi: $e");
                        } finally {
                          if (mounted) setState(() => _isSubmitting = false);
                        }
                      },
                child: const Text("Kaydet"),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openManageCategoriesDialog() async {
    List<AdminMenuCategory> dialogCategories = List.of(_categories);

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          title: const Text("Kategorileri Yönet"),
          content: SizedBox(
            width: 560,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.icon(
                    onPressed: _isSubmitting
                        ? null
                        : () async {
                            await _openCreateCategoryDialog();
                            if (!mounted || !ctx.mounted) return;
                            dialogCategories = List.of(_categories);
                            setModalState(() {});
                          },
                    icon: const Icon(Icons.add_rounded),
                    label: const Text("Yeni Kategori"),
                  ),
                ),
                const SizedBox(height: 16),
                if (dialogCategories.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Text("Kategori bulunamadı."),
                  )
                else
                  SizedBox(
                    height: 420,
                    child: ListView.separated(
                      itemCount: dialogCategories.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final category = dialogCategories[index];
                        AdminMenuCategory? parentCategory;
                        for (final candidate in dialogCategories) {
                          if (candidate.id == category.parentCategoryId) {
                            parentCategory = candidate;
                            break;
                          }
                        }
                        final isSubcategory = category.parentCategoryId != null;
                        final hasActiveProducts =
                            category.activeProductCount > 0;
                        final childCategoryCount = dialogCategories
                            .where((item) => item.parentCategoryId == category.id)
                            .length;
                        final categorySummary = isSubcategory
                            ? "Alt kategori${parentCategory == null ? "" : " · ${parentCategory.name}"} · ${category.activeProductCount} aktif ürün"
                            : "${category.activeProductCount} aktif ürün (alt kategoriler dahil) · $childCategoryCount alt kategori";
                        return ListTile(
                          contentPadding: EdgeInsets.only(
                            left: isSubcategory ? 24 : 4,
                            right: 4,
                          ),
                          leading: isSubcategory
                              ? const Icon(
                                  Icons.subdirectory_arrow_right_rounded,
                                  color: Color(0xFF64748B),
                                )
                              : category.imagePath.trim().isEmpty
                              ? CircleAvatar(
                                  backgroundColor: const Color(0xFFE2E8F0),
                                  foregroundColor: const Color(0xFF334155),
                                  child: Text(
                                    category.name.isEmpty
                                        ? "?"
                                        : category.name.characters.first
                                              .toUpperCase(),
                                  ),
                                )
                              : ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: SizedBox(
                                    width: 52,
                                    height: 52,
                                    child: _buildImagePreview(
                                      category.imagePath,
                                    ),
                                  ),
                                ),
                          title: Text(
                            category.name,
                            style: TextStyle(
                              fontWeight: isSubcategory
                                  ? FontWeight.w500
                                  : FontWeight.w700,
                            ),
                          ),
                          subtitle: Text(
                            hasActiveProducts
                                ? categorySummary
                                : isSubcategory
                                ? "Alt kategori · aktif ürün yok"
                                : "Aktif ürün yok · $childCategoryCount alt kategori",
                          ),
                          trailing: IconButton(
                            tooltip: isSubcategory
                                ? "Alt kategoriyi sil"
                                : "Kategoriyi sil",
                            color: const Color(0xFFDC2626),
                            onPressed: _isSubmitting
                                ? null
                                : () async {
                                    final deleted = await _deleteCategory(
                                      category,
                                    );
                                    if (!deleted || !mounted || !ctx.mounted) {
                                      return;
                                    }
                                    dialogCategories = List.of(_categories);
                                    setModalState(() {});
                                  },
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: _isSubmitting ? null : () => Navigator.of(ctx).pop(),
              child: const Text("Kapat"),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteProduct(AdminMenuProduct product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Ürün Sil"),
        content: Text(
          "${product.name} ürününü silmek istediğinize emin misiniz?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text("Vazgeç"),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text("Sil"),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final message = await AdminMenuService.deleteProduct(product.id);
      await _refreshCategories();
      await _refreshProducts();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message ?? "Ürün silindi.")));
    } catch (e) {
      if (!mounted) return;
      _showError(_humanizeError(e, fallback: "Ürün silinemedi."));
    }
  }

  Future<bool> _deleteCategory(AdminMenuCategory category) async {
    final pinApproved = await _verifyAdminPin(
      title: "Yönetici Onayı",
      message: "Kategori silmek için yönetici PIN girin.",
    );
    if (!mounted) return false;
    if (!pinApproved) return false;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Kategori Sil"),
        content: Text(
          "${category.name} kategorisi pasife alınacak. "
          "${_categories.any((c) => c.parentCategoryId == category.id) ? "Alt kategorileri de pasife alınacak. " : ""}"
          "${category.activeProductCount > 0 ? "Bu kategoride ${category.activeProductCount} aktif ürün var; ürünler de pasife alınacak. " : ""}"
          "Devam edilsin mi?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text("Vazgeç"),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text("Sil"),
          ),
        ],
      ),
    );

    if (confirmed != true) return false;

    setState(() => _isSubmitting = true);
    try {
      final message = await AdminMenuService.deleteCategory(category.id);
      await _refreshCategories();
      await _refreshProducts();
      if (!mounted) return false;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message ?? "Kategori silindi.")));
      return true;
    } catch (e) {
      if (!mounted) return false;
      _showError(_humanizeError(e, fallback: "Kategori silinemedi."));
      return false;
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<bool> _verifyAdminPin({
    required String title,
    required String message,
  }) async {
    final pinController = TextEditingController();
    final approved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            const SizedBox(height: 12),
            TextField(
              controller: pinController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
              obscureText: true,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: "Yönetici PIN",
                hintText: "6 haneli PIN",
              ),
              onSubmitted: (_) {
                if (pinController.text.trim().length == 6) {
                  Navigator.of(ctx).pop(true);
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text("İptal"),
          ),
          FilledButton(
            onPressed: () {
              if (pinController.text.trim().length != 6) {
                _showError("Yönetici PIN 6 haneli olmalı.");
                return;
              }
              Navigator.of(ctx).pop(true);
            },
            child: const Text("Doğrula"),
          ),
        ],
      ),
    );

    if (approved != true) return false;

    final pin = pinController.text.trim();
    if (pin.length != 6) {
      _showError("Yönetici PIN 6 haneli olmalı.");
      return false;
    }

    final isValid = await AdminAuthService.verifyAdminPin(pin);
    if (!mounted) return false;
    if (!isValid) {
      _showError("Yönetici PIN hatalı.");
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final compactActions = MediaQuery.of(context).size.width < 980;
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(title: const Text("Ürün Yönetimi"), backgroundColor: Colors.white, foregroundColor: const Color(0xFF0F172A), elevation: 0),
      body: _isLoading ? const Center(child: CircularProgressIndicator()) : Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF0F766E), Color(0xFF115E59)], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(20)),
            child: Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, runSpacing: 12, spacing: 16, children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text("Menünüzü kolayca yönetin", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 5),
                Text("${_products.length} ürün · ${_categories.length} kategori", style: const TextStyle(color: Color(0xFFD1FAE5), fontWeight: FontWeight.w600)),
              ]),
              FilledButton.icon(style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: const Color(0xFF0F766E)), onPressed: _openCreateDialog, icon: const Icon(Icons.add_rounded), label: const Text("Yeni ürün ekle")),
            ]),
          ),
          const SizedBox(height: 16),
          _buildFilterToolbar(compactActions),
          const SizedBox(height: 12),
          Expanded(child: _products.isEmpty
            ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.inventory_2_outlined, size: 48, color: Color(0xFF94A3B8)),
                const SizedBox(height: 10),
                const Text("Ürün bulunamadı", style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                const Text("Arama veya kategori filtresini değiştirebilirsiniz.", style: TextStyle(color: Color(0xFF64748B))),
              ]))
            : LayoutBuilder(builder: (context, constraints) {
                final columns = (constraints.maxWidth / 300).floor().clamp(1, 4);
                return GridView.builder(
                  padding: const EdgeInsets.only(bottom: 12),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: columns, crossAxisSpacing: 12, mainAxisSpacing: 12, mainAxisExtent: 156),
                  itemCount: _products.length,
                  itemBuilder: (context, index) => _buildProductCard(_products[index]),
                );
              }),
          ),
        ]),
      ),
    );
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _nameController.dispose();
    _priceController.dispose();
    _categoryNameController.dispose();
    super.dispose();
  }

  Widget _buildFilterToolbar(bool compact) {
    final categoryDropdown = DropdownButtonFormField<int?>(
      initialValue: _selectedCategoryFilter,
      dropdownColor: Colors.white,
      style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
      decoration: const InputDecoration(labelText: "Kategori", prefixIcon: Icon(Icons.category_outlined)),
      hint: const Text("Tüm kategoriler", style: TextStyle(color: Color(0xFF64748B))),
      items: [
        const DropdownMenuItem<int?>(value: null, child: Text("Tüm kategoriler")),
        ..._categories.map((c) => DropdownMenuItem<int?>(
          value: c.id,
          child: Text(c.parentCategoryId == null ? c.name : "  ↳ ${c.name}", overflow: TextOverflow.ellipsis),
        )),
      ],
      onChanged: (value) { setState(() => _selectedCategoryFilter = value); _refreshProducts(); },
    );
    final manageCategoriesButton = OutlinedButton.icon(onPressed: _openManageCategoriesDialog, icon: const Icon(Icons.category_rounded), label: const Text("Kategorileri yönet"));
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: LayoutBuilder(builder: (context, constraints) {
        final search = TextField(
          controller: _searchController,
          decoration: InputDecoration(hintText: "Ürün adıyla ara...", prefixIcon: const Icon(Icons.search_rounded), suffixIcon: _searchController.text.isEmpty ? null : IconButton(tooltip: "Aramayı temizle", onPressed: () { _searchController.clear(); _refreshProducts(); }, icon: const Icon(Icons.close_rounded))),
          onChanged: _onSearchChanged,
        );
        if (constraints.maxWidth < 760) return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [search, const SizedBox(height: 10), categoryDropdown, const SizedBox(height: 10), manageCategoriesButton]);
        return Row(children: [Expanded(child: search), const SizedBox(width: 12), SizedBox(width: compact ? 190 : 220, child: categoryDropdown), const SizedBox(width: 10), manageCategoriesButton]);
      }),
    );
  }

  Widget _buildProductCard(AdminMenuProduct product) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFE2E8F0)), boxShadow: const [BoxShadow(color: Color(0x080F172A), blurRadius: 12, offset: Offset(0, 4))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 38, height: 38, decoration: BoxDecoration(color: const Color(0xFFCCFBF1), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.restaurant_menu_rounded, color: Color(0xFF0F766E), size: 20)),
          const SizedBox(width: 10),
          Expanded(child: Text(product.categoryName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w700))),
          PopupMenuButton<String>(tooltip: "Ürün işlemleri", onSelected: (value) => value == "edit" ? _openEditDialog(product) : _deleteProduct(product), itemBuilder: (_) => const [PopupMenuItem(value: "edit", child: Text("Düzenle")), PopupMenuItem(value: "delete", child: Text("Sil"))]),
        ]),
        const SizedBox(height: 12),
        Text(product.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
        const Spacer(),
        Row(children: [Expanded(child: Text("${product.price.toStringAsFixed(2)} TL", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF0F766E)))), TextButton.icon(onPressed: () => _openEditDialog(product), icon: const Icon(Icons.edit_outlined, size: 17), label: const Text("Düzenle"))]),
      ]),
    );
  }

}
