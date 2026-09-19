-- ==========================================
-- NexPOS / AdisyON PostgreSQL Schema Export
-- Database: adisyon_db
-- ==========================================

-- 1. USERS TABLE
CREATE TABLE IF NOT EXISTS users (
  id BIGSERIAL PRIMARY KEY,
  full_name VARCHAR(120) NOT NULL,
  pin_code VARCHAR(255) NOT NULL UNIQUE,
  role_id SMALLINT NOT NULL CHECK (role_id IN (1, 2)),
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2. CATEGORIES TABLE
CREATE TABLE IF NOT EXISTS categories (
  id BIGSERIAL PRIMARY KEY,
  name VARCHAR(100) NOT NULL UNIQUE,
  image_path VARCHAR(255),
  printer_route VARCHAR(20) NOT NULL DEFAULT 'MUTFAK' CHECK (printer_route IN ('MUTFAK', 'BAR', 'KASA')),
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  sort_order INT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 3. PRODUCTS TABLE
CREATE TABLE IF NOT EXISTS products (
  id BIGSERIAL PRIMARY KEY,
  category_id BIGINT NOT NULL REFERENCES categories(id) ON DELETE RESTRICT,
  category VARCHAR(100),
  name VARCHAR(140) NOT NULL,
  sku VARCHAR(60),
  price NUMERIC(12, 2) NOT NULL CHECK (price >= 0),
  vat_rate NUMERIC(5, 2) NOT NULL DEFAULT 10.00 CHECK (vat_rate >= 0),
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (category_id, name)
);

-- 4. TABLES (MASALAR) TABLE
CREATE TABLE IF NOT EXISTS tables (
  id BIGSERIAL PRIMARY KEY,
  table_code VARCHAR(20) NOT NULL UNIQUE,
  display_name VARCHAR(80) NOT NULL,
  zone VARCHAR(60) NOT NULL DEFAULT 'Oyun Salonu',
  capacity INT NOT NULL DEFAULT 4 CHECK (capacity > 0),
  is_custom BOOLEAN NOT NULL DEFAULT FALSE,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 5. ORDERS TABLE
CREATE TABLE IF NOT EXISTS orders (
  id BIGSERIAL PRIMARY KEY,
  table_id BIGINT NOT NULL REFERENCES tables(id) ON DELETE RESTRICT,
  waiter_id BIGINT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  opened_by_user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  closed_by_user_id BIGINT REFERENCES users(id) ON DELETE RESTRICT,
  payment_method VARCHAR(20) CHECK (payment_method IN ('CASH', 'CARD', 'MEAL_CARD', 'CUSTOMER', 'MIXED', 'OTHER')),
  order_status VARCHAR(20) NOT NULL DEFAULT 'OPEN' CHECK (order_status IN ('OPEN', 'CONFIRMED', 'PAID', 'CANCELLED')),
  note TEXT,
  guest_count INT NOT NULL DEFAULT 1 CHECK (guest_count > 0),
  table_note TEXT,
  subtotal NUMERIC(12, 2) NOT NULL DEFAULT 0 CHECK (subtotal >= 0),
  discount_total NUMERIC(12, 2) NOT NULL DEFAULT 0 CHECK (discount_total >= 0),
  grand_total NUMERIC(12, 2) NOT NULL DEFAULT 0 CHECK (grand_total >= 0),
  opened_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  confirmed_at TIMESTAMPTZ,
  closed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 6. ORDER ITEMS TABLE
CREATE TABLE IF NOT EXISTS order_items (
  id BIGSERIAL PRIMARY KEY,
  order_id BIGINT NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  product_id BIGINT NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
  category_snapshot VARCHAR(100),
  printer_route_snapshot VARCHAR(20) NOT NULL DEFAULT 'MUTFAK' CHECK (printer_route_snapshot IN ('MUTFAK', 'BAR', 'KASA')),
  product_name_snapshot VARCHAR(140) NOT NULL,
  unit_price_snapshot NUMERIC(12, 2) NOT NULL CHECK (unit_price_snapshot >= 0),
  quantity NUMERIC(10, 2) NOT NULL CHECK (quantity > 0),
  line_total NUMERIC(12, 2) NOT NULL CHECK (line_total >= 0),
  item_status VARCHAR(20) NOT NULL DEFAULT 'PENDING' CHECK (item_status IN ('PENDING', 'SENT', 'PAID', 'VOID')),
  note TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 7. PAYMENTS TABLE
CREATE TABLE IF NOT EXISTS payments (
  id BIGSERIAL PRIMARY KEY,
  order_id BIGINT NOT NULL REFERENCES orders(id) ON DELETE RESTRICT,
  received_by_user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  payment_method VARCHAR(20) NOT NULL CHECK (payment_method IN ('CASH', 'CARD', 'MEAL_CARD', 'CUSTOMER', 'MIXED', 'OTHER')),
  amount NUMERIC(12, 2) NOT NULL CHECK (amount > 0),
  discount_amount NUMERIC(12, 2) NOT NULL DEFAULT 0 CHECK (discount_amount >= 0),
  currency VARCHAR(3) NOT NULL DEFAULT 'TRY',
  meal_card_type VARCHAR(100),
  payment_note TEXT,
  paid_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 8. VOIDS TABLE
CREATE TABLE IF NOT EXISTS voids (
  id BIGSERIAL PRIMARY KEY,
  order_id BIGINT NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  order_item_id BIGINT REFERENCES order_items(id) ON DELETE SET NULL,
  product_id BIGINT NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
  action_type VARCHAR(20) NOT NULL CHECK (action_type IN ('VOID', 'COMP')),
  quantity NUMERIC(10, 2) NOT NULL DEFAULT 0 CHECK (quantity >= 0),
  reason TEXT,
  created_by_user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 9. Z REPORTS TABLE
CREATE TABLE IF NOT EXISTS z_reports (
  id BIGSERIAL PRIMARY KEY,
  report_date DATE NOT NULL UNIQUE,
  total_revenue NUMERIC(12, 2) NOT NULL DEFAULT 0,
  cash_total NUMERIC(12, 2) NOT NULL DEFAULT 0,
  card_total NUMERIC(12, 2) NOT NULL DEFAULT 0,
  total_orders INT NOT NULL DEFAULT 0,
  total_subtotal NUMERIC(12, 2) NOT NULL DEFAULT 0,
  total_vat NUMERIC(12, 2) NOT NULL DEFAULT 0,
  generated_by_user_id BIGINT REFERENCES users(id) ON DELETE SET NULL,
  payload JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 10. EXPENSES TABLE
CREATE TABLE IF NOT EXISTS expenses (
  id BIGSERIAL PRIMARY KEY,
  expense_date DATE NOT NULL DEFAULT CURRENT_DATE,
  item_name VARCHAR(160) NOT NULL,
  quantity NUMERIC(10, 2) NOT NULL CHECK (quantity > 0),
  unit_price NUMERIC(12, 2) NOT NULL CHECK (unit_price >= 0),
  total_amount NUMERIC(12, 2) NOT NULL CHECK (total_amount >= 0),
  note TEXT,
  created_by_user_id BIGINT REFERENCES users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 11. CUSTOMERS TABLE
CREATE TABLE IF NOT EXISTS customers (
  id BIGSERIAL PRIMARY KEY,
  full_name VARCHAR(140) NOT NULL,
  phone VARCHAR(20),
  email VARCHAR(100),
  balance NUMERIC(12, 2) NOT NULL DEFAULT 0,
  note TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 12. CUSTOMER TRANSACTIONS TABLE
CREATE TABLE IF NOT EXISTS customer_transactions (
  id BIGSERIAL PRIMARY KEY,
  customer_id BIGINT NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
  order_id BIGINT REFERENCES orders(id) ON DELETE SET NULL,
  type VARCHAR(20) NOT NULL CHECK (type IN ('DEBIT', 'CREDIT')),
  amount NUMERIC(12, 2) NOT NULL CHECK (amount > 0),
  note TEXT,
  created_by_user_id BIGINT REFERENCES users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 13. PRINT QUEUE TABLE
CREATE TABLE IF NOT EXISTS print_queue (
  id BIGSERIAL PRIMARY KEY,
  printer_route VARCHAR(20) NOT NULL CHECK (printer_route IN ('MUTFAK', 'BAR', 'KASA')),
  payload JSONB NOT NULL DEFAULT '{}'::jsonb,
  status VARCHAR(20) NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'SENT', 'FAILED')),
  retry_count INT NOT NULL DEFAULT 0,
  error_message TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 14. PROCESSED REQUESTS TABLE
CREATE TABLE IF NOT EXISTS processed_requests (
  request_id VARCHAR(100) PRIMARY KEY,
  response_payload JSONB NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- INDEXES
CREATE INDEX IF NOT EXISTS idx_orders_table_id ON orders(table_id);
CREATE INDEX IF NOT EXISTS idx_orders_waiter_id ON orders(waiter_id);
CREATE INDEX IF NOT EXISTS idx_orders_status ON orders(order_status);
CREATE INDEX IF NOT EXISTS idx_orders_closed_at ON orders(closed_at);
CREATE INDEX IF NOT EXISTS idx_order_items_order_id ON order_items(order_id);
CREATE INDEX IF NOT EXISTS idx_order_items_status ON order_items(item_status);
CREATE INDEX IF NOT EXISTS idx_order_items_category_snapshot ON order_items(category_snapshot);
CREATE INDEX IF NOT EXISTS idx_products_category_id ON products(category_id);
CREATE INDEX IF NOT EXISTS idx_payments_order_id ON payments(order_id);
CREATE INDEX IF NOT EXISTS idx_payments_paid_at ON payments(paid_at);
CREATE INDEX IF NOT EXISTS idx_voids_order_id ON voids(order_id);
CREATE INDEX IF NOT EXISTS idx_z_reports_report_date ON z_reports(report_date);
CREATE INDEX IF NOT EXISTS idx_expenses_expense_date ON expenses(expense_date);
CREATE INDEX IF NOT EXISTS idx_customers_phone ON customers(phone);
CREATE INDEX IF NOT EXISTS idx_customer_transactions_customer_id ON customer_transactions(customer_id);
CREATE INDEX IF NOT EXISTS idx_print_queue_status ON print_queue(status);

-- DEFAULT USERS
-- Garson PIN: 122323
-- Admin PIN: 062362
INSERT INTO users (full_name, pin_code, role_id, is_active)
VALUES 
  ('Garson Kullanıcı', '$2a$10$wN9QkE0E3Tz4eK0pP9Y.d.6Xh.j3Wd3.Xf1d1.Xf1d1.Xf1d1.Xf1', 2, TRUE),
  ('Admin Kullanıcı', '$2a$10$xM8PjD9D2Sy3dJ9oO8X.c.5Wg.i2Vc2.We0c0.We0c0.We0c0.We0', 1, TRUE)
ON CONFLICT (pin_code) DO NOTHING;
