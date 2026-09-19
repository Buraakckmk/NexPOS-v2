import "api_client.dart";

int _safeInt(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse((value ?? "").toString()) ?? fallback;
}

double _safeDouble(dynamic value, {double fallback = 0}) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse((value ?? "").toString().replaceAll(",", ".")) ??
      fallback;
}

class AdminMenuCategory {
  final int id;
  final String name;
  final String imagePath;
  final int activeProductCount;

  const AdminMenuCategory({
    required this.id,
    required this.name,
    required this.imagePath,
    required this.activeProductCount,
  });

  factory AdminMenuCategory.fromJson(Map<String, dynamic> json) {
    return AdminMenuCategory(
      id: _safeInt(json["id"]),
      name: (json["name"] ?? "").toString(),
      imagePath: (json["image_path"] ?? "").toString(),
      activeProductCount: _safeInt(json["active_product_count"]),
    );
  }
}

class AdminMenuProduct {
  final int id;
  final String name;
  final double price;
  final int? categoryId;
  final String categoryName;

  const AdminMenuProduct({
    required this.id,
    required this.name,
    required this.price,
    required this.categoryId,
    required this.categoryName,
  });

  factory AdminMenuProduct.fromJson(Map<String, dynamic> json) {
    return AdminMenuProduct(
      id: _safeInt(json["id"]),
      name: (json["name"] ?? "").toString(),
      price: _safeDouble(json["price"]),
      categoryId: json["category_id"] == null
          ? null
          : _safeInt(json["category_id"]),
      categoryName: (json["category_name"] ?? "").toString(),
    );
  }
}

class AdminMenuService {
  static Future<List<AdminMenuCategory>> fetchCategories() async {
    final res = await ApiClient.dio.get("/admin/menu/categories");
    final data = res.data as Map<String, dynamic>;
    final categories = (data["categories"] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(AdminMenuCategory.fromJson)
        .toList();
    return categories;
  }

  static Future<void> createCategory({
    required String name,
    String? imagePath,
  }) async {
    await ApiClient.dio.post(
      "/admin/menu/categories",
      data: {
        "name": name,
        if (imagePath != null && imagePath.trim().isNotEmpty)
          "image_path": imagePath.trim(),
      },
    );
  }

  static Future<String?> deleteCategory(int categoryId) async {
    final res = await ApiClient.dio.delete(
      "/admin/menu/categories/$categoryId",
    );
    final data = res.data;
    if (data is Map<String, dynamic>) {
      return data["message"]?.toString();
    }
    return null;
  }

  static Future<List<AdminMenuProduct>> fetchProducts({
    String search = "",
    int? categoryId,
  }) async {
    final query = <String, dynamic>{"search": search};
    if (categoryId != null) query["categoryId"] = categoryId;

    final res = await ApiClient.dio.get(
      "/admin/menu/products",
      queryParameters: query,
    );
    final data = res.data as Map<String, dynamic>;
    final products = (data["products"] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(AdminMenuProduct.fromJson)
        .toList();
    return products;
  }

  static Future<void> createProduct({
    required String name,
    required double price,
    required int categoryId,
  }) async {
    await ApiClient.dio.post(
      "/admin/menu/products",
      data: {"name": name, "price": price, "category_id": categoryId},
    );
  }

  static Future<void> updateProduct({
    required int productId,
    required String name,
    required double price,
    required int categoryId,
  }) async {
    await ApiClient.dio.patch(
      "/admin/menu/products/$productId",
      data: {"name": name, "price": price, "category_id": categoryId},
    );
  }

  static Future<String?> deleteProduct(int productId) async {
    final res = await ApiClient.dio.delete("/admin/menu/products/$productId");
    final data = res.data;
    if (data is Map<String, dynamic>) {
      return data["message"]?.toString();
    }
    return null;
  }
}
