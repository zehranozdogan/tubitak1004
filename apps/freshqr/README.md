# FreshQR (Flutter)

`apps/consumer` (Flet/Python) UX prototipinin Flutter portu — gerçek ürün
uygulaması. Prototip **BAĞLAYICI DEĞİLDİ** (bkz. `apps/consumer/README.md`);
burası onun yerini alacak gerçek Flutter kod tabanı.

## Yaklaşım: UI-first

23 Eylül'de netleşen karar: ekranlar **önce arayüz olarak** (mock veriyle)
inşa edilip sonra fonksiyonellik (kamera, gerçek `analyzeFrame()`, dosya
okuma) eklenecek — Python prototipindeki `user_view.py`'nin zaten yaptığı
gibi (mock `ColorEngineResult` senaryolarıyla sonuç ekranının tüm dallarını
kamerasız önizleme).

Tasarım tokenleri `packages/ui_kit/theme.py` + `components.py`'den birebir
alındı (seed rengi `#00658F`, boşluk/radius/yazı ölçeği, kart/buton
biçimleri) — iki prototip görsel olarak tutarlı.

## Ekranlar (durum)

| Ekran | Python karşılığı | Durum |
|---|---|---|
| Giriş | `login_view.py` | Tamamlandı |
| Kullanıcı (tara/sonuç) | `user_view.py` | Tamamlandı — TÜM dallar (taze/geçiş/bozuk/düşük kalite/izin yok/geçersiz QR) mock `ColorEngineResult` ile |
| Yönetici (etiket oluştur) | `admin_view.py` | Tamamlandı (zehra) — form, canlı önizleme, gerçek export (yerel depolama) |
| Etiketler / Etiket detay | `labels_view.py` / `label_detail_view.py` | Tamamlandı — liste, detay, silme (Yönetici AppBar ikonundan) |

## Mock veri neden GERÇEK tip kullanıyor

`lib/screens/user/mock_results.dart`'taki mock sonuçlar `color_engine`
paketinin GERÇEK `ColorEngineResult` tipini kullanır (kendi ad-hoc modeli
DEĞİL) — Python `user_view.py`'deki `_MOCK_OK`/`_MOCK_FRESH`/... de aynı
ilkeyle gerçek `ColorEngineResult` dataclass'ını kullanıyordu. Kamera
entegrasyonu geldiğinde SADECE bu sabit değerlerin yerini `analyzeFrame()`
çağrısı alacak — tip, ekranlar, akış DEĞİŞMEYECEK.

## §7.2 kuralı (kritik, korunuyor)

- `rescanRecommended` ise sınıf/seviye GÖSTERİLMEZ, "Yeniden Tara" gösterilir.
- `freshnessClass` yoksa (bilimsel eşik tanımlı değilse) "Taze/Geçiş/Bozuk"
  UYDURULMAZ, `technicalLevel` gösterilir.

Bkz. `test/user_screen_test.dart` — "Düşük kalite" senaryosunda TAZE/BOZUK
metinlerinin EKRANDA OLMADIĞI ayrıca test ediliyor.

## Doğrulama

`flutter analyze` (0 uyarı), `flutter test` (52/52), `flutter build web` VE
`flutter build apk --debug` gerçekten derlendi. `zxing2` (25 Eylül'de
eklendi, aşağıya bkz.) SAF DART olduğu için bu app hâlâ hiçbir platformda
yerel derleme (CMake/NDK) gerektirmiyor — `flutter run -d chrome` de
sorunsuz çalışmalı.

## Cihazdan fotoğraf yükleme (25 Eylül)

"Tazelik Tara"nın altındaki "Cihazdan Fotoğraf Yükle" düğmesi — galeriden/
dosyadan seçilen bir görseli aynı GERÇEK zincirden (`services/
static_image_scan.dart`) geçirir. Canlı kameranın aksine **tüm
platformlarda çalışır** (`image_picker`: Android/iOS/web tam, Windows/
macOS/Linux `file_selector` üzerinden — galeri seçimi için yeterli, kamera
KAYNAĞI kullanılmıyor) — Windows'ta bile GERÇEK bir fotoğrafla test
edilebilir, tek kamerasız-olmayan gerçek doğrulama yolu budur.

İki decoder (ML Kit dosya yolundan + zxing2 yedek) aynı canlı kamera
mantığıyla dener. EXIF döndürme elle uygulanıyor (`img.bakeOrientation` —
`package:image`'in `decodeImage`'i bunu OTOMATİK yapmıyor, elle
doğrulandı). Test: `test/static_image_scan_test.dart` — gerçek PNG
dosyasından uçtan uca (ML Kit'siz ortamda zxing2 yolu dahil, bozuk/kısa
dosyalarda çökmeme dahil).

**Test yazarken bulunan bir gerçek: `flutter test`, host işletim sistemi
ne olursa olsun `defaultTargetPlatform`'u Android'e sabitliyor** —
`cameraScanSupported` gibi platform kontrolleri test ortamında YANILTICI
olabilir; testler `debugDefaultTargetPlatformOverride` ile bunu elle
geçersiz kılmalı (bkz. dosyanın kendi başlığı).

## Son okumalar: GERÇEK geçmiş (25 Eylül)

Python prototipindeki `_MOCK_RECENT_READS` (sabit örnek veri) kaldırıldı —
`data/scan_history.dart` bu cihazda YAPILMIŞ gerçek okumaları yerel bir
JSON dosyasında tutuyor (`getApplicationDocumentsDirectory()/scan_history.json`,
en fazla 30 kayıt, yeniden eskiye). SADECE tamamlanmış okumalar (kamera VE
"Dosyadan test et") kaydediliyor; "Test senaryoları" (mock düğmeleri) VE
"Yeniden tara" ile biten yarım taramalar BİLİNÇLİ OLARAK kaydedilmiyor —
gerçek olmayan/yarım bir sonucu "geçmiş" gibi göstermek dürüst değil.
`freshnessClass` yoksa (§7.2) satırda sınıf rozeti değil `technicalLevel`
gösterilir.

**Test yazarken öğrenilen gerçek ders:** `Directory.createTemp`/dosya
okuma gibi GERÇEK G/Ç çağrıları `testWidgets` gövdesinin içine DOĞRUDAN
yazılırsa (ne `setUp`'ta ne `tester.runAsync()` içinde) test SONSUZA
TAKILIYOR (`flutter_test`'in FakeAsync bölgesi gerçek I/O'nun tamamlanma
sinyalini asla görmüyor) — hatayı yeniden üretmeden önce bilinmiyordu,
bkz. `test/user_scan_history_widget_test.dart` başlığı. Aynı sırada bir
render hatası da bulundu: `Flexible`, kendisini saran Row'a `Expanded`/
`Flexible` ile bounded genişlik verilmeden kullanılamıyor — `_recentReadRow`
düzeltildi.

## Decoder: ML Kit + zxing2 (rapor §11: "en az iki decoder")

`camera_scanner.dart` İKİ decoder kullanıyor:

1. **ML Kit** (`google_mlkit_barcode_scanning`) — birincil, hızlı/donanım
   hızlandırmalı, SADECE Android/iOS.
2. **zxing2** (saf Dart ZXing portu, `packages_dart/qr_layout/lib/src/
   decode.dart`) — ML Kit ardışık ~1.5sn QR bulamazsa (`_fallbackAfterFailures`)
   AYNI karede ayrıca denenir. Dart'ın kendi ürettiği 24 etikette (3 durum
   × 8 parti no) DOĞRULANDI: temiz görüntüde 36/36, küçültülmüş+bulanık
   görüntüde kademeli (ama sert değil) bozulma. `flutter_zxing` (C++ FFI,
   yerel derleme gerektirir) yerine bu seçildi — kurulum riski yok.

zxing2 sadece finder pattern MERKEZLERİNİ verir, QR'ın gerçek dış
köşelerini değil — `estimateOuterCorners` bunu `matrixSize` bilinince
(payload çözülüp layout yeniden türetilince) kestirir. Bu kestirim
**eksen-hizalı (perspektifsiz) sentetik testte TAM köşelerle eşleşiyor**
(bkz. `qr_layout/test/decode_test.dart`) VE **uçtan uca doğrulandı**:
zxing2+kestirim yoluyla üretilen tazelik sonucu, ML Kit'in gerçek 4
köşesiyle üretilenle AYNI (bkz. `test/scan_service_test.dart`, "zxing2
yedek decoder yolu"). **Gerçek kamera açısı/perspektifi altında henüz
doğrulanmadı** — bu extrapolasyon sadece AFİN (döndürme/öteleme/hafif
eğiklik) durumda kesin doğru.

## Kamera testi (gerçek cihaz — HENÜZ YAPILMADI)

`camera_scanner.dart` yazıldı ve APK olarak DERLENİYOR; gerçek bir
telefonda denenmedi (USB kablosu yok). Saf parçalar test edildi
(`frame_convert`: NV21/BGRA -> RGB + döndürme; `qr_layout/decode.dart`:
zxing2 + köşe kestirimi). Cihazda doğrulanması gerekenler:

- ML Kit köşe noktalarının koordinat sistemi: kodda "döndürülmüş (dik)
  görüntü" varsayıldı ve kare buna göre döndürülüyor. Yanlışsa sonuç
  garip çıkar (köşe/kare uyumsuzluğu).
- Köşe sırası (sol-üst, sağ-üst, sağ-alt, sol-alt) `analyzeFrame` ile uyumlu mu.
- zxing2 köşe kestiriminin GERÇEK perspektif altında ne kadar doğru olduğu.
- `ResolutionPreset.high` renk okuması için yeterli mi, kare dönüşümü hızı
  (ML Kit + zxing2 ikisi devredeyken).
- Etiketin bu app'te üretilmiş olması gerek (paketli profil/tarif, karar 24 Eylül).

Başka platformlarda (web, Windows) "Tazelik Tara" mock sonuç gösterir.

## Çalıştırma

```
cd apps/freshqr
flutter run -d chrome   # ya da bir Android/iOS cihaz/emülatör
```
