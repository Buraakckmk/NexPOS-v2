require("dotenv").config({ override: true });

const http = require("http");
const express = require("express");
const cors = require("cors");
const helmet = require("helmet");
const { Server } = require("socket.io");

const logger = require("./config/logger");
const db = require("./config/db");
const apiRoutes = require("./routes");
const { registerSocketHandlers } = require("./sockets");
const { startBackupScheduler } = require("./services/backup.service");
const { migrateMenuCategories } = require("./services/menu_migration.service");
const { requestLogger } = require("./middlewares/request-logger.middleware");
const { notFound, errorHandler } = require("./middlewares/error.middleware");
const { idempotency } = require("./middlewares/idempotency.middleware");

const app = express();
const server = http.createServer(app);

function isLanHost(hostname) {
  if (["localhost", "127.0.0.1", "::1"].includes(hostname)) {
    return true;
  }
  if (hostname.startsWith("192.168.")) {
    return true;
  }
  if (hostname.startsWith("10.")) {
    return true;
  }
  return /^172\.(1[6-9]|2\d|3[0-1])\./.test(hostname);
}

const corsOptions = {
  origin(origin, callback) {
    if (!origin) {
      callback(null, true);
      return;
    }

    try {
      const url = new URL(origin);
      callback(null, isLanHost(url.hostname));
    } catch (error) {
      callback(null, false);
    }
  },
  credentials: true,
};

app.use(helmet());
app.use(cors(corsOptions));
app.use(express.json());
app.use(requestLogger);
app.use(idempotency);

const io = new Server(server, {
  cors: {
    origin: corsOptions.origin,
    methods: ["GET", "POST"],
  },
});

server.on("error", (error) => {
  if (error && error.code === "EADDRINUSE") {
    logger.error("server-port-in-use", {
      message: `Port ${port} zaten kullanımda. Aynı anda iki backend çalışıyor olabilir.`,
      port,
      isDevScript,
    });
    process.exitCode = 1;
    return;
  }
  logger.error("server-error", { message: error.message, stack: error.stack });
});

app.set("io", io);
registerSocketHandlers(io);

app.use("/api", apiRoutes);

app.use(notFound);
app.use(errorHandler);

const isDevScript = process.env.npm_lifecycle_event === "dev";
const port = isDevScript
  ? Number(process.env.DEV_PORT || 3002)
  : Number(process.env.PORT || 5000);

async function bootstrap() {
  startBackupScheduler();

  server.listen(port, "0.0.0.0", () => {
    logger.info(`Backend listening on http://0.0.0.0:${port} (Yerel ağda erişilebilir)`);
    logger.info(`Sunucu: ${new Date().toLocaleString("tr-TR")}`);
  });

  try {
    await db.testDbConnection();
    await migrateMenuCategories();

    // Optimize: Pre-ensure schemas on startup
    const orderService = require("./services/order.service");
    const tableService = require("./services/table.service");
    await Promise.all([
      orderService.ensureOrderSchema(),
      tableService.ensureTableSchema(),
    ]);
    logger.info("Database schemas ensured on startup.");
  } catch (error) {
    logger.error("Bootstrap error:", { message: error.message, stack: error.stack });
  }
}

async function shutdown(signal) {
  logger.info(`${signal} received, shutting down gracefully...`);
  server.close(async () => {
    await db.pool.end();
    process.exit(0);
  });
}

process.on("uncaughtException", (error) => {
  logger.error("uncaughtException", { message: error.message, stack: error.stack });
});

process.on("unhandledRejection", (reason) => {
  logger.error("unhandledRejection", {
    message: reason?.message || String(reason),
    stack: reason?.stack,
  });
});

process.on("SIGINT", () => {
  shutdown("SIGINT").catch((error) => {
    logger.error("Graceful shutdown failed", { message: error.message, stack: error.stack });
    process.exit(1);
  });
});

process.on("SIGTERM", () => {
  shutdown("SIGTERM").catch((error) => {
    logger.error("Graceful shutdown failed", { message: error.message, stack: error.stack });
    process.exit(1);
  });
});

bootstrap().catch((err) => {
  logger.error("Server startup encountered a fatal bootstrap error", {
    message: err.message,
    stack: err.stack,
  });
});
