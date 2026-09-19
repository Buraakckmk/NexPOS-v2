
-- Add meal_card_type column to payments table
ALTER TABLE payments ADD COLUMN IF NOT EXISTS meal_card_type VARCHAR(100);

-- Update the payment method check constraint to include MEAL_CARD
ALTER TABLE payments DROP CONSTRAINT IF EXISTS payments_payment_method_check;
ALTER TABLE payments ADD CONSTRAINT payments_payment_method_check CHECK (payment_method IN ('CASH', 'CARD', 'MEAL_CARD', 'MIXED', 'OTHER'));

-- Also update orders table's payment_method check constraint too
ALTER TABLE orders DROP CONSTRAINT IF EXISTS orders_payment_method_check;
ALTER TABLE orders ADD CONSTRAINT orders_payment_method_check CHECK (payment_method IN ('CASH', 'CARD', 'MEAL_CARD', 'MIXED', 'OTHER'));
