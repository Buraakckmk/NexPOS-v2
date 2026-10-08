const fs = require('fs');
let c = fs.readFileSync('frontend/lib/screens/admin_menu_management_screen.dart','utf8');
c = c.replace(/items: _categories\s*\.map\(\s*\(c\) => DropdownMenuItem<int>\(\s*value: c\.id,\s*child: Text\(c\.name,\s*style:\s*const TextStyle\(color: Color\(0xFF0F172A\),\s*fontWeight:\s*FontWeight\.w700\)\),\s*\),\s*\)\s*\.toList\(\),/g, 'items: _buildCategoryDropdownItems(),');
fs.writeFileSync('frontend/lib/screens/admin_menu_management_screen.dart', c);
