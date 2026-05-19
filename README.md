# VAS Platform

GSM operatörü için katma değerli servis (VAS) yönetim platformu. Abonelik ve tek seferlik servis işlemleri, işlem günlüğü (audit) ve raporlama Oracle veritabanında PL/SQL ile; web arayüzü Next.js ile geliştirilmiştir.

## Gereksinimler

- Oracle Database 21c (XE veya tam sürüm)
- SQL Developer veya SQL\*Plus
- Node.js 18 veya üzeri
- npm

## Proje yapısı

```
├── database/
│   ├── 01_schema.sql      # Tablolar ve sequence'ler
│   ├── 02_packages.sql    # PL/SQL paketleri (iş kuralları, raporlar)
│   └── 03_seed_data.sql   # Örnek kullanıcı, abone ve servis verileri
└── frontend/              # Next.js 14 uygulaması
    ├── .env.example       # Ortam değişkeni şablonu
    └── src/               # Arayüz ve API route'ları
```

## Veritabanı kurulumu

Oracle hesabınızla SQL Developer üzerinden bağlanın. Scriptleri **sırayla** çalıştırın:

| Sıra | Dosya | Açıklama |
|------|--------|----------|
| 1 | `database/01_schema.sql` | Tablolar, indeksler, kısıtlar |
| 2 | `database/02_packages.sql` | `pkg_vas_core`, `pkg_vas_audit`, `pkg_vas_reports` |
| 3 | `database/03_seed_data.sql` | Demo veriler (isteğe bağlı) |

> Tablolar zaten mevcutsa yalnızca paket güncellemesi için `02_packages.sql` çalıştırın. `01_schema.sql` ve `03_seed_data.sql` tekrar çalıştırmak veri çakışmasına yol açabilir.

## Web uygulaması kurulumu

### 1. Bağımlılıklar

```bash
cd frontend
npm install
```

### 2. Ortam dosyası

```bash
copy .env.example .env
```

`.env` dosyasını kendi Oracle bağlantı bilgilerinize göre düzenleyin:

| Değişken | Açıklama |
|----------|----------|
| `ORACLE_USER` | Oracle kullanıcı adı |
| `ORACLE_PASSWORD` | Şifre |
| `ORACLE_CONNECT_STRING` | TNS veya Easy Connect adresi |
| `ORACLE_TNS_ADMIN` | `tnsnames.ora` klasör yolu (gerekirse) |

### 3. Çalıştırma

Oracle servisinin çalıştığından emin olun, ardından:

```bash
npm run dev
```

Tarayıcı: [http://localhost:3000](http://localhost:3000)

### 4. Demo giriş (seed verisi yüklüyse)

| Kullanıcı | Şifre |
|-----------|--------|
| `admin` | `admin123` |
| `operator` | `operator123` |

## Özellikler

- Abonelik aktif etme / iptal (aynı serviste tekrar abonelik engeli)
- Tek seferlik satın alma
- Bakiye yükleme
- İşlem günlüğü (tarih filtresi, log seviyesi, IP, response code)
- Raporlar: ciro (24 saat / hafta / ay), aktif abonelikler, en çok satan servisler, mesai günü satış performansı

## VS Code ile çalıştırma

1. `frontend` klasörünü VS Code ile açın.
2. Terminalde `npm install` (ilk sefer).
3. `.env` oluşturup düzenleyin.
4. `npm run dev` komutunu çalıştırın.

## Üretim derlemesi (isteğe bağlı)

```bash
cd frontend
npm run build
npm start
```

## Sorun giderme

| Sorun | Öneri |
|-------|--------|
| Oracle bağlantı hatası | Listener ve servis adını (`XE`) kontrol edin; `.env` değerlerini doğrulayın |
| Paket hatası (PLS/ORA) | `02_packages.sql` dosyasını yeniden derleyin |
| Boş raporlar | `pkg_vas_reports` paketinin hatasız derlendiğini kontrol edin |
| Port meşgul | `npm run dev -- -p 3001` ile farklı port kullanın |

