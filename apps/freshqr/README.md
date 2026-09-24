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

`flutter analyze` (0 uyarı), `flutter test` (12/12), `flutter build web` VE
`flutter build apk --debug` gerçekten derlendi (bu repodaki diğer örneklerin
aksine bu paket CAMERA/ML Kit KULLANMIYOR — sadece UI, bu yüzden bu app
gerçekten `flutter run -d chrome` ile de sorunsuz çalışmalı).

## Sırada ne var

1. Kamera + ML Kit entegrasyonu (kullanıcı ekranındaki "Tazelik Tara"
   butonu şu an mock; gerçek akış `apps/flutter_camera_spike`'ta ayrıca
   doğrulandı) — bağlanınca `_runScan` çağrıları mock yerine gerçek
   `analyzeFrame()` sonucu kullanacak.

## Çalıştırma

```
cd apps/freshqr
flutter run -d chrome   # ya da bir Android/iOS cihaz/emülatör
```
