const logger = require("../config/logger");

function requestLogger(req, res, next) {
  const startedAt = Date.now();

  res.on("finish", () => {
    const durationMs = Date.now() - startedAt;
    const userId = req.user?.user_id ?? null;

    logger.info("api-request", {
      method: req.method,
      path: req.originalUrl,
      statusCode: res.statusCode,
      durationMs,
      ip: req.ip,
      userId,
      contentLength: res.getHeader("content-length") || null,
    });
  });

  next();
}

module.exports = {
  requestLogger,
};
