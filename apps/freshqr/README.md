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

`flutter analyze` (0 uyarı), `flutter test` (40/40), `flutter build web` VE
`flutter build apk --debug` gerçekten derlendi. `zxing2` (25 Eylül'de
eklendi, aşağıya bkz.) SAF DART olduğu için bu app hâlâ hiçbir platformda
yerel derleme (CMake/NDK) gerektirmiyor — `flutter run -d chrome` de
sorunsuz çalışmalı.

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
