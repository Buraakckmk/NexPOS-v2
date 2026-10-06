import sys

with open(r'c:\Projects\nexpos-v2\frontend\lib\screens\pos_order_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Update _buildCategoryVerticalList onTap
content = content.replace('''            onTap: () {
              order.setSelectedCategory(cat.label);
              order.setSearchQuery("");
              setState(() => _activeCategory = cat.label);
            },''', '''            onTap: () {
              order.setSelectedCategory(cat.label);
              order.setSearchQuery("");
              setState(() {
                _activeCategory = cat.label;
                _activeSubCategory = null;
              });
            },''')

# 2. Update _buildCategoryCard onTap
content = content.replace('''      onTap: () {
        order.setSelectedCategory(cat.label);
        order.setSearchQuery("");
        setState(() => _activeCategory = cat.label);
      },''', '''      onTap: () {
        order.setSelectedCategory(cat.label);
        order.setSearchQuery("");
        setState(() {
          _activeCategory = cat.label;
          _activeSubCategory = null;
        });
      },''')

# 3. Fix background in _buildCategoryVerticalList
# Change from F8FAFC to transparent, remove border when not selected
content = content.replace('''              decoration: BoxDecoration(
                color: isSelected ? cat.color.withValues(alpha: 0.1) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected ? cat.color.withValues(alpha: 0.3) : const Color(0xFFE2E8F0),
                ),
              ),''', '''              decoration: BoxDecoration(
                color: isSelected ? cat.color.withValues(alpha: 0.12) : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected ? cat.color.withValues(alpha: 0.4) : Colors.transparent,
                ),
              ),''')

# Make the outer container of the vertical list transparent too
content = content.replace('''    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: ListView.separated(''', '''    return Container(
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
      ),
      child: ListView.separated(''')

# 4. Remove Tümü from subcategory tab bar
old_chip = '''    Widget buildSubCategoryChip(String label, bool isSelected) {
      return InkWell(
        onTap: () {
          setState(() => _activeSubCategory = label == "Tümü" ? null : label);
          order.setSearchQuery("");
          order.setSelectedCategory(label == "Tümü" ? _activeCategory! : label);
        },'''
new_chip = '''    Widget buildSubCategoryChip(String label, bool isSelected) {
      return InkWell(
        onTap: () {
          final isActivating = !isSelected;
          setState(() => _activeSubCategory = isActivating ? label : null);
          order.setSearchQuery("");
          order.setSelectedCategory(isActivating ? label : _activeCategory!);
        },'''
content = content.replace(old_chip, new_chip)

old_list = '''    final allChips = [
      buildSubCategoryChip("Tümü", _activeSubCategory == null),
      ...subCats.map((subCat) => buildSubCategoryChip(subCat, _activeSubCategory == subCat)),
    ];'''
new_list = '''    final allChips = [
      ...subCats.map((subCat) => buildSubCategoryChip(subCat, _activeSubCategory == subCat)),
    ];'''
content = content.replace(old_list, new_list)

with open(r'c:\Projects\nexpos-v2\frontend\lib\screens\pos_order_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
print("Patch applied")
