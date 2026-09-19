const fs = require("fs");
const db = require("../config/db");
const printerService = require("../services/printer.service");
const excelReportService = require("../services/excel-report.service");
const logger = require("../config/logger");
const {
  formatLocalDate,
  getBusinessDate,
  getBusinessDateText,
  getBusinessDayStart,
} = require("../utils/business-date");

let ensureFinanceSchemaPromise = null;

async function ensureFinanceSchema() {
  if (!ensureFinanceSchemaPromise) {
    ensureFinanceSchemaPromise = db.query(`
      CREATE TABLE IF NOT EXISTS expenses (
        id BIGSERIAL PRIMARY KEY,
        expense_date DATE NOT NULL DEFAULT CURRENT_DATE,
        item_name VARCHAR(160) NOT NULL,
        quantity NUMERIC(10, 2) NOT NULL CHECK (quantity > 0),
        unit_price NUMERIC(12, 2) NOT NULL CHECK (unit_price >= 0),
        total_amount NUMERIC(12, 2) NOT NULL CHECK (total_amount >= 0),
        note TEXT,
        created_by_user_id BIGINT REFERENCES users(id) ON DELETE SET NULL,
        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
      );

      CREATE INDEX IF NOT EXISTS idx_expenses_expense_date ON expenses(expense_date);
    `);
  }

  try {
    await ensureFinanceSchemaPromise;
  } catch (error) {
    ensureFinanceSchemaPromise = null;
    throw error;
  }
}

async function getCurrentReportPeriod(client) {
  const { rows } = await client.query(
    `SELECT NOW() AS now_ts`
  );

  const now = new Date(rows[0].now_ts);
  const businessDateText = getBusinessDateText(now, 3);
  const businessDate = getBusinessDate(now, 3);
  const dayStart = getBusinessDayStart(now, 3);

  const { rows: resetRows } = await client.query(
    `
      SELECT MAX(updated_at) AS last_reset_at
      FROM z_reports
      WHERE updated_at >= $1
        AND updated_at < $2
    `,
    [dayStart.toISOString(), now.toISOString()]
  );

  const lastResetAt = resetRows[0].last_reset_at
    ? new Date(resetRows[0].last_reset_at)
    : null;
  const periodStart = lastResetAt ?? dayStart;

  return {
    periodStart,
    periodEnd: now,
    dayStart,
    lastResetAt,
    businessDateText,
    businessDate,
  };
}

async function getXReport(req, res) {
  try {
    await ensureFinanceSchema();
    const client = await db.pool.connect();

    try {
      const { periodStart, periodEnd } = await getCurrentReportPeriod(client);
      const payload = await buildXReportPayload(client, { periodStart, periodEnd });

      res.json({
        success: true,
        data: payload,
      });
    } finally {
      client.release();
    }
  } catch (error) {
    logger.error("X Report error", { message: error.message, stack: error.stack });
    res.status(500).json({ success: false, message: "X Raporu alınırken hata oluştu" });
  }
}

async function printXReport(req, res) {
  try {
    await ensureFinanceSchema();
    const client = await db.pool.connect();

    try {
      const { periodStart, periodEnd } = await getCurrentReportPeriod(client);
      const payload = await buildXReportPayload(client, { periodStart, periodEnd });

      const printedAt = new Date();
      const printPayload = {
        ...payload,
        printedAt: printedAt.toISOString(),
      };

      // Yazıcıya gönder — HTTP isteğini bloklamaz, arka planda tamamlanır
      printerService.enqueueXReport(printPayload).catch((err) => {
        logger.error("X raporu yazıcı kuyruğu hatası", { message: err.message });
      });

      res.json({
        success: true,
        data: printPayload,
      });
    } finally {
      client.release();
    }
  } catch (error) {
    logger.error("X Report print error", {
      message: error.message,
      stack: error.stack,
    });
    res.status(500).json({
      success: false,
      message: "X Raporu yazdırılırken hata oluştu",
    });
  }
}

async function buildXReportPayload(client, { periodStart, periodEnd }) {
  const query = `
    WITH payment_stats AS (
      SELECT
        COALESCE(SUM(amount), 0) as total_revenue,
        COALESCE(SUM(CASE WHEN payment_method = 'CASH' THEN amount ELSE 0 END), 0) as cash_total,
        COALESCE(SUM(CASE WHEN payment_method = 'CARD' THEN amount ELSE 0 END), 0) as card_total,
        COALESCE(COUNT(DISTINCT order_id), 0) as total_orders,
        COALESCE(SUM(discount_amount), 0) as total_discounts
      FROM payments
      WHERE paid_at >= $1 AND paid_at < $2
    ),
    order_metrics AS (
      SELECT
        COALESCE(AVG(guest_count), 0) as avg_guest_count,
        COALESCE(AVG(EXTRACT(EPOCH FROM (COALESCE(closed_at, NOW()) - opened_at)) / 60), 0) as avg_duration
      FROM orders
      WHERE id IN (
        SELECT DISTINCT order_id 
        FROM payments 
        WHERE paid_at >= $1 AND paid_at < $2
      )
    ),
    expense_data AS (
      SELECT COALESCE(SUM(total_amount), 0) as total_expenses
      FROM expenses
      WHERE created_at >= $1 AND created_at < $2
    )
    SELECT * FROM payment_stats, order_metrics, expense_data;
  `;

  const { rows } = await client.query(query, [periodStart, periodEnd]);
  const stats = rows[0] || {};

  const { rows: expenseList } = await client.query(
    "SELECT item_name, total_amount FROM expenses WHERE created_at >= $1 AND created_at < $2",
    [periodStart, periodEnd]
  );

  return {
    reportDate: new Date().toISOString(),
    totalRevenue: Number(stats.total_revenue || 0),
    cashTotal: Number(stats.cash_total || 0),
    cardTotal: Number(stats.card_total || 0),
    totalOrders: Number(stats.total_orders || 0),
    totalDiscounts: Number(stats.total_discounts || 0),
    averageGuestCount: Number(stats.avg_guest_count || 0).toFixed(1),
    averageDuration: Math.round(Number(stats.avg_duration || 0)),
    totalExpenses: Number(stats.total_expenses || 0),
    expenses: (expenseList || []).map((e) => ({
      name: e.item_name,
      amount: Number(e.total_amount || 0),
    })),
    cashIn: Number(stats.total_revenue || 0),
    cashOut: Number(stats.total_expenses || 0),
    generalCashRegister: Number((stats.total_revenue || 0) - (stats.total_expenses || 0)),
    generalCashStatus: Number((stats.cash_total || 0) - (stats.total_expenses || 0)),
  };
}

async function getDailySummary(req, res) {
  try {
    await ensureFinanceSchema();
    const client = await db.pool.connect();
    
    try {
      const { periodStart, periodEnd, businessDateText, lastResetAt } =
        await getCurrentReportPeriod(client);
      
      // Bugün alınan tüm ödemelerin toplam cirosu ve adedi
      const { rows } = await client.query(
        `
          SELECT 
            COUNT(DISTINCT p.order_id) as total_orders,
            COALESCE(SUM(p.amount), 0) as total_revenue,
            COALESCE(SUM(CASE WHEN p.payment_method = 'CASH' THEN p.amount ELSE 0 END), 0) as cash_total,
            COALESCE(SUM(CASE WHEN p.payment_method = 'CARD' THEN p.amount ELSE 0 END), 0) as card_total
          FROM payments p
          WHERE p.paid_at >= $1 
            AND p.paid_at < $2
        `,
        [periodStart, periodEnd]
      );
      
      const result = rows[0];

      const { rows: paymentRows } = await client.query(
        `
          SELECT
            p.order_id,
            p.payment_method,
            p.amount,
            p.paid_at,
            t.display_name AS table_name,
            u.full_name AS cashier_name
          FROM payments p
          JOIN orders o ON o.id = p.order_id
          JOIN tables t ON t.id = o.table_id
          LEFT JOIN users u ON u.id = p.received_by_user_id
          WHERE p.paid_at >= $1
            AND p.paid_at < $2
          ORDER BY p.paid_at ASC, p.id ASC
        `,
        [periodStart, periodEnd]
      );

      const { rows: expenseRows } = await client.query(
        `
          SELECT
            item_name,
            quantity,
            unit_price,
            total_amount,
            note,
            created_at
          FROM expenses
          WHERE created_at >= $1
            AND created_at < $2
          ORDER BY created_at ASC, id ASC
        `,
        [periodStart, periodEnd]
      );

      const { rows: productRows } = await client.query(
        `
          SELECT
            COALESCE(NULLIF(oi.category_snapshot, ''), c.name, 'Diğer') AS category_name,
            oi.product_name_snapshot AS product_name,
            COALESCE(SUM(oi.quantity), 0) AS total_quantity,
            COALESCE(SUM(oi.line_total), 0) AS total_revenue
          FROM order_items oi
          JOIN orders o ON o.id = oi.order_id
          LEFT JOIN products p ON p.id = oi.product_id
          LEFT JOIN categories c ON c.id = p.category_id
          WHERE oi.item_status <> 'VOID'
            AND o.id IN (
              SELECT DISTINCT order_id
              FROM payments
              WHERE paid_at >= $1
                AND paid_at < $2
            )
          GROUP BY category_name, oi.product_name_snapshot
          ORDER BY category_name ASC, total_revenue DESC
        `,
        [periodStart, periodEnd]
      );

      const { rows: adjustmentRows } = await client.query(
        `
          WITH discount_events AS (
            SELECT
              p.paid_at AS event_at,
              'INDIRIM'::text AS event_type,
              p.order_id,
              t.display_name AS table_name,
              NULL::text AS product_name,
              NULL::numeric AS quantity,
              COALESCE(p.discount_amount, 0)::numeric AS amount,
              COALESCE(NULLIF(TRIM(p.payment_note), ''), 'Odeme sirasinda indirim uygulandi') AS reason,
              COALESCE(u.full_name, '-') AS user_name
            FROM payments p
            JOIN orders o ON o.id = p.order_id
            JOIN tables t ON t.id = o.table_id
            LEFT JOIN users u ON u.id = p.received_by_user_id
            WHERE p.paid_at >= $1
              AND p.paid_at < $2
              AND COALESCE(p.discount_amount, 0) > 0
          ),
          void_events AS (
            SELECT
              v.created_at AS event_at,
              CASE WHEN v.action_type = 'COMP' THEN 'IKRAM' ELSE 'URUN_IPTAL' END AS event_type,
              v.order_id,
              t.display_name AS table_name,
              COALESCE(p.name, oi.product_name_snapshot, '-') AS product_name,
              COALESCE(v.quantity, 0)::numeric AS quantity,
              ROUND(COALESCE(v.quantity, 0) * COALESCE(oi.unit_price_snapshot, p.price, 0), 2)::numeric AS amount,
              COALESCE(NULLIF(TRIM(v.reason), ''), 'Urun hareketi') AS reason,
              COALESCE(u.full_name, '-') AS user_name
            FROM voids v
            JOIN orders o ON o.id = v.order_id
            JOIN tables t ON t.id = o.table_id
            LEFT JOIN order_items oi ON oi.id = v.order_item_id
            LEFT JOIN products p ON p.id = v.product_id
            LEFT JOIN users u ON u.id = v.created_by_user_id
            WHERE v.created_at >= $1
              AND v.created_at < $2
          ),
          cancelled_orders AS (
            SELECT
              o.updated_at AS event_at,
              'SIPARIS_IPTAL'::text AS event_type,
              o.id AS order_id,
              t.display_name AS table_name,
              NULL::text AS product_name,
              NULL::numeric AS quantity,
              COALESCE((
                SELECT SUM(oi2.line_total)
                FROM order_items oi2
                WHERE oi2.order_id = o.id
              ), 0)::numeric AS amount,
              'Siparis iptal edildi / masadan silindi'::text AS reason,
              COALESCE(u.full_name, '-') AS user_name
            FROM orders o
            JOIN tables t ON t.id = o.table_id
            LEFT JOIN users u ON u.id = o.closed_by_user_id
            WHERE o.order_status = 'CANCELLED'
              AND o.updated_at >= $1
              AND o.updated_at < $2
          )
          SELECT *
          FROM (
            SELECT * FROM discount_events
            UNION ALL
            SELECT * FROM void_events
            UNION ALL
            SELECT * FROM cancelled_orders
          ) all_events
          ORDER BY event_at ASC, order_id ASC
        `,
        [periodStart, periodEnd]
      );
      
      res.json({
        success: true,
        data: {
          totalRevenue: parseFloat(result.total_revenue) || 0,
          cashTotal: parseFloat(result.cash_total) || 0,
          cardTotal: parseFloat(result.card_total) || 0,
          totalOrders: parseInt(result.total_orders) || 0,
          date: businessDateText,
          periodStart: periodStart.toISOString(),
          periodEnd: periodEnd.toISOString(),
          lastResetAt: lastResetAt ? lastResetAt.toISOString() : null,
        }
      });
      
    } finally {
      client.release();
    }
  } catch (error) {
    logger.error("Daily summary error", { message: error.message, stack: error.stack });
    res.status(500).json({
      success: false,
      message: "Günlük özet alınırken hata oluştu"
    });
  }
}

async function getDailyHistory(req, res) {
  try {
    await ensureFinanceSchema();
    const client = await db.pool.connect();

    try {
      const today = new Date();
      const defaultEnd = new Date(today.getFullYear(), today.getMonth(), today.getDate());
      const defaultStart = new Date(defaultEnd);
      defaultStart.setDate(defaultEnd.getDate() - 29);

      const startDateParam = req.query?.startDate?.toString();
      const endDateParam = req.query?.endDate?.toString();

      const startDate = startDateParam
        ? new Date(startDateParam)
        : defaultStart;
      const endDate = endDateParam
        ? new Date(endDateParam)
        : defaultEnd;

      let safeStartDate = Number.isNaN(startDate.getTime())
        ? defaultStart
        : new Date(startDate.getFullYear(), startDate.getMonth(), startDate.getDate());
      let safeEndDate = Number.isNaN(endDate.getTime())
        ? defaultEnd
        : new Date(endDate.getFullYear(), endDate.getMonth(), endDate.getDate());

      if (safeStartDate > safeEndDate) {
        const temp = safeStartDate;
        safeStartDate = safeEndDate;
        safeEndDate = temp;
      }

      const maxRangeDays = 365;
      const rangeDays = Math.floor((safeEndDate.getTime() - safeStartDate.getTime()) / 86400000) + 1;
      const finalStartDate = rangeDays > maxRangeDays
        ? new Date(safeEndDate.getTime() - (maxRangeDays - 1) * 86400000)
        : safeStartDate;

      const formatLocalDate = (date) => {
        const year = date.getFullYear();
        const month = String(date.getMonth() + 1).padStart(2, '0');
        const day = String(date.getDate()).padStart(2, '0');
        return `${year}-${month}-${day}`;
      };

      const { rows } = await client.query(
        `
          WITH date_range AS (
            SELECT (gs.date)::date as day
            FROM generate_series($1::date, $2::date, interval '1 day') AS gs(date)
          ),
          payment_data AS (
            SELECT
              (timezone('Europe/Istanbul', paid_at) - interval '3 hours')::date AS day,
              COALESCE(SUM(amount), 0) AS total_revenue,
              COALESCE(SUM(CASE WHEN payment_method = 'CASH' THEN amount ELSE 0 END), 0) AS cash_total,
              COALESCE(SUM(CASE WHEN payment_method = 'CARD' THEN amount ELSE 0 END), 0) AS card_total
            FROM payments
            WHERE (timezone('Europe/Istanbul', paid_at) - interval '3 hours')::date >= $1::date
              AND (timezone('Europe/Istanbul', paid_at) - interval '3 hours')::date <= $2::date
            GROUP BY 1
          ),
          expense_data AS (
            SELECT
              expense_date AS day,
              COALESCE(SUM(total_amount), 0) AS total_expense
            FROM expenses
            WHERE expense_date >= $1::date
              AND expense_date <= $2::date
            GROUP BY 1
          )
          SELECT
            dr.day as date,
            GREATEST(COALESCE(z.total_revenue, 0), COALESCE(pd.total_revenue, 0)) AS total_revenue,
            GREATEST(COALESCE(z.cash_total, 0), COALESCE(pd.cash_total, 0)) AS cash_total,
            GREATEST(COALESCE(z.card_total, 0), COALESCE(pd.card_total, 0)) AS card_total,
            COALESCE(ed.total_expense, 0) AS total_expense
          FROM date_range dr
          LEFT JOIN z_reports z ON z.report_date = dr.day
          LEFT JOIN payment_data pd ON pd.day = dr.day
          LEFT JOIN expense_data ed ON ed.day = dr.day
          ORDER BY dr.day DESC
        `,
        [
          formatLocalDate(finalStartDate),
          formatLocalDate(safeEndDate),
        ]
      );

      res.status(200).json({
        success: true,
        data: rows.map((row) => ({
          date: row.date,
          totalRevenue: Number(row.total_revenue || 0),
          cashTotal: Number(row.cash_total || 0),
          cardTotal: Number(row.card_total || 0),
          totalExpense: Number(row.total_expense || 0),
        })),
      });
    } finally {
      client.release();
    }
  } catch (error) {
    logger.error("Daily history error", { message: error.message, stack: error.stack });
    res.status(500).json({
      success: false,
      message: "Günlük geçmiş verileri alınırken hata oluştu"
    });
  }
}

async function generateZReport(req, res) {
  try {
    await ensureFinanceSchema();
    const client = await db.pool.connect();
    
    try {
      const { periodStart, periodEnd, businessDateText, businessDate } =
        await getCurrentReportPeriod(client);
      
      // Bugün alınan tüm ödemelerin detayları
      const { rows } = await client.query(
        `
          SELECT 
            COUNT(DISTINCT p.order_id) as total_orders,
            COALESCE(SUM(p.amount), 0) as total_revenue,
            COALESCE(SUM(CASE WHEN p.payment_method = 'CASH' THEN p.amount ELSE 0 END), 0) as cash_total,
            COALESCE(SUM(CASE WHEN p.payment_method = 'CARD' THEN p.amount ELSE 0 END), 0) as card_total,
            COALESCE(SUM(p.amount / 1.1), 0) as total_subtotal,
            COALESCE(SUM(p.amount - (p.amount / 1.1)), 0) as total_vat,
            STRING_AGG(
              '#' || o.id || ' - Masa: ' || t.display_name || ' - ' || p.payment_method || ' - ' || p.amount || ' TL', 
              E'\n'
              ORDER BY p.paid_at DESC
            ) as order_details
          FROM payments p
          JOIN orders o ON o.id = p.order_id
          JOIN tables t ON t.id = o.table_id
          WHERE p.paid_at >= $1 
            AND p.paid_at < $2
        `,
        [periodStart, periodEnd]
      );
      
      const result = rows[0];
      const totalOrders = parseInt(result.total_orders || 0, 10);
      const totalRevenue = parseFloat(result.total_revenue || 0);
      const totalSubtotal = parseFloat(result.total_subtotal || 0);
      const totalVat = parseFloat(result.total_vat || 0);

      if (totalOrders === 0 && totalRevenue === 0 && totalSubtotal === 0 && totalVat === 0) {
        return res.status(400).json({
          success: false,
          message: "Z raporu boş olduğu için alınmıyor.",
        });
      }

      const { rows: paymentRows } = await client.query(
        `
          SELECT
            p.order_id,
            p.payment_method,
            p.amount,
            p.paid_at,
            t.display_name AS table_name,
            u.full_name AS cashier_name
          FROM payments p
          JOIN orders o ON o.id = p.order_id
          JOIN tables t ON t.id = o.table_id
          LEFT JOIN users u ON u.id = p.received_by_user_id
          WHERE p.paid_at >= $1
            AND p.paid_at < $2
          ORDER BY p.paid_at ASC, p.id ASC
        `,
        [periodStart, periodEnd]
      );

      const { rows: expenseRows } = await client.query(
        `
          SELECT
            item_name,
            quantity,
            unit_price,
            total_amount,
            note,
            created_at
          FROM expenses
          WHERE created_at >= $1
            AND created_at < $2
          ORDER BY created_at ASC, id ASC
        `,
        [periodStart, periodEnd]
      );

      const { rows: productRows } = await client.query(
        `
          SELECT
            COALESCE(NULLIF(oi.category_snapshot, ''), c.name, 'Diğer') AS category_name,
            oi.product_name_snapshot AS product_name,
            COALESCE(SUM(oi.quantity), 0) AS total_quantity,
            COALESCE(SUM(oi.line_total), 0) AS total_revenue
          FROM order_items oi
          JOIN orders o ON o.id = oi.order_id
          LEFT JOIN products p ON p.id = oi.product_id
          LEFT JOIN categories c ON c.id = p.category_id
          WHERE oi.item_status <> 'VOID'
            AND o.id IN (
              SELECT DISTINCT order_id
              FROM payments
              WHERE paid_at >= $1
                AND paid_at < $2
            )
          GROUP BY category_name, oi.product_name_snapshot
          ORDER BY category_name ASC, total_revenue DESC
        `,
        [periodStart, periodEnd]
      );

      const { rows: adjustmentRows } = await client.query(
        `
          WITH discount_events AS (
            SELECT
              p.paid_at AS event_at,
              'INDIRIM'::text AS event_type,
              p.order_id,
              t.display_name AS table_name,
              NULL::text AS product_name,
              NULL::numeric AS quantity,
              COALESCE(p.discount_amount, 0)::numeric AS amount,
              COALESCE(NULLIF(TRIM(p.payment_note), ''), 'Odeme sirasinda indirim uygulandi') AS reason,
              COALESCE(u.full_name, '-') AS user_name
            FROM payments p
            JOIN orders o ON o.id = p.order_id
            JOIN tables t ON t.id = o.table_id
            LEFT JOIN users u ON u.id = p.received_by_user_id
            WHERE p.paid_at >= $1
              AND p.paid_at < $2
              AND COALESCE(p.discount_amount, 0) > 0
          ),
          void_events AS (
            SELECT
              v.created_at AS event_at,
              CASE WHEN v.action_type = 'COMP' THEN 'IKRAM' ELSE 'URUN_IPTAL' END AS event_type,
              v.order_id,
              t.display_name AS table_name,
              COALESCE(p.name, oi.product_name_snapshot, '-') AS product_name,
              COALESCE(v.quantity, 0)::numeric AS quantity,
              ROUND(COALESCE(v.quantity, 0) * COALESCE(oi.unit_price_snapshot, p.price, 0), 2)::numeric AS amount,
              COALESCE(NULLIF(TRIM(v.reason), ''), 'Urun hareketi') AS reason,
              COALESCE(u.full_name, '-') AS user_name
            FROM voids v
            JOIN orders o ON o.id = v.order_id
            JOIN tables t ON t.id = o.table_id
            LEFT JOIN order_items oi ON oi.id = v.order_item_id
            LEFT JOIN products p ON p.id = v.product_id
            LEFT JOIN users u ON u.id = v.created_by_user_id
            WHERE v.created_at >= $1
              AND v.created_at < $2
          ),
          cancelled_orders AS (
            SELECT
              o.updated_at AS event_at,
              'SIPARIS_IPTAL'::text AS event_type,
              o.id AS order_id,
              t.display_name AS table_name,
              NULL::text AS product_name,
              NULL::numeric AS quantity,
              COALESCE((
                SELECT SUM(oi2.line_total)
                FROM order_items oi2
                WHERE oi2.order_id = o.id
              ), 0)::numeric AS amount,
              'Siparis iptal edildi / masadan silindi'::text AS reason,
              COALESCE(u.full_name, '-') AS user_name
            FROM orders o
            JOIN tables t ON t.id = o.table_id
            LEFT JOIN users u ON u.id = o.closed_by_user_id
            WHERE o.order_status = 'CANCELLED'
              AND o.updated_at >= $1
              AND o.updated_at < $2
          )
          SELECT *
          FROM (
            SELECT * FROM discount_events
            UNION ALL
            SELECT * FROM void_events
            UNION ALL
            SELECT * FROM cancelled_orders
          ) all_events
          ORDER BY event_at ASC, order_id ASC
        `,
        [periodStart, periodEnd]
      );

      const reportPayload = {
        date: new Date(),
        totalRevenue: parseFloat(result.total_revenue) || 0,
        cashTotal: parseFloat(result.cash_total) || 0,
        cardTotal: parseFloat(result.card_total) || 0,
        totalOrders: parseInt(result.total_orders) || 0,
        totalSubtotal: parseFloat(result.total_subtotal) || 0,
        totalVat: parseFloat(result.total_vat) || 0,
        orderDetails: result.order_details || "Bugün kapanan adisyon bulunamadı.",
        totalExpenses: expenseRows.reduce(
          (sum, row) => sum + Number(row.total_amount || 0),
          0
        ),
      };

      const generalCashRegister = reportPayload.totalRevenue - reportPayload.totalExpenses;
      const generalCashStatus = reportPayload.cashTotal - reportPayload.totalExpenses;

      await client.query(
        `
          INSERT INTO z_reports (
            report_date,
            total_revenue,
            cash_total,
            card_total,
            total_orders,
            total_subtotal,
            total_vat,
            generated_by_user_id,
            payload,
            updated_at
          )
          VALUES ($1::date, $2, $3, $4, $5, $6, $7, $8, $9::jsonb, NOW())
          ON CONFLICT ON CONSTRAINT z_reports_report_date_key
          DO UPDATE SET
            total_revenue = EXCLUDED.total_revenue,
            cash_total = EXCLUDED.cash_total,
            card_total = EXCLUDED.card_total,
            total_orders = EXCLUDED.total_orders,
            total_subtotal = EXCLUDED.total_subtotal,
            total_vat = EXCLUDED.total_vat,
            generated_by_user_id = EXCLUDED.generated_by_user_id,
            payload = EXCLUDED.payload,
            updated_at = NOW()
        `,
        [
          businessDateText,
          reportPayload.totalRevenue,
          reportPayload.cashTotal,
          reportPayload.cardTotal,
          reportPayload.totalOrders,
          reportPayload.totalSubtotal,
          reportPayload.totalVat,
          req.user?.user_id ?? null,
          JSON.stringify(reportPayload),
        ]
      );

      const excelPath = await excelReportService.appendZReportToExcel({
        date: new Date(),
        workbookDate: businessDate,
        cashTotal: reportPayload.cashTotal,
        cardTotal: reportPayload.cardTotal,
        totalRevenue: reportPayload.totalRevenue,
        totalOrders: reportPayload.totalOrders,
        totalExpenses: reportPayload.totalExpenses,
        generalCashRegister,
        generalCashStatus,
        payments: paymentRows.map((row) => ({
          orderId: Number(row.order_id || 0),
          paymentMethod: row.payment_method,
          amount: Number(row.amount || 0),
          paidAt: row.paid_at,
          tableName: row.table_name,
          cashierName: row.cashier_name || "-",
        })),
        expenses: expenseRows.map((row) => ({
          itemName: row.item_name,
          quantity: Number(row.quantity || 0),
          unitPrice: Number(row.unit_price || 0),
          totalAmount: Number(row.total_amount || 0),
          note: row.note || "",
          createdAt: row.created_at,
        })),
        productSales: productRows.map((row) => ({
          categoryName: row.category_name,
          productName: row.product_name,
          quantity: Number(row.total_quantity || 0),
          revenue: Number(row.total_revenue || 0),
        })),
        adjustments: adjustmentRows.map((row) => ({
          eventAt: row.event_at,
          eventType: row.event_type,
          orderId: Number(row.order_id || 0),
          tableName: row.table_name || "-",
          productName: row.product_name || "",
          quantity: row.quantity == null ? null : Number(row.quantity || 0),
          amount: Number(row.amount || 0),
          reason: row.reason || "",
          userName: row.user_name || "-",
        })),
      });

      const io = req.app.get("io");
      if (io) {
        io.emit("tables:refresh", { at: new Date().toISOString() });
        io.emit("orders:refresh", { at: new Date().toISOString() });
        io.emit("new-order", { at: new Date().toISOString() });
      }
      
      res.json({
        success: true,
        message: "Gün sonu başarıyla alındı. Veriler Excel'e kaydedildi.",
        data: {
          reportDate: new Date(`${businessDateText}T23:59:59`).toISOString(),
          totalRevenue: reportPayload.totalRevenue,
          cashTotal: reportPayload.cashTotal,
          cardTotal: reportPayload.cardTotal,
          totalOrders: reportPayload.totalOrders,
          totalSubtotal: reportPayload.totalSubtotal,
          totalVat: reportPayload.totalVat,
          totalExpenses: reportPayload.totalExpenses,
          generalCashRegister,
          generalCashStatus,
          orderDetails: reportPayload.orderDetails,
          date: businessDateText,
          excelPath,
        }
      });
      
    } finally {
      client.release();
    }
  } catch (error) {
    logger.error("Z Report error", { message: error.message, stack: error.stack });
    res.status(500).json({
      success: false,
      message: "Z Raporu oluşturulurken hata oluştu"
    });
  }
}

async function exportZReportExcel(req, res) {
  let client;
  try {
    client = await db.pool.connect();
    const now = new Date();
    const businessDateText = getBusinessDateText(now, 3);
    const businessDate = getBusinessDate(now, 3);

    const { rows } = await client.query(
      `SELECT 1 FROM z_reports WHERE report_date = $1 LIMIT 1`,
      [businessDateText]
    );

    if (rows.length === 0) {
      return res.status(404).json({
        success: false,
        message: "Excel raporu yalnızca gün sonu alındıktan sonra indirilebilir.",
      });
    }

    const workbookPath = excelReportService.getWorkbookPath(businessDate);
    if (!fs.existsSync(workbookPath)) {
      return res.status(404).json({
        success: false,
        message: "Henüz Excel raporu oluşturulmadı.",
      });
    }

    const year = businessDate.getFullYear();
    const month = String(businessDate.getMonth() + 1).padStart(2, "0");
    const fileName = `gun-sonu-${year}-${month}.xlsx`;
    res.download(workbookPath, fileName);
  } catch (error) {
    logger.error("Z Report excel download error", {
      message: error.message,
      stack: error.stack,
    });
    res.status(500).json({
      success: false,
      message: "Excel raporu indirilirken hata oluştu",
    });
  } finally {
    if (client) {
      client.release();
    }
  }
}

async function getPaidTransactions(req, res) {
  try {
    await ensureFinanceSchema();
    const client = await db.pool.connect();

    try {
      const page = Math.max(1, parseInt(req.query.page) || 1);
      const limit = Math.min(100, Math.max(1, parseInt(req.query.limit) || 50));
      const offset = (page - 1) * limit;

      const startDate = req.query.startDate;
      const endDate = req.query.endDate;
      const minAmount = req.query.minAmount;
      const maxAmount = req.query.maxAmount;
      const paymentMethod = req.query.paymentMethod;
      const sortBy = ["paid_at", "amount"].includes(req.query.sortBy) ? req.query.sortBy : "paid_at";
      const sortOrder = req.query.sortOrder === "ASC" ? "ASC" : "DESC";

      let whereClauses = [];
      let params = [];

      if (startDate) {
        params.push(startDate);
        whereClauses.push(`p.paid_at >= $${params.length}`);
      }
      if (endDate) {
        params.push(endDate);
        whereClauses.push(`p.paid_at <= $${params.length}`);
      }
      if (minAmount) {
        params.push(minAmount);
        whereClauses.push(`p.amount >= $${params.length}`);
      }
      if (maxAmount) {
        params.push(maxAmount);
        whereClauses.push(`p.amount <= $${params.length}`);
      }
      if (paymentMethod) {
        params.push(paymentMethod);
        whereClauses.push(`p.payment_method = $${params.length}`);
      }

      // If no date filters, default to current period
      if (!startDate && !endDate) {
        const { periodStart, periodEnd } = await getCurrentReportPeriod(client);
        params.push(periodStart, periodEnd);
        whereClauses.push(`p.paid_at >= $${params.length - 1}`);
        whereClauses.push(`p.paid_at < $${params.length}`);
      }

      const whereSql = whereClauses.length > 0 ? "WHERE " + whereClauses.join(" AND ") : "";

      const countQuery = `
        SELECT COUNT(*) as total
        FROM payments p
        JOIN orders o ON o.id = p.order_id
        ${whereSql}
      `;
      const { rows: countRows } = await client.query(countQuery, params);
      const totalItems = parseInt(countRows[0].total);

      const query = `
        SELECT
          p.id,
          p.order_id,
          p.payment_method,
          p.amount,
          p.paid_at,
          p.payment_note,
          t.display_name AS table_name,
          u.full_name AS cashier_name
        FROM payments p
        JOIN orders o ON o.id = p.order_id
        JOIN tables t ON t.id = o.table_id
        LEFT JOIN users u ON u.id = p.received_by_user_id
        ${whereSql}
        ORDER BY ${sortBy === "amount" ? "p.amount" : "p.paid_at"} ${sortOrder}, p.id DESC
        LIMIT $${params.length + 1} OFFSET $${params.length + 2}
      `;

      const { rows } = await client.query(query, [...params, limit, offset]);

      res.json({
        success: true,
        data: {
          total: totalItems,
          page,
          limit,
          totalPages: Math.ceil(totalItems / limit),
          transactions: rows.map((row) => ({
            id: Number(row.id),
            orderId: Number(row.order_id),
            tableName: row.table_name,
            paymentMethod: row.payment_method,
            amount: Number(row.amount || 0),
            paidAt: row.paid_at,
            cashierName: row.cashier_name || "-",
            note: row.payment_note || ""
          })),
        },
      });
    } finally {
      client.release();
    }
  } catch (error) {
    logger.error("Paid transactions error", { message: error.message, stack: error.stack });
    res.status(500).json({
      success: false,
      message: "Tahsilat listesi alınırken hata oluştu",
    });
  }
}

function printZReport({
  date,
  totalRevenue,
  cashTotal,
  cardTotal,
  totalOrders,
  totalSubtotal,
  totalVat,
  orderDetails,
}) {
  // Yazıcı sesi simülasyonu
  logger.info("[Z-REPORT] Sanal fiş çıktısı hazırlanıyor");
  
  const dateStr = date.toLocaleDateString('tr-TR', { 
    day: '2-digit', 
    month: '2-digit', 
    year: 'numeric' 
  });
  
  const lines = [
    "",
    "*************************************************",
    "*                                               *",
    "*           *** Z RAPORU ***                     *",
    "*                                               *",
    "*************************************************",
    "",
    `TARİH: ${dateStr}`,
    `RAPOR SAATİ: ${new Date().toLocaleTimeString('tr-TR')}`,
    "",
    "=================================================",
    "                  GÜNLÜK ÖZET                    ",
    "=================================================",
    "",
    `TOPLAM CİRO        : ${totalRevenue.toFixed(2)} TL`,
    `NAKİT TOPLAMI      : ${cashTotal.toFixed(2)} TL`,
    `KART TOPLAMI       : ${cardTotal.toFixed(2)} TL`,
    `TOPLAM ADİSYON      : ${totalOrders} ADET`,
    `ARA TOPLAM          : ${totalSubtotal.toFixed(2)} TL`,
    `TOPLAM KDV          : ${totalVat.toFixed(2)} TL`,
    "",
    "=================================================",
    "                KAPANAN ADİSYONLAR                 ",
    "=================================================",
    "",
    orderDetails,
    "",
    "=================================================",
    "",
    "*************************************************",
    "*                                               *",
    "*           GÜN İÇİ RAPOR SONU                  *",
    "*                                               *",
    "*************************************************",
    "",
    "© 2026 RESTORAN YÖNETİM SİSTEMİ",
    ""
  ];
  
  logger.info(lines.join("\n"));
}

async function getStats(req, res) {
  try {
    await ensureFinanceSchema();
    const client = await db.pool.connect();
    
    try {
      // Haftalık ciro verileri (Pazartesi-Pazar)
      const { rows: weeklyRevenue } = await client.query(
        `
          WITH day_names AS (
            SELECT 
              1 as iso_day, 'Pazartesi' as day_name
            UNION ALL SELECT 2, 'Salı'
            UNION ALL SELECT 3, 'Çarşamba'
            UNION ALL SELECT 4, 'Perşembe'
            UNION ALL SELECT 5, 'Cuma'
            UNION ALL SELECT 6, 'Cumartesi'
            UNION ALL SELECT 7, 'Pazar'
          ),
          daily_totals AS (
            SELECT 
              EXTRACT(ISODOW FROM paid_at) as iso_day,
              COALESCE(SUM(amount), 0) as daily_revenue
            FROM payments 
            WHERE paid_at >= NOW() - INTERVAL '7 days'
            GROUP BY EXTRACT(ISODOW FROM paid_at)
          )
          SELECT 
            dn.iso_day,
            dn.day_name,
            COALESCE(dt.daily_revenue, 0) as daily_revenue
          FROM day_names dn
          LEFT JOIN daily_totals dt ON dn.iso_day = dt.iso_day
          ORDER BY dn.iso_day
        `
      );

      // En çok satan ilk 5 ürün
      const { rows: topProducts } = await client.query(
        `
          SELECT 
            p.name as product_name,
            COALESCE(SUM(oi.quantity), 0) as total_quantity,
            COALESCE(SUM(oi.line_total), 0) as total_revenue
          FROM order_items oi
          JOIN orders o ON oi.order_id = o.id
          JOIN products p ON oi.product_id = p.id
          WHERE o.order_status = 'PAID'
            AND o.closed_at >= NOW() - INTERVAL '30 days'
          GROUP BY p.id, p.name
          ORDER BY total_quantity DESC
          LIMIT 5
        `
      );

      // Kategori bazlı satış dağılımı (son 30 gün)
      const { rows: categorySales } = await client.query(
        `
          SELECT 
            COALESCE(NULLIF(oi.category_snapshot, ''), c.name, 'Diğer') as category_name,
            COALESCE(SUM(oi.line_total), 0) as total_revenue,
            COALESCE(SUM(oi.quantity), 0) as total_quantity
          FROM order_items oi
          JOIN orders o ON oi.order_id = o.id
          LEFT JOIN products p ON oi.product_id = p.id
          LEFT JOIN categories c ON p.category_id = c.id
          WHERE o.order_status = 'PAID'
            AND o.closed_at >= NOW() - INTERVAL '30 days'
            AND oi.item_status <> 'VOID'
          GROUP BY category_name
          ORDER BY total_revenue DESC
        `
      );

      res.json({
        success: true,
        data: {
          weeklyRevenue: weeklyRevenue.map(row => ({
            dayName: row.day_name,
            revenue: parseFloat(row.daily_revenue) || 0,
            dayOfWeek: parseInt(row.iso_day),
          })),
          topProducts: topProducts.map(row => ({
            name: row.product_name,
            quantity: parseFloat(row.total_quantity) || 0,
            revenue: parseFloat(row.total_revenue) || 0,
          })),
          categorySales: categorySales.map(row => ({
            name: row.category_name,
            revenue: parseFloat(row.total_revenue) || 0,
            quantity: parseFloat(row.total_quantity) || 0,
          })),
        }
      });
      
    } finally {
      client.release();
    }
  } catch (error) {
    logger.error("Stats error", { message: error.message, stack: error.stack });
    res.status(500).json({
      success: false,
      message: "İstatistikler alınırken hata oluştu"
    });
  }
}

async function getFinanceSummary(req, res) {
  try {
    await ensureFinanceSchema();
    const client = await db.pool.connect();

    try {
      const requestedDays = Number(req.query?.days ?? 30);
      const days = !Number.isFinite(requestedDays)
        ? 30
        : Math.min(Math.max(Math.trunc(requestedDays), 1), 365);

      const { rows } = await client.query(
        `
          WITH date_window AS (
            SELECT (CURRENT_DATE - ($1::int - 1) * INTERVAL '1 day')::date AS start_date
          ),
          z AS (
            SELECT
              COALESCE(SUM(total_revenue), 0) AS total_revenue,
              COALESCE(SUM(cash_total), 0) AS cash_total,
              COALESCE(SUM(card_total), 0) AS card_total,
              COALESCE(SUM(total_orders), 0) AS total_orders,
              COUNT(*)::int AS report_days
            FROM z_reports, date_window
            WHERE report_date >= date_window.start_date
              AND report_date <= CURRENT_DATE
          ),
          e AS (
            SELECT
              COALESCE(SUM(total_amount), 0) AS total_expense,
              COUNT(*)::int AS expense_count
            FROM expenses, date_window
            WHERE expense_date >= date_window.start_date
              AND expense_date <= CURRENT_DATE
          )
          SELECT
            z.total_revenue,
            z.cash_total,
            z.card_total,
            z.total_orders,
            z.report_days,
            e.total_expense,
            e.expense_count,
            (z.total_revenue - e.total_expense) AS net_cash
          FROM z, e
        `,
        [days]
      );

      const summary = rows[0] || {};
      return res.status(200).json({
        success: true,
        data: {
          days,
          totalRevenue: Number(summary.total_revenue || 0),
          totalCash: Number(summary.cash_total || 0),
          totalCard: Number(summary.card_total || 0),
          totalOrders: Number(summary.total_orders || 0),
          reportDays: Number(summary.report_days || 0),
          totalExpense: Number(summary.total_expense || 0),
          expenseCount: Number(summary.expense_count || 0),
          netCash: Number(summary.net_cash || 0),
        },
      });
    } finally {
      client.release();
    }
  } catch (error) {
    logger.error("Finance summary error", {
      message: error.message,
      stack: error.stack,
    });
    return res.status(500).json({
      success: false,
      message: "Kasa özeti alınırken hata oluştu",
    });
  }
}

async function listExpenses(req, res) {
  try {
    await ensureFinanceSchema();
    const client = await db.pool.connect();

    try {
      const page = Math.max(1, parseInt(req.query.page) || 1);
      const limit = Math.min(100, Math.max(1, parseInt(req.query.limit) || 50));
      const offset = (page - 1) * limit;

      const startDate = req.query.startDate;
      const endDate = req.query.endDate;
      const minAmount = req.query.minAmount;
      const maxAmount = req.query.maxAmount;
      const search = req.query.search;
      const sortBy = ["expense_date", "total_amount"].includes(req.query.sortBy) ? req.query.sortBy : "expense_date";
      const sortOrder = req.query.sortOrder === "ASC" ? "ASC" : "DESC";

      const currentPeriodOnly = req.query?.currentPeriodOnly === 'true';

      let whereClauses = [];
      let params = [];

      if (currentPeriodOnly) {
        const { periodStart } = await getCurrentReportPeriod(client);
        params.push(periodStart);
        whereClauses.push(`e.created_at >= $${params.length}`);
      } else {
        if (startDate) {
          params.push(startDate);
          whereClauses.push(`e.expense_date >= $${params.length}`);
        }
        if (endDate) {
          params.push(endDate);
          whereClauses.push(`e.expense_date <= $${params.length}`);
        }
      }

      if (minAmount) {
        params.push(minAmount);
        whereClauses.push(`e.total_amount >= $${params.length}`);
      }
      if (maxAmount) {
        params.push(maxAmount);
        whereClauses.push(`e.total_amount <= $${params.length}`);
      }
      if (search) {
        params.push(`%${search}%`);
        whereClauses.push(`e.item_name ILIKE $${params.length}`);
      }

      const whereSql = whereClauses.length > 0 ? "WHERE " + whereClauses.join(" AND ") : "";

      const countQuery = `
        SELECT COUNT(*) as total
        FROM expenses e
        ${whereSql}
      `;
      const { rows: countRows } = await client.query(countQuery, params);
      const totalItems = parseInt(countRows[0].total);

      const query = `
        SELECT
          e.id, e.expense_date, e.item_name, e.quantity, e.unit_price, e.total_amount, e.note, e.created_at,
          u.full_name AS created_by
        FROM expenses e
        LEFT JOIN users u ON u.id = e.created_by_user_id
        ${whereSql}
        ORDER BY ${sortBy === "total_amount" ? "e.total_amount" : "e.expense_date"} ${sortOrder}, e.id DESC
        LIMIT $${params.length + 1} OFFSET $${params.length + 2}
      `;

      const { rows } = await client.query(query, [...params, limit, offset]);

      return res.status(200).json({
        success: true,
        data: {
          total: totalItems,
          page,
          limit,
          totalPages: Math.ceil(totalItems / limit),
          expenses: rows.map((row) => ({
            id: Number(row.id),
            expenseDate: row.expense_date,
            itemName: row.item_name,
            quantity: Number(row.quantity || 0),
            unitPrice: Number(row.unit_price || 0),
            totalAmount: Number(row.total_amount || 0),
            note: row.note || null,
            createdAt: row.created_at,
            createdBy: row.created_by || "-",
          })),
        },
      });
    } finally {
      client.release();
    }
  } catch (error) {
    logger.error("Expense list error", { message: error.message, stack: error.stack });
    return res.status(500).json({
      success: false,
      message: "Gider listesi alınırken hata oluştu",
    });
  }
}

async function createExpense(req, res) {
  try {
    await ensureFinanceSchema();
    const itemName = String(req.body?.item_name ?? "").trim();
    const quantity = Number(req.body?.quantity);
    const unitPrice = Number(req.body?.unit_price);
    const note = req.body?.note == null ? null : String(req.body.note).trim();
    const rawExpenseDate = String(req.body?.expense_date ?? "").trim();

    if (!itemName) {
      return res.status(400).json({ message: "item_name gerekli." });
    }
    if (!Number.isFinite(quantity) || quantity <= 0) {
      return res.status(400).json({ message: "quantity pozitif bir sayi olmali." });
    }
    if (!Number.isFinite(unitPrice) || unitPrice < 0) {
      return res.status(400).json({ message: "unit_price 0 veya pozitif olmali." });
    }

    const totalAmount = Number((quantity * unitPrice).toFixed(2));
    const expenseDate = rawExpenseDate || new Date().toISOString().slice(0, 10);

    const { rows } = await db.pool.query(
      `
        INSERT INTO expenses (
          expense_date,
          item_name,
          quantity,
          unit_price,
          total_amount,
          note,
          created_by_user_id
        )
        VALUES ($1::date, $2, $3, $4, $5, $6, $7)
        RETURNING id, expense_date, item_name, quantity, unit_price, total_amount, note, created_at
      `,
      [
        expenseDate,
        itemName,
        quantity,
        unitPrice,
        totalAmount,
        note || null,
        req.user?.user_id || null,
      ]
    );

    return res.status(201).json({
      success: true,
      message: "Gider kaydedildi.",
      data: {
        id: Number(rows[0].id),
        expenseDate: rows[0].expense_date,
        itemName: rows[0].item_name,
        quantity: Number(rows[0].quantity || 0),
        unitPrice: Number(rows[0].unit_price || 0),
        totalAmount: Number(rows[0].total_amount || 0),
        note: rows[0].note || null,
        createdAt: rows[0].created_at,
      },
    });
  } catch (error) {
    logger.error("Expense create error", { message: error.message, stack: error.stack });
    return res.status(500).json({
      success: false,
      message: "Gider kaydı sırasında hata oluştu",
    });
  }
}

async function deleteExpense(req, res) {
  try {
    const expenseId = Number(req.params.id);
    if (!Number.isFinite(expenseId)) {
      return res.status(400).json({ message: "Geçersiz gider ID." });
    }

    await db.pool.query("DELETE FROM expenses WHERE id = $1", [expenseId]);

    return res.json({
      success: true,
      message: "Gider başarıyla silindi.",
    });
  } catch (error) {
    logger.error("Expense delete error", { message: error.message, stack: error.stack });
    return res.status(500).json({
      success: false,
      message: "Gider silinirken hata oluştu",
    });
  }
}

async function updateExpense(req, res) {
  try {
    await ensureFinanceSchema();
    const expenseId = Number(req.params.id);
    const itemName = req.body?.item_name ? String(req.body.item_name).trim() : undefined;
    const quantity = req.body?.quantity != null ? Number(req.body.quantity) : undefined;
    const unitPrice = req.body?.unit_price != null ? Number(req.body.unit_price) : undefined;
    const note = req.body?.note !== undefined ? (req.body.note == null ? null : String(req.body.note).trim()) : undefined;
    const expenseDate = req.body?.expense_date ? String(req.body.expense_date).trim() : undefined;

    if (!Number.isFinite(expenseId)) {
      return res.status(400).json({ message: "Geçersiz gider ID." });
    }

    // Get current record
    const { rows: currentRows } = await db.pool.query("SELECT * FROM expenses WHERE id = $1", [expenseId]);
    if (currentRows.length === 0) {
      return res.status(404).json({ message: "Gider kaydı bulunamadı." });
    }
    const current = currentRows[0];

    const finalItemName = itemName !== undefined ? itemName : current.item_name;
    const finalQuantity = quantity !== undefined ? quantity : Number(current.quantity);
    const finalUnitPrice = unitPrice !== undefined ? unitPrice : Number(current.unit_price);
    const finalNote = note !== undefined ? note : current.note;
    const finalExpenseDate = expenseDate !== undefined ? expenseDate : current.expense_date;

    if (!finalItemName) {
      return res.status(400).json({ message: "item_name boş olamaz." });
    }
    if (finalQuantity <= 0) {
      return res.status(400).json({ message: "quantity pozitif olmalı." });
    }
    if (finalUnitPrice < 0) {
      return res.status(400).json({ message: "unit_price 0 veya pozitif olmalı." });
    }

    const totalAmount = Number((finalQuantity * finalUnitPrice).toFixed(2));

    const { rows } = await db.pool.query(
      `
        UPDATE expenses
        SET item_name = $1,
            quantity = $2,
            unit_price = $3,
            total_amount = $4,
            note = $5,
            expense_date = $6,
            updated_at = NOW()
        WHERE id = $7
        RETURNING *
      `,
      [finalItemName, finalQuantity, finalUnitPrice, totalAmount, finalNote, finalExpenseDate, expenseId]
    );

    return res.json({
      success: true,
      message: "Gider güncellendi.",
      data: rows[0]
    });
  } catch (error) {
    logger.error("Expense update error", { message: error.message, stack: error.stack });
    return res.status(500).json({
      success: false,
      message: "Gider güncellenirken hata oluştu",
    });
  }
}

async function deletePayment(req, res) {
  const client = await db.pool.connect();
  try {
    const paymentId = Number(req.params.paymentId);
    if (!Number.isFinite(paymentId)) {
      return res.status(400).json({ message: "Geçersiz ödeme ID." });
    }

    await client.query("BEGIN");

    // Get order_id before deleting
    const { rows: paymentRows } = await client.query("SELECT order_id FROM payments WHERE id = $1", [paymentId]);
    if (paymentRows.length === 0) {
      await client.query("ROLLBACK");
      return res.status(404).json({ message: "Ödeme kaydı bulunamadı." });
    }
    const orderId = paymentRows[0].order_id;

    await client.query("DELETE FROM payments WHERE id = $1", [paymentId]);

    // Recalculate order status/method
    const { rows: remainingPayments } = await client.query("SELECT payment_method FROM payments WHERE order_id = $1", [orderId]);
    
    if (remainingPayments.length === 0) {
      // If no payments left, maybe set order back to OPEN? 
      // But usually we don't delete all payments. 
      // For now, set status to partially paid if there was an order status change logic.
      // Looking at the existing code, orders have order_status.
      await client.query("UPDATE orders SET order_status = 'OPEN', payment_method = NULL WHERE id = $1", [orderId]);
    } else {
      const methods = [...new Set(remainingPayments.map(p => p.payment_method))];
      const finalMethod = methods.length > 1 ? "MIXED" : methods[0];
      await client.query("UPDATE orders SET payment_method = $1 WHERE id = $2", [finalMethod, orderId]);
    }

    await client.query("COMMIT");

    return res.json({
      success: true,
      message: "Ödeme kaydı silindi.",
    });
  } catch (error) {
    if (client) await client.query("ROLLBACK");
    logger.error("Payment delete error", { message: error.message, stack: error.stack });
    return res.status(500).json({
      success: false,
      message: "Ödeme silinirken hata oluştu",
    });
  } finally {
    if (client) client.release();
  }
}

async function updatePaymentMethod(req, res) {
  const client = await db.pool.connect();
  try {
    const paymentId = Number(req.params.paymentId);
    const { paymentMethod } = req.body;

    if (!paymentId || !["CASH", "CARD"].includes(paymentMethod)) {
      return res.status(400).json({ message: "Geçersiz parametreler." });
    }

    await client.query("BEGIN");

    // 1. Ödemeyi güncelle (updated_at opsiyonel, hata vermemesi için şimdilik kaldırdık)
    const { rows: updatedPayment } = await client.query(
      `
        UPDATE payments
        SET payment_method = $2
        WHERE id = $1
        RETURNING order_id
      `,
      [paymentId, paymentMethod]
    );

    if (updatedPayment.length === 0) {
      await client.query("ROLLBACK");
      return res.status(404).json({ message: "Ödeme kaydı bulunamadı." });
    }

    const orderId = updatedPayment[0].order_id;

    // 2. Siparişin genel ödeme yöntemini yeniden hesapla
    const { rows: orderPayments } = await client.query(
      `
        SELECT DISTINCT payment_method
        FROM payments
        WHERE order_id = $1
      `,
      [orderId]
    );

    let finalMethod = paymentMethod;
    if (orderPayments.length > 1) {
      finalMethod = "MIXED";
    } else if (orderPayments.length === 1) {
      finalMethod = orderPayments[0].payment_method;
    }

    await client.query(
      `
        UPDATE orders
        SET payment_method = $2, updated_at = NOW()
        WHERE id = $1
      `,
      [orderId, finalMethod]
    );

    await client.query("COMMIT");

    return res.status(200).json({
      success: true,
      message: "Ödeme yöntemi güncellendi.",
    });
  } catch (error) {
    if (client) await client.query("ROLLBACK");
    logger.error("Update payment method error", { message: error.message, stack: error.stack });
    return res.status(500).json({
      success: false,
      message: "Ödeme yöntemi güncellenirken hata oluştu: " + error.message,
    });
  } finally {
    if (client) client.release();
  }
}

module.exports = {
  getXReport,
  printXReport,
  getDailySummary,
  getDailyHistory,
  generateZReport,
  exportZReportExcel,
  getStats,
  getPaidTransactions,
  getFinanceSummary,
  listExpenses,
  createExpense,
  updateExpense,
  deleteExpense,
  updatePaymentMethod,
  deletePayment,
};
