const tableService = require("../services/table.service");

function emitTablesRefresh(req) {
  const io = req.app.get("io");
  if (io) {
    io.emit("tables:refresh", { at: new Date().toISOString() });
  }
}

async function listTables(req, res, next) {
  try {
    const tables = await tableService.listTablesForWaiter();
    return res.status(200).json({
      count: tables.length,
      tables,
    });
  } catch (error) {
    return next(error);
  }
}

async function createCustomTable(req, res, next) {
  try {
    const displayName = req.body?.display_name;
    const zone = req.body?.zone;
    const capacity = req.body?.capacity;

    const table = await tableService.createCustomTable({
      displayName,
      zone,
      capacity,
    });

    emitTablesRefresh(req);

    return res.status(201).json({
      message: "Ozel masa olusturuldu.",
      table,
    });
  } catch (error) {
    if (error.statusCode) {
      return res.status(error.statusCode).json({ message: error.message });
    }
    return next(error);
  }
}

async function deleteCustomTable(req, res, next) {
  try {
    const tableId = Number(req.params.tableId);

    const deletedTable = await tableService.deleteCustomTable({ tableId });

    emitTablesRefresh(req);

    return res.status(200).json({
      message: "Ozel masa silindi.",
      table: deletedTable,
    });
  } catch (error) {
    if (error.statusCode) {
      return res.status(error.statusCode).json({ message: error.message });
    }
    return next(error);
  }
}

module.exports = {
  listTables,
  createCustomTable,
  deleteCustomTable,
};
