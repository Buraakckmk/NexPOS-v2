import "package:flutter_test/flutter_test.dart";
import "package:nexpos/services/admin_menu_service.dart";

void main() {
  group("AdminMenuCategory", () {
    test("parses subcategory parent and active product count", () {
      final category = AdminMenuCategory.fromJson({
        "id": 12,
        "name": "Sıcak Kahveler",
        "image_path": "",
        "parent_category_id": 10,
        "active_product_count": 4,
      });

      expect(category.id, 12);
      expect(category.parentCategoryId, 10);
      expect(category.activeProductCount, 4);
    });

    test("keeps root categories parentless", () {
      final category = AdminMenuCategory.fromJson({
        "id": 10,
        "name": "Kahveler",
        "active_product_count": "7",
      });

      expect(category.parentCategoryId, isNull);
      expect(category.activeProductCount, 7);
    });
  });

  test("AdminMenuProduct parses products returned for subcategory filters", () {
    final product = AdminMenuProduct.fromJson({
      "id": 5,
      "name": "Latte",
      "price": "125.50",
      "category_id": 12,
      "category_name": "Sıcak Kahveler",
    });

    expect(product.categoryId, 12);
    expect(product.categoryName, "Sıcak Kahveler");
    expect(product.price, 125.5);
  });
}
