require("dotenv").config({ override: true });

const db = require("../config/db");

const PRIMARY_CATEGORY_NAME = "SANDVİÇLER VE TOSTLAR";
const CATEGORY_ALIASES = ["SANDVICLER VE TOSTLAR", "SANDVİCLER VE TOSTLAR"];
const PRINTER_ROUTE = "MUTFAK";

const ITEMS = [
  { name: "Ton Balıklı Sandviç", price: 300.0 },
  { name: "Karışık Sandviç", price: 300.0 },
  { name: "Philly Steak", price: 400.0 },
  { name: "Club Sandviç", price: 320.0 },
  { name: "Kaşarlı Tost", price: 220.0 },
  { name: "Karışık Tost", price: 260.0 },
];

async function resolveCategory(client) {
  const aliasesUpper = [PRIMARY_CATEGORY_NAME, ...CATEGORY_ALIASES].map((x) =>
    x.toUpperCase()
  );

  const existing = await client.query(
    `
      SELECT id, name
      FROM categories
      WHERE UPPER(name) = ANY($1::text[])
      ORDER BY id ASC
      LIMIT 1;
    `,
    [aliasesUpper]
  );

  if (existing.rowCount > 0) {
    const categoryId = existing.rows[0].id;
    await client.query(
      `
        UPDATE categories
        SET name = $2,
            printer_route = $3,
            is_active = TRUE,
            updated_at = NOW()
        WHERE id = $1;
      `,
      [categoryId, PRIMARY_CATEGORY_NAME, PRINTER_ROUTE]
    );
    return categoryId;
  }

  const inserted = await client.query(
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

  return inserted.rows[0].id;
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
    const categoryId = await resolveCategory(client);
    await upsertProducts(client, categoryId);
    const products = await fetchProducts(client, categoryId);
    await client.query("COMMIT");

    console.log(`Kategori: ${PRIMARY_CATEGORY_NAME} (id=${categoryId})`);
    console.log(`Toplam urun: ${products.length}`);
    for (const row of products) {
      console.log(`- ${row.name}: ${row.price} TL`);
    }
  } catch (error) {
    await client.query("ROLLBACK");
    console.error("SANDVİÇLER VE TOSTLAR seed hatasi:", error);
    process.exitCode = 1;
  } finally {
    client.release();
    await db.pool.end();
  }
}

run();
