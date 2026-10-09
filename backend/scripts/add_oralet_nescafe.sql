-- Oralet and Nescafe varieties for the ÇAYLAR category.
-- Safe to run more than once; existing matching products are reactivated and repriced.
DO $$
DECLARE
  tea_category_id BIGINT;
BEGIN
  SELECT id INTO tea_category_id
  FROM categories
  WHERE UPPER(name) = UPPER('ÇAYLAR')
  LIMIT 1;

  IF tea_category_id IS NULL THEN
    RAISE EXCEPTION 'ÇAYLAR kategorisi bulunamadı';
  END IF;

  INSERT INTO products (name, price, category_id, category, is_active)
  VALUES
    ('Oralet', 30.00, tea_category_id, 'ÇAYLAR', TRUE),
    ('Nescafe 2''si 1 Arada', 80.00, tea_category_id, 'ÇAYLAR', TRUE),
    ('Nescafe 3''ü 1 Arada', 80.00, tea_category_id, 'ÇAYLAR', TRUE)
  ON CONFLICT (category_id, name) DO UPDATE
    SET price = EXCLUDED.price,
        category = EXCLUDED.category,
        is_active = TRUE,
        updated_at = NOW();
END $$;

SELECT p.name, p.price, c.name AS category
FROM products p
JOIN categories c ON c.id = p.category_id
WHERE c.id = (SELECT id FROM categories WHERE UPPER(name) = UPPER('ÇAYLAR'))
  AND p.name IN ('Oralet', 'Nescafe 2''si 1 Arada', 'Nescafe 3''ü 1 Arada')
  AND p.is_active = TRUE
ORDER BY p.name;
