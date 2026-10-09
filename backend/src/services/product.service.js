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
      c.name AS category_name,
      c.image_path AS category_image_path,
      CASE WHEN pc.is_active THEN c.parent_category_id ELSE NULL END AS parent_category_id,
      CASE WHEN pc.is_active THEN pc.name ELSE NULL END AS parent_category_name,
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

async function listActiveCategoriesForWaiter() {
  const { rows } = await db.query(
    `
      SELECT
        c.id,
        c.name,
        c.sort_order,
        CASE WHEN pc.is_active THEN c.parent_category_id ELSE NULL END AS parent_category_id,
        CASE WHEN pc.is_active THEN pc.name ELSE NULL END AS parent_category_name
      FROM categories c
      LEFT JOIN categories pc ON pc.id = c.parent_category_id
      WHERE c.is_active = TRUE
      ORDER BY
        COALESCE(pc.sort_order, c.sort_order) ASC NULLS LAST,
        CASE WHEN pc.is_active THEN pc.sort_order ELSE c.sort_order END ASC NULLS LAST,
        c.name ASC
    `
  );
  return rows;
}

async function listCategoriesForAdmin() {
  const { rows } = await db.query(
    `
      WITH RECURSIVE category_tree AS (
        SELECT id AS ancestor_id, id AS descendant_id
        FROM categories
        WHERE is_active = TRUE
        UNION
        SELECT tree.ancestor_id, child.id
        FROM category_tree tree
        JOIN categories child ON child.parent_category_id = tree.descendant_id
        WHERE child.is_active = TRUE
      )
      SELECT
        c.id,
        c.name,
        c.printer_route,
        c.sort_order,
        c.is_active,
        c.image_path,
        c.parent_category_id,
        COUNT(DISTINCT p.id)::int AS active_product_count
      FROM categories c
      LEFT JOIN categories parent ON parent.id = c.parent_category_id
      LEFT JOIN category_tree tree ON tree.ancestor_id = c.id
      LEFT JOIN products p
        ON p.category_id = tree.descendant_id
       AND p.is_active = TRUE
      WHERE c.is_active = TRUE
      GROUP BY c.id, parent.id, parent.sort_order
      ORDER BY
        COALESCE(parent.sort_order, c.sort_order) ASC NULLS LAST,
        CASE WHEN parent.id IS NULL THEN 0 ELSE 1 END ASC,
        c.sort_order ASC NULLS LAST,
        c.name ASC;
    `
  );
  return rows;
}

async function listProductsForAdmin({ search = "", categoryId = null }) {
  const normalizedSearch = String(search || "").trim();
  const { rows } = await db.query(
    `
      WITH RECURSIVE selected_category_tree AS (
        SELECT id
        FROM categories
        WHERE id = $2::bigint
        UNION
        SELECT child.id
        FROM categories child
        JOIN selected_category_tree parent ON child.parent_category_id = parent.id
        WHERE child.is_active = TRUE
      )
      SELECT
        p.id,
        p.name,
        p.price,
        p.is_active,
        p.category_id,
        c.name AS category_name,
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
          OR p.category_id IN (SELECT id FROM selected_category_tree)
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
    const { rows: existingCategoryRows } = await db.query(
      `SELECT id, parent_category_id, is_active FROM categories WHERE id = $1 LIMIT 1;`,
      [existingRows[0].id]
    );
    const existing = existingCategoryRows[0];
    const existingParentId = existing?.parent_category_id == null
      ? null
      : Number(existing.parent_category_id);
    if (!existing || existingParentId !== parentCategoryId) {
      const error = new Error("Bu isimde kategori başka bir yerde zaten kullanılıyor.");
      error.code = "CATEGORY_NAME_EXISTS";
      throw error;
    }
    if (existing.is_active) {
      const error = new Error("Bu kategori zaten mevcut.");
      error.code = "CATEGORY_NAME_EXISTS";
      throw error;
    }

    const { rows } = await db.query(
      `
        UPDATE categories
        SET
          is_active = TRUE,
          updated_at = NOW()
        WHERE id = $1
        RETURNING id, name, printer_route, sort_order, is_active, image_path, parent_category_id;
      `,
      [existingRows[0].id]
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

async function moveCategory({ categoryId, parentCategoryId = null }) {
  const client = await db.pool.connect();
  try {
    await client.query("BEGIN");

    const { rows: categoryRows } = await client.query(
      `SELECT id, parent_category_id FROM categories WHERE id = $1 AND is_active = TRUE FOR UPDATE`,
      [categoryId]
    );
    if (!categoryRows.length) {
      const error = new Error("Kategori bulunamadı.");
      error.code = "CATEGORY_NOT_FOUND";
      throw error;
    }

    if (parentCategoryId != null) {
      if (Number(categoryRows[0].id) === Number(parentCategoryId)) {
        const error = new Error("Kategori kendisinin üst kategorisi olamaz.");
        error.code = "INVALID_CATEGORY_PARENT";
        throw error;
      }

      const { rows: parentRows } = await client.query(
        `SELECT id FROM categories WHERE id = $1 AND is_active = TRUE AND parent_category_id IS NULL FOR UPDATE`,
        [parentCategoryId]
      );
      if (!parentRows.length) {
        const error = new Error("Üst kategori bulunamadı veya kendisi alt kategori.");
        error.code = "INVALID_CATEGORY_PARENT";
        throw error;
      }

      const { rows: childRows } = await client.query(
        `SELECT id FROM categories WHERE parent_category_id = $1 AND is_active = TRUE LIMIT 1`,
        [categoryId]
      );
      if (childRows.length) {
        const error = new Error("Önce bu kategorinin alt kategorilerini taşıyın.");
        error.code = "CATEGORY_HAS_SUBCATEGORIES";
        throw error;
      }
    }

    const { rows } = await client.query(
      `
        UPDATE categories
        SET parent_category_id = $2, updated_at = NOW()
        WHERE id = $1 AND is_active = TRUE
        RETURNING id, name, parent_category_id;
      `,
      [categoryId, parentCategoryId]
    );

    await client.query("COMMIT");
    return rows[0] || null;
  } catch (error) {
    await client.query("ROLLBACK");
    throw error;
  } finally {
    client.release();
  }
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
      WITH RECURSIVE target_category AS (
        SELECT id
        FROM categories
        WHERE id = $1 AND is_active = TRUE
      ), affected_categories AS (
        SELECT id FROM target_category
        UNION
        SELECT c.id
        FROM categories c
        JOIN affected_categories parent ON c.parent_category_id = parent.id
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
  listActiveCategoriesForWaiter,
  listCategoriesForAdmin,
  listProductsForAdmin,
  createCategory,
  moveCategory,
  createProduct,
  updateProduct,
  deleteProduct,
  deactivateProduct,
  deleteCategory,
  deactivateCategory,
};
