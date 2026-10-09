const assert = require("node:assert/strict");
const { afterEach, test } = require("node:test");

const db = require("../src/config/db");
const productService = require("../src/services/product.service");

const originalQuery = db.query;
const originalConnect = db.pool.connect;
afterEach(() => {
  db.query = originalQuery;
  db.pool.connect = originalConnect;
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
  assert.match(queryText, /child\.parent_category_id\s*=\s*tree\.descendant_id/);
  assert.match(queryText, /child\.is_active\s*=\s*TRUE/);
  assert.match(queryText, /GROUP BY c\.id, parent\.id, parent\.sort_order/);
  assert.match(queryText, /COALESCE\(parent\.sort_order, c\.sort_order\)/);
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
  assert.match(queryText, /JOIN selected_category_tree parent ON child\.parent_category_id\s*=\s*parent\.id/);
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

test("moving a category updates its parent inside a transaction", async () => {
  const calls = [];
  const client = {
    async query(queryText, params) {
      calls.push({ queryText, params });
      if (queryText.includes("SELECT id, parent_category_id")) {
        return { rows: [{ id: 12, parent_category_id: 10 }] };
      }
      if (queryText.includes("SELECT id FROM categories WHERE id = $1 AND is_active = TRUE AND parent_category_id IS NULL")) {
        return { rows: [{ id: 20 }] };
      }
      if (queryText.includes("SELECT id FROM categories WHERE parent_category_id = $1")) {
        return { rows: [] };
      }
      if (queryText.includes("UPDATE categories")) {
        return { rows: [{ id: 12, name: "Espresso", parent_category_id: 20 }] };
      }
      return { rows: [] };
    },
    release() {},
  };
  db.pool.connect = async () => client;

  const moved = await productService.moveCategory({
    categoryId: 12,
    parentCategoryId: 20,
  });

  assert.equal(moved.parent_category_id, 20);
  assert.equal(calls[0].queryText, "BEGIN");
  assert.equal(calls.at(-1).queryText, "COMMIT");
});

test("moving a category with children under another category is rejected", async () => {
  const calls = [];
  const client = {
    async query(queryText) {
      calls.push(queryText);
      if (queryText.includes("SELECT id, parent_category_id")) {
        return { rows: [{ id: 12, parent_category_id: null }] };
      }
      if (queryText.includes("SELECT id FROM categories WHERE id = $1 AND is_active = TRUE AND parent_category_id IS NULL")) {
        return { rows: [{ id: 20 }] };
      }
      if (queryText.includes("SELECT id FROM categories WHERE parent_category_id = $1")) {
        return { rows: [{ id: 13 }] };
      }
      return { rows: [] };
    },
    release() {},
  };
  db.pool.connect = async () => client;

  await assert.rejects(
    productService.moveCategory({ categoryId: 12, parentCategoryId: 20 }),
    (error) => error.code === "CATEGORY_HAS_SUBCATEGORIES",
  );
  assert.equal(calls.at(-1), "ROLLBACK");
});
