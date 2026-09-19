require("dotenv").config({ override: true });

const db = require("../config/db");

async function run() {
  const client = await db.pool.connect();

  try {
    await client.query("BEGIN");

    await client.query(`
      ALTER TABLE categories
      ADD COLUMN IF NOT EXISTS printer_route VARCHAR(20) NOT NULL DEFAULT 'MUTFAK';
    `);

    await client.query(`
      ALTER TABLE order_items
      ADD COLUMN IF NOT EXISTS printer_route_snapshot VARCHAR(20) NOT NULL DEFAULT 'MUTFAK';
    `);

    await client.query("COMMIT");

    console.log("Migration tamamlandi: printer_route alanlari guvenli sekilde eklendi.");
    console.log("- categories.printer_route (default: MUTFAK)");
    console.log("- order_items.printer_route_snapshot (default: MUTFAK)");
  } catch (error) {
    await client.query("ROLLBACK");
    console.error("Migration basarisiz:", error);
    process.exitCode = 1;
  } finally {
    client.release();
    await db.pool.end();
  }
}

run();
