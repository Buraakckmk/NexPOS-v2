const jwt = require("jsonwebtoken");
const bcrypt = require("bcryptjs");
const db = require("../config/db");

async function hashPin(pin) {
  return await bcrypt.hash(pin, 10);
}

async function findUserByPin(pin) {
  const query = `
    SELECT id, full_name, role_id, pin_code, is_active
    FROM users
    WHERE is_active = TRUE
  `;
  const { rows } = await db.query(query);

  for (const user of rows) {
    if (!user.pin_code) continue;

    // Check if pin is bcrypt hash (starts with $2a$ or $2b$)
    if (user.pin_code.startsWith("$2a$") || user.pin_code.startsWith("$2b$")) {
      const match = await bcrypt.compare(pin, user.pin_code);
      if (match) return user;
    } else {
      // Legacy plain text check & auto migration
      if (user.pin_code === pin) {
        const hashed = await hashPin(pin);
        await db.query(`UPDATE users SET pin_code = $1, updated_at = NOW() WHERE id = $2`, [hashed, user.id]);
        user.pin_code = hashed;
        return user;
      }
    }
  }

  return null;
}

function signAccessToken(user) {
  return jwt.sign(
    {
      user_id: user.id,
      full_name: user.full_name,
      role_id: user.role_id,
    },
    process.env.JWT_SECRET,
    { expiresIn: process.env.JWT_EXPIRES_IN || "8h" }
  );
}

module.exports = {
  hashPin,
  findUserByPin,
  signAccessToken,
};

