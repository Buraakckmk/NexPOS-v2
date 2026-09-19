const db = require("../config/db");

let ensureTableSchemaPromise = null;

async function ensureTableSchema() {
  if (!ensureTableSchemaPromise) {
    ensureTableSchemaPromise = db.query(`
      ALTER TABLE tables
      ADD COLUMN IF NOT EXISTS is_custom BOOLEAN NOT NULL DEFAULT FALSE;
    `);
  }

  try {
    await ensureTableSchemaPromise;
  } catch (error) {
    ensureTableSchemaPromise = null;
    throw error;
  }
}

async function listTablesForWaiter() {
  await ensureTableSchema();

  const query = `
    SELECT
      t.id,
      t.table_code,
      t.display_name,
      t.zone,
      t.capacity,
      t.is_custom,
      t.is_active,
      COALESCE(open_orders.active_order_count, 0) AS active_order_count,
      open_orders.active_since,
      COALESCE(open_orders.remaining_balance, 0) AS total_amount,
      CASE
        WHEN COALESCE(open_orders.active_order_count, 0) > 0 THEN 'OCCUPIED'
        ELSE 'AVAILABLE'
      END AS table_status
    FROM tables t
    LEFT JOIN (
      SELECT
        o.table_id,
        COUNT(DISTINCT o.id) AS active_order_count,
        MIN(o.opened_at) AS active_since,
        COALESCE((
          SELECT SUM(oi.line_total)
          FROM order_items oi
          WHERE oi.order_id IN (
            SELECT id FROM orders o2 
            WHERE o2.table_id = o.table_id 
            AND o2.order_status IN ('OPEN', 'CONFIRMED')
          )
          AND oi.item_status NOT IN ('VOID', 'PAID')
        ), 0) AS remaining_balance
      FROM orders o
      WHERE o.order_status IN ('OPEN', 'CONFIRMED')
      GROUP BY o.table_id
    ) AS open_orders ON open_orders.table_id = t.id
    WHERE t.is_active = TRUE
    ORDER BY t.zone ASC, t.display_name ASC;
  `;

  const { rows } = await db.query(query);
  return rows;
}

async function createCustomTable({ displayName, zone, capacity = 4 }) {
  await ensureTableSchema();

  const normalizedName = String(displayName ?? "").trim();
  const normalizedZone = String(zone ?? "").trim() || "Salon";
  const normalizedCapacity = Number(capacity);

  if (!normalizedName) {
    const err = new Error("display_name gerekli.");
    err.statusCode = 400;
    throw err;
  }

  if (!Number.isFinite(normalizedCapacity) || normalizedCapacity <= 0) {
    const err = new Error("capacity pozitif bir sayi olmali.");
    err.statusCode = 400;
    throw err;
  }

  const client = await db.pool.connect();
  try {
    await client.query("BEGIN");

    const { rows: existingByName } = await client.query(
      `
        SELECT id
        FROM tables
        WHERE LOWER(display_name) = LOWER($1)
          AND is_active = TRUE
        LIMIT 1
      `,
      [normalizedName]
    );

    if (existingByName.length) {
      const err = new Error("Bu isimde aktif bir masa zaten var.");
      err.statusCode = 409;
      throw err;
    }

    const { rows: seqRows } = await client.query(
      `
        SELECT COALESCE(MAX(id), 0) + 1 AS next_id
        FROM tables
      `
    );
    const nextId = Number(seqRows[0]?.next_id || Date.now());
    const tableCode = `CUS-${nextId}`;

    const { rows } = await client.query(
      `
        INSERT INTO tables (
          table_code,
          display_name,
          zone,
          capacity,
          is_custom,
          is_active
        )
        VALUES ($1, $2, $3, $4, TRUE, TRUE)
        RETURNING id, table_code, display_name, zone, capacity, is_custom, is_active
      `,
      [tableCode, normalizedName, normalizedZone, Math.trunc(normalizedCapacity)]
    );

    await client.query("COMMIT");
    return rows[0];
  } catch (error) {
    await client.query("ROLLBACK");
    throw error;
  } finally {
    client.release();
  }
}

async function deleteCustomTable({ tableId }) {
  await ensureTableSchema();

  const normalizedTableId = Number(tableId);
  if (!Number.isFinite(normalizedTableId) || normalizedTableId <= 0) {
    const err = new Error("Gecersiz tableId.");
    err.statusCode = 400;
    throw err;
  }

  const client = await db.pool.connect();
  try {
    await client.query("BEGIN");

    const { rows: tableRows } = await client.query(
      `
        SELECT id, display_name, is_custom, is_active
        FROM tables
        WHERE id = $1
        FOR UPDATE
      `,
      [normalizedTableId]
    );

    if (!tableRows.length || !tableRows[0].is_active) {
      const err = new Error("Silinecek masa bulunamadi.");
      err.statusCode = 404;
      throw err;
    }

    if (!tableRows[0].is_custom) {
      const err = new Error("Sadece eklenen ozel masalar silinebilir.");
      err.statusCode = 400;
      throw err;
    }

    const { rows: activeOrderRows } = await client.query(
      `
        SELECT COUNT(*)::int AS active_count
        FROM orders
        WHERE table_id = $1
          AND order_status IN ('OPEN', 'CONFIRMED')
      `,
      [normalizedTableId]
    );

    const activeOrderCount = Number(activeOrderRows[0]?.active_count ?? 0);
    if (activeOrderCount > 0) {
      const err = new Error(
        "Masada aktif adisyon varken silme işlemi yapılamaz."
      );
      err.statusCode = 409;
      throw err;
    }

    await client.query(
      `
        UPDATE tables
        SET is_active = FALSE, updated_at = NOW()
        WHERE id = $1
      `,
      [normalizedTableId]
    );

    await client.query("COMMIT");

    return {
      id: tableRows[0].id,
      display_name: tableRows[0].display_name,
    };
  } catch (error) {
    await client.query("ROLLBACK");
    throw error;
  } finally {
    client.release();
  }
}

module.exports = {
  ensureTableSchema,
  listTablesForWaiter,
  createCustomTable,
  deleteCustomTable,
};
