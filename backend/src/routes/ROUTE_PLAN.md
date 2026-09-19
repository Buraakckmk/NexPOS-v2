# RBAC API Route Plani (MVP)

Bu plan, restoran operasyon akisini role gore ayirir.

## Auth

- `POST /api/auth/login/pin`
  - Amac: 6 haneli PIN ile giris ve JWT alma.
  - Erisim: Her aktif kullanici.
- `GET /api/auth/me`
  - Amac: Token icindeki aktif kullanici bilgisini dondurme.
  - Erisim: Tum roller (token gerekli).

## Owner (rol_id: 1)

- `GET /api/owner/reports`
  - Ciro, gelir-gider, tarihsel raporlar.
- `POST /api/owner/users`
  - Personel ekleme (rol/pin atama).
- `PATCH /api/owner/menu/prices`
  - Toplu fiyat degisikligi.
- `POST /api/owner/system/backup`
  - Yedek alma.
- `POST /api/owner/system/reset`
  - Kritik sifirlama islemleri.

## Manager (rol_id: 2) + Owner

- `GET /api/manager/operations`
  - Gunluk operasyon paneli.
- `PATCH /api/orders/:orderId/cancel`
  - Garsonun duzeltemedigi siparis iptali.
- `PATCH /api/orders/:orderId/discount`
  - Iskonto uygulama.
- `POST /api/payments/close-table`
  - Masayi odeme ile kapatma.
- `POST /api/reports/z-report`
  - Gun sonu Z raporu.

## Waiter (rol_id: 3) + Manager + Owner

- `GET /api/waiter/tables`
  - Masa listesi ve durumlari.
- `POST /api/waiter/orders`
  - Body: `{ "table_id": 1, "items": [{ "product_id": 3, "quantity": 2 }] }`
  - Ayni masada OPEN/CONFIRMED siparis varsa kalemler eklenir; masa listesinde OCCUPIED.
  - CONFIRMED siparise ekleme yapilirsa tekrar mutfaga gonderebilmek icin siparis OPEN yapilir.
- `POST /api/waiter/orders/:orderId/confirm`
  - PENDING kalemleri SENT yapar, siparisi CONFIRMED yapar.
  - Socket: `new-order` (masa adi + bu turdaki urunler).
  - Konsol: `printer.service` MVP ciktisi.

## Socket Olaylari

- `order:confirm` (client -> server, opsiyonel)
  - Geriye donuk; sunucu `new-order` yayinlar.
- `new-order` (server -> tum bagli istemciler)
  - HTTP onay sonrasi ana mutfak sinyali.

## Yazici Entegrasyonu (Sonraki adim)

- `src/services/printer.service.js` altinda ESC/POS TCP (IP:9100) gonderimi.
- Akis: siparis DB commit -> printer servis cagrisi -> socket broadcast.
