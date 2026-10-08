const fs = require('fs');
let c = fs.readFileSync('frontend/lib/screens/admin_menu_management_screen.dart','utf8');
c = c.replace('Future<void> _openAddProductDialog() async {', `List<DropdownMenuItem<int>> _buildCategoryDropdownItems() {
    final List<DropdownMenuItem<int>> items = [];
    for (final parent in _categories.where((c) => c.parentCategoryId == null)) {
      items.add(DropdownMenuItem<int>(value: parent.id, child: Text(parent.name, style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w700))));
      for (final child in _categories.where((c) => c.parentCategoryId == parent.id)) {
        items.add(DropdownMenuItem<int>(value: child.id, child: Text("  ↳ " + child.name, style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w500))));
      }
    }
    return items;
  }

  Future<void> _openAddProductDialog() async {`);
fs.writeFileSync('frontend/lib/screens/admin_menu_management_screen.dart', c);
