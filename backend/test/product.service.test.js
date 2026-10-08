const assert = require("node:assert/strict");
const { afterEach, test } = require("node:test");

const db = require("../src/config/db");
const productService = require("../src/services/product.service");

const originalQuery = db.query;
afterEach(() => {
  db.query = originalQuery;
});

test("admin category list exposes parent ids and counts active child products", async () => {
  let queryText = "";
  db.query = async (text) => {
    queryText = text;
    return {
      rows: [{ id: 10, name: "Kahveler", parent_category_id: null, active_product_count: 4 }],
    };
  };

  const categories = await productService.listCategoriesForAdmin();

  assert.equal(categories[0].parent_category_id, null);
  assert.equal(categories[0].active_product_count, 4);
  assert.match(queryText, /product_category\.parent_category_id\s*=\s*c\.id/);
  assert.match(queryText, /product_category\.is_active\s*=\s*TRUE/);
});

test("admin product filtering by a parent category includes its subcategories", async () => {
  let queryText = "";
  let queryParams;
  db.query = async (text, params) => {
    queryText = text;
    queryParams = params;
    return { rows: [{ id: 5, category_id: 12, name: "Latte" }] };
  };

  const products = await productService.listProductsForAdmin({
    search: "lat",
    categoryId: 10,
  });

  assert.equal(products.length, 1);
  assert.deepEqual(queryParams, ["lat", 10]);
  assert.match(queryText, /child\.parent_category_id\s*=\s*\$2/);
});

test("deleting a category deactivates its children and their active products", async () => {
  let queryText = "";
  let queryParams;
  db.query = async (text, params) => {
    queryText = text;
    queryParams = params;
    return {
      rows: [{ id: 12, deactivated_product_count: 3, deactivated_category_count: 1 }],
    };
  };

  const result = await productService.deleteCategory({ categoryId: 12 });

  assert.deepEqual(queryParams, [12]);
  assert.equal(result.id, 12);
  assert.equal(result.softDeleted, true);
  assert.equal(result.deactivatedProductCount, 3);
  assert.match(queryText, /c\.parent_category_id\s*=\s*parent\.id/);
  assert.match(queryText, /UPDATE products[\s\S]*?is_active\s*=\s*FALSE/);
  assert.match(queryText, /UPDATE categories[\s\S]*?is_active\s*=\s*FALSE/);
});

test("deleting a category returns null when it is missing or inactive", async () => {
  db.query = async () => ({ rows: [{ id: null, deactivated_product_count: 0 }] });

  assert.equal(await productService.deleteCategory({ categoryId: 404 }), null);
});

test("creating a subcategory rejects an inactive or non-root parent", async () => {
  let callCount = 0;
  db.query = async () => {
    callCount += 1;
    return { rows: [] };
  };

  await assert.rejects(
    productService.createCategory({ name: "Alt Kahve", parentCategoryId: 20 }),
    (error) => error.code === "INVALID_PARENT_CATEGORY",
  );
  assert.equal(callCount, 1);
});
