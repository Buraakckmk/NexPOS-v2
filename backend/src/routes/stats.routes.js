const express = require("express");
const { authenticate, authorize } = require("../middlewares/auth.middleware");
const { ROLES } = require("../constants/roles");
const statsController = require("../controllers/stats.controller");
const { asyncHandler } = require("../utils/async-handler");

const router = express.Router();

// Günlük özet istatistikleri (Hem Admin hem Garson görebilir, 
// ancak frontend'de garson için kısıtlanacak)
router.get(
  "/daily-summary",
  authenticate,
  authorize(ROLES.ADMIN, ROLES.WAITER),
  asyncHandler(statsController.getDailySummary)
);

module.exports = router;
