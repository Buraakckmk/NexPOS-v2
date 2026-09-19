require("dotenv").config({ override: true });

const db = require("../config/db");

const PRIMARY_CATEGORY_NAME = "APERATİFLER";
const CATEGORY_ALIASES = ["ATISTIRMALIKLAR", "ATIŞTIRMALIKLAR"];
const PRINTER_ROUTE = "MUTFAK";

const ITEMS = [
  { name: "Sıcak Sepet", price: 300.0 },
  { name: "Parmak Patates", price: 180.0 },
  { name: "Parmak Patates Ve Soğan Halkası", price: 220.0 },
  { name: "Elma Dilim Patates", price: 190.0 },
  { name: "Çıtır Tavuk Dilimleri", price: 250.0 },
  { name: "Dedikodu Tabağı", price: 400.0 },
];

async function resolveCategory(client) {
  const aliasResult = await client.query(
    `
      SELECT id, name
      FROM categories
      WHERE UPPER(name) = ANY($1::text[])
      ORDER BY id ASC
      LIMIT 1;
    `,
    [[PRIMARY_CATEGORY_NAME, ...CATEGORY_ALIASES].map((x) => x.toUpperCase())]
  );

  if (aliasResult.rowCount > 0) {
    const row = aliasResult.rows[0];
    await client.query(
      `
        UPDATE categories
        SET name = $2,
            printer_route = $3,
            is_active = TRUE,
            updated_at = NOW()
        WHERE id = $1;
      `,
      [row.id, PRIMARY_CATEGORY_NAME, PRINTER_ROUTE]
    );
    return row.id;
  }

  const created = await client.query(
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
    [PRIMARY_CATEGORY_NAME, PRINTER_ROUTE]
  );

  return created.rows[0].id;
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
      [categoryId, PRIMARY_CATEGORY_NAME, item.name, item.price]
    );
  }
}

async function fetchSummary(client, categoryId) {
  const result = await client.query(
    `
      SELECT name, price
      FROM products
      WHERE category_id = $1
      ORDER BY name ASC;
    `,
    [categoryId]
  );

  return result.rows;
}

async function run() {
  const client = await db.pool.connect();

  try {
    await client.query("BEGIN");

    const categoryId = await resolveCategory(client);
    await upsertProducts(client, categoryId);
    const products = await fetchSummary(client, categoryId);

    await client.query("COMMIT");

    console.log(`Kategori: ${PRIMARY_CATEGORY_NAME} (id=${categoryId})`);
    console.log(`Toplam urun: ${products.length}`);
    for (const row of products) {
      console.log(`- ${row.name}: ${row.price} TL`);
    }
  } catch (error) {
    await client.query("ROLLBACK");
    console.error("APERATİFLER seed hatasi:", error);
    process.exitCode = 1;
  } finally {
    client.release();
    await db.pool.end();
  }
}

run();
