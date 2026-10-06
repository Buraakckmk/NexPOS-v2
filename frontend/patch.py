import sys

with open(r'c:\Projects\nexpos-v2\frontend\lib\screens\pos_order_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

methods = '''  Widget _buildCategoryPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.touch_app_rounded, size: 48, color: Color(0xFFCBD5E1)),
            SizedBox(height: 16),
            Text(
              "Kategori seçiniz",
              style: TextStyle(
                color: Color(0xFF64748B),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryVerticalList(OrderProvider order, {bool compactLayout = false}) {
    final categories = _orderedCategoriesForDisplay(order.categories);

    if (categories.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: const Color(0xFFFFFFFF),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Center(
          child: Text(
            "Kategori bulunamadı.",
            style: TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: ListView.separated(
        padding: EdgeInsets.all(compactLayout ? 8 : 10),
        physics: const BouncingScrollPhysics(),
        itemCount: categories.length,
        separatorBuilder: (_, __) => SizedBox(height: compactLayout ? 8 : 10),
        itemBuilder: (context, index) {
          final cat = categories[index];
          final isSelected = _activeCategory == cat.label;
          return InkWell(
            onTap: () {
              order.setSelectedCategory(cat.label);
              order.setSearchQuery("");
              setState(() => _activeCategory = cat.label);
            },
            borderRadius: BorderRadius.circular(10),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              decoration: BoxDecoration(
                color: isSelected ? cat.color.withValues(alpha: 0.1) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected ? cat.color.withValues(alpha: 0.3) : const Color(0xFFE2E8F0),
                ),
              ),
              child: Row(
                children: [
                  Icon(cat.icon, color: cat.color, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      cat.label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                        color: isSelected ? cat.color : const Color(0xFF334155),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCategoryGrid(OrderProvider order, {bool compactLayout = false}) {'''

if 'Widget _buildCategoryGrid' in content and '_buildCategoryVerticalList' not in content:
    with open(r'c:\Projects\nexpos-v2\frontend\lib\screens\pos_order_screen.dart', 'w', encoding='utf-8') as f:
        f.write(content.replace('  Widget _buildCategoryGrid(OrderProvider order, {bool compactLayout = false}) {', methods))
    print('Added vertical list and placeholder successfully')
else:
    print('Could not add methods')
