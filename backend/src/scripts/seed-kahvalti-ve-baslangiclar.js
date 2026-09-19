require("dotenv").config({ override: true });

const db = require("../config/db");

const CATEGORY_NAME = "KAHVALTI VE BAŞLANGIÇLAR";
const PRINTER_ROUTE = "MUTFAK";

const ITEMS = [
  { name: "Leb-i Derya Kahvaltı", price: 800.0 },
  { name: "İtalyan Kahvaltı", price: 200.0 },
  { name: "Sahanda Sucuklu Yumurta", price: 160.0 },
  { name: "Bal Kaymak", price: 160.0 },
  { name: "Peynir Tabağı", price: 220.0 },
  { name: "Gevrek Kahvaltı Soğuk", price: 230.0 },
  { name: "Gevrek Kahvaltı Sıcak", price: 250.0 },
  { name: "Kahvaltı Tabağı", price: 350.0 },
  { name: "Sahanda Yumurta", price: 120.0 },
  { name: "Ekmek Üstü", price: 450.0 },
  { name: "Pişi Kahvaltı", price: 450.0 },
  { name: "Omlet Deryası", price: 220.0 },
  { name: "Sade Omlet", price: 150.0 },
  { name: "Beyaz Peynirli Omlet", price: 170.0 },
  { name: "Kaşarlı Omlet", price: 175.0 },
  { name: "Sucuklu Omlet", price: 180.0 },
  { name: "Klasik Menemen", price: 170.0 },
  { name: "Kaşar Peynirli Menemen", price: 180.0 },
  { name: "Sucuklu Menemen", price: 190.0 },
  { name: "Karışık Menemen", price: 220.0 },
  { name: "Kalem Börek", price: 320.0 },
  { name: "Sigara Böreği", price: 170.0 },
];

async function upsertCategory(client) {
  const query = `
    INSERT INTO categories (name, printer_route, sort_order, is_active)
    VALUES ($1, $2, 999, TRUE)
    ON CONFLICT (name)
    DO UPDATE SET
      printer_route = EXCLUDED.printer_route,
      is_active = TRUE,
      updated_at = NOW()
    RETURNING id;
  `;

  const { rows } = await client.query(query, [CATEGORY_NAME, PRINTER_ROUTE]);
  return rows[0].id;
}

async function upsertProducts(client, categoryId) {
  for (const item of ITEMS) {
    await client.query(
      `
        INSERT INTO products (
          category_id,
          category,
          name,
          price,
          vat_rate,
          is_active
        )
        VALUES ($1, $2, $3, $4, 10.00, TRUE)
        ON CONFLICT (category_id, name)
        DO UPDATE SET
          category = EXCLUDED.category,
          price = EXCLUDED.price,
          is_active = TRUE,
          updated_at = NOW();
      `,
      [categoryId, CATEGORY_NAME, item.name, item.price]
    );
  }
}

async function fetchSummary(client, categoryId) {
  const summary = await client.query(
    `
      SELECT COUNT(*)::int AS count
      FROM products
      WHERE category_id = $1;
    `,
    [categoryId]
  );

  const sampleRows = await client.query(
    `
      SELECT name, price
      FROM products
      WHERE category_id = $1
      ORDER BY name ASC
      LIMIT 5;
    `,
    [categoryId]
  );

  return {
    count: summary.rows[0].count,
    sample: sampleRows.rows,
  };
}

async function run() {
  const client = await db.pool.connect();

  try {
    await client.query("BEGIN");

    const categoryId = await upsertCategory(client);
    await upsertProducts(client, categoryId);
    const result = await fetchSummary(client, categoryId);

    await client.query("COMMIT");

    console.log(`Kategori: ${CATEGORY_NAME} (id=${categoryId})`);
    console.log(`Toplam urun: ${result.count}`);
    console.log("Ornek urunler:");
    for (const row of result.sample) {
      console.log(`- ${row.name}: ${row.price} TL`);
    }
  } catch (error) {
    await client.query("ROLLBACK");
    console.error("KAHVALTI seed hatasi:", error);
    process.exitCode = 1;
  } finally {
    client.release();
    await db.pool.end();
  }
}

run();
