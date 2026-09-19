require("dotenv").config({ override: true });

const fs = require("fs");
const path = require("path");
const db = require("../config/db");

async function run() {
  const sqlPath = path.join(__dirname, "reset-sales-data.sql");
  const sql = fs.readFileSync(sqlPath, "utf8");
  const client = await db.pool.connect();

  try {
    await client.query(sql);
    console.log("Sales/order history reset completed successfully.");
  } catch (error) {
    console.error("Sales/order history reset failed:", error.message);
    process.exitCode = 1;
  } finally {
    client.release();
    await db.pool.end();
  }
}

run();
