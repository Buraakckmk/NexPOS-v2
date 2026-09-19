const db = require("../config/db");
const printerService = require("./printer.service");
const customerService = require("./customer.service");

let ensureOrderSchemaPromise = null;

async function ensureOrderSchema() {
  if (!ensureOrderSchemaPromise) {
    ensureOrderSchemaPromise = db.query(`
      ALTER TABLE categories
      ADD COLUMN IF NOT EXISTS image_path VARCHAR(255);

      ALTER TABLE categories
      ADD COLUMN IF NOT EXISTS printer_route VARCHAR(20) NOT NULL DEFAULT 'MUTFAK';

      UPDATE categories
      SET printer_route = CASE
        WHEN UPPER(name) IN (
          'SICAK İÇECEKLER',
          'SOĞUK İÇECEKLER',
          'ÇAYLAR',
          'TÜRK KAHVESİ ÇEŞİTLERİ',
          'ESPRESSOLU KAHVELER',
          'FİLTRE KAHVELER',
          'FRAPPELER',
          'SAHLEP-SICAK ÇİKOLATA',
          'SOĞUK KAHVELER',
          'MEŞRUBATLAR',
          'MEYVELİ FROZENLER',
          'MİLKSHAKELER',
          'MATCHA (MAÇA)',
          'DETOKS'
        ) THEN 'BAR'
        ELSE COALESCE(NULLIF(UPPER(printer_route), ''), 'MUTFAK')
      END,
      updated_at = NOW()
      WHERE printer_route IS NULL
        OR TRIM(printer_route) = ''
        OR UPPER(printer_route) NOT IN ('MUTFAK', 'BAR', 'KASA');

      ALTER TABLE categories
      DROP CONSTRAINT IF EXISTS categories_printer_route_check;

      ALTER TABLE categories
      ADD CONSTRAINT categories_printer_route_check
      CHECK (printer_route IN ('MUTFAK', 'BAR', 'KASA'));

      ALTER TABLE order_items
      ADD COLUMN IF NOT EXISTS printer_route_snapshot VARCHAR(20) NOT NULL DEFAULT 'MUTFAK';

      UPDATE order_items oi
      SET printer_route_snapshot = COALESCE(NULLIF(c.printer_route, ''), 'MUTFAK')
      FROM products p
      JOIN categories c ON c.id = p.category_id
      WHERE p.id = oi.product_id
        AND (
          oi.printer_route_snapshot IS NULL
          OR TRIM(oi.printer_route_snapshot) = ''
          OR oi.printer_route_snapshot NOT IN ('MUTFAK', 'BAR', 'KASA')
        );

      ALTER TABLE order_items
      DROP CONSTRAINT IF EXISTS order_items_printer_route_snapshot_check;

      ALTER TABLE order_items
      ADD CONSTRAINT order_items_printer_route_snapshot_check
      CHECK (printer_route_snapshot IN ('MUTFAK', 'BAR', 'KASA'));

      ALTER TABLE orders
      ADD COLUMN IF NOT EXISTS guest_count INT NOT NULL DEFAULT 1,
      ADD COLUMN IF NOT EXISTS table_note TEXT,
      ADD COLUMN IF NOT EXISTS payment_lock_user_id INT,
      ADD COLUMN IF NOT EXISTS payment_lock_at TIMESTAMPTZ;
    `);
  }

  try {
    await ensureOrderSchemaPromise;
  } catch (error) {
    ensureOrderSchemaPromise = null;
    throw error;
  }
}

function normalizeNote(note) {
  const trimmed = String(note ?? "").trim();
  return trimmed.length ? trimmed : null;
}

function normalizePrinterRoute(route) {
  const value = String(route ?? "").trim().toUpperCase();
  return ["MUTFAK", "BAR", "KASA"].includes(value) ? value : "MUTFAK";
}

function formatKitchenQuantity(value) {
  const n = Number(value);
  if (Number.isNaN(n)) return String(value ?? "0");
  const rounded = Math.round(n);
  if (Math.abs(n - rounded) < 0.000001) return String(rounded);
  return n.toFixed(2).replace(/\.?0+$/, "");
}

function formatKitchenDateTime(value) {
  const date = value instanceof Date ? value : new Date(value);
  if (Number.isNaN(date.getTime())) {
    return formatKitchenDateTime(new Date());
  }
  const pad = (n) => String(n).padStart(2, "0");
  return `${pad(date.getDate())}.${pad(date.getMonth() + 1)}.${date.getFullYear()} ${pad(date.getHours())}:${pad(date.getMinutes())}`;
}

/**
 * MVP: Fiziksel mutfak yazicisi yokken termal fis benzeri konsol ciktisi.
 * Fiyatsiz; yalnizca yeni onaylanan (PENDING -> SENT) kalemler.
 */
function printKitchenReceiptSimulation({ tableDisplayName, items, confirmedAt }) {
  if (!Array.isArray(items) || items.length === 0) return;

  try {
    process.stdout.write("\x07");
  } catch (_) {
    // Bazi terminaller bell karakterini desteklemez; fis yine basilir.
  }

  const when = formatKitchenDateTime(confirmedAt || new Date());
  const masa = String(tableDisplayName ?? "-").toUpperCase();
  const lines = [
    "",
    "[BIIIP BIIIP BIIIP - MUTFAK YAZICISI CALISTI]",
    "",
    "  +------------------------------------------+",
    "  |       *** MUTFAK FISI ***                |",
    "  +------------------------------------------+",
    "",
    `   MASA: ${masa}`,
    `   TARIH/SAAT: ${when}`,
    "",
    "  --------------------------------------------",
    `   ${"ADET".padEnd(6)}| URUN`,
    "  --------------------------------------------",
  ];

  for (const row of items) {
    const qty = formatKitchenQuantity(row.quantity);
    const name = String(row.name ?? "-").toUpperCase();
    lines.push(`   ${qty.padEnd(6)}| ${name}`);
    const note = String(row.note ?? "").trim();
    if (note) {
      lines.push(`         # ${note.toUpperCase()}`);
    }
  }

  lines.push(
    "  --------------------------------------------",
    "",
    ""
  );

  console.log(lines.join("\n"));
}

const PAYMENT_LOCK_TIMEOUT_MS = 3 * 60 * 1000;

function isPaymentLockActive(row, userId = null) {
  if (!row?.payment_lock_user_id || !row?.payment_lock_at) {
    return false;
  }

  const lockedAt = new Date(row.payment_lock_at).getTime();
  if (!Number.isFinite(lockedAt)) {
    return false;
  }

  const expired = Date.now() - lockedAt > PAYMENT_LOCK_TIMEOUT_MS;
  if (expired) {
    return false;
  }

  if (userId != null && Number(row.payment_lock_user_id) === Number(userId)) {
    return false;
  }

  return true;
}

function buildPaymentLockedError() {
  const err = new Error("Bu adisyonda su anda odeme aliniyor. Lutfen odeme bitince tekrar deneyin.");
  err.statusCode = 409;
  return err;
}

function isLockNotAvailableError(error) {
  return String(error?.code || "") === "55P03";
}

async function clearExpiredPaymentLock(client, orderId) {
  await client.query(
    `
      UPDATE orders
      SET payment_lock_user_id = NULL,
          payment_lock_at = NULL,
          updated_at = NOW()
      WHERE id = $1
        AND payment_lock_at IS NOT NULL
        AND payment_lock_at < NOW() - INTERVAL '3 minutes'
    `,
    [orderId]
  );
}

async function assertOrderNotLockedByAnotherUser(client, orderId, userId) {
  let rows;
  try {
    const result = await client.query(
      `
        SELECT id, payment_lock_user_id, payment_lock_at
        FROM orders
        WHERE id = $1
        FOR UPDATE NOWAIT
      `,
      [orderId]
    );
    rows = result.rows;
  } catch (error) {
    if (isLockNotAvailableError(error)) {
      throw buildPaymentLockedError();
    }
    throw error;
  }

  if (!rows.length) {
    const err = new Error("Siparis bulunamadi.");
    err.statusCode = 404;
    throw err;
  }

  // Row lock alindiktan sonra expire olmus kilidi temizlemek artik bloklamaz.
  await clearExpiredPaymentLock(client, orderId);

  if (isPaymentLockActive(rows[0], userId)) {
    throw buildPaymentLockedError();
  }

  return rows[0];
}

async function acquirePaymentLock(client, orderId, userId) {
  const orderRow = await assertOrderNotLockedByAnotherUser(client, orderId, userId);

  await client.query(
    `
      UPDATE orders
      SET payment_lock_user_id = $2,
          payment_lock_at = NOW(),
          updated_at = NOW()
      WHERE id = $1
    `,
    [orderId, userId]
  );

  return orderRow;
}

async function releasePaymentLock(client, orderId, userId = null) {
  await clearExpiredPaymentLock(client, orderId);

  const params = userId == null ? [orderId] : [orderId, userId];
  const filter = userId == null ? "" : " AND payment_lock_user_id = $2";

  await client.query(
    `
      UPDATE orders
      SET payment_lock_user_id = NULL,
          payment_lock_at = NULL,
          updated_at = NOW()
      WHERE id = $1${filter}
    `,
    params
  );
}

async function getTableById(client, tableId) {
  const { rows } = await client.query(
    `SELECT id, table_code, display_name, is_active FROM tables WHERE id = $1`,
    [tableId]
  );
  return rows[0] || null;
}

async function findActiveOrderForTable(client, tableId) {
  const { rows } = await client.query(
    `
      SELECT id, order_status, waiter_id, discount_total
      FROM orders
      WHERE table_id = $1
        AND order_status IN ('OPEN', 'CONFIRMED')
      ORDER BY opened_at DESC
      LIMIT 1
    `,
    [tableId]
  );
  return rows[0] || null;
}

async function getProductById(client, productId) {
  const { rows } = await client.query(
    `
      SELECT
        p.id,
        p.name,
        p.price,
        p.is_active,
        COALESCE(NULLIF(p.category, ''), c.name) AS category_name,
        COALESCE(NULLIF(c.printer_route, ''), 'MUTFAK') AS printer_route
      FROM products p
      LEFT JOIN categories c ON c.id = p.category_id
      WHERE p.id = $1
    `,
    [productId]
  );
  return rows[0] || null;
}

async function recalcOrderTotals(client, orderId) {
  await client.query(
    `
      UPDATE orders o
      SET
        subtotal = s.sum_lines,
        grand_total = GREATEST(s.sum_lines - o.discount_total, 0),
        updated_at = NOW()
      FROM (
        SELECT COALESCE(SUM(line_total), 0)::numeric AS sum_lines
        FROM order_items
        WHERE order_id = $1
            AND item_status NOT IN ('VOID', 'PAID')
      ) AS s
      WHERE o.id = $1
    `,
    [orderId]
  );
}

/**
 * Masa için açık (OPEN/CONFIRMED) sipariş varsa kalemleri ona ekler; yoksa yeni sipariş açar.
 */
async function createOrAppendOrder({ tableId, items, userId }) {
  if (!Array.isArray(items) || items.length === 0) {
    const err = new Error("En az bir urun satiri gerekli.");
    err.statusCode = 400;
    throw err;
  }

  const client = await db.pool.connect();

  try {
    await client.query("BEGIN");

    const table = await getTableById(client, tableId);
    if (!table || !table.is_active) {
      const err = new Error("Masa bulunamadi veya pasif.");
      err.statusCode = 404;
      throw err;
    }

    let orderRow = await findActiveOrderForTable(client, tableId);
    let orderId;
    let createdNew = false;

    if (!orderRow) {
      const ins = await client.query(
        `
          INSERT INTO orders (
            table_id,
            waiter_id,
            opened_by_user_id,
            guest_count,
            table_note,
            order_status,
            subtotal,
            discount_total,
            grand_total
          )
          VALUES ($1, $2, $2, 1, NULL, 'OPEN', 0, 0, 0)
          RETURNING id, order_status
        `,
        [tableId, userId]
      );
      orderRow = ins.rows[0];
      orderId = orderRow.id;
      createdNew = true;
    } else {
      orderRow = await assertOrderNotLockedByAnotherUser(client, orderRow.id, userId);
      orderId = orderRow.id;
    }

    for (const line of items) {
      const productId = line.product_id;
      const quantity = Number(line.quantity);
      const note = normalizeNote(line.note);

      if (!Number.isFinite(quantity) || quantity <= 0) {
        const err = new Error("Gecersiz adet: her satir icin quantity > 0 olmali.");
        err.statusCode = 400;
        throw err;
      }

      const product = await getProductById(client, productId);
      if (!product || !product.is_active) {
        const err = new Error(`Urun bulunamadi veya pasif: ${productId}`);
        err.statusCode = 404;
        throw err;
      }

      const providedPrice = (line.unit_price !== undefined && line.unit_price !== null)
        ? Number(line.unit_price)
        : NaN;
      const unitPrice = (Number.isFinite(providedPrice) && providedPrice >= 0)
        ? providedPrice
        : Number(product.price);
      const lineTotal = Math.round(unitPrice * quantity * 100) / 100;

      await client.query(
        `
          INSERT INTO order_items (
            order_id,
            product_id,
            category_snapshot,
            printer_route_snapshot,
            product_name_snapshot,
            unit_price_snapshot,
            quantity,
            line_total,
            item_status,
            note
          )
          VALUES ($1, $2, $3, $4, $5, $6, $7, $8, 'PENDING', $9)
        `,
        [
          orderId,
          product.id,
          product.category_name,
          normalizePrinterRoute(product.printer_route),
          product.name,
          unitPrice,
          quantity,
          lineTotal,
          note,
        ]
      );
    }

    // CONFIRMED siparise yeni satir eklendiyse tekrar onay (mutfak) icin OPEN'a al
    if (orderRow && orderRow.order_status === "CONFIRMED") {
      await client.query(
        `
          UPDATE orders
          SET order_status = 'OPEN', confirmed_at = NULL, updated_at = NOW()
          WHERE id = $1
        `,
        [orderId]
      );
    }

    await recalcOrderTotals(client, orderId);

    const { rows: fullOrder } = await client.query(
      `
        SELECT id, table_id, waiter_id, order_status, subtotal, discount_total, grand_total, opened_at
        FROM orders
        WHERE id = $1
      `,
      [orderId]
    );

    await client.query("COMMIT");

    return {
      order: fullOrder[0],
      table_display_name: table.display_name,
      created_new_order: createdNew,
    };
  } catch (e) {
    await client.query("ROLLBACK");
    throw e;
  } finally {
    client.release();
  }
}

async function getOrderWithItems(client, orderId) {
  const { rows: orders } = await client.query(
    `
      SELECT
        o.id,
        o.table_id,
        o.waiter_id,
        u.full_name AS waiter_full_name,
        o.guest_count,
        o.table_note,
        o.order_status,
        o.subtotal,
        o.discount_total,
        o.grand_total,
        o.opened_at,
        o.confirmed_at,
        t.display_name AS table_display_name,
        COALESCE((SELECT SUM(amount) FROM payments WHERE order_id = o.id), 0) AS total_paid
      FROM orders o
      JOIN tables t ON t.id = o.table_id
      JOIN users u ON u.id = o.waiter_id
      WHERE o.id = $1
    `,
    [orderId]
  );
  if (!orders.length) return null;

  const { rows: itemRows } = await client.query(
    `
      SELECT
        oi.id,
        oi.product_id,
        oi.category_snapshot AS category_name,
        oi.printer_route_snapshot AS printer_route,
        oi.product_name_snapshot AS name,
        oi.quantity,
        oi.line_total,
        oi.item_status,
        oi.note
      FROM order_items oi
      WHERE oi.order_id = $1
        AND oi.item_status NOT IN ('PAID', 'VOID')
      ORDER BY oi.id ASC
    `,
    [orderId]
  );

  return { order: orders[0], items: itemRows };
}

/**
 * OPEN siparişi CONFIRMED yapar; kalemleri SENT işaretler; socket + konsol fişi için payload döner.
 * Waiter alanında ekip bazlı çalışmayı desteklemek için aktif siparişlerde waiter sahiplik kısıtı uygulanmaz.
 */
async function confirmOrder({ orderId, userId, roleId }) {
  const client = await db.pool.connect();

  try {
    await client.query("BEGIN");

    const snapshot = await getOrderWithItems(client, orderId);
    if (!snapshot) {
      const err = new Error("Siparis bulunamadi.");
      err.statusCode = 404;
      throw err;
    }

    const { order, items } = snapshot;

    if (!["OPEN", "CONFIRMED"].includes(order.order_status)) {
      const err = new Error("Sadece aktif siparisler onaylanabilir.");
      err.statusCode = 409;
      throw err;
    }

    const pendingItems = items.filter((i) => i.item_status === "PENDING");
    if (pendingItems.length === 0) {
      if (order.order_status === "CONFIRMED") {
        await client.query("COMMIT");
        return {
          socketPayload: {
            order_id: String(order.id),
            table_display_name: order.table_display_name,
            items: [],
            confirmed_at: order.confirmed_at
              ? new Date(order.confirmed_at).toISOString()
              : new Date().toISOString(),
          },
          printArgs: {
            orderId: order.id,
            tableDisplayName: order.table_display_name,
            confirmedAt: order.confirmed_at
              ? new Date(order.confirmed_at).toISOString()
              : new Date().toISOString(),
            items: [],
          },
        };
      }

      const err = new Error("Mutfaga gonderilecek bekleyen (PENDING) kalem yok.");
      err.statusCode = 409;
      throw err;
    }

    await client.query(
      `
        UPDATE order_items
        SET item_status = 'SENT', updated_at = NOW()
        WHERE order_id = $1 AND item_status = 'PENDING'
      `,
      [orderId]
    );

    await client.query(
      `
        UPDATE orders
        SET
          order_status = 'CONFIRMED',
          confirmed_at = NOW(),
          updated_at = NOW()
        WHERE id = $1
      `,
      [orderId]
    );

    const confirmedAt = new Date().toISOString();

    const socketPayload = {
      order_id: String(order.id),
      table_display_name: order.table_display_name,
      items: pendingItems.map((i) => ({
        name: i.name,
        category_name: i.category_name ?? null,
        printer_route: normalizePrinterRoute(i.printer_route),
        quantity: String(i.quantity),
        note: i.note ?? null,
      })),
      confirmed_at: confirmedAt,
    };

    await client.query("COMMIT");

    printKitchenReceiptSimulation({
      tableDisplayName: order.table_display_name,
      items: pendingItems.map((i) => ({
        name: i.name,
        quantity: i.quantity,
        note: i.note ?? null,
      })),
      confirmedAt,
    });

    return {
      socketPayload,
      printArgs: {
        tableDisplayName: order.table_display_name,
        waiterName: order.waiter_full_name,
        orderId: String(order.id),
        guestCount: order.guest_count || 0,
        items: socketPayload.items,
        confirmedAt,
      },
    };
  } catch (e) {
    await client.query("ROLLBACK");
    throw e;
  } finally {
    client.release();
  }
}

async function getActiveOrderForTable({ tableId }) {
  const client = await db.pool.connect();
  try {
    const { rows: orderRows } = await client.query(
      `
        SELECT
          o.id,
          o.table_id,
          o.waiter_id,
          o.guest_count,
          o.table_note,
          o.order_status,
          o.subtotal,
          o.discount_total,
          o.grand_total,
          COALESCE((
            SELECT SUM(p.amount)
            FROM payments p
            WHERE p.order_id = o.id
          ), 0) AS total_paid,
          COALESCE((
            SELECT SUM(p.amount)
            FROM payments p
            WHERE p.order_id = o.id
              AND p.payment_note = 'Tutar girerek odeme'
          ), 0) AS amount_payment_paid,
          o.opened_at,
          o.confirmed_at,
          t.display_name AS table_display_name
        FROM orders o
        JOIN tables t ON t.id = o.table_id
        WHERE o.table_id = $1
          AND o.order_status IN ('OPEN', 'CONFIRMED')
        ORDER BY o.opened_at DESC
        LIMIT 1
      `,
      [tableId]
    );

    if (!orderRows.length) return null;
    const order = orderRows[0];

    const { rows: items } = await client.query(
      `
        SELECT
          oi.product_id,
          oi.product_name_snapshot AS name,
          oi.unit_price_snapshot AS unit_price,
          SUM(oi.quantity) AS quantity,
          SUM(oi.line_total) AS line_total,
          NULLIF(STRING_AGG(DISTINCT NULLIF(TRIM(oi.note), ''), ' | '), '') AS note
        FROM order_items oi
        WHERE oi.order_id = $1
          AND oi.item_status NOT IN ('VOID', 'PAID')
        GROUP BY oi.product_id, oi.product_name_snapshot, oi.unit_price_snapshot
        ORDER BY oi.product_name_snapshot ASC
      `,
      [order.id]
    );

    return { order, items };
  } finally {
    client.release();
  }
}

async function updateOrderItemNote({ orderId, productId, note }) {
  const client = await db.pool.connect();

  try {
    await client.query("BEGIN");

    const { rows: orderRows } = await client.query(
      `
        SELECT id, order_status
        FROM orders
        WHERE id = $1
        FOR UPDATE
      `,
      [orderId]
    );

    if (!orderRows.length) {
      const err = new Error("Siparis bulunamadi.");
      err.statusCode = 404;
      throw err;
    }

    if (!["OPEN", "CONFIRMED"].includes(orderRows[0].order_status)) {
      const err = new Error("Not sadece aktif siparislerde guncellenebilir.");
      err.statusCode = 409;
      throw err;
    }

    const normalizedNote = normalizeNote(note);
    const { rows: updatedRows } = await client.query(
      `
        UPDATE order_items
        SET note = $3, updated_at = NOW()
        WHERE order_id = $1
          AND product_id = $2
          AND item_status NOT IN ('VOID', 'PAID')
        RETURNING id
      `,
      [orderId, productId, normalizedNote]
    );

    if (!updatedRows.length) {
      const err = new Error("Not guncellenecek aktif urun satiri bulunamadi.");
      err.statusCode = 404;
      throw err;
    }

    await client.query("COMMIT");
    return { updatedCount: updatedRows.length, note: normalizedNote };
  } catch (error) {
    await client.query("ROLLBACK");
    throw error;
  } finally {
    client.release();
  }
}

async function updateOrderItemPrice({ orderId, productId, unitPrice }) {
  const client = await db.pool.connect();

  try {
    await client.query("BEGIN");

    const normalizedPrice = Number(unitPrice);
    if (!Number.isFinite(normalizedPrice) || normalizedPrice < 0) {
      const err = new Error("unit_price 0 veya pozitif olmali.");
      err.statusCode = 400;
      throw err;
    }

    const { rows: orderRows } = await client.query(
      `
        SELECT id, order_status
        FROM orders
        WHERE id = $1
        FOR UPDATE
      `,
      [orderId]
    );

    if (!orderRows.length) {
      const err = new Error("Siparis bulunamadi.");
      err.statusCode = 404;
      throw err;
    }

    if (!["OPEN", "CONFIRMED"].includes(orderRows[0].order_status)) {
      const err = new Error("Fiyat sadece aktif siparislerde guncellenebilir.");
      err.statusCode = 409;
      throw err;
    }

    const { rows: updatedRows } = await client.query(
      `
        UPDATE order_items
        SET
          unit_price_snapshot = $3,
          line_total = ROUND((quantity * ($3)::numeric), 2),
          updated_at = NOW()
        WHERE order_id = $1
          AND product_id = $2
          AND item_status NOT IN ('VOID', 'PAID')
        RETURNING id
      `,
      [orderId, productId, normalizedPrice]
    );

    if (!updatedRows.length) {
      const err = new Error("Fiyati guncellenecek aktif urun satiri bulunamadi.");
      err.statusCode = 404;
      throw err;
    }

    await recalcOrderTotals(client, orderId);

    await client.query("COMMIT");
    return { updatedCount: updatedRows.length, unitPrice: normalizedPrice };
  } catch (error) {
    await client.query("ROLLBACK");
    throw error;
  } finally {
    client.release();
  }
}

async function updateOrderMeta({ orderId, guestCount, tableNote }) {
  const client = await db.pool.connect();
  try {
    await client.query("BEGIN");

    const normalizedGuest = Number(guestCount);
    if (!Number.isFinite(normalizedGuest) || normalizedGuest <= 0) {
      const err = new Error("guest_count pozitif bir sayi olmali.");
      err.statusCode = 400;
      throw err;
    }

    const normalizedTableNote = normalizeNote(tableNote);

    const { rows } = await client.query(
      `
        UPDATE orders
        SET
          guest_count = $2,
          table_note = $3,
          updated_at = NOW()
        WHERE id = $1
          AND order_status IN ('OPEN', 'CONFIRMED')
        RETURNING id, guest_count, table_note
      `,
      [orderId, Math.trunc(normalizedGuest), normalizedTableNote]
    );

    if (!rows.length) {
      const err = new Error("Guncellenecek aktif siparis bulunamadi.");
      err.statusCode = 404;
      throw err;
    }

    await client.query("COMMIT");
    return rows[0];
  } catch (error) {
    await client.query("ROLLBACK");
    throw error;
  } finally {
    client.release();
  }
}

async function transferOrderItem({ orderId, productId, quantity, toTableId, userId }) {
  const client = await db.pool.connect();
  try {
    await client.query("BEGIN");

    const transferQty = Number(quantity);
    if (!Number.isFinite(transferQty) || transferQty <= 0) {
      const err = new Error("quantity pozitif bir sayi olmali.");
      err.statusCode = 400;
      throw err;
    }

    const sourceOrderQ = await client.query(
      `
        SELECT id, table_id, waiter_id, order_status, guest_count, table_note
        FROM orders
        WHERE id = $1
          AND order_status IN ('OPEN', 'CONFIRMED')
        FOR UPDATE
      `,
      [orderId]
    );

    if (!sourceOrderQ.rows.length) {
      const err = new Error("Kaynak siparis bulunamadi.");
      err.statusCode = 404;
      throw err;
    }

    const sourceOrder = sourceOrderQ.rows[0];
    if (Number(sourceOrder.table_id) === Number(toTableId)) {
      const err = new Error("Urun ayni masaya tasinamaz.");
      err.statusCode = 400;
      throw err;
    }

    const { rows: sourceTableRows } = await client.query(
      `SELECT id, display_name, is_active FROM tables WHERE id = $1 FOR UPDATE`,
      [sourceOrder.table_id]
    );
    const { rows: targetTableRows } = await client.query(
      `SELECT id, display_name, is_active FROM tables WHERE id = $1 FOR UPDATE`,
      [toTableId]
    );

    if (!sourceTableRows.length || !targetTableRows.length || !targetTableRows[0].is_active) {
      const err = new Error("Masa bulunamadi veya pasif.");
      err.statusCode = 404;
      throw err;
    }

    const candidatesQ = await client.query(
      `
        SELECT
          id,
          quantity,
          unit_price_snapshot,
          category_snapshot,
          product_name_snapshot,
          note,
          item_status,
          product_id
        FROM order_items
        WHERE order_id = $1
          AND product_id = $2
          AND item_status IN ('PENDING', 'SENT')
        ORDER BY id ASC
        FOR UPDATE
      `,
      [orderId, productId]
    );

    const availableQty = candidatesQ.rows.reduce(
      (sum, row) => sum + Number(row.quantity || 0),
      0
    );

    if (availableQty < transferQty) {
      const err = new Error("Transfer icin yeterli urun adedi yok.");
      err.statusCode = 400;
      throw err;
    }

    const targetActiveQ = await client.query(
      `
        SELECT id, order_status
        FROM orders
        WHERE table_id = $1
          AND order_status IN ('OPEN', 'CONFIRMED')
        ORDER BY opened_at DESC
        LIMIT 1
        FOR UPDATE
      `,
      [toTableId]
    );

    let targetOrderId;
    let targetOrderStatus = "OPEN";
    let createdTargetOrder = false;

    if (targetActiveQ.rows.length) {
      targetOrderId = targetActiveQ.rows[0].id;
      targetOrderStatus = targetActiveQ.rows[0].order_status;
    } else {
      const insQ = await client.query(
        `
          INSERT INTO orders (
            table_id,
            waiter_id,
            opened_by_user_id,
            guest_count,
            table_note,
            order_status,
            subtotal,
            discount_total,
            grand_total
          )
          VALUES ($1, $2, $2, 1, NULL, 'OPEN', 0, 0, 0)
          RETURNING id, order_status
        `,
        [toTableId, userId || sourceOrder.waiter_id]
      );
      targetOrderId = insQ.rows[0].id;
      targetOrderStatus = insQ.rows[0].order_status;
      createdTargetOrder = true;
    }

    let remaining = transferQty;
    let movedPending = false;
    let movedTotal = 0;

    for (const row of candidatesQ.rows) {
      if (remaining <= 0) break;
      const rowQty = Number(row.quantity || 0);
      if (rowQty <= 0) continue;

      const moveQty = Math.min(rowQty, remaining);
      const remainingInRow = rowQty - moveQty;
      if (row.item_status === "PENDING") {
        movedPending = true;
      }

      if (remainingInRow <= 0) {
        await client.query(
          `
            UPDATE order_items
            SET order_id = $2, updated_at = NOW()
            WHERE id = $1
          `,
          [row.id, targetOrderId]
        );
      } else {
        await client.query(
          `
            UPDATE order_items
            SET
              quantity = $2,
              line_total = ROUND(($2 * unit_price_snapshot)::numeric, 2),
              updated_at = NOW()
            WHERE id = $1
          `,
          [row.id, remainingInRow]
        );

        await client.query(
          `
            INSERT INTO order_items (
              order_id,
              product_id,
              category_snapshot,
              product_name_snapshot,
              unit_price_snapshot,
              quantity,
              line_total,
              item_status,
              note
            )
            VALUES (
              $1,
              $2,
              $3,
              $4,
              $5,
              $6,
              ROUND((($6)::numeric * ($5)::numeric), 2),
              $7,
              $8
            )
          `,
          [
            targetOrderId,
            row.product_id,
            row.category_snapshot,
            row.product_name_snapshot,
            row.unit_price_snapshot,
            moveQty,
            row.item_status,
            row.note,
          ]
        );
      }

      movedTotal += moveQty;
      remaining -= moveQty;
    }

    await recalcOrderTotals(client, orderId);
    await recalcOrderTotals(client, targetOrderId);

    const sourceOpenItemsQ = await client.query(
      `
        SELECT COUNT(*)::int AS open_count
        FROM order_items
        WHERE order_id = $1
          AND item_status IN ('PENDING', 'SENT')
      `,
      [orderId]
    );

    if (Number(sourceOpenItemsQ.rows[0]?.open_count || 0) === 0) {
      await client.query(
        `
          UPDATE orders
          SET
            order_status = 'CANCELLED',
            subtotal = 0,
            grand_total = 0,
            updated_at = NOW()
          WHERE id = $1
        `,
        [orderId]
      );
    }

    if (movedPending && targetOrderStatus === "CONFIRMED") {
      await client.query(
        `
          UPDATE orders
          SET order_status = 'OPEN', confirmed_at = NULL, updated_at = NOW()
          WHERE id = $1
        `,
        [targetOrderId]
      );
    }

    await client.query("COMMIT");

    return {
      sourceOrderId: orderId,
      targetOrderId,
      movedQuantity: movedTotal,
      sourceTable: sourceTableRows[0],
      targetTable: targetTableRows[0],
      createdTargetOrder,
    };
  } catch (error) {
    await client.query("ROLLBACK");
    throw error;
  } finally {
    client.release();
  }
}

async function checkoutOrder({
  orderId,
  userId,
  roleId,
  paymentMethod,
  discountAmount,
  mealCardType,
}) {
  const client = await db.pool.connect();
  try {
    await client.query("BEGIN");
    const { rows } = await client.query(
      `
        SELECT
          o.id,
          o.table_id,
          o.waiter_id,
          o.order_status,
          o.subtotal,
          o.discount_total,
          o.grand_total,
          t.display_name AS table_display_name
        FROM orders o
        JOIN tables t ON t.id = o.table_id
        WHERE o.id = $1
      `,
      [orderId]
    );

    if (!rows.length) {
      const err = new Error("Siparis bulunamadi.");
      err.statusCode = 404;
      throw err;
    }

    const order = rows[0];
    if (!["OPEN", "CONFIRMED"].includes(order.order_status)) {
      const err = new Error("Sadece aktif siparisler hesap alina bilir.");
      err.statusCode = 409;
      throw err;
    }

    const { rows: itemRows } = await client.query(
      `
        SELECT
          oi.product_name_snapshot AS name,
          oi.category_snapshot AS category_name,
          oi.quantity,
          oi.unit_price_snapshot AS unit_price
        FROM order_items oi
        WHERE oi.order_id = $1
          AND oi.item_status NOT IN ('VOID', 'PAID')
        ORDER BY oi.id ASC
      `,
      [orderId]
    );

    const subtotal = Number(order.subtotal || 0);
    const discount = Math.min(Number(discountAmount || 0), subtotal);
    const grandTotal = Number((subtotal - discount).toFixed(2));

    if (grandTotal <= 0) {
      const err = new Error("İskonto sonrası ödeme tutarı 0 olamaz.");
      err.statusCode = 400;
      throw err;
    }

    // Fişi terminale bas (arka planda çalıştır, ana işlemi bloklama)
    printFinalReceipt({
      client,
      orderId,
      tableDisplayName: order.table_display_name,
      items: itemRows,
      subtotal,
      discountAmount: discount,
      grandTotal,
      paymentMethod,
      mealCardType,
    }).catch((err) => console.error("Arka plan fiş yazdırma hatası:", err));

    await client.query(
      `
        INSERT INTO payments (
          order_id,
          received_by_user_id,
          payment_method,
          amount,
          discount_amount,
          currency,
          meal_card_type,
          payment_note
        )
        VALUES ($1, $2, $3, $4, $5, 'TRY', $6, 'Tam ödeme')
      `,
      [orderId, userId, paymentMethod, grandTotal, discount, mealCardType]
    );

    if (paymentMethod === "CUSTOMER" || (mealCardType && mealCardType.startsWith("CUSTOMER:"))) {
      let custId;
      if (mealCardType && mealCardType.startsWith("CUSTOMER:")) {
        custId = Number(mealCardType.split(":")[1]);
      }
      if (custId && Number.isFinite(custId)) {
        await customerService.addTransaction({
          customer_id: custId,
          order_id: orderId,
          type: "DEBIT",
          amount: grandTotal,
          note: `Masa Adisyonu Cariye Aktarıldı (#${orderId})`,
          created_by_user_id: userId,
        });
      }
    }

    await client.query(
      `
        UPDATE orders
        SET
          order_status = 'PAID',
          payment_method = $3,
          discount_total = $4,
          grand_total = $5,
          closed_by_user_id = $2,
          closed_at = NOW(),
          updated_at = NOW()
        WHERE id = $1
      `,
      [orderId, userId, paymentMethod, discount, grandTotal]
    );

    await client.query("COMMIT");
    return {
      order_id: String(order.id),
      table_id: String(order.table_id),
      table_status: "AVAILABLE",
      order_status: "PAID",
    };
  } catch (e) {
    await client.query("ROLLBACK");
    throw e;
  } finally {
    client.release();
  }
}

async function startPaymentSession({ orderId, userId }) {
  const client = await db.pool.connect();
  try {
    await client.query("BEGIN");

    const { rows } = await client.query(
      `
        SELECT id, order_status, payment_lock_user_id, payment_lock_at
        FROM orders
        WHERE id = $1
        FOR UPDATE
      `,
      [orderId]
    );

    if (!rows.length) {
      const err = new Error("Siparis bulunamadi.");
      err.statusCode = 404;
      throw err;
    }

    if (!["OPEN", "CONFIRMED"].includes(rows[0].order_status)) {
      const err = new Error("Bu siparis odeme icin uygun degil.");
      err.statusCode = 409;
      throw err;
    }

    if (isPaymentLockActive(rows[0], userId)) {
      throw buildPaymentLockedError();
    }

    await acquirePaymentLock(client, orderId, userId);
    await client.query("COMMIT");
    return { locked: true };
  } catch (error) {
    await client.query("ROLLBACK");
    throw error;
  } finally {
    client.release();
  }
}

async function endPaymentSession({ orderId, userId }) {
  const client = await db.pool.connect();
  try {
    await client.query("BEGIN");
    await releasePaymentLock(client, orderId, userId);
    await client.query("COMMIT");
    return { released: true };
  } catch (error) {
    await client.query("ROLLBACK");
    throw error;
  } finally {
    client.release();
  }
}

async function printFinalReceipt({
  client,
  orderId,
  tableDisplayName,
  items,
  subtotal,
  discountAmount,
  grandTotal,
  paymentMethod,
  mealCardType,
}) {
  try {
    const vatAmount = Math.max(grandTotal - grandTotal / 1.1, 0);
    await printerService.enqueueCashReceipt({
      tableDisplayName,
      orderId: String(orderId),
      items: items || [],
      subtotal,
      discountAmount: discountAmount || 0,
      vatAmount,
      grandTotal,
      paymentMethod,
      mealCardType,
    });
  } catch (err) {
    console.error("Fiş yazdırma hatası:", err);
    // Yazdırma hatası ödemeyi engellememeli, o yüzden throw etmiyoruz.
  }
}

async function transferOrderBetweenTables({ fromTableId, toTableId, userId }) {
  const client = await db.pool.connect();

  try {
    await client.query("BEGIN");

    // Kaynak masanın aktif siparişini kontrol et
    const { rows: fromOrders } = await client.query(
      `
        SELECT id, order_status
        FROM orders
        WHERE table_id = $1
          AND order_status IN ('OPEN', 'CONFIRMED')
        ORDER BY opened_at DESC
        LIMIT 1
      `,
      [fromTableId]
    );

    if (!fromOrders.length) {
      const err = new Error("Kaynak masada aktif siparis bulunamadi.");
      err.statusCode = 404;
      throw err;
    }

    const activeOrder = fromOrders[0];

    // Hedef masanın durumunu kontrol et
    const { rows: toOrders } = await client.query(
      `
        SELECT id
        FROM orders
        WHERE table_id = $1
          AND order_status IN ('OPEN', 'CONFIRMED')
      `,
      [toTableId]
    );

    if (toOrders.length > 0) {
      const err = new Error("Hedef masada zaten aktif siparis var.");
      err.statusCode = 409;
      throw err;
    }

    // Masaları al
    const { rows: fromTableRows } = await client.query(
      `SELECT id, display_name FROM tables WHERE id = $1`,
      [fromTableId]
    );
    const { rows: toTableRows } = await client.query(
      `SELECT id, display_name FROM tables WHERE id = $1`,
      [toTableId]
    );

    if (!fromTableRows.length || !toTableRows.length) {
      const err = new Error("Masalar bulunamadi.");
      err.statusCode = 404;
      throw err;
    }

    // Siparişi hedef masaya taşı
    await client.query(
      `
        UPDATE orders
        SET
          table_id = $1,
          updated_at = NOW()
        WHERE id = $2
      `,
      [toTableId, activeOrder.id]
    );

    await client.query("COMMIT");

    return {
      fromTable: fromTableRows[0],
      toTable: toTableRows[0],
      order: { id: activeOrder.id },
    };
  } catch (e) {
    await client.query("ROLLBACK");
    throw e;
  } finally {
    client.release();
  }
}

async function mergeOrderBetweenTables({ sourceTableId, targetTableId }) {
  const client = await db.pool.connect();

  try {
    await client.query("BEGIN");

    // Kaynak masanın aktif siparişini kontrol et
    const { rows: sourceOrders } = await client.query(
      `SELECT id, order_status, confirmed_at FROM orders
       WHERE table_id = $1 AND order_status IN ('OPEN', 'CONFIRMED')
       ORDER BY opened_at DESC LIMIT 1
       FOR UPDATE`,
      [sourceTableId]
    );
    if (!sourceOrders.length) {
      const err = new Error("Kaynak masada aktif siparis bulunamadi.");
      err.statusCode = 404;
      throw err;
    }

    // Hedef masanın aktif siparişini kontrol et
    const { rows: targetOrders } = await client.query(
      `SELECT id, order_status, confirmed_at FROM orders
       WHERE table_id = $1 AND order_status IN ('OPEN', 'CONFIRMED')
       ORDER BY opened_at DESC LIMIT 1
       FOR UPDATE`,
      [targetTableId]
    );

    const sourceOrderId = sourceOrders[0].id;

    // Masaları al
    const { rows: srcTableRows } = await client.query(
      `SELECT id, display_name FROM tables WHERE id = $1`, [sourceTableId]
    );
    const { rows: tgtTableRows } = await client.query(
      `SELECT id, display_name FROM tables WHERE id = $1`, [targetTableId]
    );
    if (!srcTableRows.length || !tgtTableRows.length) {
      const err = new Error("Masalar bulunamadi.");
      err.statusCode = 404;
      throw err;
    }

    if (!targetOrders.length) {
      // Hedef masada sipariş yoksa doğrudan siparişi hedef masaya taşı
      await client.query(
        `UPDATE orders SET table_id = $1, updated_at = NOW() WHERE id = $2`,
        [targetTableId, sourceOrderId]
      );
      await client.query("COMMIT");
      return {
        sourceTable: srcTableRows[0],
        targetTable: tgtTableRows[0],
      };
    }

    const targetOrderId = targetOrders[0].id;

    const { rows: sourceItemRows } = await client.query(
      `
        SELECT id, item_status
        FROM order_items
        WHERE order_id = $1
          AND item_status NOT IN ('VOID', 'PAID')
        FOR UPDATE
      `,
      [sourceOrderId]
    );

    if (!sourceItemRows.length) {
      const err = new Error("Kaynak masada birleştirilecek aktif ürün bulunamadi.");
      err.statusCode = 409;
      throw err;
    }

    // Kaynak siparişin ürünlerini hedef siparişe taşı
    await client.query(
      `
        UPDATE order_items
        SET order_id = $1, updated_at = NOW()
        WHERE order_id = $2
          AND item_status NOT IN ('VOID', 'PAID')
      `,
      [targetOrderId, sourceOrderId]
    );

    await recalcOrderTotals(client, targetOrderId);

    const hasPendingItems = sourceItemRows.some((item) => item.item_status === "PENDING");
    if (hasPendingItems && targetOrders[0].order_status === "CONFIRMED") {
      await client.query(
        `
          UPDATE orders
          SET order_status = 'OPEN', confirmed_at = NULL, updated_at = NOW()
          WHERE id = $1
        `,
        [targetOrderId]
      );
    }

    // Kaynak siparişi iptal et
    await client.query(
      `
        UPDATE orders
        SET
          order_status = 'CANCELLED',
          subtotal = 0,
          grand_total = 0,
          updated_at = NOW()
        WHERE id = $1
      `,
      [sourceOrderId]
    );

    await client.query("COMMIT");

    return {
      sourceTable: srcTableRows[0],
      targetTable: tgtTableRows[0],
      targetOrderId,
    };
  } catch (e) {
    await client.query("ROLLBACK");
    throw e;
  } finally {
    client.release();
  }
}

module.exports = {
  ensureOrderSchema,
  createOrAppendOrder,
  confirmOrder,
  getActiveOrderForTable,
  checkoutOrder,
  startPaymentSession,
  endPaymentSession,
  transferOrderBetweenTables,
  mergeOrderBetweenTables,
  updateOrderItemNote,
  updateOrderItemPrice,
  updateOrderMeta,
  transferOrderItem,
  printFinalReceipt,
};
