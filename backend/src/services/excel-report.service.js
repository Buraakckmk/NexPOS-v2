const fs = require("fs");
const fsp = require("fs/promises");
const path = require("path");
const XLSX = require("xlsx");

function getReportDirectory() {
  const configured = process.env.REPORT_DIR || "./reports";
  return path.resolve(process.cwd(), configured);
}

function getWorkbookPath(date = new Date()) {
  const dt = new Date(date);
  const year = dt.getFullYear();
  const month = String(dt.getMonth() + 1).padStart(2, "0");
  const day = String(dt.getDate()).padStart(2, "0");
  return path.join(getReportDirectory(), `gun-sonu-${year}-${month}-${day}.xlsx`);
}

function formatDateParts(date = new Date()) {
  const dt = new Date(date);
  const day = String(dt.getDate()).padStart(2, "0");
  const month = String(dt.getMonth() + 1).padStart(2, "0");
  const year = dt.getFullYear();
  const hour = String(dt.getHours()).padStart(2, "0");
  const minute = String(dt.getMinutes()).padStart(2, "0");
  const second = String(dt.getSeconds()).padStart(2, "0");

  return {
    dateText: `${day}.${month}.${year}`,
    timeText: `${hour}:${minute}:${second}`,
  };
}

async function appendZReportToExcel({
  date,
  workbookDate,
  cashTotal,
  cardTotal,
  totalRevenue,
  totalOrders,
  totalExpenses,
  generalCashRegister,
  generalCashStatus,
  payments = [],
  expenses = [],
  productSales = [],
  adjustments = [],
}) {
  const workbookDt = new Date(workbookDate || date || new Date());
  const dt = new Date(date || new Date());
  const reportDir = getReportDirectory();
  const workbookPath = getWorkbookPath(workbookDt);

  await fsp.mkdir(reportDir, { recursive: true });

  let workbook;
  if (fs.existsSync(workbookPath)) {
    workbook = XLSX.readFile(workbookPath);
  } else {
    workbook = XLSX.utils.book_new();
    const initialSheet = XLSX.utils.aoa_to_sheet([
      [
        "Tarih",
        "Saat",
        "Nakit",
        "Kart",
        "Toplam",
        "Adisyon",
        "Gider",
        "Genel Kasa",
        "Kasadaki Nakit",
      ],
    ]);
    XLSX.utils.book_append_sheet(workbook, initialSheet, "GunSonu");
  }

  const sheetName = workbook.SheetNames.includes("GunSonu")
    ? "GunSonu"
    : workbook.SheetNames[0];
  const sheet = workbook.Sheets[sheetName];

  const { dateText, timeText } = formatDateParts(date);
  XLSX.utils.sheet_add_aoa(
    sheet,
    [[
      dateText,
      timeText,
      Number(cashTotal || 0),
      Number(cardTotal || 0),
      Number(totalRevenue || 0),
      Number(totalOrders || 0),
      Number(totalExpenses || 0),
      Number(generalCashRegister || 0),
      Number(generalCashStatus || 0),
    ]],
    { origin: -1 }
  );

  const safeStamp = `${dateText.replaceAll(".", "")}_${timeText.replaceAll(":", "")}`;

  const detailsSheetName = `Detay_${safeStamp}`.slice(0, 31);
  const detailRows = [
    ["Alan", "Deger"],
    ["Tarih", dateText],
    ["Saat", timeText],
    ["Toplam Ciro", Number(totalRevenue || 0)],
    ["Nakit", Number(cashTotal || 0)],
    ["Kart", Number(cardTotal || 0)],
    ["Toplam Adisyon", Number(totalOrders || 0)],
    ["Toplam Gider", Number(totalExpenses || 0)],
    ["Genel Kasa", Number(generalCashRegister || 0)],
    ["Kasadaki Nakit", Number(generalCashStatus || 0)],
  ];
  const detailSheet = XLSX.utils.aoa_to_sheet(detailRows);
  XLSX.utils.book_append_sheet(workbook, detailSheet, detailsSheetName);

  const paymentSheetName = `Odemeler_${safeStamp}`.slice(0, 31);
  const paymentSheet = XLSX.utils.json_to_sheet(
    (payments || []).map((p) => ({
      TarihSaat: p.paidAt || "",
      AdisyonNo: Number(p.orderId || 0),
      Masa: p.tableName || "-",
      Kasiyer: p.cashierName || "-",
      Yontem: p.paymentMethod || "-",
      Tutar: Number(p.amount || 0),
    }))
  );
  XLSX.utils.book_append_sheet(workbook, paymentSheet, paymentSheetName);

  const expenseSheetName = `Giderler_${safeStamp}`.slice(0, 31);
  const expenseSheet = XLSX.utils.json_to_sheet(
    (expenses || []).map((e) => ({
      TarihSaat: e.createdAt || "",
      Kalem: e.itemName || "",
      Miktar: Number(e.quantity || 0),
      BirimFiyat: Number(e.unitPrice || 0),
      Tutar: Number(e.totalAmount || 0),
      Not: e.note || "",
    }))
  );
  XLSX.utils.book_append_sheet(workbook, expenseSheet, expenseSheetName);

  const productSheetName = `UrunDetay_${safeStamp}`.slice(0, 31);
  const productSheet = XLSX.utils.json_to_sheet(
    (productSales || []).map((p) => ({
      Kategori: p.categoryName || "Diger",
      Urun: p.productName || "",
      Adet: Number(p.quantity || 0),
      Tutar: Number(p.revenue || 0),
    }))
  );
  XLSX.utils.book_append_sheet(workbook, productSheet, productSheetName);

  const adjustmentSheetName = `IptalIndirim_${safeStamp}`.slice(0, 31);
  const adjustmentRows = (adjustments || []).map((a) => ({
    TarihSaat: a.eventAt || "",
    HareketTipi: a.eventType || "",
    AdisyonNo: Number(a.orderId || 0),
    Masa: a.tableName || "-",
    Urun: a.productName || "",
    Adet: a.quantity == null ? "" : Number(a.quantity || 0),
    Tutar: Number(a.amount || 0),
    Aciklama: a.reason || "",
    Personel: a.userName || "-",
  }));
  const adjustmentSheet = adjustmentRows.length
    ? XLSX.utils.json_to_sheet(adjustmentRows)
    : XLSX.utils.aoa_to_sheet([
      [
        "TarihSaat",
        "HareketTipi",
        "AdisyonNo",
        "Masa",
        "Urun",
        "Adet",
        "Tutar",
        "Aciklama",
        "Personel",
      ],
      ["", "", "", "", "", "", "", "Bu periyotta kayit yok", ""],
    ]);
  XLSX.utils.book_append_sheet(workbook, adjustmentSheet, adjustmentSheetName);

  try {
    XLSX.writeFile(workbook, workbookPath);
    return workbookPath;
  } catch (error) {
    if (error && (error.code === "EBUSY" || error.code === "EACCES")) {
      const fallbackPath = path.join(
        reportDir,
        `gun-sonu-${dt.getFullYear()}-${String(dt.getMonth() + 1).padStart(2, "0")}-${String(dt.getDate()).padStart(2, "0")}-${Date.now()}.xlsx`
      );
      XLSX.writeFile(workbook, fallbackPath);
      return fallbackPath;
    }

    throw error;
  }
}

module.exports = {
  appendZReportToExcel,
  getWorkbookPath,
};
