const orderService = require("../services/order.service");
const printerService = require("../services/printer.service");
const customerService = require("../services/customer.service");
const db = require("../config/db");
const logger = require("../config/logger");

function buildHttpError(message, statusCode = 400) {
  const error = new Error(message);
  error.statusCode = statusCode;
  return error;
}

async function refreshOrderTotals(client, orderId) {
  await client.query(
    `
      UPDATE orders o
      SET
        subtotal = totals.subtotal,
        grand_total = GREATEST(totals.subtotal - o.discount_total, 0),
        updated_at = NOW()
      FROM (
        SELECT COALESCE(SUM(line_total), 0)::numeric AS subtotal
        FROM order_items
        WHERE order_id = $1
          AND item_status NOT IN ('VOID', 'PAID')
      ) AS totals
      WHERE o.id = $1
    `,
    [orderId]
  );
}

function emitTablesRefresh(req) {
  const io = req.app.get("io");
  if (io) {
    io.emit("tables:refresh", { at: new Date().toISOString() });
  }
}

async function createOrder(req, res, next) {
  try {
    const tableId = req.body.table_id;
    const items = req.body.items;
    const userId = req.user.user_id;

    if (tableId === undefined || tableId === null) {
      return res.status(400).json({ message: "table_id gerekli." });
    }

    const result = await orderService.createOrAppendOrder({
      tableId: Number(tableId),
      items,
      userId,
    });

    emitTablesRefresh(req);

    return res.status(201).json({
      message: "Siparis kaydedildi.",
      table_status: "OCCUPIED",
      created_new_order: result.created_new_order,
      order: {
        id: String(result.order.id),
        table_id: String(result.order.table_id),
        waiter_id: String(result.order.waiter_id),
        order_status: result.order.order_status,
        subtotal: result.order.subtotal,
        discount_total: result.order.discount_total,
        grand_total: result.order.grand_total,
        opened_at: result.order.opened_at,
      },
      table_display_name: result.table_display_name,
    });
  } catch (error) {
    if (error.statusCode) {
      return res.status(error.statusCode).json({ message: error.message });
    }
    return next(error);
  }
}

async function confirmOrder(req, res, next) {
  try {
    const orderId = Number(req.params.orderId);
    if (!Number.isFinite(orderId)) {
      return res.status(400).json({ message: "Gecersiz orderId." });
    }

    const { socketPayload, printArgs } = await orderService.confirmOrder({
      orderId,
      userId: req.user.user_id,
      roleId: req.user.role_id,
    });

    const hasPrintableItems = Array.isArray(printArgs?.items) && printArgs.items.length > 0;

    if (hasPrintableItems) {
      printerService.printKitchenReceipt(printArgs).catch((printError) => {
        logger.error("[order-confirmation-print] Departman fisleri gonderilemedi", {
          orderId,
          message: printError.message,
          stack: printError.stack,
        });
      });
    }

    const io = req.app.get("io");
    if (io && hasPrintableItems) {
      io.emit("new-order", socketPayload);
    }

    // Keep all waiter/cashier views in sync even if they only listen to table refresh.
    emitTablesRefresh(req);

    return res.status(200).json({
      message: hasPrintableItems
        ? "Siparis mutfaga iletildi."
        : "Siparis zaten onayli.",
      payload: socketPayload,
    });
  } catch (error) {
    if (error.statusCode) {
      return res.status(error.statusCode).json({ message: error.message });
    }
    return next(error);
  }
}

async function getActiveOrderByTable(req, res, next) {
  try {
    const tableId = Number(req.params.tableId);
    if (!Number.isFinite(tableId)) {
      return res.status(400).json({ message: "Gecersiz tableId." });
    }

    const result = await orderService.getActiveOrderForTable({ tableId });
    if (!result) {
      return res.status(200).json({ active_order: null });
    }

    return res.status(200).json({
      active_order: {
        id: String(result.order.id),
        table_id: String(result.order.table_id),
        waiter_id: String(result.order.waiter_id),
        guest_count: Number(result.order.guest_count || 1),
        table_note: result.order.table_note ?? null,
        order_status: result.order.order_status,
        subtotal: result.order.subtotal,
        discount_total: result.order.discount_total,
        grand_total: result.order.grand_total,
        opened_at: result.order.opened_at,
        confirmed_at: result.order.confirmed_at,
        table_display_name: result.order.table_display_name,
        total_paid: Number(result.order.total_paid || 0),
        amount_payment_paid: Number(result.order.amount_payment_paid || 0),
      },
      items: result.items.map((i) => ({
        product_id: String(i.product_id),
        name: i.name,
        unit_price: i.unit_price,
        quantity: i.quantity,
        line_total: i.line_total,
        note: i.note,
      })),
    });
  } catch (error) {
    if (error.statusCode) {
      return res.status(error.statusCode).json({ message: error.message });
    }
    return next(error);
  }
}

async function printCurrentAccount(req, res, next) {
  try {
    const tableId = Number(req.params.tableId);
    const orderId = req.body?.order_id == null ? null : Number(req.body.order_id);
    const tableDisplayName = String(req.body?.table_display_name ?? "").trim();
    const guestCount = Number(req.body?.guest_count ?? 1);
    const tableNote = String(req.body?.table_note ?? "").trim();
    const subtotal = Number(req.body?.subtotal ?? 0);
    const discountAmount = Number(req.body?.discount_amount ?? 0);
    const totalPaid = Number(req.body?.total_paid ?? 0);
    const remainingTotal = Number(req.body?.remaining_total ?? 0);
    const rawItems = Array.isArray(req.body?.items) ? req.body.items : [];

    if (!Number.isFinite(tableId)) {
      return res.status(400).json({ message: "Gecersiz tableId." });
    }

    const items = rawItems
      .filter((item) => item && String(item.name ?? "").trim())
      .map((item) => ({
        name: String(item.name ?? "").trim(),
        quantity: Number(item.quantity ?? 0),
        unit_price: Number(item.unit_price ?? 0),
        note: String(item.note ?? "").trim(),
      }))
      .filter((item) => Number.isFinite(item.quantity) && item.quantity > 0);

    if (!items.length) {
      return res.status(400).json({ message: "Yazdirilacak urun bulunamadi." });
    }

    printerService.enqueueCurrentAccountReceipt({
      tableDisplayName: tableDisplayName || `MASA ${tableId}`,
      orderId: Number.isFinite(orderId) ? String(orderId) : "-",
      guestCount: Number.isFinite(guestCount) && guestCount > 0 ? guestCount : 1,
      tableNote,
      items,
      subtotal: Number.isFinite(subtotal) ? subtotal : 0,
      discountAmount: Number.isFinite(discountAmount) ? discountAmount : 0,
      totalPaid: Number.isFinite(totalPaid) ? totalPaid : 0,
      remainingTotal: Number.isFinite(remainingTotal) ? remainingTotal : 0,
    }).catch((printError) => {
      logger.error("[current-account-print] Kasa fisine gonderilemedi", {
        tableId,
        orderId,
        message: printError.message,
        stack: printError.stack,
      });
    });

    return res.status(200).json({
      message: "Adisyon kasa yazicisi kuyruguna gonderildi.",
    });
  } catch (error) {
    if (error.statusCode) {
      return res.status(error.statusCode).json({ message: error.message });
    }
    return next(error);
  }
}

async function updateOrderItemNote(req, res, next) {
  try {
    const orderId = Number(req.params.orderId);
    const productId = Number(req.body?.product_id);
    const note = req.body?.note;

    if (!Number.isFinite(orderId) || !Number.isFinite(productId)) {
      return res.status(400).json({ message: "Gecersiz orderId veya product_id." });
    }

    const result = await orderService.updateOrderItemNote({
      orderId,
      productId,
      note,
    });

    emitTablesRefresh(req);

    return res.status(200).json({
      message: "Siparis notu guncellendi.",
      updated_count: result.updatedCount,
      note: result.note,
    });
  } catch (error) {
    if (error.statusCode) {
      return res.status(error.statusCode).json({ message: error.message });
    }
    return next(error);
  }
}

async function updateOrderItemPrice(req, res, next) {
  try {
    const orderId = Number(req.params.orderId);
    const productId = Number(req.body?.product_id);
    const unitPrice = Number(req.body?.unit_price);

    if (
      !Number.isFinite(orderId) ||
      !Number.isFinite(productId) ||
      !Number.isFinite(unitPrice)
    ) {
      return res
        .status(400)
        .json({ message: "Gecersiz orderId, product_id veya unit_price." });
    }

    const result = await orderService.updateOrderItemPrice({
      orderId,
      productId,
      unitPrice,
    });

    emitTablesRefresh(req);

    return res.status(200).json({
      message: "Urun fiyati guncellendi.",
      updated_count: result.updatedCount,
      unit_price: result.unitPrice,
    });
  } catch (error) {
    if (error.statusCode) {
      return res.status(error.statusCode).json({ message: error.message });
    }
    return next(error);
  }
}

async function checkoutOrder(req, res, next) {
  try {
    const orderId = Number(req.params.orderId);
    const paymentMethod = (req.body?.paymentMethod ?? "").toString().toUpperCase();
    const discountAmount = Number(req.body?.discountAmount ?? 0);

    if (!Number.isFinite(orderId)) {
      return res.status(400).json({ message: "Gecersiz orderId." });
    }

    if (!["CASH", "CARD", "MEAL_CARD", "CUSTOMER"].includes(paymentMethod)) {
      return res.status(400).json({ message: "paymentMethod CASH, CARD, MEAL_CARD veya CUSTOMER olmalı." });
    }

    if (!Number.isFinite(discountAmount) || discountAmount < 0) {
      return res.status(400).json({ message: "discountAmount 0 veya pozitif olmalı." });
    }

    const mealCardType = req.body?.mealCardType?.toString().trim() || null;
    const result = await orderService.checkoutOrder({
      orderId,
      userId: req.user.user_id,
      roleId: req.user.role_id,
      paymentMethod,
      discountAmount,
      mealCardType,
    });

    emitTablesRefresh(req);

    return res.status(200).json({
      message: "Hesap alindi, masa bosaltildi.",
      ...result,
    });
  } catch (error) {
    if (error.statusCode) {
      return res.status(error.statusCode).json({ message: error.message });
    }
    return next(error);
  }
}

async function transferTable(req, res, next) {
  try {
    const { from_table_id, to_table_id } = req.body;
    const userId = req.user.user_id;

    if (!from_table_id || !to_table_id) {
      return res.status(400).json({ message: "from_table_id ve to_table_id gerekli." });
    }

    if (from_table_id === to_table_id) {
      return res.status(400).json({ message: "Ayni masaya transfer yapilamaz." });
    }

    const result = await orderService.transferOrderBetweenTables({
      fromTableId: Number(from_table_id),
      toTableId: Number(to_table_id),
      userId,
    });

    emitTablesRefresh(req);

    return res.status(200).json({
      message: "Masa basariyla transfer edildi.",
      from_table: {
        id: String(result.fromTable.id),
        display_name: result.fromTable.display_name,
        status: "AVAILABLE",
      },
      to_table: {
        id: String(result.toTable.id),
        display_name: result.toTable.display_name,
        status: "OCCUPIED",
      },
      order: {
        id: String(result.order.id),
        table_id: String(result.toTable.id),
      },
    });
  } catch (error) {
    if (error.statusCode) {
      return res.status(error.statusCode).json({ message: error.message });
    }
    return next(error);
  }
}

async function startPaymentSession(req, res, next) {
  try {
    const orderId = Number(req.params.orderId);
    if (!Number.isFinite(orderId)) {
      return res.status(400).json({ message: "Gecersiz orderId." });
    }

    await orderService.startPaymentSession({
      orderId,
      userId: req.user.user_id,
    });

    return res.status(200).json({
      message: "Odeme oturumu baslatildi.",
      order_id: orderId,
    });
  } catch (error) {
    if (error.statusCode) {
      return res.status(error.statusCode).json({ message: error.message });
    }
    return next(error);
  }
}

async function endPaymentSession(req, res, next) {
  try {
    const orderId = Number(req.params.orderId);
    if (!Number.isFinite(orderId)) {
      return res.status(400).json({ message: "Gecersiz orderId." });
    }

    await orderService.endPaymentSession({
      orderId,
      userId: req.user.user_id,
    });

    return res.status(200).json({
      message: "Odeme oturumu kapatildi.",
      order_id: orderId,
    });
  } catch (error) {
    if (error.statusCode) {
      return res.status(error.statusCode).json({ message: error.message });
    }
    return next(error);
  }
}

async function partialCheckout(req, res, next) {
  let client;
  try {
    const orderId = Number(req.params.orderId);
    const { items, payments } = req.body;
    const paymentMethod = (req.body?.paymentMethod ?? "").toString().toUpperCase();
    const discountAmount = Number(req.body?.discountAmount ?? 0);
    const fallbackMealCardType = req.body?.mealCardType?.toString().trim() || null;
    if (!Number.isFinite(orderId) || !Array.isArray(items) || items.length === 0) {
      return res.status(400).json({ message: "Gecersiz istek." });
    }

    if (payments && !Array.isArray(payments)) {
      return res.status(400).json({ message: "payments bir dizi olmalı." });
    }

    if (!payments && !["CASH", "CARD", "MEAL_CARD", "CUSTOMER"].includes(paymentMethod)) {
      return res.status(400).json({ message: "paymentMethod CASH, CARD, MEAL_CARD veya CUSTOMER olmalı." });
    }

    if (!Number.isFinite(discountAmount) || discountAmount < 0) {
      return res.status(400).json({ message: "discountAmount 0 veya pozitif olmalı." });
    }

    await orderService.startPaymentSession({
      orderId,
      userId: req.user.user_id,
    });

    client = await db.pool.connect();
    try {
      await client.query("BEGIN");

      const { rows: targetOrderRows } = await client.query(
        `
          SELECT id, order_status
          FROM orders
          WHERE id = $1
          FOR UPDATE
        `,
        [orderId]
      );

      if (!targetOrderRows.length) {
        throw buildHttpError("Siparis bulunamadi.", 404);
      }

      if (!["OPEN", "CONFIRMED"].includes(targetOrderRows[0].order_status)) {
        throw buildHttpError("Bu siparis kismi odemeye uygun degil.", 400);
      }

      let paidAmount = 0;

      for (const selectedItem of items) {
        const productId = Number(selectedItem.product_id);
        const requestedQty = Number(selectedItem.quantity);

        if (!Number.isFinite(productId) || !Number.isFinite(requestedQty) || requestedQty <= 0) {
          throw buildHttpError("Gecersiz urun veya adet.", 400);
        }

        let remainingQty = requestedQty;

        const { rows: candidates } = await client.query(
          `
            SELECT id, quantity, unit_price_snapshot, product_name_snapshot as name
            FROM order_items
            WHERE order_id = $1
              AND product_id = $2
              AND item_status IN ('PENDING', 'SENT')
            ORDER BY id ASC
            FOR UPDATE
          `,
          [orderId, productId]
        );

        const availableQty = candidates.reduce((sum, row) => sum + Number(row.quantity), 0);
        if (availableQty < remainingQty) {
          throw buildHttpError(
            `Urun icin yeterli adet yok. product_id=${productId}, mevcut=${availableQty}, istenen=${remainingQty}`,
            400
          );
        }

        for (const row of candidates) {
          if (remainingQty <= 0) break;

          const rowQty = Number(row.quantity);
          const unitPrice = Number(row.unit_price_snapshot);

          if (rowQty <= remainingQty) {
            await client.query(
              `
                UPDATE order_items
                SET item_status = 'PAID', updated_at = NOW()
                WHERE id = $1
              `,
              [row.id]
            );
            remainingQty -= rowQty;
            paidAmount += unitPrice * rowQty;
            continue;
          }

          const unpaidQty = rowQty - remainingQty;
          const paidQty = remainingQty;

          await client.query(
            `
              UPDATE order_items
              SET
                quantity = $2,
                line_total = ROUND(($2 * unit_price_snapshot)::numeric, 2),
                updated_at = NOW()
              WHERE id = $1
            `,
            [row.id, unpaidQty]
          );

          await client.query(
            `
              INSERT INTO order_items (
                order_id,
                product_id,
                category_snapshot,
                product_name_snapshot,
                unit_price_snapshot,
                quantity,
                line_total,
                item_status,
                note
              )
              SELECT
                order_id,
                product_id,
                category_snapshot,
                product_name_snapshot,
                unit_price_snapshot,
                $2,
                ROUND(($2 * unit_price_snapshot)::numeric, 2),
                'PAID',
                note
              FROM order_items
              WHERE id = $1
            `,
            [row.id, paidQty]
          );

          paidAmount += unitPrice * paidQty;
          remainingQty = 0;
        }
      }

      await client.query(
        `
          UPDATE orders o
          SET
            subtotal = s.sum_lines,
            grand_total = s.sum_lines,
            updated_at = NOW()
          FROM (
            SELECT COALESCE(SUM(line_total), 0)::numeric AS sum_lines
            FROM order_items
            WHERE order_id = $1
              AND item_status NOT IN ('VOID', 'PAID')
          ) AS s
          WHERE o.id = $1
        `,
        [orderId]
      );

      // Masada hala açık ürün varsa sipariş açık kalır
      const checkOpenItems = await client.query(
        `SELECT COUNT(*) as open_count FROM order_items 
         WHERE order_id = $1 AND item_status IN ('PENDING', 'SENT')`,
        [orderId]
      );
      const hasOpen = parseInt(checkOpenItems.rows[0].open_count) > 0;

      const rawPaid = Number(paidAmount.toFixed(2));
      const appliedDiscount = Math.min(Number(discountAmount.toFixed(2)), rawPaid);
      const netPaidAmount = Number((rawPaid - appliedDiscount).toFixed(2));

      if (netPaidAmount <= 0) {
        throw buildHttpError("İskonto sonrası ödeme tutarı 0 olamaz.", 400);
      }

      if (payments && payments.length > 0) {
        for (let i = 0; i < payments.length; i++) {
          const p = payments[i];
          const pAmount = Number(p.amount);
          const pMethod = (p.paymentMethod || "CASH").toUpperCase();
          const pMealCardType = p.mealCardType ? String(p.mealCardType).trim() : null;
          const pDiscount = i === 0 ? appliedDiscount : 0; // İndirimi ilk ödemeye ekle

          await client.query(
            `
              INSERT INTO payments (
                order_id,
                received_by_user_id,
                payment_method,
                amount,
                discount_amount,
                currency,
                meal_card_type,
                payment_note
              )
              VALUES ($1, $2, $3, $4, $5, 'TRY', $6, 'Kısmi ödeme')
            `,
            [orderId, req.user.user_id, pMethod, pAmount, pDiscount, pMealCardType]
          );

          if (pMethod === "CUSTOMER" || (pMealCardType && pMealCardType.startsWith("CUSTOMER:"))) {
            let custId = p.customerId || p.customer_id;
            if (!custId && pMealCardType && pMealCardType.startsWith("CUSTOMER:")) {
              custId = Number(pMealCardType.split(":")[1]);
            }
            if (custId && Number.isFinite(custId)) {
              await customerService.addTransaction({
                customer_id: custId,
                order_id: orderId,
                type: "DEBIT",
                amount: pAmount,
                note: `Masa Adisyonu Cariye Aktarıldı (#${orderId})`,
                created_by_user_id: req.user.user_id,
              });
            }
          }
        }
      } else {
        await client.query(
          `
            INSERT INTO payments (
              order_id,
              received_by_user_id,
              payment_method,
              amount,
              discount_amount,
              currency,
              meal_card_type,
              payment_note
            )
            VALUES ($1, $2, $3, $4, $5, 'TRY', $6, 'Kısmi ödeme')
          `,
          [orderId, req.user.user_id, paymentMethod, netPaidAmount, appliedDiscount, fallbackMealCardType]
        );

        if (paymentMethod === "CUSTOMER" || (fallbackMealCardType && fallbackMealCardType.startsWith("CUSTOMER:"))) {
          let custId = req.body.customerId || req.body.customer_id;
          if (!custId && fallbackMealCardType && fallbackMealCardType.startsWith("CUSTOMER:")) {
            custId = Number(fallbackMealCardType.split(":")[1]);
          }
          if (custId && Number.isFinite(custId)) {
            await customerService.addTransaction({
              customer_id: custId,
              order_id: orderId,
              type: "DEBIT",
              amount: netPaidAmount,
              note: `Masa Adisyonu Cariye Aktarıldı (#${orderId})`,
              created_by_user_id: req.user.user_id,
            });
          }
        }
      }

      // Fişi yazdır (Kısmi ödeme için)
      try {
        const { rows: tableRows } = await client.query(
          "SELECT t.display_name FROM orders o JOIN tables t ON t.id = o.table_id WHERE o.id = $1",
          [orderId]
        );
        const tableDisplayName = tableRows[0]?.display_name || "-";

        const { rows: paidItems } = await client.query(
          `SELECT product_name_snapshot as name, quantity, unit_price_snapshot as unit_price 
           FROM order_items 
           WHERE order_id = $1 AND item_status = 'PAID' AND updated_at >= NOW() - INTERVAL '5 seconds'`,
          [orderId]
        );

        if (paidItems.length > 0) {
          const mainPaymentMethod = (payments && payments.length > 0) 
            ? (payments.length > 1 ? "MIXED" : payments[0].paymentMethod)
            : paymentMethod;

          // İlk ödemenin meal card type'ını al (eğer varsa)
          const mainMealCardType = (payments && payments.length > 0)
            ? (payments[0].mealCardType || null)
            : fallbackMealCardType;

          // Arka planda yazdır, ana işlemi bloklama
          orderService.printFinalReceipt({
            orderId,
            tableDisplayName,
            items: paidItems,
            subtotal: rawPaid,
            discountAmount: appliedDiscount,
            grandTotal: netPaidAmount,
            paymentMethod: mainPaymentMethod,
            mealCardType: mainMealCardType,
          }).catch(printErr => console.error("Kısmi ödeme fiş yazdırma hatası:", printErr));
        }
      } catch (printErr) {
        console.error("Kısmi ödeme fiş yazdırma hatası:", printErr);
      }

      // Masa açıksa (hasOpen=true) subtotal ve total_paid güncellemeliyiz
      // Masa kapanmışsa (hasOpen=false) tüm veriler güncellenecek
      if (!hasOpen) {
        const { rows: totalsRows } = await client.query(
          `
            SELECT
              COALESCE((
                SELECT SUM(oi.line_total)
                FROM order_items oi
                WHERE oi.order_id = $1 AND oi.item_status != 'VOID'
              ), 0) AS gross_subtotal,
              COALESCE((
                SELECT SUM(oi.line_total)
                FROM order_items oi
                WHERE oi.order_id = $1 AND oi.item_status = 'PAID'
              ), 0) AS paid_items_total,
              COALESCE((
                SELECT SUM(p.discount_amount)
                FROM payments p
                WHERE p.order_id = $1
              ), 0) AS total_discount,
              COALESCE((
                SELECT SUM(p.amount)
                FROM payments p
                WHERE p.order_id = $1
              ), 0) AS paid_total,
              COALESCE((
                SELECT COUNT(DISTINCT p.payment_method)
                FROM payments p
                WHERE p.order_id = $1
              ), 0) AS method_count,
              (
                SELECT MIN(p.payment_method)
                FROM payments p
                WHERE p.order_id = $1
              ) AS single_method
          `,
          [orderId]
        );

        const totals = totalsRows[0] || {};
        const grossSubtotal = Number(totals.gross_subtotal || 0);
        const totalDiscount = Number(totals.total_discount || 0);
        const paidItemsTotal = Number(totals.paid_items_total || 0);
        const methodCount = Number(totals.method_count || 0);
        const finalMethod = methodCount > 1 ? "MIXED" : (totals.single_method || paymentMethod);
        const finalGrandTotal = Math.max(paidItemsTotal - totalDiscount, 0);

        await client.query(
          `
            UPDATE orders
            SET
              order_status = 'PAID',
              payment_method = $3,
              payment_lock_user_id = NULL,
              payment_lock_at = NULL,
              subtotal = $4,
              discount_total = $5,
              grand_total = $6,
              closed_by_user_id = $2,
              closed_at = NOW(),
              updated_at = NOW()
            WHERE id = $1
          `,
          [
            orderId,
            req.user.user_id,
            finalMethod,
            grossSubtotal,
            totalDiscount,
            finalGrandTotal,
          ]
        );
      } else {
        // Açık item varsa sadece subtotal güncelle
        await client.query(
          `
            UPDATE orders
            SET
              subtotal = (
                SELECT COALESCE(SUM(line_total), 0)
                FROM order_items
                WHERE order_id = $1 AND item_status NOT IN ('VOID', 'PAID')
              ),
              updated_at = NOW()
            WHERE id = $1
          `,
          [orderId]
        );
      }

      await client.query("COMMIT");
      emitTablesRefresh(req);

      const io = req.app.get("io");
      if (io) {
        io.emit("new-order", { at: new Date().toISOString() });
      }

      res.json({
        success: true,
        message: "Kısmi ödeme başarılı.",
        data: {
          paid_amount: netPaidAmount,
          payment_method: paymentMethod,
          discount_amount: appliedDiscount,
          order_status: hasOpen ? "CONFIRMED" : "PAID",
        },
      });
    } catch (innerError) {
      await client.query("ROLLBACK");
      throw innerError;
    } finally {
      client.release();
    }
  } catch (error) {
    return next(error);
  }
}

async function voidOrderItem(req, res, next) {
  let client;
  try {
    const orderId = Number(req.params.orderId);
    const productId = Number(req.body?.product_id);
    const decreaseAmount = Number(req.body?.decrease_amount ?? 1);

    if (
      !Number.isFinite(orderId) ||
      !Number.isFinite(productId) ||
      !Number.isFinite(decreaseAmount) ||
      decreaseAmount <= 0
    ) {
      return res.status(400).json({ message: "Gecersiz istek." });
    }

    client = await db.pool.connect();
    try {
      await client.query("BEGIN");

      const { rows: impactedRows } = await client.query(
        `
          SELECT
            id,
            quantity,
            unit_price_snapshot,
            product_name_snapshot,
            category_snapshot
          FROM order_items
          WHERE order_id = $1
            AND product_id = $2
            AND item_status NOT IN ('VOID', 'PAID')
          FOR UPDATE
        `,
        [orderId, productId]
      );

      const availableQuantity = impactedRows.reduce(
        (sum, row) => sum + Number(row.quantity || 0),
        0
      );

      if (!impactedRows.length || availableQuantity <= 0) {
        throw buildHttpError("Iptal edilecek aktif urun bulunamadi.", 404);
      }

      if (decreaseAmount > availableQuantity + 0.0001) {
        throw buildHttpError(
          `Iptal adedi mevcut miktardan buyuk olamaz. (Maks: ${availableQuantity})`,
          400
        );
      }

      let remainingToCancel = decreaseAmount;
      let cancelledQuantity = 0;
      let firstImpactedOrderItemId = impactedRows[0]?.id ?? null;
      const cancelledProductName =
        String(impactedRows[0]?.product_name_snapshot ?? "").trim() ||
        `URUN #${productId}`;
      const cancelledCategory = String(
        impactedRows[0]?.category_snapshot ?? ""
      ).trim();

      for (const row of impactedRows) {
        if (remainingToCancel <= 0) break;

        const rowQuantity = Number(row.quantity || 0);
        if (rowQuantity <= 0) continue;

        const cancelFromRow = Math.min(rowQuantity, remainingToCancel);
        const newRowQuantity = rowQuantity - cancelFromRow;

        if (newRowQuantity <= 0) {
          await client.query(`DELETE FROM order_items WHERE id = $1`, [row.id]);
        } else {
          await client.query(
            `
              UPDATE order_items
              SET
                quantity = $2,
                line_total = ROUND(($2 * unit_price_snapshot)::numeric, 2),
                updated_at = NOW()
              WHERE id = $1
            `,
            [row.id, newRowQuantity]
          );
        }

        cancelledQuantity += cancelFromRow;
        remainingToCancel -= cancelFromRow;
      }

      let safeOrderItemId = null;
      if (firstImpactedOrderItemId) {
        const { rows: orderItemRefRows } = await client.query(
          `SELECT id FROM order_items WHERE id = $1 LIMIT 1`,
          [firstImpactedOrderItemId]
        );
        safeOrderItemId = orderItemRefRows.length
          ? firstImpactedOrderItemId
          : null;
      }

      await client.query(
        `
          INSERT INTO voids (
            order_id,
            order_item_id,
            product_id,
            action_type,
            quantity,
            reason,
            created_by_user_id
          )
          VALUES ($1, $2, $3, 'VOID', $4, $5, $6)
        `,
        [
          orderId,
          safeOrderItemId,
          productId,
          cancelledQuantity,
          "POS üzerinden ürün iptali",
          req.user.user_id,
        ]
      );

      await refreshOrderTotals(client, orderId);

      const { rows: remainingRows } = await client.query(
        `
          SELECT COUNT(*)::int AS remaining_count
          FROM order_items
          WHERE order_id = $1
            AND item_status NOT IN ('VOID', 'PAID')
        `,
        [orderId]
      );

      const remainingCount = Number(remainingRows[0]?.remaining_count ?? 0);
      let tableClosed = false;
      if (remainingCount <= 0) {
        // Masadaki TÜM ürünler silindiği için masayı tamamen kapat/iptal et
        await client.query(
          `
            UPDATE orders
            SET
              order_status = 'CANCELLED',
              subtotal = 0,
              grand_total = 0,
              updated_at = NOW()
            WHERE id = $1
          `,
          [orderId]
        );
        tableClosed = true;
      } else {
        // Masada hala ürün var, sadece adisyon durumunu (status) kontrol et
        // Eğer sipariş OPEN ise OPEN kalsın, CONFIRMED ise CONFIRMED kalsın.
        // recalcOrderTotals (refreshOrderTotals) zaten tutarları güncelledi.
      }

      await client.query("COMMIT");
      emitTablesRefresh(req);

      try {
        const { rows: orderPrintRows } = await db.pool.query(
          `
            SELECT o.id, t.display_name
            FROM orders o
            LEFT JOIN tables t ON t.id = o.table_id
            WHERE o.id = $1
            LIMIT 1
          `,
          [orderId]
        );

        const tableDisplayName =
          String(orderPrintRows[0]?.display_name ?? "").trim() ||
          "MASA -";

        printerService.enqueueItemCancelledReceipt({
          tableDisplayName,
          orderId: String(orderId),
          items: [
            {
              name: cancelledProductName,
              category_name: cancelledCategory,
              quantity: cancelledQuantity,
            },
          ],
        }).catch((printError) => {
          logger.error("[item-cancel-print] Iptal fisi gonderilemedi", {
            orderId,
            productId,
            message: printError.message,
            stack: printError.stack,
          });
        });
      } catch (printLookupError) {
        logger.error("[item-cancel-print] Siparis bilgisi alinamadi", {
          orderId,
          productId,
          message: printLookupError.message,
          stack: printLookupError.stack,
        });
      }

      res.json({
        success: true,
        message: tableClosed
          ? "Secilen adet iptal edildi. Siparis kapatildi."
          : "Secilen adet iptal edildi.",
        cancelled_quantity: cancelledQuantity,
        table_closed: tableClosed,
      });
    } catch (innerError) {
      await client.query("ROLLBACK");
      throw innerError;
    } finally {
      client.release();
    }
  } catch (error) {
    return next(error);
  }
}

async function compOrderItem(req, res, next) {
  let client;
  try {
    const orderId = Number(req.params.orderId);
    const { product_id } = req.body;
    if (!Number.isFinite(orderId) || !product_id) {
      return res.status(400).json({ message: "Gecersiz istek." });
    }

    client = await db.pool.connect();
    try {
      await client.query("BEGIN");

      const { rows: impactedRows } = await client.query(
        `
          SELECT id, quantity
          FROM order_items
          WHERE order_id = $1
            AND product_id = $2
            AND item_status NOT IN ('VOID', 'PAID')
          FOR UPDATE
        `,
        [orderId, product_id]
      );

      const impactedQuantity = impactedRows.reduce(
        (sum, row) => sum + Number(row.quantity || 0),
        0
      );
      const impactedOrderItemId = impactedRows[0]?.id ?? null;
      if (!impactedRows.length || impactedQuantity <= 0) {
        throw buildHttpError("Ikram edilecek aktif urun bulunamadi.", 404);
      }

      // Ürün fiyatını 0 yap (COMP = Complimentary)
      await client.query(
        `UPDATE order_items 
         SET unit_price_snapshot = 0, line_total = 0, updated_at = NOW()
         WHERE order_id = $1 AND product_id = $2`,
        [orderId, product_id]
      );

      await client.query(
        `
          INSERT INTO voids (
            order_id,
            order_item_id,
            product_id,
            action_type,
            quantity,
            reason,
            created_by_user_id
          )
          VALUES ($1, $2, $3, 'COMP', $4, $5, $6)
        `,
        [
          orderId,
          impactedOrderItemId,
          product_id,
          impactedQuantity,
          "POS üzerinden ikram işlemi",
          req.user.user_id,
        ]
      );

      await refreshOrderTotals(client, orderId);

      await client.query("COMMIT");
      emitTablesRefresh(req);
      res.json({ success: true, message: "Ürün ikram edildi (0 TL)." });
    } catch (innerError) {
      await client.query("ROLLBACK");
      throw innerError;
    } finally {
      client.release();
    }
  } catch (error) {
    return next(error);
  }
}

async function mergeTable(req, res, next) {
  try {
    const { source_table_id, target_table_id } = req.body;

    if (!source_table_id || !target_table_id) {
      return res.status(400).json({ message: "source_table_id ve target_table_id gerekli." });
    }
    if (source_table_id === target_table_id) {
      return res.status(400).json({ message: "Ayni masalar birlestirilemez." });
    }

    const result = await orderService.mergeOrderBetweenTables({
      sourceTableId: Number(source_table_id),
      targetTableId: Number(target_table_id),
    });

    emitTablesRefresh(req);

    return res.status(200).json({
      message: "Masalar basariyla birlesti.",
      source_table: {
        id: String(result.sourceTable.id),
        display_name: result.sourceTable.display_name,
        status: "AVAILABLE",
      },
      target_table: {
        id: String(result.targetTable.id),
        display_name: result.targetTable.display_name,
        status: "OCCUPIED",
      },
    });
  } catch (error) {
    if (error.statusCode) {
      return res.status(error.statusCode).json({ message: error.message });
    }
    return next(error);
  }
}

async function updateOrderMeta(req, res, next) {
  try {
    const orderId = Number(req.params.orderId);
    const guestCount = req.body?.guest_count;
    const tableNote = req.body?.table_note;

    if (!Number.isFinite(orderId)) {
      return res.status(400).json({ message: "Gecersiz orderId." });
    }

    const result = await orderService.updateOrderMeta({
      orderId,
      guestCount,
      tableNote,
    });

    emitTablesRefresh(req);

    return res.status(200).json({
      message: "Siparis bilgileri guncellendi.",
      order: {
        id: String(result.id),
        guest_count: Number(result.guest_count || 1),
        table_note: result.table_note ?? null,
      },
    });
  } catch (error) {
    if (error.statusCode) {
      return res.status(error.statusCode).json({ message: error.message });
    }
    return next(error);
  }
}

async function transferOrderItem(req, res, next) {
  try {
    const orderId = Number(req.params.orderId);
    const productId = Number(req.body?.product_id);
    const quantity = Number(req.body?.quantity);
    const toTableId = Number(req.body?.to_table_id);

    if (
      !Number.isFinite(orderId) ||
      !Number.isFinite(productId) ||
      !Number.isFinite(quantity) ||
      !Number.isFinite(toTableId)
    ) {
      return res.status(400).json({ message: "Gecersiz transfer parametreleri." });
    }

    const result = await orderService.transferOrderItem({
      orderId,
      productId,
      quantity,
      toTableId,
      userId: req.user.user_id,
    });

    emitTablesRefresh(req);

    return res.status(200).json({
      message: "Urun baska masaya tasindi.",
      source_order_id: String(result.sourceOrderId),
      target_order_id: String(result.targetOrderId),
      moved_quantity: Number(result.movedQuantity || 0),
      created_target_order: Boolean(result.createdTargetOrder),
      source_table: {
        id: String(result.sourceTable.id),
        display_name: result.sourceTable.display_name,
      },
      target_table: {
        id: String(result.targetTable.id),
        display_name: result.targetTable.display_name,
      },
    });
  } catch (error) {
    if (error.statusCode) {
      return res.status(error.statusCode).json({ message: error.message });
    }
    return next(error);
  }
}

async function amountPayment(req, res, next) {
  let client;
  try {
    const orderId = Number(req.params.orderId);
    const amount = Number(req.body?.amount ?? 0);
    const paymentMethod = (req.body?.paymentMethod ?? "").toString().toUpperCase();
    const discountAmount = Number(req.body?.discountAmount ?? 0);
    const expectedFinalTotalRaw = req.body?.finalTotal;
    const hasExpectedFinalTotal =
      expectedFinalTotalRaw !== undefined && expectedFinalTotalRaw !== null && expectedFinalTotalRaw !== "";
    const expectedFinalTotal = hasExpectedFinalTotal
      ? Number(expectedFinalTotalRaw)
      : null;

    if (!Number.isFinite(orderId) || !Number.isFinite(amount) || amount < 0) {
      return res.status(400).json({ message: "Gecersiz tutar." });
    }

    if (!Number.isFinite(discountAmount) || discountAmount < 0) {
      return res.status(400).json({ message: "discountAmount 0 veya pozitif olmalı." });
    }

    if (hasExpectedFinalTotal && (!Number.isFinite(expectedFinalTotal) || expectedFinalTotal < 0)) {
      return res.status(400).json({ message: "finalTotal gecersiz." });
    }

    if (!["CASH", "CARD", "MEAL_CARD"].includes(paymentMethod)) {
      return res.status(400).json({ message: "paymentMethod CASH, CARD veya MEAL_CARD olmalı." });
    }

    await orderService.startPaymentSession({
      orderId,
      userId: req.user.user_id,
    });

    client = await db.pool.connect();
    await client.query("BEGIN");

    const { rows: orderRows } = await client.query(
      `
        SELECT id, table_id, order_status, subtotal, discount_total, grand_total
        FROM orders
        WHERE id = $1
        FOR UPDATE
      `,
      [orderId]
    );

    if (!orderRows.length) {
      await client.query("ROLLBACK");
      return res.status(404).json({ message: "Siparis bulunamadi." });
    }

    if (!["OPEN", "CONFIRMED"].includes(orderRows[0].order_status)) {
      await client.query("ROLLBACK");
      return res.status(400).json({ message: "Bu siparis odemeye uygun degil." });
    }

    let currentGrandTotal = Number(orderRows[0].grand_total);
    const currentSubtotal = Number(orderRows[0].subtotal ?? currentGrandTotal);

    if (discountAmount > 0) {
      // Siparişin brüt toplamını (indirimden önceki halini) bulalım
      const { rows: grossRows } = await client.query(
        "SELECT COALESCE(SUM(line_total), 0) as gross_total FROM order_items WHERE order_id = $1 AND item_status <> 'VOID'",
        [orderId]
      );
      const grossTotal = Number(grossRows[0].gross_total);
      
      // Yeni indirim sonrası oluşacak toplam tutar
      const discountedGrandTotal = Math.max(grossTotal - discountAmount, 0);

      // Daha önce yapılmış tahsilatları bulalım
      const { rows: paidRowsBeforeDiscount } = await client.query(
        "SELECT COALESCE(SUM(amount), 0) as total_paid FROM payments WHERE order_id = $1",
        [orderId]
      );
      const alreadyPaid = Number(paidRowsBeforeDiscount[0].total_paid);

      // Eğer yapılan tahsilatlar, yeni indirimli toplamdan büyükse bu indirim yapılamaz
      if (alreadyPaid > discountedGrandTotal + 0.05) {
        await client.query("ROLLBACK");
        return res.status(400).json({
          message: `Mevcut tahsilat (${alreadyPaid.toFixed(2)} ₺), indirimli toplamdan (${discountedGrandTotal.toFixed(2)} ₺) büyük olduğu için bu indirim uygulanamaz.`,
        });
      }

      await client.query(
        `
          UPDATE orders
          SET
            discount_total = $2,
            grand_total = $3,
            updated_at = NOW()
          WHERE id = $1
        `,
        [orderId, discountAmount, discountedGrandTotal]
      );

      // currentGrandTotal'i güncellemeliyiz ki aşağıda remaining doğru hesaplansın
      // Önemli: Tutar girerek ödemede 'remaining' aslında (Gross Total - Discount - Already Paid) olmalı.
      currentGrandTotal = Math.max(discountedGrandTotal - alreadyPaid, 0);
    } else {
      // İndirim yoksa, remaining = Grand Total (ki o zaten [Gross - Discount - Paid] mantığıyla tutuluyor olabilir)
      // Ancak mevcut sistemde grand_total bazen kafa karıştırıcı olabiliyor.
      // En garantisi: remaining = (Gross Total - Discount Total - Already Paid)
      const { rows: balanceRows } = await client.query(
        `
          SELECT 
            COALESCE(SUM(oi.line_total), 0) - COALESCE(o.discount_total, 0) - COALESCE(p.total_paid, 0) as remaining_balance
          FROM orders o
          LEFT JOIN (SELECT order_id, SUM(line_total) as line_total FROM order_items WHERE item_status <> 'VOID' GROUP BY order_id) oi ON oi.order_id = o.id
          LEFT JOIN (SELECT order_id, SUM(amount) as total_paid FROM payments GROUP BY order_id) p ON p.order_id = o.id
          WHERE o.id = $1
          GROUP BY o.id, o.discount_total, p.total_paid
        `,
        [orderId]
      );
      currentGrandTotal = Math.max(Number(balanceRows[0]?.remaining_balance || 0), 0);
    }

    // Önemli: Artık 'remaining' değişkeni yukarıdaki hesaplamalara göre netleşti.
    const remaining = Number(currentGrandTotal.toFixed(2));

    // Yüzeysel bir hata payı (floating point) bırakalım
    if (amount > remaining + 0.05) {
      await client.query("ROLLBACK");
      return res.status(400).json({
        message: `Girdiğiniz tutar (${amount.toFixed(
          2
        )} ₺) kalan borçtan (${remaining.toFixed(2)} ₺) fazla.`,
      });
    }

    const mealCardType = req.body?.mealCardType?.toString().trim() || null;
    const netAmount = Number(amount.toFixed(2));
    let tableClosed = false;

    if (netAmount <= 0) {
      // Önemli: Eğer tutar 0 ise (tam indirim durumu), payments tablosuna kayıt atmıyoruz
      // ancak işlemin devam etmesine ve kalan borç 0 ise masanın kapanmasına izin veriyoruz.
    } else {
      await client.query(
        `
          INSERT INTO payments (
            order_id,
            received_by_user_id,
            payment_method,
            amount,
            currency,
            meal_card_type,
            payment_note
          )
          VALUES ($1, $2, $3, $4, 'TRY', $5, 'Tutar girerek odeme')
        `,
        [orderId, req.user.user_id, paymentMethod, netAmount, mealCardType]
      );
    }

    // Eğer tüm borç kapandıysa (veya indirimle sıfırlandıysa) masayı kapat.
    // Tutar girilerek yapılan ödemelerde borç bitmediyse masa açık kalmaya devam eder.
    if (Math.abs(remaining - netAmount) < 0.05) {
      // Önemli: Eğer borç 0 veya indirimle 0'a düştüyse, masadaki tüm ürünleri PAID yapmalıyız ki masa kapansın.
      await client.query(
        `
          UPDATE order_items
          SET item_status = 'PAID', updated_at = NOW()
          WHERE order_id = $1 AND item_status NOT IN ('VOID', 'PAID')
        `,
        [orderId]
      );

      await client.query(
        `
          UPDATE orders
          SET order_status = 'PAID',
              closed_at = NOW(),
              closed_by_user_id = $2,
              payment_lock_user_id = NULL,
              payment_lock_at = NULL,
              subtotal = 0,
              grand_total = 0,
              updated_at = NOW()
          WHERE id = $1
        `,
        [orderId, req.user.user_id]
      );
      tableClosed = true;
      
      if (orderRows[0].table_id) {
        await client.query("UPDATE tables SET is_active = TRUE WHERE id = $1", [orderRows[0].table_id]);
      }

      // Fişi yazdır (arka planda; ödeme cevabını bekletmesin)
      try {
        const { rows: orderData } = await client.query(
          `SELECT o.subtotal, o.discount_total, o.grand_total, t.display_name 
           FROM orders o JOIN tables t ON t.id = o.table_id WHERE o.id = $1`,
          [orderId]
        );
        const { rows: itemRows } = await client.query(
          `SELECT product_name_snapshot as name, quantity, unit_price_snapshot as unit_price 
           FROM order_items WHERE order_id = $1 AND item_status != 'VOID'`,
          [orderId]
        );
        
        if (orderData.length) {
          orderService.printFinalReceipt({
            orderId,
            tableDisplayName: orderData[0].display_name,
            items: itemRows,
            subtotal: Number(orderData[0].subtotal),
            discountAmount: Number(orderData[0].discount_total),
            grandTotal: Number(orderData[0].grand_total),
            paymentMethod,
            mealCardType,
          }).catch((printErr) => {
            console.error("Otomatik fiş yazdırma hatası (amountPayment):", printErr);
          });
        }
      } catch (printErr) {
        console.error("Otomatik fiş yazdırma hatası (amountPayment):", printErr);
      }
    }

    await client.query("COMMIT");

    emitTablesRefresh(req);

    const io = req.app.get("io");
    if (io) {
      io.emit("new-order", { at: new Date().toISOString() });
    }

    return res.status(200).json({
      success: true,
      message: tableClosed ? "Ödeme tamamlandı. Masa kapatıldı." : "Ödeme alındı.",
      amount: netAmount,
      is_fully_paid: Math.abs(remaining - netAmount) < 0.05,
      table_closed: tableClosed
    });
  } catch (error) {
    if (client) {
      try {
        await client.query("ROLLBACK");
      } catch (_) {}
    }
    return next(error);
  } finally {
    client?.release();
  }
}

module.exports = {
  createOrder,
  confirmOrder,
  getActiveOrderByTable,
  printCurrentAccount,
  checkoutOrder,
  startPaymentSession,
  endPaymentSession,
  transferTable,
  mergeTable,
  partialCheckout,
  amountPayment,
  voidOrderItem,
  compOrderItem,
  updateOrderItemNote,
  updateOrderItemPrice,
  updateOrderMeta,
  transferOrderItem,
};
