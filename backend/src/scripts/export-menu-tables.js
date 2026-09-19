/**
 * export-menu-tables.js
 * categories, products ve tables tablolarini SQL INSERT dosyasina aktar.
 * Kullanim: node src/scripts/export-menu-tables.js
 */

require("dotenv").config({ override: true });

const fs = require("fs");
const path = require("path");
const { Pool } = require("pg");

const pool = new Pool({
  host: process.env.DB_HOST || "127.0.0.1",
  port: Number(process.env.DB_PORT || 5432),
  
  database: process.env.DB_NAME || "adisyon_db",
  user: process.env.DB_USER || "postgres",
  password: process.env.DB_PASSWORD || "postgres",
});

function esc(val) {
  if (val === null || val === undefined) return "NULL";
  if (typeof val === "boolean") return val ? "TRUE" : "FALSE";
  if (typeof val === "number") return String(val);
  return "'" + String(val).replace(/'/g, "''") + "'";
}

function rowsToInserts(table, rows) {
  if (!rows.length) return `-- ${table}: kayit yok\n`;
  const cols = Object.keys(rows[0]);
  const lines = rows.map(
    (r) => `INSERT INTO ${table} (${cols.join(", ")}) VALUES (${cols.map((c) => esc(r[c])).join(", ")}) ON CONFLICT DO NOTHING;`
  );
  return lines.join("\n") + "\n";
}

async function main() {
  const client = await pool.connect();
  try {
    const cats  = await client.query("SELECT * FROM categories ORDER BY id");
    const prods = await client.query("SELECT * FROM products ORDER BY id");
    const tbls  = await client.query("SELECT * FROM tables ORDER BY id");

    const outDir = path.join(__dirname, "..", "..", "exports");
    fs.mkdirSync(outDir, { recursive: true });

    const date = new Date().toISOString().slice(0, 10);
    const outFile = path.join(outDir, `menu_tables_export_${date}.sql`);

    const sql = [
      "-- NexPOS Menu & Masa Export",
      `-- Tarih: ${new Date().toLocaleString("tr-TR")}`,
      "",
      "-- CATEGORIES",
      rowsToInserts("categories", cats.rows),
      "",
      "-- PRODUCTS",
      rowsToInserts("products", prods.rows),
      "",
      "-- TABLES",
      rowsToInserts("tables", tbls.rows),
    ].join("\n");

    fs.writeFileSync(outFile, sql, "utf8");

    console.log(`\nExport tamamlandi:`);
    console.log(`  Kategoriler : ${cats.rowCount}`);
    console.log(`  Urunler     : ${prods.rowCount}`);
    console.log(`  Masalar     : ${tbls.rowCount}`);
    console.log(`  Dosya       : ${outFile}\n`);
  } finally {
    client.release();
    await pool.end();
  }
}

main().catch((err) => {
  console.error("HATA:", err.message);
  process.exit(1);
});
