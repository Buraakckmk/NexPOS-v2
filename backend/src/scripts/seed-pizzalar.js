require("dotenv").config({ override: true });

const db = require("../config/db");

const CATEGORY_NAME = "PİZZALAR";
const PRINTER_ROUTE = "MUTFAK";

const ITEMS = [
  { name: "Ton Balıklı Pizza", price: 370.0 },
  { name: "Vejetaryen Pizza", price: 270.0 },
  { name: "Pastırmalı Pizza", price: 400.0 },
  { name: "Margarita Pizza", price: 270.0 },
  { name: "Karışık Pizza", price: 370.0 },
];

async function upsertCategory(client) {
  const { rows } = await client.query(
    `
      INSERT INTO categories (name, printer_route, sort_order, is_active)
      VALUES ($1, $2, 999, TRUE)
      ON CONFLICT (name)
      DO UPDATE SET
        printer_route = EXCLUDED.printer_route,
        is_active = TRUE,
        updated_at = NOW()
      RETURNING id;
    `,
    [CATEGORY_NAME, PRINTER_ROUTE]
  );

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

async function fetchProducts(client, categoryId) {
  const { rows } = await client.query(
    `
      SELECT name, price
      FROM products
      WHERE category_id = $1
      ORDER BY name ASC;
    `,
    [categoryId]
  );

  return rows;
}

async function run() {
  const client = await db.pool.connect();

  try {
    await client.query("BEGIN");
    const categoryId = await upsertCategory(client);
    await upsertProducts(client, categoryId);
    const products = await fetchProducts(client, categoryId);
    await client.query("COMMIT");

    console.log(`Kategori: ${CATEGORY_NAME} (id=${categoryId})`);
    console.log(`Toplam urun: ${products.length}`);
    for (const row of products) {
      console.log(`- ${row.name}: ${row.price} TL`);
    }
  } catch (error) {
    await client.query("ROLLBACK");
    console.error("PİZZALAR seed hatasi:", error);
    process.exitCode = 1;
  } finally {
    client.release();
    await db.pool.end();
  }
}

run();
