BEGIN;

-- Clean slate for sales/order history without touching menu or table structure.
TRUNCATE TABLE
  expenses,
  payments,
  voids,
  order_items,
  orders,
  z_reports
RESTART IDENTITY CASCADE;

COMMIT;
