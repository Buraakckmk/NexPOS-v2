require("dotenv").config({ override: true });

const db = require("../config/db");

const MENU_TEXT = `
Kahvaltı
Yöresel Serpme Kahvaltı
Leb-i Derya Kahvaltı (Yöresel Kahvaltı) – ₺800,00

Kahvaltısız Yapamayanlar
Gevrek Kahvaltı Soğuk – ₺230,00
Gevrek Kahvaltı Sıcak – ₺250,00
Kahvaltı Tabağı – ₺350,00
Sahanda Yumurta – ₺120,00
Pişi Kahvaltı – ₺450,00
İtalyan Kahvaltısı – ₺200,00
Sahanda Sucuklu Yumurta – ₺160,00
Bal Kaymak – ₺160,00
Peynir Tabağı – ₺220,00

Omlet
Sade Omlet – ₺150,00
Beyaz Peynirli Omlet – ₺170,00
Kaşarlı Omlet – ₺175,00
Sucuklu Omlet – ₺180,00
Omlet Deryası – ₺220,00

Menemen
Karışık Menemen – ₺220,00
Klasik Menemen – ₺170,00
Kaşar Peynirli Menemen – ₺180,00
Sucuklu Menemen – ₺190,00

Börekler
Sigara Böreği – ₺170,00
Kalem Börek – ₺320,00

Aperatifler
Atıştırmalıklar
Sıcak Sepet – ₺300,00
Parmak Patates – ₺180,00
Parmak Patates ve Soğan Halkası – ₺220,00
Elma Dilim Patates – ₺190,00
Çıtır Tavuk Dilimleri – ₺250,00
Dedikodu Tabağı – ₺400,00

Sandviçler / Tostlar
Kaşarlı Tost – ₺220,00
Karışık Tost – ₺260,00
Ton Balıklı Sandviç – ₺300,00
Karışık Sandviç – ₺300,00
Philly Steak – ₺400,00
Club Sandviç – ₺320,00

Burgerler
Cheese Burger – ₺350,00
Big Chicken – ₺280,00
Klasik Usül Burger – ₺320,00
Cheese Mushroom Burger – ₺520,00

Pizzalar
Karışık Pizza – ₺370,00
Ton Balıklı Pizza – ₺370,00
Vejeteryan Pizza – ₺270,00
Pastırmalı Pizza – ₺400,00
Margarita Pizza – ₺270,00

Wrapler
Etli Wrap – ₺390,00
Tavuklu Wrap – ₺290,00

Krepler
Etli Krep – ₺450,00
Tavuklu Krep – ₺350,00

Salatalar
Ege Usulü – ₺270,00
Diyet Salata – ₺300,00
Hellim Salata – ₺280,00
Ton Balıklı Salata – ₺300,00
Tavuklu Sezar Salata – ₺300,00

Makarnalar
Fettucini Alfredo – ₺320,00
Mantı – ₺300,00
Penne Arabiatta – ₺250,00
Penne Al Fredo – ₺290,00
Spagetti Napoliten – ₺250,00
Spagetti Bolognese – ₺300,00

Ana Yemekler
Tavuk Yemekleri
Beşamel Soslu Tavuk – ₺350,00
Tavuk Izgara – ₺350,00
Köri Soslu Tavuk – ₺350,00
Soya Soslu Tavuk – ₺350,00
Piliç Şinitzel – ₺330,00
Tavuklu Fajita – ₺400,00

Et Yemekleri
Chef Köfte Kaşarlı – ₺380,00
Bodrum Çökertmesi – ₺600,00
Gurme Bonfile – ₺700,00
Etli Fajita – ₺700,00
Güveçte Et Sote – ₺550,00
Chef Köfte – ₺350,00
Steak Rulo – ₺700,00

Sıcak İçecekler
Klasik Türk Kahvesi Çeşitleri
Sütlü Türk Kahvesi – ₺140,00
Double Türk Kahvesi – ₺160,00
Türk Kahvesi – ₺120,00

Özel Türk Kahvesi Çeşitleri
Osmanlı Dibek Kahvesi – ₺150,00
Osmanlı Dibek Damla Sakızlı Kahve – ₺140,00
Yeditepe İstanbul – ₺150,00
Menengiç Kahvesi – ₺140,00
Leb-İ Derya Kahvesi – ₺150,00
Damla Sakızlı Türk Kahvesi – ₺150,00
Çikolata – Fındıklı Türk Kahvesi – ₺150,00
Dağ Çilekli Türk Kahvesi – ₺150,00
Double Aromalı Türk Kahvesi Çeşitleri – ₺180,00

Espressolu Kahve Çeşitleri
Espresso – ₺130,00
Double Espresso – ₺150,00
Espresso Macciato – ₺150,00
Double Espresso Macciato – ₺160,00
Espresso Con Panna – ₺160,00
Double Espresso Con Panna – ₺170,00
Oreo Hot Coffee – ₺190,00
White Chocolate Mocha – ₺220,00
Karamel Macchiato – ₺210,00
Aromalı Cafe Latte – ₺200,00
Cappucino – ₺190,00
Aromalı Cappucino – ₺170,00
Latte Macchiato – ₺190,00
Hazır Kahve Sade – ₺170,00
Hazır Kahve Sütlü – ₺190,00
Kahve Deryası Special – ₺210,00
Americano – ₺170,00
Cafe Latte – ₺190,00
Cafe Mocha – ₺210,00
Cortado – ₺190,00
Flat White – ₺200,00
Lotus Latte – ₺210,00
Antep Fıstıklı Latte – ₺210,00
Matcha – ₺220,00
Hurma Latte – ₺210,00
Kestane Latte – ₺210,00
Apple Pie Latte – ₺210,00
Toffee Nut Latte – ₺210,00
Cookies Latte – ₺210,00
Vanilla Coconout Latte – ₺210,00
Zencefil Tarçın Latte – ₺210,00
Salted Caramel Latte – ₺210,00
Pumpkin Spice Latte – ₺210,00
Irish Cream Latte – ₺210,00

Filtre Kahve Çeşitleri
Filtre Kahve – ₺160,00
Sütlü Filtre Kahve – ₺170,00

Aromalı Filtre Kahveler
Karamelli Filtre Kahve – ₺190,00
Fındıklı Filtre Kahve – ₺190,00

Yöresel Kahveler
Ethiopia – ₺190,00
Colombian Supremo – ₺190,00
Brazilian Santos – ₺190,00
Guetemala Yirgacheffe – ₺190,00

Yeni Nesil Kahveler
Cold Brew – ₺200,00
Cold Brew Sütlü – ₺210,00
Chemex – ₺230,00

Frappeler
Oreo Frappe – ₺250,00
White Mocha Frappe – ₺250,00
Dondurmalı Frappe – ₺250,00
Kahve Deryası Frappe – ₺250,00
Buzlu Hazır Kahve – ₺220,00

Alternatif Tatlar
Salep – ₺190,00
Damla Sakızlı Salep – ₺200,00
Damla Sakızlı - Fındık Parçacıklı Salep – ₺200,00
Ballı - Bademli Salep – ₺200,00

Sıcak Çikolatalar
Sıcak Çikolata – ₺190,00
Bitter Sıcak Çikolata – ₺200,00
Dağ Çilekli Sıcak Çikolata – ₺200,00
Beyaz Sıcak Çikolata – ₺200,00
Aromalı Sıcak Çikolata – ₺200,00

Çay
Çay – ₺40,00
Fincan Çay – ₺70,00
Sütlü Çay – ₺80,00

Bitkisel Çaylar
Papatya – ₺160,00
Adaçayı – ₺160,00
Rezene – ₺160,00
Ihlamur – ₺160,00

Doğal Harman Çayları
Yeşil Çay – ₺170,00
Naneli Yeşil Çay – ₺170,00
Nane - Limon Yeşil Çay – ₺170,00
Limonlu Yeşil Çay – ₺170,00
Yaseminli Yeşil Çay – ₺170,00
Orman Meyveli Siyah Çay – ₺170,00
Limonlu Siyah Çay – ₺170,00

Meyveli Çaylar
Kuşburnu Çayı – ₺160,00
Elma Çayı – ₺160,00
Böğürtlen Çayı – ₺160,00
Nar Çayı – ₺160,00
Çilek Çayı – ₺160,00
Nane – Limon Çayı – ₺160,00
Winter Tea Çayı – ₺160,00

Soğuk İçecekler
Alternatif Soğuklar
Buzlu Çikolata – ₺160,00
Buzlu Beyaz Çikolata – ₺160,00
Çikolatalı Smoothie – ₺150,00
Beyaz Çikolatalı Smoothie – ₺125,00
Çilek Limon Aşkı – ₺190,00
Dondurma Espresso Aşkı – ₺150,00
Vişne - Muz Aşkı – ₺190,00
Mavi Rüya – ₺190,00
Chai Tea Latte – ₺170,00
Green Heaven – ₺180,00
Pinkberry – ₺180,00
Caremella – ₺180,00
Coco Choco – ₺180,00
Deep Forest – ₺190,00
Berriscus – ₺190,00
Green Tea – ₺180,00
Fresh Lime – ₺190,00
Bubble Tea Frambuaz – ₺190,00
Bubble Tea Çarkıfelek – ₺190,00
Bubble Tea Limon – ₺190,00
Bubble Tea Frenk – ₺190,00
Bubble Tea Çilek – ₺190,00
Green Wind – ₺190,00
Orange Mango – ₺190,00
Rasberry Acai – ₺190,00
Summer Breeze – ₺190,00
Cloudy – ₺190,00

Soğuk Kahveler
Affogato – ₺220,00
Ice Antep Fıstıklı Latte – ₺200,00
Ice Coffee Nut Latte – ₺170,00
Ice Cafe Latte – ₺190,00
Iced Chai Tea Latte – ₺180,00
Frappe – ₺250,00
Buzlu Fındık – ₺180,00
Ice Americano – ₺170,00
Ice Mocha – ₺220,00
Ice Caramel – ₺200,00

Meyveli Frozen
Tropicana Frozen – ₺230,00
Çilekli Frozen – ₺230,00
Kavunlu Frozen – ₺230,00
Muzlu Frozen – ₺230,00
Şeftali Frozen – ₺230,00
Nane Limon Frozen – ₺230,00

Milkshakes
Karadut Deryası Milkshakes – ₺250,00
Çikolata Milkshakes – ₺250,00
Çilek Milkshakes – ₺250,00
Muz Milkshakes – ₺250,00
Karamel Milkshakes – ₺250,00
Limon Milkshakes – ₺250,00
Oreo Milkshakes – ₺250,00

Meşrubatlar
Citrus Pop – ₺195,00
Acai Moctails – ₺195,00
Red Bull White – ₺180,00
Peach Twist – ₺240,00
Blue Twist – ₺240,00
White Twist – ₺240,00
Berry Me – ₺240,00
Passion Paradise – ₺220,00
Pink Lemonade – ₺220,00
Sour Island – ₺220,00
Vanilla Inspration – ₺220,00
Coca Cola Zero – ₺110,00
Coca Cola – ₺110,00
Coca Cola Light – ₺110,00
Fanta – ₺110,00
Sprite – ₺110,00
Cappy – ₺110,00
Fusetea – ₺110,00
Schweppes – ₺110,00
Pet Su – ₺30,00
Cam Şişe Su – ₺65,00
Meyveli Soda – ₺80,00
Soda – ₺70,00
Soda Limon – ₺90,00
Churchill – ₺100,00
Limonata – ₺160,00
Meyveli Limonata – ₺170,00
Taze Sıkılmış Portakal Suyu – ₺180,00
Muzlu Süt – ₺190,00
Ayran – ₺80,00
Red Bull Energy Drink – ₺180,00
Red Bull Sugar Free – ₺180,00
Red Bull Yellow Edition – ₺180,00
Red Bull Blue Edition – ₺180,00
Schweppespresso – ₺200,00
Fix Cocktail – ₺195,00
Coke Mojito – ₺200,00

Detoks İçecekler
Yeşil Detoks – ₺230,00
Meyve Detoks – ₺250,00

Tatlılar
Pasta ve Kekler
Kedi Dili Tiramisu – ₺250,00
Belçika Çikolatalı Pasta – ₺250,00
Coco Star – ₺250,00
Brownie Karamel Cheesecake – ₺250,00
Latte Mono Cake – ₺250,00
Orman Meyveleri – ₺250,00
Havuçlu Kek – ₺250,00
Tiramisu – ₺250,00
Frambuazlı Cheesecake – ₺250,00
Limonlu Cheesecake – ₺250,00
Kara Orman Pasta – ₺250,00
Siyah Profiterollü Pasta – ₺250,00
Mozaik Pasta – ₺250,00
Devil's Fudge – ₺250,00
Brownie – ₺250,00
Antep Keyfi – ₺250,00
Sufle – ₺300,00
Nuthellalı Pasta – ₺250,00
İspanyol Cream Cheesecake – ₺250,00
Marlenka – ₺250,00

Waffle
Waffle İdeal Çikolata, Mevsim Meyveleri – ₺270,00
Waffle Mix – ₺300,00
Waffle Sade Çikolatalı – ₺250,00

Fondü & Meyve
Karışık Çerez Tabağı – ₺280,00
Tek Kişilik – ₺200,00
Çift Kişilik – ₺250,00
Meyve Tabağı – ₺280,00

Dondurmalar
Dondurmalar (4 Top) – ₺185,00
Top Dondurma – ₺0,00

Kokteyller
Pineapple Pop – ₺250,00
Red Bull Twist – ₺240,00
Tropical Breeze – ₺200,00

Hediyelik Ürünler
Madlen Çikolata Kutusu (750gr) – ₺690,00
Madlen Çikolata Kutusu (500gr) – ₺590,00
Çakıltaşı (100gr) – ₺150,00
Türk Kahvesi 100 Gr (Poşet) – ₺160,00
Aromalı Türk Kahvesi 100 Gr (Poşet) – ₺160,00
Filtre Kahve (100 Gr) – ₺170,00
Aromalı Filtre Kahve (100gr) – ₺170,00
Kurabiye Çeşitleri – ₺200,00
`;

function parsePrice(raw) {
  const cleaned = String(raw ?? "")
    .trim()
    .replace(/\./g, "")
    .replace(",", ".")
    .replace(/[^\d.-]/g, "");
  const n = Number.parseFloat(cleaned);
  return Number.isFinite(n) ? Math.round(n * 100) / 100 : null;
}

function buildMenuFromText(text) {
  const posCategoryOrder = [
    "SICAK İÇECEKLER",
    "SOĞUK İÇECEKLER",
    "ANA YEMEKLER",
    "APERATİFLER",
    "ÇAYLAR",
    "TÜRK KAHVESİ ÇEŞİTLERİ",
    "ESPRESSOLU KAHVELER",
    "FİLTRE KAHVELER",
    "FRAPPELER",
    "KAHVALTI VE BAŞLANGIÇLAR",
    "DONDURMALAR",
    "KREPLER",
    "MAKARNALAR",
    "MEŞRUBATLAR",
    "MEYVELİ FROZENLER",
    "MİLKSHAKELER",
    "PASTA VE KEKLER",
    "PİZZALAR",
    "SAHLEP-SICAK ÇİKOLATA",
    "SALATALAR",
    "SOĞUK KAHVELER",
    "WRAPLAR",
    "YENİ NESİL KAHVELER",
    "DETOKS",
    "TAKE AWAY",
    "FONDU-WAFFLE",
    "MATCHA (MAÇA)",
  ];

  const printerRouteByPosCategory = new Map([
    ["SICAK İÇECEKLER", "BAR"],
    ["SOĞUK İÇECEKLER", "BAR"],
    ["ÇAYLAR", "BAR"],
    ["TÜRK KAHVESİ ÇEŞİTLERİ", "BAR"],
    ["ESPRESSOLU KAHVELER", "BAR"],
    ["FİLTRE KAHVELER", "BAR"],
    ["FRAPPELER", "BAR"],
    ["MEŞRUBATLAR", "BAR"],
    ["MEYVELİ FROZENLER", "BAR"],
    ["MİLKSHAKELER", "BAR"],
    ["SAHLEP-SICAK ÇİKOLATA", "BAR"],
    ["SOĞUK KAHVELER", "BAR"],
    ["YENİ NESİL KAHVELER", "BAR"],
    ["DETOKS", "BAR"],
    ["MATCHA (MAÇA)", "BAR"],
    ["KAHVALTI VE BAŞLANGIÇLAR", "MUTFAK"],
    ["APERATİFLER", "MUTFAK"],
    ["ANA YEMEKLER", "MUTFAK"],
    ["PİZZALAR", "MUTFAK"],
    ["WRAPLAR", "MUTFAK"],
    ["KREPLER", "MUTFAK"],
    ["SALATALAR", "MUTFAK"],
    ["MAKARNALAR", "MUTFAK"],
    ["FONDU-WAFFLE", "BAR"],
    ["PASTA VE KEKLER", "BAR"],
    ["DONDURMALAR", "BAR"],
    ["TAKE AWAY", "KASA"],
  ]);

  const topLevels = new Set([
    "Kahvaltı",
    "Aperatifler",
    "Burgerler",
    "Pizzalar",
    "Wrapler",
    "Krepler",
    "Salatalar",
    "Makarnalar",
    "Ana Yemekler",
    "Sıcak İçecekler",
    "Soğuk İçecekler",
    "Tatlılar",
    "Kokteyller",
    "Hediyelik Ürünler",
  ]);

  const lines = String(text ?? "")
    .split("\n")
    .map((l) => l.trim())
    .filter((l) => l.length > 0);

  let currentTop = null;
  let currentSub = null;

  function resolvePosCategory(top, sub, name) {
    const t = String(top ?? "").trim();
    const s = String(sub ?? "").trim();
    const n = String(name ?? "").trim();

    if (t === "Kahvaltı") return "KAHVALTI VE BAŞLANGIÇLAR";

    if (t === "Aperatifler") return "APERATİFLER";

    if (t === "Burgerler") return "ANA YEMEKLER";

    if (t === "Pizzalar") return "PİZZALAR";

    if (t === "Wrapler") return "WRAPLAR";

    if (t === "Krepler") return "KREPLER";

    if (t === "Salatalar") return "SALATALAR";

    if (t === "Makarnalar") return "MAKARNALAR";

    if (t === "Ana Yemekler") return "ANA YEMEKLER";

    if (t === "Sıcak İçecekler") {
      if (s.toLowerCase().includes("matcha")) return "MATCHA (MAÇA)";
      if (s.toLowerCase().includes("çay")) return "ÇAYLAR";
      if (s.toLowerCase().includes("türk kahvesi")) return "TÜRK KAHVESİ ÇEŞİTLERİ";
      if (s.toLowerCase().includes("espresso")) return "ESPRESSOLU KAHVELER";
      if (s.toLowerCase().includes("filtre") || s.toLowerCase().includes("yöresel kahveler"))
        return "FİLTRE KAHVELER";
      if (s.toLowerCase().includes("yeni nesil")) return "YENİ NESİL KAHVELER";
      if (s.toLowerCase().includes("frappe")) return "FRAPPELER";
      if (s.toLowerCase().includes("salep") || s.toLowerCase().includes("çikolata"))
        return "SAHLEP-SICAK ÇİKOLATA";
      if (n.toLowerCase().includes("salep") || n.toLowerCase().includes("çikolata"))
        return "SAHLEP-SICAK ÇİKOLATA";
      return "SICAK İÇECEKLER";
    }

    if (t === "Soğuk İçecekler") {
      if (s.toLowerCase().includes("soğuk kahve")) return "SOĞUK KAHVELER";
      if (s.toLowerCase().includes("frozen")) return "MEYVELİ FROZENLER";
      if (s.toLowerCase().includes("milkshake")) return "MİLKSHAKELER";
      if (s.toLowerCase().includes("meşrubat")) return "MEŞRUBATLAR";
      if (s.toLowerCase().includes("detoks")) return "DETOKS";
      if (n.toLowerCase().includes("detoks")) return "DETOKS";
      return "SOĞUK İÇECEKLER";
    }

    if (t === "Tatlılar") {
      if (s.toLowerCase().includes("dondurma") || n.toLowerCase().includes("dondurma"))
        return "DONDURMALAR";
      if (s.toLowerCase().includes("waffle") || s.toLowerCase().includes("fondü"))
        return "FONDU-WAFFLE";
      return "PASTA VE KEKLER";
    }

    if (t === "Kokteyller") return "MEŞRUBATLAR";

    if (t === "Hediyelik Ürünler") return "TAKE AWAY";

    return "ANA YEMEKLER";
  }

  const categories = new Map();

  for (const line of lines) {
    if (topLevels.has(line)) {
      currentTop = line;
      currentSub = null;
      continue;
    }

    const match = line.match(/^(.*?)\s+–\s+₺\s*([0-9\.,]+)\s*$/);
    if (match) {
      const name = match[1].trim();
      const price = parsePrice(match[2]);
      if (!name || price == null) continue;

      const categoryName = resolvePosCategory(currentTop, currentSub, name);
      const route = printerRouteByPosCategory.get(categoryName) || "MUTFAK";

      if (!categories.has(categoryName)) {
        categories.set(categoryName, { printer_route: route, items: [] });
      }

      categories.get(categoryName).items.push({
        name,
        price,
      });
      continue;
    }

    currentSub = line;
  }

  const ordered = [];
  for (const catName of posCategoryOrder) {
    if (categories.has(catName)) {
      ordered.push([
        catName,
        categories.get(catName),
      ]);
    }
  }
  for (const entry of categories.entries()) {
    if (!posCategoryOrder.includes(entry[0])) ordered.push(entry);
  }

  return ordered.map(([name, value]) => ({
    name,
    printer_route: value.printer_route,
    items: value.items,
  }));
}

async function buildMenuFromDatabase(client) {
  const { rows } = await client.query(
    `
      SELECT
        c.name AS category_name,
        COALESCE(NULLIF(c.printer_route, ''), 'MUTFAK') AS printer_route,
        p.name AS product_name,
        p.price AS product_price
      FROM categories c
      JOIN products p ON p.category_id = c.id
      WHERE c.is_active = TRUE
        AND p.is_active = TRUE
      ORDER BY c.sort_order ASC, c.name ASC, p.name ASC
    `
  );

  if (!rows.length) return [];

  const categories = new Map();
  for (const row of rows) {
    const categoryName = String(row.category_name || "").trim();
    const productName = String(row.product_name || "").trim();
    const price = Number(row.product_price || 0);
    if (!categoryName || !productName) continue;

    if (!categories.has(categoryName)) {
      categories.set(categoryName, {
        name: categoryName,
        printer_route: String(row.printer_route || "MUTFAK"),
        items: [],
      });
    }

    categories.get(categoryName).items.push({
      name: productName,
      price: Math.round(price * 100) / 100,
    });
  }

  return [...categories.values()].filter((c) => c.items.length > 0);
}

async function run() {
  const client = await db.pool.connect();

  try {
    await client.query("BEGIN");
    const liveMenu = await buildMenuFromDatabase(client);
    const menu = liveMenu.length > 0 ? liveMenu : buildMenuFromText(MENU_TEXT);

    if (liveMenu.length > 0) {
      console.log(
        `Canli menu bulundu, guncel urunler kullaniliyor. Kategori: ${liveMenu.length}`
      );
    } else {
      console.log("Canli menu bulunamadi, MENU_TEXT fallback kullaniliyor.");
    }

    await client.query(`UPDATE products SET is_active = FALSE, updated_at = NOW();`);
    await client.query(`UPDATE categories SET is_active = FALSE, updated_at = NOW();`);

    const categoryIdByName = new Map();

    for (let i = 0; i < menu.length; i++) {
      const category = menu[i];
      const sortOrder = i + 1;

      const { rows } = await client.query(
        `
          INSERT INTO categories (name, printer_route, sort_order, is_active)
          VALUES ($1, $2, $3, TRUE)
          ON CONFLICT (name)
          DO UPDATE SET
            printer_route = EXCLUDED.printer_route,
            sort_order = EXCLUDED.sort_order,
            is_active = TRUE,
            updated_at = NOW()
          RETURNING id
        `,
        [category.name, category.printer_route, sortOrder]
      );
      categoryIdByName.set(category.name, rows[0].id);
    }

    let totalProducts = 0;
    for (const category of menu) {
      const categoryId = categoryIdByName.get(category.name);
      for (const item of category.items) {
        totalProducts += 1;
        await client.query(
          `
            INSERT INTO products (
              category_id,
              category,
              name,
              sku,
              price,
              vat_rate,
              is_active
            )
            VALUES ($1, $2, $3, NULL, $4, 10.00, TRUE)
            ON CONFLICT (category_id, name)
            DO UPDATE SET
              category = EXCLUDED.category,
              price = EXCLUDED.price,
              vat_rate = EXCLUDED.vat_rate,
              is_active = TRUE,
              updated_at = NOW()
          `,
          [categoryId, category.name, item.name, item.price]
        );
      }
    }

    await client.query("COMMIT");
    console.log("Menü senkronize edildi.");
    console.log(`Kategori: ${menu.length}`);
    console.log(`Ürün: ${totalProducts}`);
  } catch (error) {
    await client.query("ROLLBACK");
    console.error("seed-demo failed:", error);
    process.exitCode = 1;
  } finally {
    client.release();
    await db.pool.end();
  }
}

run();
