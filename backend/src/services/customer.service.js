const db = require("../config/db");

async function listCustomers({ search = "" }) {
  const normalizedSearch = String(search || "").trim();
  const query = `
    SELECT 
      c.id,
      c.full_name,
      c.phone,
      c.email,
      c.balance,
      c.note,
      c.created_at,
      c.updated_at
    FROM customers c
    WHERE ($1 = '' OR c.full_name ILIKE '%' || $1 || '%' OR c.phone ILIKE '%' || $1 || '%')
    ORDER BY c.full_name ASC
  `;
  const { rows } = await db.query(query, [normalizedSearch]);
  return rows;
}

async function getCustomerById(id) {
  const query = `
    SELECT c.*,
      (
        SELECT JSON_AGG(ct ORDER BY ct.created_at DESC)
        FROM customer_transactions ct
        WHERE ct.customer_id = c.id
      ) AS transactions
    FROM customers c
    WHERE c.id = $1
  `;
  const { rows } = await db.query(query, [id]);
  return rows[0] || null;
}

async function createCustomer({ full_name, phone, email, note }) {
  const query = `
    INSERT INTO customers (full_name, phone, email, note, balance)
    VALUES ($1, $2, $3, $4, 0)
    RETURNING *
  `;
  const { rows } = await db.query(query, [full_name, phone || null, email || null, note || null]);
  return rows[0];
}

async function updateCustomer(id, { full_name, phone, email, note }) {
  const query = `
    UPDATE customers
    SET 
      full_name = COALESCE($1, full_name),
      phone = COALESCE($2, phone),
      email = COALESCE($3, email),
      note = COALESCE($4, note),
      updated_at = NOW()
    WHERE id = $5
    RETURNING *
  `;
  const { rows } = await db.query(query, [full_name, phone, email, note, id]);
  return rows[0] || null;
}

async function deleteCustomer(id) {
  const { rows } = await db.query(`DELETE FROM customers WHERE id = $1 RETURNING id`, [id]);
  return rows[0] || null;
}

async function addTransaction({ customer_id, order_id, type, amount, note, created_by_user_id }) {
  const client = await db.pool.connect();
  try {
    await client.query("BEGIN");

    const numAmount = Number(amount);
    if (Number.isNaN(numAmount) || numAmount <= 0) {
      throw new Error("Gecersiz islem tutari.");
    }

    const { rows: custRows } = await client.query(`SELECT id, balance FROM customers WHERE id = $1 FOR UPDATE`, [customer_id]);
    if (!custRows.length) {
      throw new Error("Musteri bulunamadi.");
    }

    // DEBIT increases balance (customer owes more), CREDIT decreases balance (customer paid)
    const balanceDelta = type === "DEBIT" ? numAmount : -numAmount;

    await client.query(
      `UPDATE customers SET balance = balance + $1, updated_at = NOW() WHERE id = $2`,
      [balanceDelta, customer_id]
    );

    const { rows: txRows } = await client.query(
      `
      INSERT INTO customer_transactions (customer_id, order_id, type, amount, note, created_by_user_id)
      VALUES ($1, $2, $3, $4, $5, $6)
      RETURNING *
      `,
      [customer_id, order_id || null, type, numAmount, note || null, created_by_user_id || null]
    );

    await client.query("COMMIT");
    return txRows[0];
  } catch (error) {
    await client.query("ROLLBACK");
    throw error;
  } finally {
    client.release();
  }
}

module.exports = {
  listCustomers,
  getCustomerById,
  createCustomer,
  updateCustomer,
  deleteCustomer,
  addTransaction,
};
