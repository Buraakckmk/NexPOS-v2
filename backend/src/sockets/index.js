const logger = require("../config/logger");

function registerSocketHandlers(io) {
  io.on("connection", (socket) => {
    logger.info(`Socket connected: ${socket.id}`);

    socket.on("order:confirm", (payload) => {
      io.emit("new-order", payload);
    });

    socket.on("disconnect", () => {
      logger.info(`Socket disconnected: ${socket.id}`);
    });
  });
}

module.exports = {
  registerSocketHandlers,
};
