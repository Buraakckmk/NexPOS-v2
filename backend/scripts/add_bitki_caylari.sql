-- BİTKİ ÇAYLARI kategorisi ve ürünleri ekleme scripti
-- Encoding: UTF8

-- 1) Mevcut sort_order >= 5 olan kategorileri 1 kaydır (BİTKİ ÇAYLARI için yer aç)
UPDATE categories SET sort_order = sort_order + 1 WHERE sort_order >= 5 AND is_active = TRUE;

-- 2) BİTKİ ÇAYLARI kategorisini ekle
INSERT INTO categories (name, printer_route, is_active, sort_order)
VALUES ('BİTKİ ÇAYLARI', 'BAR', TRUE, 5)
ON CONFLICT (name) DO UPDATE
  SET is_active = TRUE,
      printer_route = 'BAR',
      sort_order = 5,
      updated_at = NOW()
RETURNING id, name, sort_order;

-- 3) Yeni kategori ID'sini al ve ürünleri ekle
DO $$
DECLARE
  cat_id BIGINT;
BEGIN
  SELECT id INTO cat_id FROM categories WHERE UPPER(name) = UPPER('BİTKİ ÇAYLARI') LIMIT 1;

  IF cat_id IS NULL THEN
    RAISE EXCEPTION 'BİTKİ ÇAYLARI kategorisi bulunamadı';
  END IF;

  -- Ürünleri ekle (zaten varsa fiyatı güncelle)
  INSERT INTO products (name, price, category_id, category, is_active)
  VALUES
    ('Papatya',             160.00, cat_id, 'BİTKİ ÇAYLARI', TRUE),
    ('Ihlamur',             160.00, cat_id, 'BİTKİ ÇAYLARI', TRUE),
    ('Adaçayı',             160.00, cat_id, 'BİTKİ ÇAYLARI', TRUE),
    ('Rezene',              160.00, cat_id, 'BİTKİ ÇAYLARI', TRUE),
    ('Kuşburnu Çayı',       160.00, cat_id, 'BİTKİ ÇAYLARI', TRUE),
    ('Nane – Limon Çayı',   160.00, cat_id, 'BİTKİ ÇAYLARI', TRUE),
    ('Nar Çayı',            160.00, cat_id, 'BİTKİ ÇAYLARI', TRUE),
    ('Çilek Çayı',          160.00, cat_id, 'BİTKİ ÇAYLARI', TRUE),
    ('Böğürtlen Çayı',      160.00, cat_id, 'BİTKİ ÇAYLARI', TRUE),
    ('Elma Çayı',           160.00, cat_id, 'BİTKİ ÇAYLARI', TRUE),
    ('Melisa',              160.00, cat_id, 'BİTKİ ÇAYLARI', TRUE),
    ('Zencefil Çayı',       160.00, cat_id, 'BİTKİ ÇAYLARI', TRUE),
    ('Kış Çayı',            160.00, cat_id, 'BİTKİ ÇAYLARI', TRUE),
    ('Winter Tea',          160.00, cat_id, 'BİTKİ ÇAYLARI', TRUE)
  ON CONFLICT (category_id, name) DO UPDATE
    SET is_active = TRUE,
        price = EXCLUDED.price,
        updated_at = NOW();

  RAISE NOTICE 'BİTKİ ÇAYLARI ürünleri başarıyla eklendi. Kategori ID: %', cat_id;
END $$;

-- 4) Sonucu göster
SELECT p.id, p.name, p.price, c.name AS category
FROM products p
JOIN categories c ON c.id = p.category_id
WHERE UPPER(c.name) = UPPER('BİTKİ ÇAYLARI')
  AND p.is_active = TRUE
ORDER BY p.name ASC;
