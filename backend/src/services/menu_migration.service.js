const db = require("../config/db");
const logger = require("../config/logger");

let migratePromise = null;

async function migrateMenuCategories() {
  if (migratePromise) {
    return migratePromise;
  }

  migratePromise = (async () => {
    const client = await db.pool.connect();

    try {
      await client.query("BEGIN");

      const hamburgerName = "HAMBURGERLER";
      const burgerName = "BURGERLER";

      const { rows: hamburgerRows } = await client.query(
        "SELECT id FROM categories WHERE name = $1",
        [hamburgerName]
      );
      const { rows: burgerRows } = await client.query(
        "SELECT id FROM categories WHERE name = $1",
        [burgerName]
      );

      const hamburgerId = hamburgerRows[0]?.id;
      const burgerId = burgerRows[0]?.id;

      if (burgerId && !hamburgerId) {
        await client.query(
          `
            UPDATE categories
            SET name = $1,
                is_active = TRUE,
                printer_route = 'MUTFAK',
                updated_at = NOW()
            WHERE id = $2;
          `,
          [hamburgerName, burgerId]
        );

        await client.query(
          `
            UPDATE products
            SET category = $1,
                updated_at = NOW()
            WHERE category_id = $2
              AND (category IS NULL OR category = '' OR category <> $1);
          `,
          [hamburgerName, burgerId]
        );
      } else if (burgerId && hamburgerId) {
        await client.query(
          `
            UPDATE products
            SET category_id = $1,
                category = $2,
                updated_at = NOW()
            WHERE category_id = $3 OR category = $4;
          `,
          [hamburgerId, hamburgerName, burgerId, burgerName]
        );

        await client.query(
          `
            UPDATE categories
            SET is_active = FALSE,
                updated_at = NOW()
            WHERE id = $1;
          `,
          [burgerId]
        );
      } else if (hamburgerId) {
        await client.query(
          `
            UPDATE categories
            SET is_active = TRUE,
                printer_route = 'MUTFAK',
                updated_at = NOW()
            WHERE id = $1;
          `,
          [hamburgerId]
        );

        await client.query(
          `
            UPDATE products
            SET category = $1,
                updated_at = NOW()
            WHERE category_id = $2
              AND (category IS NULL OR category = '' OR category <> $1);
          `,
          [hamburgerName, hamburgerId]
        );
      }

      const { rows: hotDrinkCats } = await client.query(
        `
          SELECT id
          FROM categories
          WHERE UPPER(name) IN ('SICAK İÇECEKLER', 'SICAK ICECEKLER');
        `
      );

      if (hotDrinkCats.length > 0) {
        const ids = hotDrinkCats.map((r) => r.id);

        await client.query(
          `
            UPDATE categories
            SET is_active = FALSE,
                updated_at = NOW()
            WHERE id = ANY($1::bigint[]);
          `,
          [ids]
        );

        await client.query(
          `
            UPDATE products
            SET is_active = FALSE,
                updated_at = NOW()
            WHERE category_id = ANY($1::bigint[])
               OR UPPER(category) IN ('SICAK İÇECEKLER', 'SICAK ICECEKLER');
          `,
          [ids]
        );
      }

      await client.query("COMMIT");
      logger.info("menu-migration: completed");
    } catch (error) {
      await client.query("ROLLBACK");
      logger.error("menu-migration: failed", {
        message: error.message,
        stack: error.stack,
      });
    } finally {
      client.release();
    }
  })();

  return migratePromise;
}

module.exports = {
  migrateMenuCategories,
};

