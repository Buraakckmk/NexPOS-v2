const db = require("../config/db");

async function listActiveProductsForWaiter() {
  const query = `
    WITH product_sales AS (
      SELECT
        oi.product_id,
        COALESCE(SUM(oi.quantity), 0)::numeric AS total_qty
      FROM order_items oi
      JOIN orders o ON o.id = oi.order_id
      WHERE o.order_status = 'PAID'
        AND oi.item_status <> 'VOID'
      GROUP BY oi.product_id
    )
    SELECT
      p.id,
      p.name,
      p.price,
      p.vat_rate,
      c.id AS category_id,
      COALESCE(NULLIF(p.category, ''), c.name) AS category_name,
      c.image_path AS category_image_path,
      c.parent_category_id,
      pc.name AS parent_category_name,
      COALESCE(ps.total_qty, 0) AS sales_qty
    FROM products p
    JOIN categories c ON c.id = p.category_id
    LEFT JOIN categories pc ON pc.id = c.parent_category_id
    LEFT JOIN product_sales ps ON ps.product_id = p.id
    WHERE p.is_active = TRUE
      AND c.is_active = TRUE
    ORDER BY c.sort_order ASC, sales_qty DESC, p.name ASC;
  `;

  const { rows } = await db.query(query);
  return rows;
}

async function listCategoriesForAdmin() {
  const { rows } = await db.query(
    `
      SELECT
        c.id,
        c.name,
        c.printer_route,
        c.sort_order,
        c.is_active,
        c.image_path,
        c.parent_category_id,
        (
          SELECT COUNT(*)::int
          FROM products p
          JOIN categories product_category ON product_category.id = p.category_id
          WHERE p.is_active = TRUE
            AND product_category.is_active = TRUE
            AND (
              product_category.id = c.id
              OR product_category.parent_category_id = c.id
            )
        ) AS active_product_count
      FROM categories c
      WHERE is_active = TRUE
      ORDER BY sort_order ASC NULLS LAST, name ASC;
    `
  );
  return rows;
}

async function listProductsForAdmin({ search = "", categoryId = null }) {
  const normalizedSearch = String(search || "").trim();
  const { rows } = await db.query(
    `
      SELECT
        p.id,
        p.name,
        p.price,
        p.is_active,
        p.category_id,
        COALESCE(NULLIF(p.category, ''), c.name) AS category_name,
        p.updated_at
      FROM products p
      LEFT JOIN categories c ON c.id = p.category_id
      WHERE
        p.is_active = TRUE
        AND c.is_active = TRUE
        AND
        ($1 = '' OR p.name ILIKE '%' || $1 || '%')
        AND (
          $2::bigint IS NULL
          OR p.category_id = $2
          OR EXISTS (
            SELECT 1
            FROM categories child
            WHERE child.id = p.category_id
              AND child.parent_category_id = $2
          )
        )
      ORDER BY c.sort_order ASC NULLS LAST, p.name ASC;
    `,
    [normalizedSearch, categoryId]
  );
  return rows.sort((a, b) => a.name.localeCompare(b.name, "tr"));
}

async function createCategory({
  name,
  printerRoute = "MUTFAK",
  imagePath = null,
  sortOrder = null,
  parentCategoryId = null,
}) {
  const normalizedName = String(name || "").trim();
  const normalizedRoute = String(printerRoute || "MUTFAK").trim().toUpperCase();
  const normalizedImagePath = String(imagePath || "").trim() || null;
  const normalizedSortOrder = Number.isInteger(sortOrder) && sortOrder >= 0
    ? sortOrder
    : null;

  if (parentCategoryId != null) {
    const { rows: parentRows } = await db.query(
      `SELECT id FROM categories WHERE id = $1 AND is_active = TRUE AND parent_category_id IS NULL LIMIT 1;`,
      [parentCategoryId]
    );
    if (!parentRows.length) {
      const error = new Error("Ust kategori bulunamadi veya zaten alt kategori.");
      error.code = "INVALID_PARENT_CATEGORY";
      throw error;
    }
    const { rows: sameCategory } = await db.query(
      `SELECT id FROM categories WHERE UPPER(name) = UPPER($1) AND id = $2 LIMIT 1;`,
      [normalizedName, parentCategoryId]
    );
    if (sameCategory.length) {
      const error = new Error("Kategori kendisinin alt kategorisi olamaz.");
      error.code = "INVALID_PARENT_CATEGORY";
      throw error;
    }
  }

  const { rows: existingRows } = await db.query(
    `
      SELECT id
      FROM categories
      WHERE UPPER(name) = UPPER($1)
      LIMIT 1;
    `,
    [normalizedName]
  );

  if (existingRows.length) {
    const { rows } = await db.query(
      `
        UPDATE categories
        SET
          name = $2,
          printer_route = $3,
          image_path = $4,
          is_active = TRUE,
          sort_order = COALESCE($5, sort_order),
          parent_category_id = $6,
          updated_at = NOW()
        WHERE id = $1
        RETURNING id, name, printer_route, sort_order, is_active, image_path, parent_category_id;
      `,
      [existingRows[0].id, normalizedName, normalizedRoute, normalizedImagePath, normalizedSortOrder, parentCategoryId]
    );
    return rows[0] || null;
  }

  const { rows } = await db.query(
    `
      WITH next_sort AS (
        SELECT COALESCE(MAX(sort_order), 0) + 1 AS value
        FROM categories
      )
      INSERT INTO categories (name, printer_route, image_path, is_active, sort_order, parent_category_id)
      VALUES ($1, $2, $3, TRUE, COALESCE($4, (SELECT value FROM next_sort)), $5)
      RETURNING id, name, printer_route, sort_order, is_active, image_path, parent_category_id;
    `,
    [normalizedName, normalizedRoute, normalizedImagePath, normalizedSortOrder, parentCategoryId]
  );

  return rows[0] || null;
}

async function deactivateProduct({ productId }) {
  const { rows } = await db.query(
    `
      UPDATE products
      SET is_active = FALSE,
          updated_at = NOW()
      WHERE id = $1
      RETURNING id;
    `,
    [productId]
  );
  return rows[0] || null;
}

async function deactivateCategory({ categoryId }) {
  const { rows } = await db.query(
    `
      UPDATE categories
      SET is_active = FALSE,
          updated_at = NOW()
      WHERE id = $1
      RETURNING id;
    `,
    [categoryId]
  );
  return rows[0] || null;
}

async function createProduct({ name, price, categoryId }) {
  const { rows } = await db.query(
    `
      INSERT INTO products (name, price, category_id, category, is_active)
      SELECT $1, $2, c.id, c.name, TRUE
      FROM categories c
      WHERE c.id = $3
      RETURNING
        id,
        name,
        price,
        is_active,
        category_id,
        category AS category_name,
        updated_at;
    `,
    [name, price, categoryId]
  );
  return rows[0] || null;
}

async function updateProduct({ productId, name, price, categoryId }) {
  const { rows } = await db.query(
    `
      UPDATE products p
      SET
        name = $1,
        price = $2,
        category_id = c.id,
        category = c.name,
        updated_at = NOW()
      FROM categories c
      WHERE p.id = $4
        AND c.id = $3
      RETURNING
        p.id,
        p.name,
        p.price,
        p.is_active,
        p.category_id,
        p.category AS category_name,
        p.updated_at;
    `,
    [name, price, categoryId, productId]
  );
  return rows[0] || null;
}

async function deleteProduct({ productId }) {
  try {
    const { rows } = await db.query(
      `
        DELETE FROM products
        WHERE id = $1
        RETURNING id;
      `,
      [productId]
    );

    if (rows[0]) {
      return {
        id: rows[0].id,
        softDeleted: false,
      };
    }
    return null;
  } catch (error) {
    // 23503: foreign_key_violation, 23001: restrict_violation
    const constraintCodes = new Set(["23503", "23001"]);
    if (!constraintCodes.has(String(error?.code || ""))) {
      throw error;
    }

    // Ürün daha önce satılmışsa (order_items içinde varsa) silemeyiz, pasife çekeriz
    const { rows } = await db.query(
      `
        UPDATE products
        SET is_active = FALSE,
            updated_at = NOW()
        WHERE id = $1
        RETURNING id;
      `,
      [productId]
    );

    if (rows[0]) {
      return {
        id: rows[0].id,
        softDeleted: true,
      };
    }
    return null;
  }
}

async function deleteCategory({ categoryId }) {
  // Keep category rows as historical references for existing orders. Deactivate
  // the category, its direct subcategories, and products in those categories.
  const { rows } = await db.query(
    `
      WITH target_category AS (
        SELECT id
        FROM categories
        WHERE id = $1 AND is_active = TRUE
      ), affected_categories AS (
        SELECT id FROM target_category
        UNION
        SELECT c.id
        FROM categories c
        JOIN target_category parent ON c.parent_category_id = parent.id
      ), deactivated_products AS (
        UPDATE products
        SET is_active = FALSE, updated_at = NOW()
        WHERE category_id IN (SELECT id FROM affected_categories)
          AND is_active = TRUE
        RETURNING id
      ), deactivated_categories AS (
        UPDATE categories
        SET is_active = FALSE, updated_at = NOW()
        WHERE id IN (SELECT id FROM affected_categories)
          AND is_active = TRUE
        RETURNING id
      )
      SELECT
        (SELECT id FROM target_category LIMIT 1) AS id,
        (SELECT COUNT(*)::int FROM deactivated_products) AS deactivated_product_count,
        (SELECT COUNT(*)::int FROM deactivated_categories) AS deactivated_category_count;
    `,
    [categoryId]
  );
  const result = rows[0];
  if (!result?.id) return null;
  return {
    id: result.id,
    softDeleted: true,
    deactivatedProductCount: result.deactivated_product_count ?? 0,
  };
}

module.exports = {
  listActiveProductsForWaiter,
  listCategoriesForAdmin,
  listProductsForAdmin,
  createCategory,
  createProduct,
  updateProduct,
  deleteProduct,
  deactivateProduct,
  deleteCategory,
  deactivateCategory,
};
