-- parent_category_id kolonu ekle ve BİTKİ ÇAYLARI'yı ÇAYLAR'ın altına al
-- Encoding: UTF8

-- 1) parent_category_id kolonu ekle (yoksa)
ALTER TABLE categories
  ADD COLUMN IF NOT EXISTS parent_category_id BIGINT REFERENCES categories(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_categories_parent_id ON categories(parent_category_id);

-- 2) BİTKİ ÇAYLARI'nı ÇAYLAR'ın alt kategorisi yap
UPDATE categories
SET parent_category_id = (SELECT id FROM categories WHERE UPPER(name) = 'ÇAYLAR' LIMIT 1)
WHERE UPPER(name) = 'BİTKİ ÇAYLARI';

-- 3) Sonucu doğrula
SELECT c.id, c.name, c.sort_order, c.parent_category_id,
       p.name AS parent_name
FROM categories c
LEFT JOIN categories p ON p.id = c.parent_category_id
WHERE c.is_active = TRUE
ORDER BY c.sort_order ASC NULLS LAST, c.name ASC;
