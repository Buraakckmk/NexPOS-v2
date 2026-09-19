require("dotenv").config({ override: true });

const db = require("../config/db");

const PRINTER_ROUTE = "MUTFAK";

const CATEGORIES = [
  {
    name: "KREPLER",
    items: [
      { name: "Etli Krep", price: 450.0 },
      { name: "Tavuklu Krep", price: 350.0 },
    ],
  },
  {
    name: "SALATALAR",
    items: [
      { name: "Tavuklu Sezar Salata", price: 300.0 },
      { name: "Ege Usulü", price: 270.0 },
      { name: "Diyet Salata", price: 300.0 },
      { name: "Hellim Salata", price: 280.0 },
      { name: "Ton Balıklı Salata", price: 300.0 },
    ],
  },
];

async function upsertCategory(client, categoryName) {
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
    [categoryName, PRINTER_ROUTE]
  );

  return rows[0].id;
}

async function upsertProducts(client, categoryId, categoryName, items) {
  for (const item of items) {
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
      [categoryId, categoryName, item.name, item.price]
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

    for (const category of CATEGORIES) {
      const categoryId = await upsertCategory(client, category.name);
      await upsertProducts(client, categoryId, category.name, category.items);
      const products = await fetchProducts(client, categoryId);

      console.log(`Kategori: ${category.name} (id=${categoryId})`);
      console.log(`Toplam urun: ${products.length}`);
      for (const row of products) {
        console.log(`- ${row.name}: ${row.price} TL`);
      }
    }

    await client.query("COMMIT");
  } catch (error) {
    await client.query("ROLLBACK");
    console.error("KREPLER/SALATALAR seed hatasi:", error);
    process.exitCode = 1;
  } finally {
    client.release();
    await db.pool.end();
  }
}

run();
