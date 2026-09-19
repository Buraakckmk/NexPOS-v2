const path = require("path");
require("dotenv").config({ path: path.resolve(__dirname, "../.env") });
const printerService = require("../src/services/printer.service");

async function runTest() {
  console.log("--- Standalone Printer Routing Test Started ---");
  console.log("Target IPs:");
  console.log("- BAR:   ", process.env.BAR_PRINTER_IP);
  console.log("- MUTFAK:", process.env.MUTFAK_PRINTER_IP);
  console.log("- KASA:  ", process.env.KASA_PRINTER_IP);
  console.log("Target Ports:");
  console.log("- BAR:   ", process.env.BAR_PRINTER_PORT || process.env.PRINTER_PORT);
  console.log("- MUTFAK:", process.env.MUTFAK_PRINTER_PORT || process.env.PRINTER_PORT);
  console.log("- KASA:  ", process.env.KASA_PRINTER_PORT || process.env.PRINTER_PORT);
  console.log("-----------------------------------------------");

  const mockOrder = {
    tableDisplayName: "TEST MASA 1",
    waiterName: "TEST GARSON",
    orderId: "9999",
    confirmedAt: new Date().toISOString(),
    items: [
      { name: "Adana Kebap (Mutfak)", quantity: 1, category_name: "ANA YEMEKLER" },
      { name: "Sıcak Çay (Bar)", quantity: 2, category_name: "SICAK İÇECEKLER" },
    ],
  };

  try {
    // 1. Test Department Routing (Mutfak & Bar)
    console.log(
      `>> Sending Adana Kebap to Mutfak (${process.env.MUTFAK_PRINTER_IP}:${process.env.MUTFAK_PRINTER_PORT || process.env.PRINTER_PORT}) & Çay to Bar (${process.env.BAR_PRINTER_IP}:${process.env.BAR_PRINTER_PORT || process.env.PRINTER_PORT})...`
    );
    await printerService.enqueueOrderDepartmentTickets(mockOrder);

    // 2. Test Cash Receipt (Kasa)
    console.log(
      `>> Sending Adisyon to Kasa (${process.env.KASA_PRINTER_IP}:${process.env.KASA_PRINTER_PORT || process.env.PRINTER_PORT})...`
    );
    await printerService.enqueueCashReceipt({
      tableDisplayName: mockOrder.tableDisplayName,
      orderId: mockOrder.orderId,
      items: [
        { name: "Adana Kebap", quantity: 1, unit_price: 250 },
        { name: "Sıcak Çay", quantity: 2, unit_price: 25 },
      ],
      subtotal: 300,
      discountAmount: 0,
      vatAmount: 30,
      grandTotal: 300,
      paymentMethod: "NAKİT",
    });

    console.log("-----------------------------------------------");
    console.log("Test commands sent to printer queues.");
    console.log("Please check your physical printers now.");
  } catch (error) {
    console.error("Test failed:", error);
  }
}

runTest();
