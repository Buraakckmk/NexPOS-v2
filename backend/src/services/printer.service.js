const {
  ThermalPrinter,
  PrinterTypes,
  CharacterSet,
} = require("node-thermal-printer");
const logger = require("../config/logger");
const db = require("../config/db");

const PRINTER_TYPES = {
  KASA: "KASA",
  MUTFAK: "MUTFAK",
  BAR: "BAR",
  CASH: "KASA",
  KITCHEN: "MUTFAK",
};

const DEPARTMENT_ROUTES = [PRINTER_TYPES.MUTFAK, PRINTER_TYPES.BAR, PRINTER_TYPES.KASA];
const BRAND_NAME = (process.env.CAFE_NAME || "KAHVE DERYASI").toUpperCase();
const PRINTER_CHARSET =
  process.env.PRINTER_CHARSET || CharacterSet.PC857_TURKISH;

const BAR_CATEGORIES = new Set([
  "SICAK İÇECEKLER",
  "SOĞUK İÇECEKLER",
  "ÇAYLAR",
  "TÜRK KAHVESİ ÇEŞİTLERİ",
  "ESPRESSOLU KAHVELER",
  "FİLTRE KAHVELER",
  "FRAPPELER",
  "SAHLEP-SICAK ÇİKOLATA",
  "SOĞUK KAHVELER",
  "MEŞRUBATLAR",
  "MEYVELİ FROZENLER",
  "MİLKSHAKELER",
  "MATCHA (MAÇA)",
  "DETOKS",
]);

const printerChains = new Map();

function formatMoney(value) {
  const n = Number(value);
  if (Number.isNaN(n)) return String(value);
  return `${n.toFixed(2)} TL`;
}

function formatMoneyTr(value) {
  const n = Number(value);
  if (Number.isNaN(n)) return "0,00 TL";
  return `${n.toLocaleString("tr-TR", {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  })} TL`;
}

function formatDateTime(value) {
  const date = value instanceof Date ? value : new Date(value);
  if (Number.isNaN(date.getTime())) {
    return formatDateTime(new Date());
  }
  const pad = (n) => String(n).padStart(2, "0");
  return `${pad(date.getDate())}.${pad(date.getMonth() + 1)}.${date.getFullYear()} ${pad(date.getHours())}:${pad(date.getMinutes())}`;
}

function formatQuantity(value) {
  const n = Number(value);
  if (Number.isNaN(n)) return String(value ?? "0");
  const rounded = Math.round(n);
  if (Math.abs(n - rounded) < 0.000001) return String(rounded);
  return n.toFixed(2).replace(/\.?0+$/, "");
}

function aggregatePrintableItems(items = []) {
  const grouped = new Map();

  for (const item of items) {
    const name = String(item?.name ?? "").trim();
    if (!name) continue;

    const quantity = Number(item?.quantity ?? 0);
    if (!Number.isFinite(quantity) || quantity <= 0) continue;

    const unitPrice = Number(item?.unit_price ?? item?.unitPrice ?? 0);
    const safeUnitPrice = Number.isFinite(unitPrice) ? unitPrice : 0;

    const key = `${name.toUpperCase()}|${safeUnitPrice.toFixed(4)}`;
    const existing = grouped.get(key);

    if (existing) {
      existing.quantity += quantity;
      continue;
    }

    grouped.set(key, {
      ...item,
      name,
      unit_price: safeUnitPrice,
      quantity,
    });
  }

  return Array.from(grouped.values());
}

function tryCall(printer, method, ...args) {
  try {
    if (typeof printer?.[method] === "function") {
      printer[method](...args);
    }
  } catch (_) {
    return;
  }
}

function normalizePrinterType(value) {
  const printerType = String(value ?? "").trim().toUpperCase();
  if (["KASA", "CASH"].includes(printerType)) return PRINTER_TYPES.KASA;
  if (["MUTFAK", "KITCHEN"].includes(printerType)) return PRINTER_TYPES.MUTFAK;
  if (printerType === "BAR") return PRINTER_TYPES.BAR;
  return null;
}

function resolvePrinterIp(printerType) {
  const envByRoute = process.env[`PRINTER_IP_${printerType}`];
  if (envByRoute) {
    return envByRoute;
  }

  if (printerType === PRINTER_TYPES.KASA) {
    return process.env.KASA_PRINTER_IP || null;
  }

  if (printerType === PRINTER_TYPES.MUTFAK) {
    return process.env.MUTFAK_PRINTER_IP || null;
  }

  if (printerType === PRINTER_TYPES.BAR) {
    return process.env.BAR_PRINTER_IP || null;
  }

  return null;
}

function resolvePrinterPort(printerType) {
  const envByRoute = process.env[`PRINTER_PORT_${printerType}`];
  if (envByRoute) return envByRoute;

  if (printerType === PRINTER_TYPES.KASA) return process.env.KASA_PRINTER_PORT || process.env.PRINTER_PORT || 9100;
  if (printerType === PRINTER_TYPES.MUTFAK) return process.env.MUTFAK_PRINTER_PORT || process.env.PRINTER_PORT || 9100;
  if (printerType === PRINTER_TYPES.BAR) return process.env.BAR_PRINTER_PORT || process.env.PRINTER_PORT || 9100;

  return process.env.PRINTER_PORT || 9100;
}

function getPrinterTarget(printerType) {
  const printerIp = resolvePrinterIp(printerType);
  if (!printerIp) return null;
  const port = resolvePrinterPort(printerType);
  return `tcp://${printerIp}:${port}`;
}

function buildPrinter(printerType) {
  const interfacePath = getPrinterTarget(printerType);
  if (!interfacePath) {
    return null;
  }

  return new ThermalPrinter({
    type: PrinterTypes.EPSON,
    interface: interfacePath,
    characterSet: PRINTER_CHARSET,
    removeSpecialCharacters: false,
    lineCharacter: "-",
    options: {
      timeout: 10000, // Süreyi 10 saniyeye çıkardım
    },
  });
}

function queueByPrinter(printerType, task) {
  const previous = printerChains.get(printerType) || Promise.resolve();
  const next = previous.catch(() => undefined).then(task);
  printerChains.set(printerType, next.catch(() => undefined));
  return next;
}

async function executePrintJob(printerType, payload) {
  const printer = buildPrinter(printerType);
  if (!printer) {
    logger.error(`[printer-config] ${printerType} yazıcı IP tanımı eksik.`, {
      ticketType: payload?.ticketType,
      payloadPreview: String(payload?.text || "").slice(0, 300),
    });
    return;
  }

  try {
    printer.clear();

    const isOrder = payload.ticketType === "ORDER_CONFIRMATION";
    const isItemCancelled = payload.ticketType === "ITEM_CANCELLED";
    const isCustomerReceipt = payload.ticketType === "CUSTOMER_RECEIPT";
    const isCurrentAccount = payload.ticketType === "CURRENT_ACCOUNT";
    const isXReport = payload.ticketType === "X_REPORT";
    const isZReport = payload.ticketType === "Z_REPORT";

    if (isOrder) {
      // ─── KITCHEN/BAR ORDER TEMPLATE (OPTIMIZED) ────────────────────────
      tryCall(printer, "alignCenter");
      tryCall(printer, "setTextNormal");
      tryCall(printer, "bold", true);
      printer.println(BRAND_NAME);
      tryCall(printer, "bold", false);
      printer.println(`${String(printerType || "").toUpperCase()} / 1.30`);
      printer.println("");

      tryCall(printer, "alignLeft");
      tryCall(printer, "setTextNormal");
      const waiter = String(payload.waiterName || "-").toUpperCase();
      const serviceType = "Masa Servis";
      const table = String(payload.tableDisplayName || "-").toUpperCase();
      
      printer.println(`${waiter.padEnd(16)} ${serviceType.padEnd(12)} ${table.padStart(10)}`);
      printer.println("=".repeat(42));

      // CENTER TABLE NAME (normal height, not double)
      tryCall(printer, "alignCenter");
      tryCall(printer, "bold", true);
      printer.println(table);
      tryCall(printer, "bold", false);
      printer.println("");

      // ORDER INFO
      tryCall(printer, "alignLeft");
      tryCall(printer, "setTextNormal");
      const checkId = `CEK #${payload.orderId || "-"}`;
      const guests = `KISI ${payload.guestCount || 0}`;
      printer.println(`${checkId.padEnd(21)} ${guests.padStart(21)}`);
      printer.println("-".repeat(42));

      // ITEMS WITH IMPROVED SPACING
      for (const item of payload.items || []) {
        const qty = formatQuantity(item.quantity);
        const name = String(item.name || "-").toUpperCase().substring(0, 35);

        // Product line: bold normal size for qty and name
        tryCall(printer, "setTextNormal");
        tryCall(printer, "bold", true);
        const qtyFormatted = qty.padEnd(3);
        const productLine = `${qtyFormatted} ${name}`;
        printer.println(productLine);
        tryCall(printer, "bold", false);

        // Process notes (can be multi-line) — normal font
        const note = String(item.note || "").trim();
        if (note) {
          const noteLines = note.split("\n");
          for (const noteLine of noteLines) {
            const trimmedNote = noteLine.trim().toUpperCase().substring(0, 37);
            printer.println(`    # ${trimmedNote}`);
          }
        }

        // Blank line between items for readability
        printer.println("");
      }

      printer.println("=".repeat(42));
      tryCall(printer, "alignRight");
      tryCall(printer, "setTextNormal");
      printer.println(formatDateTime(payload.confirmedAt || new Date()));
      // ──────────────────────────────────────────────────────────────────
    } else if (isItemCancelled) {
      // ─── ITEM CANCELLATION TICKET ────────────────────────────────────
      tryCall(printer, "alignCenter");
      tryCall(printer, "setTextNormal");
      tryCall(printer, "bold", true);
      printer.println(BRAND_NAME);
      tryCall(printer, "setTextSize", 1, 2);
      printer.println("URUN IPTAL EDILDI");
      tryCall(printer, "setTextNormal");
      tryCall(printer, "bold", false);
      printer.println("");

      tryCall(printer, "alignLeft");
      printer.println(`MASA: ${String(payload.tableDisplayName || "-").toUpperCase()}`);
      printer.println(`CEK: #${payload.orderId || "-"}`);
      printer.println("-".repeat(42));

      for (const item of payload.items || []) {
        const qty = formatQuantity(item.quantity);
        const name = String(item.name || "-").toUpperCase().substring(0, 34);
        tryCall(printer, "bold", true);
        printer.println(`${qty.padEnd(4)} ${name}`);
        tryCall(printer, "bold", false);
      }

      printer.println("-".repeat(42));
      tryCall(printer, "alignRight");
      printer.println(formatDateTime(new Date()));
      // ──────────────────────────────────────────────────────────────────
    } else if (isCustomerReceipt) {
      // ─── ÖDENEN HESAP FİŞİ (OPTIMIZED) ────────────────────────────────
      tryCall(printer, "alignCenter");
      tryCall(printer, "setTextNormal");
      tryCall(printer, "bold", true);
      printer.println(BRAND_NAME);
      tryCall(printer, "bold", false);
      printer.println("");

      tryCall(printer, "alignLeft");
      tryCall(printer, "setTextNormal");
      printer.println(`MASA: ${String(payload.tableDisplayName || "-").toUpperCase()}`);
      printer.println(`CEK: #${payload.orderId || "-"}`);
      printer.println("=".repeat(42));

      // ITEMS
      const printableItems = aggregatePrintableItems(payload.items || []);
      for (const item of printableItems) {
        const qty = formatQuantity(item.quantity);
        const name = String(item.name || "-").toUpperCase().substring(0, 26);
        const price = formatMoney(item.unit_price * item.quantity);
        const qtyPadded = qty.padEnd(4);
        const namePadded = name.padEnd(26);
        printer.println(`${qtyPadded}${namePadded}${price.padStart(10)}`);
      }

      printer.println("=".repeat(42));
      tryCall(printer, "bold", true);
      const _totalStr = formatMoney(payload.grandTotal);
      printer.println(`${"TOPLAM:".padEnd(42 - _totalStr.length)}${_totalStr}`);
      
      if (payload.discountAmount > 0) {
        const _iskontoStr = formatMoney(payload.discountAmount);
        printer.println(`${"ISKONTO:".padEnd(42 - _iskontoStr.length)}${_iskontoStr}`);
      }
      const _odemeText = String(payload.paymentMethod || "-").toUpperCase();
      printer.println(`${"ODEME:".padEnd(42 - _odemeText.length)}${_odemeText}`);
      tryCall(printer, "bold", false);
      
      printer.println("");
      tryCall(printer, "alignCenter");
      printer.println("* Mali Degeri Yoktur *");
      printer.println("* Hesap Odendi *");
      printer.println(formatDateTime(new Date()));
      // ──────────────────────────────────────────────────────────────────
    } else if (isCurrentAccount) {
      // ─── HESAP OZETI TEMPLATE (OPTIMIZED) ──────────────────────────────
      tryCall(printer, "alignCenter");
      tryCall(printer, "setTextNormal");
      tryCall(printer, "bold", true);
      printer.println(BRAND_NAME);
      printer.println("");
      printer.println("HESAP OZETI");
      tryCall(printer, "bold", false);
      printer.println("");

      tryCall(printer, "alignLeft");
      tryCall(printer, "setTextNormal");
      printer.println(`MASA: ${String(payload.tableDisplayName || "-").toUpperCase()}`);
      printer.println(`CEK: #${payload.orderId || "-"}`);
      printer.println("=".repeat(42));

      // ITEMS WITH IMPROVED FORMATTING
      const printableItems = aggregatePrintableItems(payload.items || []);
      for (const item of printableItems) {
        const qty = formatQuantity(item.quantity);
        const name = String(item.name || "-").toUpperCase().substring(0, 26);
        const price = formatMoney((Number(item.unit_price) || 0) * (Number(item.quantity) || 0));
        
        // Main item line with monospace alignment
        const qtyPadded = qty.padEnd(4);
        const namePadded = name.padEnd(26);
        printer.println(`${qtyPadded}${namePadded}${price.padStart(10)}`);

        // Spacer between items
        printer.println("");
      }

      printer.println("=".repeat(42));
      tryCall(printer, "bold", true);
      const _araToplamStr = formatMoney(payload.subtotal || 0);
      printer.println(`${"ARA TOPLAM:".padEnd(42 - _araToplamStr.length)}${_araToplamStr}`);
      const _kalanStr = formatMoney(payload.remainingTotal || 0);
      printer.println(`${"KALAN:".padEnd(42 - _kalanStr.length)}${_kalanStr}`);
      tryCall(printer, "bold", false);

      printer.println("");
      tryCall(printer, "alignCenter");
      printer.println("* Mali Degeri Yoktur *");
      printer.println(formatDateTime(new Date()));
      // ──────────────────────────────────────────────────────────────────
    } else if (isXReport) {
      // ─── X RAPORU (onizleme ile birebir metin) ────────────────────────
      tryCall(printer, "alignCenter");
      tryCall(printer, "alignLeft");
      tryCall(printer, "setTextNormal");
      const lines = String(payload.text || "").split("\n");
      for (const line of lines) {
        const trimmed = line.trim();
        if (!trimmed) {
          printer.println("");
          continue;
        }
        if (trimmed === "*** X RAPORU ***") {
          tryCall(printer, "alignCenter");
          tryCall(printer, "bold", true);
          printer.println(trimmed);
          tryCall(printer, "bold", false);
          tryCall(printer, "alignLeft");
          continue;
        }
        printer.println(line);
      }
      // ──────────────────────────────────────────────────────────────────
    } else {
      // ─── Z RAPORU VE DİĞERLERİ ────────────────────────────────────────
      tryCall(printer, "bold", true);
      tryCall(printer, "alignCenter");
      
      const isReport = ["X_REPORT", "Z_REPORT"].includes(payload.ticketType);
      if (isReport) {
        tryCall(printer, "setTextSize", 1, 1);
      } else {
        tryCall(printer, "setTextSize", 2, 2);
      }
      
      printer.println(BRAND_NAME);
      tryCall(printer, "setTextSize", 1, 1);
      printer.println(String(printerType || "").toUpperCase());
      printer.println("");

      tryCall(printer, "bold", false);
      tryCall(printer, "alignLeft");
      
      const lines = String(payload.text || "").split("\n");
      for (let i = 0; i < lines.length; i++) {
        const line = lines[i].replace(/\s+$/, "");
        
        const productMatch = line.match(/^(\d+x|[\d.]+x)\s+(.+)$/);
        const isNote = line.toLowerCase().startsWith("not:") || line.toLowerCase().startsWith("  not:");

        if (productMatch) {
          const qty = productMatch[1];
          const name = productMatch[2];
          
          tryCall(printer, "alignLeft");
          tryCall(printer, "setTextSize", 1, 1);
          printer.print(`${qty} `);
          tryCall(printer, "bold", true);
          tryCall(printer, "setTextSize", 2, 2);
          printer.println(name);
          tryCall(printer, "bold", false);
          tryCall(printer, "setTextSize", 1, 1);
        } else if (isNote) {
          tryCall(printer, "setTextSize", 1, 1);
          printer.println(line);
        } else if (isReport) {
          tryCall(printer, "setTextSize", 1, 1);
          printer.println(line);
        } else {
          tryCall(printer, "setTextSize", 1, 1);
          printer.println(line);
        }
      }

      printer.println("");
      tryCall(printer, "alignCenter");
      printer.println(formatDateTime(new Date()));
    }
    
    const beepEnabled = String(process.env.PRINTER_BEEP_ENABLED ?? "1").trim().toLowerCase();
    const beepKasaEnabled = String(process.env.PRINTER_BEEP_KASA ?? "0").trim().toLowerCase();
    const ticketType = String(payload?.ticketType || "");
    const shouldBeep =
      beepEnabled !== "0" &&
      beepEnabled !== "false" &&
      beepEnabled !== "off" &&
      (printerType !== PRINTER_TYPES.KASA ||
        (beepKasaEnabled !== "0" &&
          beepKasaEnabled !== "false" &&
          beepKasaEnabled !== "off")) &&
      (ticketType === "ORDER_CONFIRMATION" || ticketType === "ITEM_CANCELLED");

    if (shouldBeep) {
      const count = ticketType === "ITEM_CANCELLED" ? 3 : Number.parseInt(process.env.PRINTER_BEEP_COUNT || "2", 10);
      const length = ticketType === "ITEM_CANCELLED" ? 3 : Number.parseInt(process.env.PRINTER_BEEP_LENGTH || "2", 10);
      printer.beep(Number.isFinite(count) ? count : 2, Number.isFinite(length) ? length : 2);
    }
    printer.cut();
    await printer.execute();
  } catch (error) {
    logger.error(`[printer-error] ${printerType}`, {
      message: error.message,
      stack: error.stack,
      ticketType: payload?.ticketType,
      payloadPreview: String(payload?.text || "").slice(0, 300),
    });
  }
}

async function enqueuePrintJob({ printerType, ticketType, payload }) {
  const normalizedType = normalizePrinterType(printerType);
  if (!normalizedType) {
    throw new Error(`Unsupported printer type: ${printerType}`);
  }

  await queueByPrinter(normalizedType, async () => {
    await executePrintJob(normalizedType, { ...payload, ticketType });
  });

  return `${normalizedType}-${ticketType}-${Date.now()}`;
}

function buildKitchenText({ title, tableDisplayName, waiterName, orderId, items, confirmedAt }) {
  const lines = [
    `MASA: ${String(tableDisplayName ?? "-").toUpperCase()}`,
    `GARSON: ${String(waiterName ?? "-").toUpperCase()}`,
    `SIPARIS: #${orderId ?? "-"}`,
    "",
  ];

  for (const item of items || []) {
    const qty = formatQuantity(item.quantity);
    const name = String(item.name ?? "-");
    lines.push(`${qty}x ${name}`);
    const note = String(item.note ?? "").trim();
    if (note) {
      lines.push(`Not: ${note}`);
    }
  }

  return lines.join("\n");
}

function buildCashReceiptText({
  tableDisplayName,
  orderId,
  items,
  subtotal,
  discountAmount,
  vatAmount,
  grandTotal,
  paymentMethod,
  mealCardType,
}) {
  const lines = [
    `MASA: ${String(tableDisplayName ?? "-").toUpperCase()}`,
    `SIPARIS: #${orderId ?? "-"}`,
    "",
  ];

  const printableItems = aggregatePrintableItems(items || []);
  for (const row of printableItems) {
    const qty = formatQuantity(row.quantity);
    const name = String(row.name ?? "-");
    lines.push(`${qty}x ${name}`);
  }

  const paymentLine = mealCardType
    ? `ODEME: ${String(paymentMethod || "-").toUpperCase()} - ${mealCardType.toUpperCase()}`
    : `ODEME: ${String(paymentMethod || "-").toUpperCase()}`;

  lines.push(
    "",
    `ARA TOPLAM: ${formatMoney(subtotal)}`,
    `ISKONTO: ${formatMoney(discountAmount || 0)}`,
    `KDV: ${formatMoney(vatAmount || 0)}`,
    `TOPLAM: ${formatMoney(grandTotal)}`,
    paymentLine
  );

  return lines.join("\n");
}

function buildCurrentAccountText({
  tableDisplayName,
  orderId,
  guestCount,
  items,
  subtotal,
  remainingTotal,
}) {
  const lines = [
    `MASA: ${String(tableDisplayName ?? "-").toUpperCase()}`,
    `SIPARIS: #${orderId ?? "-"}`,
  ];

  lines.push("");

  const printableItems = aggregatePrintableItems(items || []);
  for (const row of printableItems) {
    const qty = formatQuantity(row.quantity);
    const name = String(row.name ?? "-");
    lines.push(`${qty}x ${name}`);
  }

  lines.push(
    "",
    `ARA TOPLAM: ${formatMoney(subtotal || 0)}`,
    `KALAN HESAP: ${formatMoney(remainingTotal || 0)}`
  );

  return lines.join("\n");
}

function buildZReportText({
  totalRevenue,
  cashTotal,
  cardTotal,
  totalOrders,
  totalSubtotal,
  totalVat,
  orderDetails,
}) {
  const cafeName = BRAND_NAME;
  const branch = process.env.CAFE_BRANCH || "MERKEZ";
  const now = new Date();
  const dateStr = now.toLocaleDateString("tr-TR");
  const timeStr = now.toLocaleTimeString("tr-TR", { hour: "2-digit", minute: "2-digit" });

  const lines = [
    "*** Z RAPORU ***",
    `Kafe: ${cafeName.toUpperCase()} / ${branch.toUpperCase()}`,
    `Tarih: ${dateStr} ${timeStr}`,
    "--------------------------------",
    "ISLEMLER VE TUTARLAR:",
    `Nakit: ${formatMoney(cashTotal)}`,
    `Kart:  ${formatMoney(cardTotal)}`,
    `Toplam: ${formatMoney(totalRevenue)}`,
    "--------------------------------",
    "KAPANIS OZETI:",
    `Adisyon: ${totalOrders}`,
    `Ara Toplam: ${formatMoney(totalSubtotal)}`,
    `Toplam KDV: ${formatMoney(totalVat)}`,
    "--------------------------------",
    "KAPANAN ADISYONLAR:",
    String(orderDetails || "Kapanan adisyon bulunamadi.").trim(),
    "--------------------------------",
    "Kasiyer: YONETICI",
    "* Gun Sonu Tamamlandi *",
    "* Mali Degeri Vardir *",
  ];

  return lines.join("\n");
}

function buildXReportText({
  reportDate,
  printedAt,
  totalRevenue,
  cashTotal,
  cardTotal,
  totalOrders,
  totalDiscounts,
  averageGuestCount,
  averageDuration,
  totalExpenses,
  expenses,
  generalCashRegister,
  generalCashStatus,
}) {
  const cafeName = BRAND_NAME;
  const branch = process.env.CAFE_BRANCH || "MERKEZ";
  const now = new Date(printedAt || reportDate || new Date());
  const dateStr = now.toLocaleDateString("tr-TR");
  const timeStr = now.toLocaleTimeString("tr-TR", { hour: "2-digit", minute: "2-digit" });

  const lines = [
    "*** X RAPORU ***",
    `Kafe: ${cafeName.toUpperCase()} / ${branch.toUpperCase()}`,
    `Tarih: ${dateStr} ${timeStr}`,
    "--------------------------------",
    "İŞLEMLER VE TUTARLAR:",
    `Nakit: ${formatMoneyTr(cashTotal)}`,
    `Kart: ${formatMoneyTr(cardTotal)}`,
    `Toplam: ${formatMoneyTr(totalRevenue)}`,
    "--------------------------------",
    "IPTAL/IADE/INDIRIM:",
    `İndirim: ${formatMoneyTr(totalDiscounts)}`,
    "--------------------------------",
    "KASA DETAYLARI:",
    `Gider: ${formatMoneyTr(totalExpenses)}`,
    `Kasa: ${formatMoneyTr(generalCashRegister)}`,
    `Nakit: ${formatMoneyTr(generalCashStatus)}`,
    "--------------------------------",
    "DİĞER:",
    `Adet/Kişi: ${totalOrders} / ${averageGuestCount}`,
    `Ort. Harcama: ${formatMoneyTr(totalRevenue / (totalOrders || 1))}`,
  ];

  lines.push("--------------------------------");
  lines.push(`Kasiyer: ${process.env.DEFAULT_KASIYER || "YÖNETİCİ"}`);

  return lines.join("\n");
}

function resolveDepartmentPrinter(categoryName) {
  const normalized = String(categoryName ?? "").trim().toUpperCase();
  return BAR_CATEGORIES.has(normalized) ? PRINTER_TYPES.BAR : PRINTER_TYPES.MUTFAK;
}

function splitItemsByPrinter(items = []) {
  return items.reduce((accumulator, item) => {
    const printerType =
      normalizePrinterType(item.printer_route || item.printerRoute) ||
      resolveDepartmentPrinter(item.category_name || item.categoryName);
    if (!accumulator[printerType]) {
      accumulator[printerType] = [];
    }
    accumulator[printerType].push(item);
    return accumulator;
  }, {});
}

async function enqueueOrderDepartmentTickets({
  tableDisplayName,
  waiterName,
  orderId,
  guestCount,
  items,
  confirmedAt,
}) {
  const grouped = splitItemsByPrinter(items);
  await Promise.all(
    Object.entries(grouped).map(([printerType, printerItems]) => {
      const title = `${printerType} FISI`;
      return enqueuePrintJob({
        printerType,
        ticketType: "ORDER_CONFIRMATION",
        payload: {
          tableDisplayName,
          waiterName,
          orderId,
          guestCount: guestCount || 0,
          items: printerItems,
          confirmedAt,
          text: buildKitchenText({
            title,
            tableDisplayName,
            waiterName,
            orderId,
            items: printerItems,
            confirmedAt,
          }),
        },
      });
    })
  );
}

async function enqueueCashReceipt(payload) {
  await enqueuePrintJob({
    printerType: PRINTER_TYPES.KASA,
    ticketType: "CUSTOMER_RECEIPT",
    payload: {
      ...payload,
      text: buildCashReceiptText(payload),
    },
  });
}

async function enqueueCurrentAccountReceipt(payload) {
  await enqueuePrintJob({
    printerType: PRINTER_TYPES.KASA,
    ticketType: "CURRENT_ACCOUNT",
    payload: {
      ...payload,
      text: buildCurrentAccountText(payload),
    },
  });
}

async function enqueueItemCancelledReceipt(payload) {
  const firstItem = Array.isArray(payload?.items) && payload.items.length
    ? payload.items[0]
    : null;
  const printerType =
    normalizePrinterType(firstItem?.printer_route || firstItem?.printerRoute) ||
    resolveDepartmentPrinter(firstItem?.category_name || firstItem?.categoryName);

  await enqueuePrintJob({
    printerType,
    ticketType: "ITEM_CANCELLED",
    payload,
  });
}

async function enqueueZReport(payload) {
  await enqueuePrintJob({
    printerType: PRINTER_TYPES.KASA,
    ticketType: "Z_REPORT",
    payload: {
      ...payload,
      text: buildZReportText(payload),
    },
  });
}

async function enqueueXReport(payload) {
  await enqueuePrintJob({
    printerType: PRINTER_TYPES.KASA,
    ticketType: "X_REPORT",
    payload: {
      ...payload,
      text: buildXReportText(payload),
    },
  });
}

async function printKitchenReceipt({
  tableDisplayName,
  waiterName,
  orderId,
  guestCount,
  items,
  confirmedAt,
}) {
  await enqueueOrderDepartmentTickets({
    tableDisplayName,
    waiterName,
    orderId,
    guestCount,
    items,
    confirmedAt,
  });
}

function getPrinterSnapshot() {
  return DEPARTMENT_ROUTES.map((printerType) => ({
    printerType,
    target: getPrinterTarget(printerType),
  }));
}

function attachSocketServer() {}
function registerPrinterAgent() { return null; }
function unregisterPrinterAgent() {}
function markPrinterHeartbeat() {}

module.exports = {
  PRINTER_TYPES,
  attachSocketServer,
  registerPrinterAgent,
  unregisterPrinterAgent,
  markPrinterHeartbeat,
  getPrinterSnapshot,
  printKitchenReceipt,
  enqueueCashReceipt,
  enqueueCurrentAccountReceipt,
  enqueueItemCancelledReceipt,
  enqueueOrderDepartmentTickets,
  enqueueZReport,
  enqueueXReport,
  formatMoney,
};
