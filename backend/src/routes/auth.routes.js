const express = require("express");
const authController = require("../controllers/auth.controller");
const { authenticate } = require("../middlewares/auth.middleware");
const { asyncHandler } = require("../utils/async-handler");

const router = express.Router();

router.post("/login/pin", asyncHandler(authController.loginWithPin));
router.post("/verify-admin", asyncHandler(authController.verifyAdmin));
router.get("/me", authenticate, asyncHandler(authController.me));

module.exports = router;
