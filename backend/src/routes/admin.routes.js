const express = require("express");
const router = express.Router();
const adminController = require("../controllers/admin.controller");
const productController = require("../controllers/product.controller");
const { authenticate, authorize } = require("../middlewares/auth.middleware");
const { ROLES } = require("../constants/roles");
const { asyncHandler } = require("../utils/async-handler");

// Günlük özet endpoint'i
router.get(
	"/daily-summary",
	authenticate,
	authorize(ROLES.ADMIN),
	asyncHandler(adminController.getDailySummary)
);

// Günlük geçmiş listesi
router.get(
	"/daily-history",
	authenticate,
	authorize(ROLES.ADMIN),
	asyncHandler(adminController.getDailyHistory)
);

// X Raporu endpoint'i
router.get(
	"/x-report",
	authenticate,
	authorize(ROLES.ADMIN),
	asyncHandler(adminController.getXReport)
);

router.post(
	"/x-report/print",
	authenticate,
	authorize(ROLES.ADMIN),
	asyncHandler(adminController.printXReport)
);

// İstatistikler endpoint'i
router.get(
	"/stats",
	authenticate,
	authorize(ROLES.ADMIN),
	asyncHandler(adminController.getStats)
);

// Tahsil edilen hesaplar listesi (mevcut dönem)
router.get(
	"/paid-transactions",
	authenticate,
	authorize(ROLES.ADMIN),
	asyncHandler(adminController.getPaidTransactions)
);

router.patch(
	"/payments/:paymentId/method",
	authenticate,
	authorize(ROLES.ADMIN),
	asyncHandler(adminController.updatePaymentMethod)
);

router.delete(
	"/payments/:paymentId",
	authenticate,
	authorize(ROLES.ADMIN),
	asyncHandler(adminController.deletePayment)
);

// 30 günlük kasa / gelir-gider özeti
router.get(
	"/finance-summary",
	authenticate,
	authorize(ROLES.ADMIN),
	asyncHandler(adminController.getFinanceSummary)
);

// Gider kayıtları
router.get(
	"/expenses",
	authenticate,
	authorize(ROLES.ADMIN),
	asyncHandler(adminController.listExpenses)
);

router.post(
	"/expenses",
	authenticate,
	authorize(ROLES.ADMIN),
	asyncHandler(adminController.createExpense)
);

router.patch(
	"/expenses/:id",
	authenticate,
	authorize(ROLES.ADMIN),
	asyncHandler(adminController.updateExpense)
);

router.delete(
	"/expenses/:id",
	authenticate,
	authorize(ROLES.ADMIN),
	asyncHandler(adminController.deleteExpense)
);

// Z Raporu endpoint'i
router.post(
	"/z-report",
	authenticate,
	authorize(ROLES.ADMIN),
	asyncHandler(adminController.generateZReport)
);

router.get(
	"/menu/categories",
	authenticate,
	authorize(ROLES.ADMIN),
	asyncHandler(productController.listCategoriesAdmin)
);

router.post(
	"/menu/categories",
	authenticate,
	authorize(ROLES.ADMIN),
	asyncHandler(productController.createCategoryAdmin)
);

router.delete(
	"/menu/categories/:categoryId",
	authenticate,
	authorize(ROLES.ADMIN),
	asyncHandler(productController.deleteCategoryAdmin)
);

router.get(
	"/menu/products",
	authenticate,
	authorize(ROLES.ADMIN),
	asyncHandler(productController.listProductsAdmin)
);

router.post(
	"/menu/products",
	authenticate,
	authorize(ROLES.ADMIN),
	asyncHandler(productController.createProductAdmin)
);

router.patch(
	"/menu/products/:productId",
	authenticate,
	authorize(ROLES.ADMIN),
	asyncHandler(productController.updateProductAdmin)
);

router.delete(
	"/menu/products/:productId",
	authenticate,
	authorize(ROLES.ADMIN),
	asyncHandler(productController.deleteProductAdmin)
);

const customerController = require("../controllers/customer.controller");

// Son gün sonu Excel indir
router.get(
	"/z-report/excel",
	authenticate,
	authorize(ROLES.ADMIN),
	asyncHandler(adminController.exportZReportExcel)
);

// Müşteri / Cari Hesap Yönetimi
router.get(
	"/customers",
	authenticate,
	authorize(ROLES.ADMIN, ROLES.WAITER),
	asyncHandler(customerController.listCustomers)
);

router.get(
	"/customers/:id",
	authenticate,
	authorize(ROLES.ADMIN, ROLES.WAITER),
	asyncHandler(customerController.getCustomerById)
);

router.post(
	"/customers",
	authenticate,
	authorize(ROLES.ADMIN, ROLES.WAITER),
	asyncHandler(customerController.createCustomer)
);

router.patch(
	"/customers/:id",
	authenticate,
	authorize(ROLES.ADMIN),
	asyncHandler(customerController.updateCustomer)
);

router.delete(
	"/customers/:id",
	authenticate,
	authorize(ROLES.ADMIN),
	asyncHandler(customerController.deleteCustomer)
);

router.post(
	"/customers/transactions",
	authenticate,
	authorize(ROLES.ADMIN, ROLES.WAITER),
	asyncHandler(customerController.addTransaction)
);

module.exports = router;
