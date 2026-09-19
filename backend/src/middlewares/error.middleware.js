const logger = require("../config/logger");

function notFound(req, res) {
  res.status(404).json({ message: "Endpoint bulunamadi." });
}

function errorHandler(err, req, res, next) {
  const statusCode = Number(err.statusCode || err.status || 500);
  const isServerError = statusCode >= 500;

  logger.error("api-error", {
    method: req.method,
    path: req.originalUrl,
    statusCode,
    message: err.message,
    stack: err.stack,
  });

  if (res.headersSent) {
    return next(err);
  }

  res.status(statusCode).json({
    message: isServerError
        ? "Sunucuda beklenmeyen bir hata oluştu. Lütfen tekrar deneyin."
        : err.message || "İstek işlenemedi.",
  });
}

module.exports = {
  notFound,
  errorHandler,
};
