const express = require("express");
const authRoutes = require("./auth.routes");
const waiterRoutes = require("./waiter.routes");
const adminRoutes = require("./admin.routes");
const statsRoutes = require("./stats.routes");
const testRoutes = require("./test.routes");
const { authenticate, authorize } = require("../middlewares/auth.middleware");
const { ROLES } = require("../constants/roles");

const router = express.Router();

router.get("/health", (req, res) => {
  res.status(200).json({ status: "ok" });
});

router.use("/auth", authRoutes);
router.use("/waiter", waiterRoutes);
router.use("/admin", adminRoutes);
router.use("/stats", statsRoutes);
router.use("/test", testRoutes);

// RBAC örnek endpointi (MVP placeholder)
router.get(
  "/admin/operations",
  authenticate,
  authorize(ROLES.ADMIN),
  (req, res) => res.status(200).json({ message: "Admin operasyon alani." })
);

module.exports = router;
