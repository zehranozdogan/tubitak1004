# QR Kod Tabanlı Akıllı Tazelik Sensörü

Balık ambalajında bozulmayla ilişkili uçucu aminler ve pH değişimi nedeniyle renk
değiştiren **kolorimetrik sensör yüzeyi + QR** etiketini standart bir telefon
kamerasıyla okuyup renk değişimini **nicel** ölçen ve kullanıcıya anlaşılır bir
tazelik sonucu (yoksa teknik renk seviyesi) veren **uçtan uca** prototip.

> Yapı ve kararlar **Öğrenci Teknik Devir Raporu**'na (10 Eylül 2026) göredir.
> Bu, eski uygulamanın devamı değildir — temiz repo, sıfırdan sistem (§2).

## Yapı (Rapor §3.2)

```
apps/
  consumer/     Flet-web PROTOTİPİ (bağlayıcı değil) — UX'i localhost'ta
                önizlemek için; gerçek uygulama apps/freshqr'dır (§0002).
  freshqr/      GERÇEK tüketici + üretici uygulaması (Flutter). Login →
                Yönetici (etiket oluştur/yönet) / Kullanıcı (tara/sonuç).
packages/       Python motoru (asıl geliştirme + doğrulama burada yapılır)
  qr_layout/        Standart QR + fonksiyon maskesi + DAĞITILMIŞ reaktif modül (§5)
  color_engine/     Homografi + kalibrasyon (A-E) + ROI + Lab/ΔE + profil eşleştirme (§6)
  profile_schema/   sensor_profile / layout_version / label_payload JSON şemaları (§6.3, §10.1)
  label_export/     Etiket paketi üretimi (PNG/PDF/JSON + sentetik durumlar, §8)
  ui_kit/           Flet prototipi için ortak tasarım sistemi
packages_dart/  packages/'in Flutter için Dart portu — HER paketin gerçek
                Python çıktılarıyla (piksel/matris/ΔE bazında) karşılaştırmalı
                doğrulandığı ayrı bir katman, elle çevrilmiş TAHMİN değil.
  qr_layout/ color_engine/ profile_schema/ label_export/
tests/
  synthetic/    QR / şema / motor birim testleri (§11 Aşama A çekirdeği)
  device/       Telefon / ışık / mesafe / açı test protokolü + gerçek test
                sonuçları (results_*.md, §11 Aşama B)
docs/           Mimari, veri sözleşmesi, ekip planı, kararlar (docs/decisions/)
```

**Ortak motor kuralı:** koordinat / eşik / kalibrasyon parametreleri koda gömülmez;
`packages/profile_schema` dosyalarından (Flutter'da `apps/freshqr/assets/reference/`
altında paketlenmiş kopyalarından, §0005/§0006) okunur. Okuyucu koordinat
hard-code etmez (§10.2) — reaktif hücreleri QR'dan çözdüğü payload'tan aynı
algoritmayla yeniden türetir.

## Kurulum

### Python motoru + testler

```bash
python3 -m venv .venv && source .venv/bin/activate    # Windows: .venv\Scripts\activate
pip install -r requirements.txt

pytest                                # tests/synthetic — 133/133
flet run -w apps/consumer/main.py     # Flet PROTOTİPİ (bağlayıcı değil), tarayıcıda açılır
```

### Flutter uygulaması (`apps/freshqr`) — asıl ürün

```bash
cd apps/freshqr
flutter pub get
flutter test                          # 52/52
flutter run -d chrome                 # web'de hızlı önizleme (kamera çalışmaz)
flutter run                           # bağlı bir Android cihaz/emülatörde (kamera dahil tam işlevsel)
```

Dart motor paketlerini (`packages_dart/*`) tek başına test etmek için:

```bash
cd packages_dart/<paket> && dart pub get && dart test
```

## İş bölümü (Rapor §9)

| | Klasör |
|---|---|
| **Öğrenci 1** (teknik lider) | `apps/consumer`, `packages/qr_layout`, `packages/profile_schema`, `packages/label_export`, entegrasyon |
| **Öğrenci 2** (algoritma/doğrulama) | `packages/color_engine`, `tests/device`, kalibrasyon benchmark |
| **Ortak** (iki onay) | `packages/qr_layout/reactive.py`, `packages/ui_kit`, `tests/synthetic`, `docs/`, `pyproject.toml`, `apps/freshqr`, `packages_dart/*` |

Detay: [docs/team.md](docs/team.md) · Git akışı: `main` korumalı, `zehra`/`devrim`
branch'lerinden PR/merge.

## Şu an ne çalışıyor

**Python motoru — tamamlandı:**
- `packages/qr_layout`: QR üretimi, ISO/IEC 18004 fonksiyon maskesi, mekânsal
  dağıtılmış reaktif modül seçimi, kasıtlı-hata mekanizması, kenar referans
  yamaları (§6.1 B/C), basılabilir PNG/PDF render
- `packages/color_engine`: homografi, kalibrasyon (A/B/C/E uygulandı), ROI
  örnekleme, Lab/ΔE eşleştirme, kalite skoru, modül-tutarlılığı confidence
  formülü — uçtan uca gerçek fotoğraflarla test edildi
- `packages/profile_schema`, `packages/label_export`: tam
- `tests/synthetic`: 133/133 · `tests/device`: gerçek KAĞIT baskı testi
  sonuçları (`results_2026-09-22.md`) — bkz. [0004](docs/decisions/0004-calibration-method-choice.md)

**Dart portu (`packages_dart/*`) — tamamlandı:** dört paket de gerçek Python
çıktılarıyla (piksel/matris/ΔE) karşılaştırmalı doğrulandı, homografi dahil
`opencv_dart` gibi bir kütüphaneye gerek duymadan elle port edildi.

**`apps/freshqr` (Flutter, gerçek uygulama):**
- Giriş, Yönetici (form → canlı önizleme → gerçek export: PNG/PDF/JSON +
  sentetik taze/geçiş/bozuk + Paylaş/Yazdır + Galeriye kaydet), Etiketler
  listesi/detay/silme — tamamlandı
- Kullanıcı: canlı kamera + ML Kit (yedek decoder: zxing2) taraması
  (Android/iOS), "Cihazdan Fotoğraf Yükle" (kamerasız, tüm platformlar),
  gerçek okuma zinciri (paketli referans veri + layout yeniden türetme,
  §0006), gerçek "Son okumalar" geçmişi — tamamlandı
- `flutter test`: 52/52 · `flutter analyze`: 0 uyarı · web + Android APK
  gerçekten derlendi, gerçek Android emülatöründe çalıştırıldı

## Açık kararlar

- **Kalibrasyon yöntemi (A/B/C)**: gerçek kağıt baskı testleriyle
  karşılaştırılıyor, henüz kesinleşmedi — bkz.
  [0004](docs/decisions/0004-calibration-method-choice.md)
- **Tazelik eşikleri**: bilimsel ground-truth (TVB-N/duyusal panel) henüz yok
  → `class_thresholds: null`, `freshness_class` üretilmiyor, sadece
  `technical_level` gösteriliyor (§7.2)
- **Gerçek fiziksel mürekkep/baskı**: henüz simülasyon (sentetik taze/geçiş/
  bozuk renkleri) — gerçek pigment reaksiyonu kimya tarafının kapsamında
- **Veri dağıtımı**: DB YOK, statik/paketli veri + okuyucunun layout'u
  yeniden türetmesi — bkz. [0005](docs/decisions/0005-statik-veri-db-yok.md),
  [0006](docs/decisions/0006-okuyucu-layout-yeniden-turetme.md)
- **Motor mimarisi (Flutter)**: tam Dart port (Chaquopy/opencv_dart
  KULLANILMADI) — bkz. [0002](docs/decisions/0002-framework-spike.md),
  `packages_dart/*/README.md`

## Kapsam dışı (§13)

Kullanıcı hesabı / login, bulut veritabanı, ERP, çoklu fabrika, mağaza paneli,
blockchain, ödeme, app-store yayını.

## Kaynaklar

Onaylı proje dosyası: *Su Ürünlerinin Tazeliğinin Takibine Yönelik QR Kod Tabanlı
Akıllı Ambalaj Etiketi Geliştirilmesi* (TÜBİTAK 1004). Ayrıca Benito-Altamirano ve
ark. (2023/2024) back-compatible color QR çalışmaları; ColorSensing yaklaşımı.
