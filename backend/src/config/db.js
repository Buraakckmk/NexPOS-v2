const path = require("path");
require("dotenv").config({ path: path.join(__dirname, "..", "..", ".env"), override: true });

const { Pool } = require("pg");
const logger = require("./logger");

function buildPoolConfig() {
  return {
    host: process.env.DB_HOST || "127.0.0.1",
    port: Number(process.env.DB_PORT || 5432),
    database: process.env.DB_NAME || "adisyon_db",
    user: process.env.DB_USER || "postgres",
    password: process.env.DB_PASSWORD || "postgres",
    max: Number(process.env.DB_POOL_MAX || 30),
    min: Number(process.env.DB_POOL_MIN || 2),
    idleTimeoutMillis: Number(process.env.DB_IDLE_TIMEOUT_MS || 30000),
    connectionTimeoutMillis: Number(process.env.DB_CONNECTION_TIMEOUT_MS || 10000),
    keepAlive: true,
    allowExitOnIdle: false,
    application_name: process.env.DB_APPLICATION_NAME || "adisyon-backend",
  };
}

const pool = new Pool(buildPoolConfig());

pool.on("error", (err) => {
  logger.error("Unexpected PostgreSQL pool error", {
    message: err.message,
    stack: err.stack,
  });
});

async function testDbConnection() {
  const client = await pool.connect();
  try {
    const { rows } = await client.query(
      "SELECT NOW() AS now, current_database() AS database"
    );
    logger.info(
      `PostgreSQL connection established. database=${rows[0]?.database || "unknown"}`
    );
  } finally {
    client.release();
  }
}

async function query(text, params) {
  try {
    return await pool.query(text, params);
  } catch (error) {
    logger.error("PostgreSQL query failed", {
      message: error.message,
      stack: error.stack,
      query: typeof text === "string" ? text.slice(0, 500) : "unknown",
    });
    throw error;
  }
}

module.exports = {
  pool,
  query,
  testDbConnection,
};
