const express = require("express");
const { authenticate, authorize } = require("../middlewares/auth.middleware");
const { ROLES } = require("../constants/roles");
const printerService = require("../services/printer.service");
const { asyncHandler } = require("../utils/async-handler");

const router = express.Router();

/**
 * Test printer routing by sending a mock order
 * Category determines routing: 'SICAK İÇECEKLER' -> BAR, others -> MUTFAK
 * This endpoint also tests KASA printer.
 */
router.post(
  "/test-routing",
  authenticate,
  authorize(ROLES.ADMIN),
  asyncHandler(async (req, res) => {
    const mockOrder = {
      tableDisplayName: "TEST MASA 1",
      waiterName: "TEST GARSON",
      orderId: "9999",
      confirmedAt: new Date().toISOString(),
      items: [
        { name: "Test Kebap (Mutfak)", quantity: 1, category_name: "ANA YEMEKLER" },
        { name: "Test Çay (Bar)", quantity: 2, category_name: "SICAK İÇECEKLER" },
      ],
    };

    console.log("--- Printer Routing Test Started ---");
    
    // 1. Test Department Routing (Mutfak & Bar)
    console.log("Testing Mutfak & Bar routing...");
    await printerService.enqueueOrderDepartmentTickets(mockOrder);

    // 2. Test Cash Receipt (Kasa)
    console.log("Testing Kasa routing...");
    await printerService.enqueueCashReceipt({
      tableDisplayName: mockOrder.tableDisplayName,
      orderId: mockOrder.orderId,
      items: [
        { name: "Test Kebap", quantity: 1, unit_price: 250 },
        { name: "Test Çay", quantity: 2, unit_price: 25 },
      ],
      subtotal: 300,
      discountAmount: 0,
      vatAmount: 30,
      grandTotal: 300,
      paymentMethod: "NAKİT",
    });

    console.log("--- Printer Routing Test Finished ---");

    return res.status(200).json({
      message: "Yazıcı yönlendirme testi başlatıldı. Terminal loglarını ve yazıcıları kontrol edin.",
      targetIps: {
        bar: process.env.BAR_PRINTER_IP,
        mutfak: process.env.MUTFAK_PRINTER_IP,
        kasa: process.env.KASA_PRINTER_IP,
      },
      mockOrder,
    });
  })
);

module.exports = router;
