const db = require("../config/db");
const {
  getBusinessDate,
  getBusinessDateText,
  getBusinessDayStart,
} = require("../utils/business-date");

async function getCurrentReportPeriod() {
  const { rows } = await db.query(`SELECT NOW() AS now_ts`);

  const now = new Date(rows[0].now_ts);
  const dayStart = getBusinessDayStart(now, 3);

  const { rows: resetRows } = await db.query(
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

  return {
    periodStart: lastResetAt ?? dayStart,
    periodEnd: now,
  };
}

/**
 * Günlük özet istatistiklerini hesaplar:
 * - Anlık Ciro: Bugün ödenen (kapanan) + şu an açık masalardaki mevcut siparişler
 * - Toplam Adisyon: Bugün içinde açılmış olan toplam masa/fiş sayısı
 * - Ortalama Süre: Bugün kapanan veya şu an açık olan masaların ortalama oturma süresi (dakika)
 * - Günün Yıldızı: Bugün adet bazında en çok sipariş edilen ürün
 */
async function getDailySummary() {
  const { periodStart, periodEnd } = await getCurrentReportPeriod();

  const query = `
    WITH paid_today AS (
      -- Son Z raporundan sonra yapılan ödemeler
      SELECT 
        COALESCE(SUM(amount), 0) as total,
        COUNT(DISTINCT order_id) as paid_orders
      FROM payments
      WHERE paid_at >= $1 AND paid_at < $2
    ),
    open_orders_total AS (
      -- Son reset döneminde açılmış ve hâlâ açık masaların toplamı
      SELECT SUM(o.grand_total) - COALESCE(SUM(p.total_paid), 0) as balance
      FROM orders o
      LEFT JOIN (
        SELECT order_id, SUM(amount) as total_paid
        FROM payments
        GROUP BY order_id
      ) p ON p.order_id = o.id
      WHERE o.order_status IN ('OPEN', 'CONFIRMED')
        AND o.opened_at >= $1
        AND o.opened_at < $2
    ),
    top_product AS (
      -- Son Z raporundan sonra en çok satılan ürün
      SELECT 
        product_name_snapshot as name,
        SUM(quantity) as total_qty
      FROM order_items
      WHERE created_at >= $1
        AND created_at < $2
        AND item_status <> 'VOID'
      GROUP BY product_name_snapshot
      ORDER BY total_qty DESC
      LIMIT 1
    ),
    avg_duration AS (
      -- Son Z raporundan sonra açılan masaların ortalama süresi
      SELECT 
        AVG(EXTRACT(EPOCH FROM (COALESCE(closed_at, NOW()) - opened_at)) / 60) as avg_mins
      FROM orders
      WHERE opened_at >= $1 AND opened_at < $2
    )
    SELECT
      -- Anlık Ciro = Bugün alınan ödemeler + Açık masalardaki bekleyen tutar
      (SELECT total FROM paid_today) + COALESCE((SELECT balance FROM open_orders_total), 0) as instant_revenue,
      -- Toplam Adisyon = Bugün ödeme yapılan toplam farklı adisyon sayısı
      (SELECT paid_orders FROM paid_today) as total_orders,
      -- Ortalama Süre
      COALESCE((SELECT avg_mins FROM avg_duration), 0) as average_duration,
      -- Günün Yıldızı
      (SELECT name FROM top_product) as star_product_name,
      (SELECT total_qty FROM top_product) as star_product_qty;
  `;

  const { rows } = await db.query(query, [periodStart, periodEnd]);
  const result = rows[0];

  return {
    instantRevenue: parseFloat(result.instant_revenue || 0),
    totalOrders: parseInt(result.total_orders || 0),
    averageDuration: Math.round(parseFloat(result.average_duration || 0)),
    starProduct: {
      name: result.star_product_name || "Henüz yok",
      quantity: parseFloat(result.star_product_qty || 0)
    }
  };
}

module.exports = {
  getDailySummary
};
