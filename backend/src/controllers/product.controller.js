const productService = require("../services/product.service");

function parsePositiveInt(value) {
  const parsed = Number.parseInt(String(value), 10);
  return Number.isInteger(parsed) && parsed > 0 ? parsed : null;
}

function parsePrice(value) {
  const parsed = Number.parseFloat(String(value));
  if (!Number.isFinite(parsed) || parsed < 0) return null;
  return Number(parsed.toFixed(2));
}

function normalizeName(value) {
  return String(value || "").trim().replace(/\s+/g, " ");
}

function normalizePrinterRoute(value) {
  return String(value || "MUTFAK").trim().toUpperCase();
}

function emitMenuRefresh(req) {
  const io = req.app.get("io");
  if (io) {
    io.emit("menu:refresh", { at: new Date().toISOString() });
  }
}

async function listProducts(req, res, next) {
  try {
    const products = await productService.listActiveProductsForWaiter();
    return res.status(200).json({
      count: products.length,
      products,
    });
  } catch (error) {
    return next(error);
  }
}

async function listCategoriesAdmin(req, res, next) {
  try {
    const categories = await productService.listCategoriesForAdmin();
    return res.status(200).json({ count: categories.length, categories });
  } catch (error) {
    return next(error);
  }
}

async function createCategoryAdmin(req, res, next) {
  try {
    const name = normalizeName(req.body?.name);
    const printerRoute = normalizePrinterRoute(req.body?.printer_route);
    const imagePath = String(req.body?.image_path ?? "").trim();
    const rawSortOrder = req.body?.sort_order;
    const sortOrder =
      rawSortOrder == null || rawSortOrder === ""
        ? null
        : Number.parseInt(String(rawSortOrder), 10);

    if (!name) {
      return res.status(400).json({ message: "Kategori adi bos birakilamaz." });
    }
    if (name.length > 100) {
      return res.status(400).json({ message: "Kategori adi en fazla 100 karakter olabilir." });
    }
    if (!["MUTFAK", "BAR", "KASA"].includes(printerRoute)) {
      return res.status(400).json({ message: "Yazici rotasi gecersiz." });
    }
    if (sortOrder != null && (!Number.isInteger(sortOrder) || sortOrder < 0)) {
      return res.status(400).json({ message: "Siralama degeri gecersiz." });
    }
    const category = await productService.createCategory({
      name,
      printerRoute,
      imagePath,
      sortOrder,
    });

    if (!category) {
      return res.status(500).json({ message: "Kategori olusturulamadi." });
    }

    emitMenuRefresh(req);

    return res.status(201).json({ message: "Kategori kaydedildi.", category });
  } catch (error) {
    if (error?.code === "23505") {
      return res.status(409).json({ message: "Bu isimde kategori zaten var." });
    }
    return next(error);
  }
}

async function listProductsAdmin(req, res, next) {
  try {
    const search = (req.query.search || "").toString();
    const categoryId = req.query.categoryId ? parsePositiveInt(req.query.categoryId) : null;

    if (req.query.categoryId && categoryId == null) {
      return res.status(400).json({ message: "Gecersiz kategori secimi." });
    }

    const products = await productService.listProductsForAdmin({ search, categoryId });
    return res.status(200).json({ count: products.length, products });
  } catch (error) {
    return next(error);
  }
}

async function createProductAdmin(req, res, next) {
  try {
    const name = normalizeName(req.body?.name);
    const price = parsePrice(req.body?.price);
    const categoryId = parsePositiveInt(req.body?.category_id);

    if (!name) {
      return res.status(400).json({ message: "Urun adi bos birakilamaz." });
    }
    if (name.length > 140) {
      return res.status(400).json({ message: "Urun adi en fazla 140 karakter olabilir." });
    }
    if (price == null) {
      return res.status(400).json({ message: "Fiyat gecersiz." });
    }
    if (categoryId == null) {
      return res.status(400).json({ message: "Kategori secimi zorunludur." });
    }

    const created = await productService.createProduct({ name, price, categoryId });
    if (!created) {
      return res.status(404).json({ message: "Kategori bulunamadi." });
    }

    emitMenuRefresh(req);

    return res.status(201).json({ message: "Urun eklendi.", product: created });
  } catch (error) {
    if (error?.code === "23505") {
      return res.status(409).json({ message: "Bu kategoride ayni isimde urun zaten var." });
    }
    return next(error);
  }
}

async function updateProductAdmin(req, res, next) {
  try {
    const productId = parsePositiveInt(req.params.productId);
    const name = normalizeName(req.body?.name);
    const price = parsePrice(req.body?.price);
    const categoryId = parsePositiveInt(req.body?.category_id);

    if (productId == null) {
      return res.status(400).json({ message: "Gecersiz urun kimligi." });
    }
    if (!name) {
      return res.status(400).json({ message: "Urun adi bos birakilamaz." });
    }
    if (name.length > 140) {
      return res.status(400).json({ message: "Urun adi en fazla 140 karakter olabilir." });
    }
    if (price == null) {
      return res.status(400).json({ message: "Fiyat gecersiz." });
    }
    if (categoryId == null) {
      return res.status(400).json({ message: "Kategori secimi zorunludur." });
    }

    const updated = await productService.updateProduct({ productId, name, price, categoryId });
    if (!updated) {
      return res.status(404).json({ message: "Urun veya kategori bulunamadi." });
    }

    emitMenuRefresh(req);

    return res.status(200).json({ message: "Urun guncellendi.", product: updated });
  } catch (error) {
    if (error?.code === "23505") {
      return res.status(409).json({ message: "Bu kategoride ayni isimde urun zaten var." });
    }
    return next(error);
  }
}

async function deleteProductAdmin(req, res, next) {
  const productId = parsePositiveInt(req.params.productId);
  try {
    if (productId == null) {
      return res.status(400).json({ message: "Gecersiz urun kimligi." });
    }

    const deleted = await productService.deleteProduct({ productId });
    if (!deleted) {
      return res.status(404).json({ message: "Urun bulunamadi." });
    }

    if (deleted.softDeleted) {
      emitMenuRefresh(req);
      return res.status(200).json({
        message: "Urun gecmis kayitlara bagli oldugu icin pasife alindi.",
        softDeleted: true,
      });
    }

    emitMenuRefresh(req);
    return res.status(200).json({
      message: "Urun silindi.",
      softDeleted: false,
    });
  } catch (error) {
    return next(error);
  }
}

async function deleteCategoryAdmin(req, res, next) {
  const categoryId = parsePositiveInt(req.params.categoryId);
  try {
    if (categoryId == null) {
      return res.status(400).json({ message: "Gecersiz kategori kimligi." });
    }

    const deleted = await productService.deleteCategory({ categoryId });
    if (!deleted) {
      return res.status(404).json({ message: "Kategori bulunamadi." });
    }

    emitMenuRefresh(req);

    return res.status(200).json({
      message: deleted.softDeleted
        ? `Kategori pasife alindi. Bu kategoriye bagli ${deleted.deactivatedProductCount ?? 0} aktif urun de pasife alindi.`
        : "Kategori silindi.",
      softDeleted: Boolean(deleted.softDeleted),
      deactivatedProductCount: deleted.deactivatedProductCount ?? 0,
    });
  } catch (error) {
    return next(error);
  }
}

module.exports = {
  listProducts,
  listCategoriesAdmin,
  createCategoryAdmin,
  listProductsAdmin,
  createProductAdmin,
  updateProductAdmin,
  deleteProductAdmin,
  deleteCategoryAdmin,
};
