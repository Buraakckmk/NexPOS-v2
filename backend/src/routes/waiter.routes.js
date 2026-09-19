const express = require("express");
const { authenticate, authorize } = require("../middlewares/auth.middleware");
const { ROLES } = require("../constants/roles");
const tableController = require("../controllers/table.controller");
const orderController = require("../controllers/order.controller");
const productController = require("../controllers/product.controller");
const { asyncHandler } = require("../utils/async-handler");

const router = express.Router();

router.get(
  "/tables",
  authenticate,
  authorize(ROLES.ADMIN, ROLES.WAITER),
  asyncHandler(tableController.listTables)
);

router.post(
  "/tables/custom",
  authenticate,
  authorize(ROLES.ADMIN, ROLES.WAITER),
  asyncHandler(tableController.createCustomTable)
);

router.delete(
  "/tables/custom/:tableId",
  authenticate,
  authorize(ROLES.ADMIN),
  asyncHandler(tableController.deleteCustomTable)
);

router.get(
  "/products",
  authenticate,
  authorize(ROLES.ADMIN, ROLES.WAITER),
  asyncHandler(productController.listProducts)
);

router.get(
  "/tables/:tableId/active-order",
  authenticate,
  authorize(ROLES.ADMIN, ROLES.WAITER),
  asyncHandler(orderController.getActiveOrderByTable)
);

router.post(
  "/tables/:tableId/print-current-account",
  authenticate,
  authorize(ROLES.ADMIN, ROLES.WAITER),
  asyncHandler(orderController.printCurrentAccount)
);

router.post(
  "/orders",
  authenticate,
  authorize(ROLES.ADMIN, ROLES.WAITER),
  asyncHandler(orderController.createOrder)
);

router.post(
  "/orders/:orderId/confirm",
  authenticate,
  authorize(ROLES.ADMIN, ROLES.WAITER),
  asyncHandler(orderController.confirmOrder)
);

router.post(
  "/orders/:orderId/checkout",
  authenticate,
  authorize(ROLES.ADMIN),
  asyncHandler(orderController.checkoutOrder)
);

router.post(
  "/orders/:orderId/payment-session/start",
  authenticate,
  authorize(ROLES.ADMIN),
  asyncHandler(orderController.startPaymentSession)
);

router.post(
  "/orders/:orderId/payment-session/end",
  authenticate,
  authorize(ROLES.ADMIN),
  asyncHandler(orderController.endPaymentSession)
);

router.post(
  "/orders/:orderId/partial-checkout",
  authenticate,
  authorize(ROLES.ADMIN),
  asyncHandler(orderController.partialCheckout)
);

router.post(
  "/orders/:orderId/amount-payment",
  authenticate,
  authorize(ROLES.ADMIN),
  asyncHandler(orderController.amountPayment)
);

router.post(
  "/orders/:orderId/void-item",
  authenticate,
  authorize(ROLES.ADMIN, ROLES.WAITER),
  asyncHandler(orderController.voidOrderItem)
);

router.post(
  "/orders/:orderId/comp-item",
  authenticate,
  authorize(ROLES.ADMIN, ROLES.WAITER),
  asyncHandler(orderController.compOrderItem)
);

router.post(
  "/orders/:orderId/item-note",
  authenticate,
  authorize(ROLES.ADMIN, ROLES.WAITER),
  asyncHandler(orderController.updateOrderItemNote)
);

router.post(
  "/orders/:orderId/item-price",
  authenticate,
  authorize(ROLES.ADMIN),
  asyncHandler(orderController.updateOrderItemPrice)
);

router.post(
  "/orders/:orderId/meta",
  authenticate,
  authorize(ROLES.ADMIN, ROLES.WAITER),
  asyncHandler(orderController.updateOrderMeta)
);

router.post(
  "/orders/:orderId/transfer-item",
  authenticate,
  authorize(ROLES.ADMIN, ROLES.WAITER),
  asyncHandler(orderController.transferOrderItem)
);

router.post(
  "/tables/transfer",
  authenticate,
  authorize(ROLES.ADMIN, ROLES.WAITER),
  asyncHandler(orderController.transferTable)
);

router.post(
  "/tables/merge",
  authenticate,
  authorize(ROLES.ADMIN, ROLES.WAITER),
  asyncHandler(orderController.mergeTable)
);

module.exports = router;
