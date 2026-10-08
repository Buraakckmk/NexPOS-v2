const fs = require('fs');
let c = fs.readFileSync('frontend/lib/screens/admin_transactions_screen.dart','utf8');

// Fix trailing row overflow
c = c.replace('trailing: Row(', 'trailing: FittedBox(fit: BoxFit.scaleDown, child: Row(');
c = c.replace('                            ),\r\n                          ],\r\n                        ),', '                            ),\r\n                          ],\r\n                        )),');
c = c.replace('                            ),\n                          ],\n                        ),', '                            ),\n                          ],\n                        )),');

// Fix pagination overflow
c = c.replace('child: Row(\r\n        mainAxisAlignment: MainAxisAlignment.spaceBetween,\r\n        children: [\r\n          Text("Toplam: $_totalItems"),\r\n          Row(', 'child: Wrap(\r\n        alignment: WrapAlignment.spaceBetween,\r\n        crossAxisAlignment: WrapCrossAlignment.center,\r\n        spacing: 16,\r\n        runSpacing: 8,\r\n        children: [\r\n          Text("Toplam: $_totalItems"),\r\n          Row(\r\n            mainAxisSize: MainAxisSize.min,');
c = c.replace('child: Row(\n        mainAxisAlignment: MainAxisAlignment.spaceBetween,\n        children: [\n          Text("Toplam: $_totalItems"),\n          Row(', 'child: Wrap(\n        alignment: WrapAlignment.spaceBetween,\n        crossAxisAlignment: WrapCrossAlignment.center,\n        spacing: 16,\n        runSpacing: 8,\n        children: [\n          Text("Toplam: $_totalItems"),\n          Row(\n            mainAxisSize: MainAxisSize.min,');

// Fix AlertDialog overflow
c = c.replace('AlertDialog(\r\n          title: const Text("Filtrele ve Sırala"),', 'AlertDialog(\r\n          scrollable: true,\r\n          title: const Text("Filtrele ve Sırala"),');
c = c.replace('AlertDialog(\n          title: const Text("Filtrele ve Sırala"),', 'AlertDialog(\n          scrollable: true,\n          title: const Text("Filtrele ve Sırala"),');

fs.writeFileSync('frontend/lib/screens/admin_transactions_screen.dart', c);
