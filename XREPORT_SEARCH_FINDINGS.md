# X Report & Z Report - Complete Backend Search Findings

## Executive Summary
The codebase contains two main report types: **X Report** (interim daily report) and **Z Report** (end-of-day report). Both heavily utilize product name queries with `product_name_snapshot` fields stored in the `order_items` table from paid/confirmed orders.

---

## 1. X REPORT FUNCTIONALITY

### Main Endpoints
| Endpoint | Method | Handler | File & Line |
|----------|--------|---------|------------|
| `/api/admin/x-report` | GET | `getXReport` | [admin.routes.js](admin.routes.js#L19-L22) |
| `/api/admin/x-report/print` | GET | `printXReport` | [admin.routes.js](admin.routes.js#L26-L29) |

### Core Functions

#### `getXReport(req, res)`
**File:** [admin.controller.js](admin.controller.js#L70)  
**Lines:** 70-91  
**Purpose:** Retrieves interim X report data for display without printing

#### `printXReport(req, res)`
**File:** [admin.controller.js](admin.controller.js#L92)  
**Lines:** 92-110  
**Purpose:** Retrieves X report and sends to printer

#### `buildXReportPayload(client, { periodStart, periodEnd })`
**File:** [admin.controller.js](admin.controller.js#L131)  
**Lines:** 131-185  
**Description:** Builds X report payload with summarized daily metrics

**Metrics Calculated:**
- `totalRevenue`: Sum of payments
- `cashTotal`: Sum of cash payments
- `cardTotal`: Sum of card payments
- `totalOrders`: Count of distinct orders
- `totalDiscounts`: Sum of discounts
- `averageGuestCount`: Average guests per order
- `averageDuration`: Average order duration in minutes
- `totalExpenses`: Sum of expenses
- `expenses`: List of expense items with `item_name` and `total_amount`

**Key SQL Queries:**
```sql
-- Query at line 131-157 groups by:
WITH daily_data AS (
  SELECT total_orders, total_discounts, avg_guest_count, avg_duration
  FROM orders
  WHERE (opened_at >= $1 AND opened_at < $2) 
     OR (closed_at >= $1 AND closed_at < $2)
),
payment_data AS (
  SELECT total_revenue, cash_total, card_total
  FROM payments
  WHERE paid_at >= $1 AND paid_at < $2
),
expense_data AS (
  SELECT total_expenses
  FROM expenses
  WHERE created_at >= $1 AND created_at < $2
)
```

---

## 2. Z REPORT FUNCTIONALITY

### Endpoints
| Endpoint | Method | Handler | File & Line |
|----------|--------|---------|------------|
| `/api/admin/z-report` | POST | `generateZReport` | [admin.routes.js](admin.routes.js#L87-L90) |
| `/api/admin/z-report/excel` | POST | `exportZReportExcel` | [admin.routes.js](admin.routes.js#L144-L147) |

### Core Function

#### `generateZReport(req, res)`
**File:** [admin.controller.js](admin.controller.js#L300)  
**Lines:** 300-520  
**Purpose:** Generates end-of-day Z report with detailed product breakdown

### **CRITICAL: Product Name Grouping Queries**

#### Query 1: Product Sales Summary (Line 268-298)
```sql
SELECT
  COALESCE(NULLIF(oi.category_snapshot, ''), c.name, 'Diğer') AS category_name,
  oi.product_name_snapshot AS product_name,
  COALESCE(SUM(oi.quantity), 0) AS total_quantity,
  COALESCE(SUM(oi.line_total), 0) AS total_revenue
FROM order_items oi
JOIN orders o ON o.id = oi.order_id
LEFT JOIN products p ON p.id = oi.product_id
LEFT JOIN categories c ON c.id = p.category_id
WHERE oi.item_status <> 'VOID'
  AND o.id IN (
    SELECT DISTINCT order_id
    FROM payments
    WHERE paid_at >= $1 AND paid_at < $2
  )
GROUP BY category_name, oi.product_name_snapshot          ⚠️ GROUPS BY product_name_snapshot
ORDER BY category_name ASC, total_revenue DESC
```
**Location:** [admin.controller.js](admin.controller.js#L254-L298)  
**Line Range:** 254-298  
**Issue:** Uses `product_name_snapshot` from `order_items` table  
**Turkish Character Impact:** ✅ Uses snapshot (immutable), no character set issues

#### Query 2: Order Details Aggregation (Line 313-327)
```sql
SELECT 
  COUNT(DISTINCT p.order_id) as total_orders,
  COALESCE(SUM(p.amount), 0) as total_revenue,
  -- ... other aggregations ...
  STRING_AGG(
    '#' || o.id || ' - Masa: ' || t.display_name || ' - ' || p.payment_method || ' - ' || p.amount || ' TL', 
    E'\n'
    ORDER BY p.paid_at DESC
  ) as order_details
FROM payments p
JOIN orders o ON o.id = p.order_id
JOIN tables t ON t.id = o.table_id
WHERE p.paid_at >= $1 AND p.paid_at < $2
```
**Location:** [admin.controller.js](admin.controller.js#L313-L345)  
**Line Range:** 313-345  
**Note:** No product names in this query (payment/order level aggregation)

---

## 3. DAILY SUMMARY & TOP PRODUCTS

### Function: `getDailySummary()`
**File:** [stats.service.js](stats.service.js#L30)  
**Lines:** 30-130  
**Purpose:** Calculates daily business metrics including "Günün Yıldızı" (Star Product)

### **CRITICAL: Top Product Query (Line 91 in stats.service.js)**
```sql
top_product AS (
  -- Son Z raporundan sonra en çok satılan ürün
  SELECT 
    product_name_snapshot as name,
    SUM(quantity) as total_qty
  FROM order_items
  WHERE created_at >= $1
    AND created_at < $2
    AND item_status <> 'VOID'
  GROUP BY product_name_snapshot          ⚠️ GROUPS BY product_name_snapshot
  ORDER BY total_qty DESC
  LIMIT 1
),
...
SELECT
  ...
  (SELECT name FROM top_product) as star_product_name,
  (SELECT total_qty FROM top_product) as star_product_qty
```
**Location:** [stats.service.js](stats.service.js#L88-L100)  
**Line Range:** 88-100  
**Issue:** `GROUP BY product_name_snapshot` - Groups items by product name  
**Turkish Character Risk:** ✅ LOW - Uses `product_name_snapshot` (text immutable field)

---

## 4. ORDER ITEMS TABLE & PRODUCT NAME STORAGE

### Schema Definition
**File:** [init-db.js](init-db.js#L208)  
**Lines:** 208-226

```sql
CREATE TABLE IF NOT EXISTS order_items (
  id BIGSERIAL PRIMARY KEY,
  order_id BIGINT NOT NULL,
  product_id BIGINT NOT NULL,
  category_snapshot VARCHAR(100),
  printer_route_snapshot VARCHAR(20) NOT NULL DEFAULT 'MUTFAK',
  product_name_snapshot VARCHAR(140) NOT NULL,             ⚠️ 140 char VARCHAR
  unit_price_snapshot NUMERIC(12, 2) NOT NULL,
  quantity NUMERIC(10, 2) NOT NULL,
  line_total NUMERIC(12, 2) NOT NULL,
  item_status VARCHAR(20) NOT NULL DEFAULT 'PENDING',
  note TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

**Key Field:** `product_name_snapshot VARCHAR(140) NOT NULL`
- **Capacity:** 140 characters (should handle most Turkish product names)
- **Type:** VARCHAR (text, no fixed collation issues in PostgreSQL with UTF-8)
- **Turkish Support:** ✅ YES - PostgreSQL UTF-8 supports Turkish characters (Ş, ş, Ç, ç, Ğ, ğ, İ, ı, Ö, ö, Ü, ü)

---

## 5. PRODUCT NAME RETRIEVAL & QUERIES

### In Order Service - Get Current Order Items
**File:** [order.service.js](order.service.js#L615)  
**Lines:** 615-640

```sql
SELECT
  oi.product_id,
  oi.product_name_snapshot AS name,              ✅ Retrieves snapshot
  oi.unit_price_snapshot AS unit_price,
  SUM(oi.quantity) AS quantity,
  SUM(oi.line_total) AS line_total,
  NULLIF(STRING_AGG(DISTINCT NULLIF(TRIM(oi.note), ''), ' | '), '') AS note
FROM order_items oi
WHERE oi.order_id = $1
  AND oi.item_status NOT IN ('VOID', 'PAID')
GROUP BY oi.product_id, oi.product_name_snapshot, oi.unit_price_snapshot
ORDER BY oi.product_name_snapshot ASC              ⚠️ ORDERS BY product_name_snapshot
```
**Location:** [order.service.js](order.service.js#L620-L638)  
**Line Range:** 620-638  
**Issue:** `ORDER BY oi.product_name_snapshot ASC` - Uses default collation  
**Turkish Character Risk:** ⚠️ **POTENTIAL** - Default PostgreSQL collation may not sort Turkish characters correctly

---

## 6. PRODUCT SEARCH & FILTERING

### Product Listing with Search
**File:** [product.service.js](product.service.js#L66)  
**Lines:** 66-87

```javascript
async function listProductsForAdmin({ search = "", categoryId = null }) {
  const normalizedSearch = String(search || "").trim();
  const { rows } = await db.query(
    `
    SELECT p.id, p.name, p.price, p.is_active, p.category_id, ...
    FROM products p
    LEFT JOIN categories c ON c.id = p.category_id
    WHERE
      p.is_active = TRUE
      AND c.is_active = TRUE
      AND
      ($1 = '' OR p.name ILIKE '%' || $1 || '%')      ✅ Uses ILIKE (case-insensitive)
      AND ($2::bigint IS NULL OR p.category_id = $2)
    ORDER BY c.sort_order ASC NULLS LAST, p.name ASC;
    `,
    [normalizedSearch, categoryId]
  );
}
```
**Location:** [product.service.js](product.service.js#L66-L87)  
**Line Range:** 66-87  
**Features:**
- ✅ Uses `ILIKE` (case-insensitive pattern matching)
- ✅ PostgreSQL ILIKE supports Turkish character matching
- ✅ Proper Unicode handling for Turkish characters

---

## 7. CHARACTER ENCODING & PRINTER SUPPORT

### Database Configuration
**File:** [config/db.js](config/db.js#L1)  
**Lines:** 1-50  
**Database:** PostgreSQL (default UTF-8 encoding)

### Printer Character Set Configuration
**File:** [services/printer.service.js](services/printer.service.js#L1)  
**Lines:** 1-20

```javascript
const {
  ThermalPrinter,
  PrinterTypes,
  CharacterSet,
} = require("node-thermal-printer");

const PRINTER_TYPES = {
  KASA: "KASA",
  MUTFAK: "MUTFAK",
  BAR: "BAR",
  CASH: "KASA",
  KITCHEN: "MUTFAK",
};

const PRINTER_CHARSET =
  process.env.PRINTER_CHARSET || CharacterSet.PC857_TURKISH;  ⚠️ Uses PC857_TURKISH
```
**Location:** [printer.service.js](printer.service.js#L18-L19)  
**Lines:** 18-19  
**Charset:** `PC857_TURKISH` (Turkish code page for thermal printers)  
**Turkish Support:** ✅ YES - Specifically handles Turkish characters for printing

### Printer Initialization
**File:** [services/printer.service.js](services/printer.service.js#L140)  
**Lines:** 135-145

```javascript
const printer = new ThermalPrinter({
  type: PrinterTypes.EPSON,
  interface: `tcp://${printerIp}:${printerPort}`,
  characterSet: PRINTER_CHARSET,     ✅ Uses configured Turkish charset
  width: 48,
  breakLine: true,
  options,
});
```

---

## 8. TURKISH CHARACTER HANDLING IN PRODUCT NAMES

### Confirmed Support Points
✅ **In Database:**
- PostgreSQL UTF-8 encoding (default)
- VARCHAR fields support Turkish characters
- Turkish characters in `product_name_snapshot`: (Ş, ş, Ç, ç, Ğ, ğ, İ, ı, Ö, ö, Ü, ü)

✅ **In Search:**
- `ILIKE` operator handles Turkish character matching
- Case-insensitive search works with Turkish characters

✅ **In Printing:**
- `PC857_TURKISH` character set specified
- Thermal printer configured for Turkish output

### Potential Issues
⚠️ **In ORDER BY Queries:**
- [order.service.js](order.service.js#L628): `ORDER BY oi.product_name_snapshot ASC`
- [product.service.js](product.service.js#L86): `ORDER BY c.sort_order ASC NULLS LAST, p.name ASC`
- Default collation may not sort Turkish characters in linguistic order
- Could cause sorting issues for products like "Beşamel Soslu Tavuk", "Bodrum Çökertmesi"

---

## 9. SEARCH FOR "Beşamel" & "Bodrum" EXAMPLES

**Search Results:**
- ❌ No records found with "Beşamel Soslu Tavuk" in codebase (seed data)
- ❌ No records found with "Bodrum Çökertmesi" in codebase (seed data)
- ✅ Turkish characters confirmed in category names: ["SICAK İÇECEKLER", "SOĞUK İÇECEKLER", "ÇAYLAR", "TÜRK KAHVESİ ÇEŞİTLERİ", etc.]

---

## 10. GROUP BY OPERATIONS SUMMARY

| Location | Query Type | Groups By | Line | Issue |
|----------|-----------|-----------|------|-------|
| [admin.controller.js](admin.controller.js#L268) | Z Report Products | `category_name, oi.product_name_snapshot` | 268 | ⚠️ Potential Turkish sort issue |
| [admin.controller.js](admin.controller.js#L398) | Z Report Products | `category_name, oi.product_name_snapshot` | 398 | ⚠️ Potential Turkish sort issue |
| [stats.service.js](stats.service.js#L91) | Top Product | `product_name_snapshot` | 91 | ⚠️ Potential Turkish sort issue |
| [order.service.js](order.service.js#L627) | Order Items | `oi.product_id, oi.product_name_snapshot, oi.unit_price_snapshot` | 627 | ⚠️ Potential Turkish sort issue |

---

## 11. FUNCTION REFERENCE GUIDE

### X/Z Report Related Functions
| Function Name | File | Lines | Type |
|---------------|------|-------|------|
| `getXReport` | [admin.controller.js](admin.controller.js#L70) | 70-91 | Controller |
| `printXReport` | [admin.controller.js](admin.controller.js#L92) | 92-110 | Controller |
| `buildXReportPayload` | [admin.controller.js](admin.controller.js#L131) | 131-185 | Controller |
| `generateZReport` | [admin.controller.js](admin.controller.js#L300) | 300-520 | Controller |
| `exportZReportExcel` | [admin.controller.js](admin.controller.js#L522) | 522-680+ | Controller |
| `getDailySummary` | [stats.service.js](stats.service.js#L30) | 30-130 | Service |
| `getCurrentReportPeriod` | [admin.controller.js](admin.controller.js) or [stats.service.js](stats.service.js) | Various | Service |

### Product-Related Functions
| Function Name | File | Lines | Type |
|---------------|------|-------|------|
| `listProductsForAdmin` | [product.service.js](product.service.js#L66) | 66-87 | Service |
| `getCurrentOrderItems` | [order.service.js](order.service.js#L615) | 615-640 | Service |

---

## 12. INVENTORY OF ALL QUERIES WITH PRODUCT NAMES

### Queries Involving `product_name_snapshot`
1. **Z Report Products Query** - [admin.controller.js](admin.controller.js#L254-L298)
2. **Top Product Query** - [stats.service.js](stats.service.js#L88-L100)
3. **Current Order Items** - [order.service.js](order.service.js#L620-L638)
4. **Order Details** - [order.controller.js](order.controller.js#L500)
5. **Partial Checkout** - [order.controller.js](order.controller.js#L672)
6. **Payment Session** - [order.controller.js](order.controller.js#L1337)

### Queries Involving `products.name`
1. **Product Search** - [product.service.js](product.service.js#L80)
2. **Top Products (last 30 days)** - [admin.controller.js](admin.controller.js#L714)

---

## 13. RECOMMENDED ACTIONS

### To Fix Potential Turkish Character Sorting Issues:
1. **Add COLLATE Clause** to ORDER BY statements:
   ```sql
   ORDER BY oi.product_name_snapshot COLLATE "tr_TR.UTF-8" ASC
   ```

2. **In Product Service** [product.service.js](product.service.js#L86):
   ```sql
   ORDER BY c.sort_order ASC NULLS LAST, p.name COLLATE "tr_TR.UTF-8" ASC
   ```

3. **In Order Service** [order.service.js](order.service.js#L628):
   ```sql
   ORDER BY oi.product_name_snapshot COLLATE "tr_TR.UTF-8" ASC
   ```

4. **Set Database Default Collation** during initialization:
   ```sql
   ALTER DATABASE adisyon_db SET DEFAULT_COLLATION_OID = (
     SELECT oid FROM pg_collation 
     WHERE collname = 'tr_TR.utf8'
   );
   ```

---

## CONCLUSION

✅ **Turkish Character Encoding:** Fully supported throughout the codebase
⚠️ **Potential Issue:** Product name sorting with Turkish characters may not follow Turkish alphabetical rules (Ç, Ş, ğ placement)
✅ **Report Queries:** X and Z reports properly use `product_name_snapshot` field
✅ **Printer Support:** PC857_TURKISH charset configured for printer output
