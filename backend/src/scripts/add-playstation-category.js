const path = require("path");
require("dotenv").config({ path: path.join(__dirname, "..", "..", ".env"), override: true });
const db = require("../config/db");

async function run() {
  const client = await db.pool.connect();
  try {
    await client.query("BEGIN");

    // 1. Add "PLAYSTATION" Menu Category if not exists
    const { rows: existingCat } = await client.query(
      `SELECT id FROM categories WHERE UPPER(name) = 'PLAYSTATION'`
    );

    let catId;
    if (existingCat.length === 0) {
      const { rows: catInsert } = await client.query(
        `INSERT INTO categories (name, printer_route, is_active, sort_order) 
         VALUES ('PLAYSTATION', 'KASA', TRUE, 1) RETURNING id`
      );
      catId = catInsert[0].id;
      console.log(`Created menu category 'PLAYSTATION' with ID ${catId}`);

      // Add default PlayStation products
      await client.query(
        `INSERT INTO products (category_id, category, name, price, vat_rate, is_active) VALUES
         ($1, 'PLAYSTATION', 'PS5 - 1 Saat (Çift Kol)', 150.00, 20.00, TRUE),
         ($1, 'PLAYSTATION', 'PS5 - 1 Saat (Tek Kol)', 100.00, 20.00, TRUE),
         ($1, 'PLAYSTATION', 'PS4 - 1 Saat (Çift Kol)', 120.00, 20.00, TRUE),
         ($1, 'PLAYSTATION', 'PS4 - 1 Saat (Tek Kol)', 80.00, 20.00, TRUE),
         ($1, 'PLAYSTATION', 'Ekstra Kol (1 Saat)', 40.00, 20.00, TRUE)
         ON CONFLICT DO NOTHING`,
        [catId]
      );
    } else {
      catId = existingCat[0].id;
      console.log(`Menu category 'PLAYSTATION' already exists with ID ${catId}`);
    }

    // 2. Add PlayStation Table Zone tables (PS-1 to PS-10)
    for (let i = 1; i <= 10; i++) {
      const tableCode = `PS-${i}`;
      const displayName = `PlayStation ${i}`;
      await client.query(
        `INSERT INTO tables (table_code, display_name, zone, capacity, is_custom, is_active)
         VALUES ($1, $2, 'PlayStation', 4, FALSE, TRUE)
         ON CONFLICT (table_code) DO UPDATE SET is_active = TRUE, zone = 'PlayStation'`,
        [tableCode, displayName]
      );
    }
    console.log("PlayStation tables PS-1 to PS-10 added/activated.");

    await client.query("COMMIT");
    console.log("Successfully created PlayStation category & tables!");
  } catch (err) {
    await client.query("ROLLBACK");
    console.error("Failed to add PlayStation category:", err);
  } finally {
    client.release();
    process.exit(0);
  }
}

run();
