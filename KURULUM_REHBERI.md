# NexPOS - Başka Bilgisayara Kurulum ve Çalıştırma Rehberi

Bu proje, hem **Flutter Windows Frontend** (Arayüz) hem de **Node.js Backend & PostgreSQL Veritabanı** yapısını tek bir kurulum paketinde birleştirir.

---

## 🚀 1. Hazırlık (hedef bilgisayarda 1 defa yapılır)

Hedef bilgisayarda uygulamanın çalışabilmesi için sadece **PostgreSQL** veritabanının yüklü olması yeterlidir:

1. [PostgreSQL İndir](https://www.postgresql.org/download/windows/) (Örn: PostgreSQL 15 veya 16).
2. Kurulum yaparken veritabanı `postgres` kullanıcısı şifresini belirleyin (Varsayılan şifre önerisi: `postgres` veya projenizin `.env` şifresi).
3. Port olarak varsayılan `5432` portunu bırakın.

---

## 📦 2. Kurulum (NexPOS-Setup.exe)

1. Proje klasöründe üretilen **`NexPOS-Setup.exe`** dosyasını hedef bilgisayara kopyalayın ve çalıştırın.
2. Kurulum sihirbazını takip edin (Varsayılan hedef: `C:\Program Files\NexPOS`).
3. Masaüstü kısayolları otomatik oluşturulacaktır:
   - **`NexPOS`** (Ana Arayüz)
   - **`NexPOS Backend Servisi`** (Backend Sunucusu & Veritabanı Başlatıcı)

---

## ⚡ 3. İlk Çalıştırma & Veritabanı Otomatik Kurulumu

1. Masaüstündeki **"NexPOS Backend Servisi"** kısayolunu bir kez çalıştırın.
   - Bu servis, PostgreSQL üzerinde `adisyon_db` veritabanını, tüm tabloları, kısıtlamaları ve varsayılan kullanıcıları **otomatik** oluşturur.
2. Ardından masaüstündeki **"NexPOS"** uygulamasına çift tıklayın.

---

## 🔑 Varsayılan Giriş Bilgileri

* **Admin Kullanıcı PIN**: `062362`
* **Garson Kullanıcı PIN**: `122323`

---

## 🗄️ Manuel SQL Şeması (İsteğe Bağlı)

Eğer veritabanını pgAdmin veya psql ile manuel kurmak isterseniz:
* Kurulum dizinindeki `backend\schema.sql` dosyasını `adisyon_db` içerisine içe aktarabilirsiniz (Import).
