import sys

with open(r'c:\Projects\nexpos-v2\frontend\lib\screens\pos_order_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

target1 = '''  _PosCategory(
    "TAKE AWAY",
    Icons.takeout_dining_rounded,
    Color(0xFF2563EB),
  ), // Blue-600'''

target2 = '''    "TAKE AWAY": "assets/take away.jpg",'''

if target1 in content or target2 in content:
    content = content.replace(target1, '')
    content = content.replace(target2, '')
    with open(r'c:\Projects\nexpos-v2\frontend\lib\screens\pos_order_screen.dart', 'w', encoding='utf-8') as f:
        f.write(content)
    print('Removed TAKE AWAY successfully')
else:
    print('Targets not found')
