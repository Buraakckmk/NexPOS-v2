import "package:flutter/material.dart";
import "package:dio/dio.dart";
import "package:file_picker/file_picker.dart";

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
                    items: _categories
                        .map(
                          (c) => DropdownMenuItem<int>(
                            value: c.id,
                            child: Text(c.name, style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w700)),
                          ),
                        )
                        .toList(),
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
                    items: _categories
                        .map(
                          (c) => DropdownMenuItem<int>(
                            value: c.id,
                            child: Text(c.name, style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w700)),
                          ),
                        )
                        .toList(),
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
                        final hasActiveProducts =
                            category.activeProductCount > 0;
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 6,
                          ),
                          leading: category.imagePath.trim().isEmpty
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
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            hasActiveProducts
                                ? "${category.activeProductCount} aktif ürün var"
                                : "Aktif ürün yok",
                          ),
                          trailing: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFFDC2626),
                            ),
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
                              size: 18,
                            ),
                            label: const Text("Sil"),
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
          category.activeProductCount > 0
              ? "${category.name} kategorisinde ${category.activeProductCount} aktif ürün var. Silersen kategori ve bu ürünler pasife alınacak. Devam edilsin mi?"
              : "${category.name} kategorisini silmek istediğinize emin misiniz?",
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
              obscureText: true,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: "Yönetici PIN",
                hintText: "PIN girin",
              ),
              onSubmitted: (_) => Navigator.of(ctx).pop(true),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text("İptal"),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text("Doğrula"),
          ),
        ],
      ),
    );

    if (approved != true) return false;

    final pin = pinController.text.trim();
    if (pin.isEmpty) {
      _showError("PIN boş bırakılamaz.");
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
    final screenWidth = MediaQuery.of(context).size.width;
    final compactActions = screenWidth < 980;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text("Ürün Yönetimi"),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildFilterToolbar(compactActions),
                  const SizedBox(height: 12),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: _products.isEmpty
                          ? const Center(child: Text("Ürün bulunamadı"))
                          : ListView.separated(
                              itemCount: _products.length,
                              separatorBuilder: (_, _) => const Divider(
                                height: 1,
                                color: Color(0xFFE2E8F0),
                              ),
                              itemBuilder: (context, index) {
                                final p = _products[index];
                                return _buildProductRow(p, compactActions);
                              },
                            ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  @override
  void dispose() {
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
      decoration: const InputDecoration(labelText: "Kategori (opsiyonel)"),
      hint: const Text("Kategori seç", style: TextStyle(color: Color(0xFF64748B))),
      items: _categories
          .map(
            (c) => DropdownMenuItem<int?>(
              value: c.id,
              child: Text(c.name, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w700)),
            ),
          )
          .toList(),
      onChanged: (value) {
        setState(() => _selectedCategoryFilter = value);
        _refreshProducts();
      },
    );

    final createButton = FilledButton.icon(
      onPressed: _openCreateDialog,
      icon: const Icon(Icons.add_rounded),
      label: const Text("Yeni Ürün Ekle"),
    );

    final manageCategoriesButton = OutlinedButton.icon(
      onPressed: _openManageCategoriesDialog,
      icon: const Icon(Icons.category_rounded),
      label: const Text("Kategoriler"),
    );

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 860) {
            return Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: "Ürün ara",
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: IconButton(
                      onPressed: _refreshProducts,
                      icon: const Icon(Icons.tune_rounded),
                    ),
                  ),
                  onSubmitted: (_) => _refreshProducts(),
                  onChanged: (v) {
                    if (v.trim().isEmpty) _refreshProducts();
                  },
                ),
                const SizedBox(height: 12),
                categoryDropdown,
                const SizedBox(height: 12),
                SizedBox(width: double.infinity, child: manageCategoriesButton),
                const SizedBox(height: 8),
                SizedBox(width: double.infinity, child: createButton),
              ],
            );
          }

          return Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: "Ürün ara",
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: IconButton(
                      onPressed: _refreshProducts,
                      icon: const Icon(Icons.tune_rounded),
                    ),
                  ),
                  onSubmitted: (_) => _refreshProducts(),
                  onChanged: (v) {
                    if (v.trim().isEmpty) _refreshProducts();
                  },
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(width: compact ? 200 : 230, child: categoryDropdown),
              const SizedBox(width: 12),
              manageCategoriesButton,
              const SizedBox(width: 12),
              createButton,
            ],
          );
        },
      ),
    );
  }

  Widget _buildProductRow(AdminMenuProduct p, bool compact) {
    if (!compact) {
      return ListTile(
        title: Text(
          p.name,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(p.categoryName),
        trailing: Wrap(
          spacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              "${p.price.toStringAsFixed(2)} TL",
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F766E),
              ),
            ),
            OutlinedButton.icon(
              onPressed: () => _openEditDialog(p),
              icon: const Icon(Icons.edit_rounded, size: 16),
              label: const Text("Düzenle"),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
              ),
              onPressed: () => _deleteProduct(p),
              icon: const Icon(Icons.delete_rounded, size: 16),
              label: const Text("Sil"),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            p.name,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
          ),
          const SizedBox(height: 2),
          Text(
            p.categoryName,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                "${p.price.toStringAsFixed(2)} TL",
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F766E),
                ),
              ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: () => _openEditDialog(p),
                icon: const Icon(Icons.edit_rounded, size: 16),
                label: const Text("Düzenle"),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626),
                ),
                onPressed: () => _deleteProduct(p),
                icon: const Icon(Icons.delete_rounded, size: 16),
                label: const Text("Sil"),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
