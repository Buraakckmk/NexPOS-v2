const cron = require("node-cron");
const fs = require("fs/promises");
const path = require("path");
const { spawn } = require("child_process");

let backupTask;

function getBackupDirectory() {
  const configured = process.env.BACKUP_DIR || "./backups";
  return path.resolve(process.cwd(), configured);
}

function buildBackupFilename(date = new Date()) {
  const isoDate = date.toISOString().slice(0, 10);
  return `backup_${isoDate}.sql`;
}

async function runBackupNow() {
  const backupDir = getBackupDirectory();
  await fs.mkdir(backupDir, { recursive: true });

  const outputFile = path.join(backupDir, buildBackupFilename());
  const executable = process.env.PG_DUMP_PATH || "pg_dump";
  const args = [
    "-h",
    process.env.DB_HOST || "127.0.0.1",
    "-p",
    String(process.env.DB_PORT || 5432),
    "-U",
    process.env.DB_USER || "postgres",
    "-d",
    process.env.DB_NAME || "adisyon_db",
    "-F",
    "p",
    "-f",
    outputFile,
  ];

  await new Promise((resolve, reject) => {
    const child = spawn(executable, args, {
      env: {
        ...process.env,
        PGPASSWORD: process.env.DB_PASSWORD || "",
      },
      shell: false,
      windowsHide: true,
    });

    let stderr = "";
    child.stderr.on("data", (chunk) => {
      stderr += chunk.toString();
    });

    child.on("error", (error) => {
      reject(error);
    });

    child.on("close", (code) => {
      if (code === 0) {
        console.log(`[backup] completed: ${outputFile}`);
        resolve();
        return;
      }

      reject(new Error(stderr || `pg_dump exited with code ${code}`));
    });
  });

  return outputFile;
}

function startBackupScheduler() {
  if (backupTask) {
    return backupTask;
  }

  const expression = process.env.BACKUP_CRON || "0 3 * * *";
  backupTask = cron.schedule(
    expression,
    () => {
      runBackupNow().catch((error) => {
        console.error("[backup-error]", error);
      });
    },
    {
      scheduled: true,
      timezone: process.env.BACKUP_TIMEZONE || "Europe/Istanbul",
    }
  );

  console.log(`[backup] scheduler started with cron: ${expression}`);
  return backupTask;
}

module.exports = {
  runBackupNow,
  startBackupScheduler,
};