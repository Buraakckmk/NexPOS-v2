const db = require("../config/db");

async function idempotency(req, res, next) {
  const requestId = req.headers["x-request-id"];
  if (!requestId || req.method === "GET") {
    return next();
  }

  try {
    const { rows } = await db.query(
      `SELECT response_payload FROM processed_requests WHERE request_id = $1`,
      [requestId]
    );

    if (rows.length > 0) {
      const cached = rows[0].response_payload;
      return res.status(cached.status || 200).json(cached.body);
    }

    // Intercept res.json to capture response payload
    const originalJson = res.json.bind(res);
    res.json = (body) => {
      if (res.statusCode >= 200 && res.statusCode < 300) {
        db.query(
          `INSERT INTO processed_requests (request_id, response_payload) VALUES ($1, $2) ON CONFLICT DO NOTHING`,
          [requestId, JSON.stringify({ status: res.statusCode, body })]
        ).catch((err) => {
          console.error("Failed to store idempotency record:", err.message);
        });
      }
      return originalJson(body);
    };

    return next();
  } catch (error) {
    console.error("Idempotency middleware error:", error);
    return next();
  }
}

module.exports = {
  idempotency,
};
