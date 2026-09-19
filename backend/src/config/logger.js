const path = require("path");
const winston = require("winston");
const DailyRotateFile = require("winston-daily-rotate-file");

const logDir = path.resolve(process.cwd(), "logs");
const level = process.env.LOG_LEVEL || "info";

const baseFormat = winston.format.combine(
  winston.format.timestamp({ format: "YYYY-MM-DD HH:mm:ss" }),
  winston.format.errors({ stack: true }),
  winston.format.printf(({ timestamp, level: lvl, message, stack, ...meta }) => {
    const rest = Object.keys(meta).length ? ` ${JSON.stringify(meta)}` : "";
    const text = stack || message;
    return `[${timestamp}] ${lvl.toUpperCase()} ${text}${rest}`;
  })
);

const transports = [
  new winston.transports.Console({
    level,
    format: winston.format.combine(
      winston.format.colorize(),
      winston.format.timestamp({ format: "HH:mm:ss" }),
      winston.format.printf(({ timestamp, level: lvl, message, stack, ...meta }) => {
        const rest = Object.keys(meta).length ? ` ${JSON.stringify(meta)}` : "";
        const text = stack || message;
        return `[${timestamp}] ${lvl} ${text}${rest}`;
      })
    ),
  }),
  new DailyRotateFile({
    dirname: logDir,
    filename: "app-%DATE%.log",
    datePattern: "YYYY-MM-DD",
    maxFiles: "30d",
    level,
    zippedArchive: false,
    format: baseFormat,
  }),
  new DailyRotateFile({
    dirname: logDir,
    filename: "error-%DATE%.log",
    datePattern: "YYYY-MM-DD",
    maxFiles: "60d",
    level: "error",
    zippedArchive: false,
    format: baseFormat,
  }),
];

const logger = winston.createLogger({
  level,
  defaultMeta: { service: "adisyon-backend" },
  transports,
});

module.exports = logger;
