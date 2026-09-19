const path = require("path");
require("dotenv").config({ path: path.join(__dirname, "..", "..", ".env"), override: true });
const db = require("../config/db");

async function run() {
  const client = await db.pool.connect();
  try {
    await client.query("BEGIN");

    // 1. Deactivate tables in other zones (e.g. 'Salon')
    await client.query(`UPDATE tables SET is_active = FALSE WHERE zone NOT IN ('Oyun Salonu', 'VIP', 'PlayStation', 'Balkon')`);

    // 2. Change all 'Balkon' tables to 'Oyun Salonu'
    await client.query(`UPDATE tables SET zone = 'Oyun Salonu' WHERE zone = 'Balkon'`);

    // 3. Re-code and re-name active 'Oyun Salonu' tables sequentially
    const { rows: oyunTables } = await client.query(
      `SELECT id FROM tables WHERE zone = 'Oyun Salonu' AND is_active = TRUE ORDER BY id`
    );

    for (let i = 0; i < oyunTables.length; i++) {
      const num = i + 1;
      await client.query(
        `UPDATE tables SET table_code = $1, display_name = $2 WHERE id = $3`,
        [`OYUN-TEMP-${num}`, `Oyun Salonu ${num}`, oyunTables[i].id]
      );
    }
    for (let i = 0; i < oyunTables.length; i++) {
      const num = i + 1;
      await client.query(
        `UPDATE tables SET table_code = $1 WHERE id = $2`,
        [`OYUN-${num}`, oyunTables[i].id]
      );
    }

    // 4. Re-code and re-name active 'VIP' tables sequentially
    const { rows: vipTables } = await client.query(
      `SELECT id FROM tables WHERE zone = 'VIP' AND is_active = TRUE ORDER BY id`
    );

    for (let i = 0; i < vipTables.length; i++) {
      const num = i + 1;
      await client.query(
        `UPDATE tables SET table_code = $1, display_name = $2 WHERE id = $3`,
        [`VIP-TEMP-${num}`, `VIP ${num}`, vipTables[i].id]
      );
    }
    for (let i = 0; i < vipTables.length; i++) {
      const num = i + 1;
      await client.query(
        `UPDATE tables SET table_code = $1 WHERE id = $2`,
        [`VIP-${num}`, vipTables[i].id]
      );
    }

    await client.query("COMMIT");
    console.log(`Updated successfully! Oyun Salonu active count: ${oyunTables.length}, VIP active count: ${vipTables.length}`);
  } catch (err) {
    await client.query("ROLLBACK");
    console.error("Migration failed:", err);
  } finally {
    client.release();
    process.exit(0);
  }
}

run();
