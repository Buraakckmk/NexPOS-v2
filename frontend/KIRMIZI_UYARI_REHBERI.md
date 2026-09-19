# Kırmızı Uyarı Rehberi

Bu doküman, uygulamada görülen kırmızı uyarıların hangi durumlarda çıktığını, teknik olarak hangi katmandan geldiğini ve özellikle `Çıkış` sonrası login ekranında neden görülebildiğini açıklar.

## 1. Kırmızı uyarı tipleri

Uygulamada kırmızı uyarılar temelde 3 ana kaynaktan gelir:

1. Global uygulama hataları
2. Ağ / backend / API hataları
3. Ekran bazlı iş kuralı veya form doğrulama hataları

Bu uyarıların çoğu `SnackBar` olarak gösterilir.

## 2. Global kırmızı uyarılar

Bu grup, tek bir ekrana ait olmayan, framework veya uygulama altyapısı seviyesindeki hatalardır.

### 2.1 `Uygulamada beklenmeyen bir hata oluştu. Lütfen tekrar deneyin.`

Kaynak:

- `frontend/lib/main.dart`
- `FlutterError.onError`

Bu mesaj şu tür durumlarda çıkar:

- Bir widget build edilirken exception fırlarsa
- Layout hesaplamasında hata olursa
- Render sırasında hata olursa
- `RenderFlex overflowed` gibi Flutter UI hataları oluşursa
- Geçersiz widget ağacı veya build sırasında çöken bir bileşen varsa

Bu, senin son ekrandaki kırmızı uyarına doğrudan uyan mesajdır.

### 2.2 `Bağlantı veya sistem hatası oluştu. Lütfen tekrar deneyin.`

Kaynak:

- `frontend/lib/main.dart`
- `PlatformDispatcher.instance.onError`

Bu mesaj şu tür durumlarda çıkar:

- Yakalanmamış async exception oluşursa
- Platform kanalı / plugin tarafında hata olursa
- Arka planda çalışan servislerden biri patlarsa
- Flutter framework dışına taşan runtime hata oluşursa

Geçmişte bu mesajın bir örnek sebebi şuydu:

- Windows üzerinde `sqflite` için `databaseFactory` initialize edilmemişti
- Sonuç: `Bad state: databaseFactory not initialized`
- Bu da global kırmızı uyarı üretmişti

### 2.3 `Beklenmeyen bir hata oluştu. İşlem güvenli şekilde durduruldu.`

Kaynak:

- `frontend/lib/main.dart`
- `runZonedGuarded`

Bu mesaj şu durumlarda çıkar:

- Uygulama ana zone içinde yakalanmamış bir exception atarsa
- Bir async zincirde hata yukarı kadar kaçarsa

Bu mesaj, `FlutterError.onError` ve `PlatformDispatcher.onError` dışında kalan yakalanmamış hatalar için son güvenlik katmanıdır.

## 3. Çıkış butonuna basınca login ekranında neden kırmızı uyarı görülebilir?

Senin sorduğun senaryo için en önemli bölüm burasıdır.

### Beklenen akış

`Çıkış` butonu şu akışı çalıştırır:

- Token temizlenir
- Kullanıcı state'i sıfırlanır
- Ekran `LoginScreen`'e döner

Kaynaklar:

- `frontend/lib/providers/auth_provider.dart`
- `frontend/lib/screens/pos_order_screen.dart`

### Kırmızı uyarının gerçek sebebi ne olur?

`Çıkış` işleminin kendisi normalde kırmızı uyarı üretmez.

Kırmızı uyarı, çoğu zaman login ekranı yeniden açıldığında login ekranının kendi UI yapısında bir hata oluştuğu için görünür.

Örnekler:

- Login ekranında `bottom overflow`
- Sabit yükseklikli layout'un küçük pencereye sığmaması
- PIN tuş takımının build sırasında taşma üretmesi
- Login ekranına dönülürken render/layout hatası oluşması

Bu durumda çalışan mekanizma şudur:

1. `Logout` başarılı şekilde çalışır
2. `LoginScreen` açılır
3. Login ekranı çizilirken Flutter bir render/layout exception üretir
4. `FlutterError.onError` devreye girer
5. Kırmızı snackbar görünür: `Uygulamada beklenmeyen bir hata oluştu. Lütfen tekrar deneyin.`

Yani burada sorun çoğunlukla `logout` fonksiyonu değil, `login ekranına dönüş sonrası UI hata üretmesi` olur.

## 4. Ağ ve backend kaynaklı kırmızı uyarılar

Kaynak:

- `frontend/lib/services/api_client.dart`
- `frontend/lib/services/auth_service.dart`
- bazı ekranlarda yerel `ScaffoldMessenger` kullanımı

### 4.1 Global ağ hataları

`ApiClient` içindeki interceptor, birçok ağ hatasında otomatik olarak global kırmızı uyarı gösterir.

Örnek mesajlar:

- `Bağlantı zaman aşımına uğradı. Lütfen tekrar deneyin.`
- `Sunucuya bağlanılamadı, IP'yi kontrol edin ve kasa backend'inin açık olduğundan emin olun.`
- `Sunucu isteği işleyemedi. Lütfen tekrar deneyin.`
- `İstek iptal edildi.`
- `Beklenmeyen bir ağ hatası oluştu.`

Bu mesajlar şu durumlarda çıkar:

- Backend kapalıysa
- Yanlış IP veya port kullanılıyorsa
- Sunucu cevap vermiyorsa
- API 4xx/5xx hatası dönüyorsa
- İstek ağ katmanında başarısız oluyorsa

### 4.2 Login ekranındaki kırmızı uyarılar

Kaynak:

- `frontend/lib/services/auth_service.dart`
- `frontend/lib/providers/auth_provider.dart`
- `frontend/lib/screens/login_screen.dart`

Login sırasında kırmızı snackbar şu durumlarda çıkabilir:

- Hatalı PIN
- Pasif kullanıcı
- Backend'e ulaşılamaması
- Timeout
- API'nin beklenmeyen cevap dönmesi
- Token dönmemesi
- User objesinde eksik veri olması

Örnek mesajlar:

- `Gecersiz PIN veya pasif kullanici.`
- `Sunucuya bağlanılamadı, IP'yi kontrol edin. API adresi: ...`
- `Sunucuya zamaninda ulasilamadi. API adresi: ...`
- `Giris istegi basarisiz. HTTP ...`
- `Token alinamadi.`
- `Kullanici bilgisi eksik. Giriş tamamlanamadı.`

Not:

- `loginWithPin` isteğinde `showGlobalError: false` kullanılıyor
- Bu yüzden login hataları çoğunlukla doğrudan login ekranında yerel snackbar olarak gösterilir
- Yani burada kırmızı uyarı kaynağı global ağ interceptor değil, `AuthProvider -> errorMessage -> LoginScreen SnackBar` zinciridir

## 5. Ekran bazlı kırmızı uyarılar

Bu grup, kullanıcının yanlış işlem yapması veya iş kuralına aykırı bir aksiyon denemesi halinde gösterilir.

### 5.1 Masa yönetimi ekranı örnekleri

Kaynak:

- `frontend/lib/screens/waiter_tables_screen.dart`

Örnek durumlar:

- Özel masa açarken masa adı boş bırakılırsa
- Masa taşıma için yanlış kaynak/hedef masa seçilirse
- Taşıma / birleştirme API isteği başarısız olursa

Örnek mesajlar:

- `Masa adı zorunlu.`
- `Özel masa açılamadı.`
- `Sadece dolu masalar taşınabilir.`
- `Sadece boş masalara transfer yapılabilir.`
- `Transfer başarısız: ...`
- `Birleştirme başarısız: ...`

### 5.2 POS / adisyon ekranı örnekleri

Kaynak:

- `frontend/lib/screens/pos_order_screen.dart`

Örnek durumlar:

- Sipariş yokken masa bilgisi açılmak istenirse
- Sipariş meta bilgisi kaydedilemezse
- Sipariş onaylanamazsa
- Ürün transferi başarısız olursa
- Sipariş notu kaydedilemezse
- Yönetici olmayan kullanıcı ödeme almaya çalışırsa

Örnek mesajlar:

- `Önce masaya en az bir ürün ekleyin.`
- `Masa bilgileri kaydedilemedi.`
- `Sipariş onaylanamadı.`
- `Ürün transfer işlemi başarısız.`
- `Siparis notu kaydedilemedi.`
- `Ödeme işlemi sadece yönetici tarafından yapılabilir.`

Bu tip uyarılar sistem çökmesi anlamına gelmez. Genelde:

- eksik veri
- yetki sorunu
- hatalı işlem sırası
- backend iş kuralı reddi

gibi nedenlerle çıkar.

## 6. Kırmızı uyarıların ekranda görünme şekli

Kaynak:

- `frontend/lib/services/app_feedback_service.dart`

Davranış:

- Kırmızı uyarılar `SnackBar` ile gösterilir
- Arka plan rengi `0xFFB91C1C`
- Aynı mesaj 2 saniye içinde tekrar gelirse spam olmasın diye tekrar gösterilmez
- Yeni mesaj gelirse eski snackbar gizlenip yenisi gösterilir

Bu nedenle bazen aynı hata sürekli tekrar etse bile snackbar her frame'de görünmez; kısa süreli filtreleme vardır.

## 7. Çıkış sonrası görülen kırmızı uyarı için pratik yorumlama

Eğer kullanıcı `Çıkış` butonuna bastıktan sonra login ekranında şu mesajı görüyorsa:

- `Uygulamada beklenmeyen bir hata oluştu. Lütfen tekrar deneyin.`

ilk kontrol edilmesi gerekenler şunlardır:

1. Login ekranında overflow var mı?
2. PIN pad sabit yükseklik nedeniyle taşma üretiyor mu?
3. `FittedBox`, `SizedBox`, `Column` kombinasyonu küçük pencere yüksekliğinde hata veriyor mu?
4. Login ekranına dönerken build sırasında exception oluşuyor mu?

Eğer görülen mesaj şu ise:

- `Bağlantı veya sistem hatası oluştu. Lütfen tekrar deneyin.`

ilk kontrol edilmesi gerekenler şunlardır:

1. Arka planda çalışan servislerden biri exception fırlatıyor mu?
2. Plugin / database / socket / connectivity tarafında hata var mı?
3. Masaüstü platform init kodları eksik mi?

## 8. Özet

Kırmızı uyarı her zaman aynı anlama gelmez.

- `Uygulamada beklenmeyen bir hata oluştu...`
  - çoğunlukla widget/render/layout kaynaklı Flutter hatasıdır
- `Bağlantı veya sistem hatası oluştu...`
  - çoğunlukla platform, plugin veya yakalanmamış async hatadır
- Login ekranındaki kırmızı mesajlar
  - çoğunlukla PIN, backend erişimi veya auth response problemidir
- Masa / sipariş ekranlarındaki kırmızı mesajlar
  - çoğunlukla iş kuralı veya kullanıcı aksiyonu kaynaklıdır

Özellikle `Çıkış` sonrası login ekranında çıkan kırmızı uyarı, çoğu durumda `çıkış işlemi bozuk` anlamına değil, `login ekranı yeniden çizilirken hata oluştu` anlamına gelir.