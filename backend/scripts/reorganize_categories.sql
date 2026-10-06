-- Kategorileri hiyerarşik yapıya geçirme scripti
-- Encoding: UTF8

-- 1. KAHVELER ana kategorisini oluştur
INSERT INTO categories (name, printer_route, is_active, sort_order)
VALUES ('KAHVELER', 'BAR', TRUE, 10)
ON CONFLICT (name) DO UPDATE SET is_active = TRUE, sort_order = 10, parent_category_id = NULL
RETURNING id;

-- 2. Kahve alt kategorilerini KAHVELER altına taşı
UPDATE categories
SET parent_category_id = (SELECT id FROM categories WHERE UPPER(name) = 'KAHVELER' LIMIT 1)
WHERE UPPER(name) IN (
    'TÜRK KAHVESİ ÇEŞİTLERİ',
    'ESPRESSOLU KAHVELER',
    'FİLTRE KAHVELER',
    'SOĞUK KAHVELER',
    'YENİ NESİL KAHVELER'
);

-- 3. YEMEKLER ana kategorisini oluştur
INSERT INTO categories (name, printer_route, is_active, sort_order)
VALUES ('YEMEKLER', 'MUTFAK', TRUE, 20)
ON CONFLICT (name) DO UPDATE SET is_active = TRUE, sort_order = 20, parent_category_id = NULL
RETURNING id;

-- 4. Yemek alt kategorilerini YEMEKLER altına taşı
UPDATE categories
SET parent_category_id = (SELECT id FROM categories WHERE UPPER(name) = 'YEMEKLER' LIMIT 1)
WHERE UPPER(name) IN (
    'ANA YEMEKLER',
    'APERATİFLER',
    'MAKARNALAR',
    'PİZZALAR',
    'SALATALAR',
    'WRAPLAR',
    'HAMBURGERLER',
    'KAHVALTI VE BAŞLANGIÇLAR'
);

-- 5. Tatlılar ana kategorisini oluştur (opsiyonel ama mantıklı olur)
INSERT INTO categories (name, printer_route, is_active, sort_order)
VALUES ('TATLILAR', 'MUTFAK', TRUE, 30)
ON CONFLICT (name) DO UPDATE SET is_active = TRUE, sort_order = 30, parent_category_id = NULL
RETURNING id;

-- 6. Tatlı alt kategorilerini TATLILAR altına taşı
UPDATE categories
SET parent_category_id = (SELECT id FROM categories WHERE UPPER(name) = 'TATLILAR' LIMIT 1)
WHERE UPPER(name) IN (
    'DONDURMALAR',
    'KREPLER',
    'PASTA VE KEKLER',
    'FONDU-WAFFLE'
);

-- İçecekler ana kategorisi
INSERT INTO categories (name, printer_route, is_active, sort_order)
VALUES ('SOĞUK İÇECEKLER', 'BAR', TRUE, 40)
ON CONFLICT (name) DO UPDATE SET is_active = TRUE, sort_order = 40, parent_category_id = NULL
RETURNING id;

UPDATE categories
SET parent_category_id = (SELECT id FROM categories WHERE UPPER(name) = 'SOĞUK İÇECEKLER' LIMIT 1)
WHERE UPPER(name) IN (
    'MEŞRUBATLAR',
    'MEYVELİ FROZENLER',
    'MİLKSHAKELER',
    'FRAPPELER',
    'DETOKS'
) AND id != (SELECT id FROM categories WHERE UPPER(name) = 'SOĞUK İÇECEKLER' LIMIT 1);
