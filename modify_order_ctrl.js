const fs = require('fs');
let c = fs.readFileSync('backend/src/controllers/order.controller.js','utf8');
c = c.replace('              payment_lock_at = NULL,\r\n              subtotal = 0,\r\n              grand_total = 0,\r\n              updated_at = NOW()', '              payment_lock_at = NULL,\r\n              updated_at = NOW()');
fs.writeFileSync('backend/src/controllers/order.controller.js', c);
