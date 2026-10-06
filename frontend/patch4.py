import sys
import re

with open(r'c:\Projects\nexpos-v2\frontend\lib\screens\pos_order_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

new_method = '''  // ── Sub-Category tab bar (shown when a parent category has sub-categories) ──
  Widget _buildSubCategoryTabBar(OrderProvider order) {
    if (_activeCategory == null) return const SizedBox.shrink();

    final subCats = order.subCategoriesOf(_activeCategory!);
    if (subCats.isEmpty) return const SizedBox.shrink();

    Widget buildSubCategoryChip(String label, bool isSelected) {
      return InkWell(
        onTap: () {
          final isActivating = !isSelected;
          setState(() => _activeSubCategory = isActivating ? label : null);
          order.setSearchQuery("");
          order.setSelectedCategory(isActivating ? label : _activeCategory!);
        },
        borderRadius: BorderRadius.circular(30),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            gradient: isSelected
                ? const LinearGradient(
                    colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: isSelected ? null : const Color(0xFFFFFFFF),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: isSelected ? Colors.transparent : const Color(0xFFE2E8F0),
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    )
                  ]
                : [
                    BoxShadow(
                      color: const Color(0xFF94A3B8).withValues(alpha: 0.1),
                      blurRadius: 2,
                      offset: const Offset(0, 2),
                    )
                  ],
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? Colors.white : const Color(0xFF475569),
                letterSpacing: 0.3,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      height: 56,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        itemCount: subCats.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final subCat = subCats[i];
          return buildSubCategoryChip(subCat, _activeSubCategory == subCat);
        },
      ),
    );
  }'''

# Extract the old method and replace it
start_marker = "  // ── Sub-Category tab bar (shown when a parent category has sub-categories) ──"
end_marker = "  // ── Category grid (27 items, 9 per row) ──────────────────────────────────"

start_idx = content.find(start_marker)
end_idx = content.find(end_marker)

if start_idx != -1 and end_idx != -1:
    content = content[:start_idx] + new_method + '\n' + content[end_idx:]
    with open(r'c:\Projects\nexpos-v2\frontend\lib\screens\pos_order_screen.dart', 'w', encoding='utf-8') as f:
        f.write(content)
    print("Replaced successfully")
else:
    print("Markers not found")
