import sys
import re

with open(r'c:\Projects\nexpos-v2\frontend\lib\screens\pos_order_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Fix blurRadius issue
old_shadow = '''            boxShadow: isSelected
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
                  ],'''
new_shadow = ''
content = content.replace(old_shadow, new_shadow)

with open(r'c:\Projects\nexpos-v2\frontend\lib\screens\pos_order_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
print("Removed box shadow from AnimatedContainer to prevent blurRadius error")
