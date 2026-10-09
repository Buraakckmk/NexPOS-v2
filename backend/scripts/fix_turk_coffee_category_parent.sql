-- Keep Turkish coffee varieties under the KAHVELER parent category.
UPDATE categories AS child
SET parent_category_id = parent.id,
    updated_at = NOW()
FROM categories AS parent
WHERE UPPER(parent.name) = UPPER('KAHVELER')
  AND UPPER(child.name) = UPPER('TÜRK KAHVESİ ÇEŞİTLERİ');

SELECT child.id, child.name, parent.name AS parent_category
FROM categories AS child
LEFT JOIN categories AS parent ON parent.id = child.parent_category_id
WHERE UPPER(child.name) = UPPER('TÜRK KAHVESİ ÇEŞİTLERİ');
