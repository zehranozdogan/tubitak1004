# color_engine (Dart portu)

`packages/color_engine` (Python) renk motorunun Dart'a taşınmış hâli.
`docs/decisions/0002-framework-spike.md`'de bahsedilen "motor mantığı port
edilir" işi — **22 Eylül itibarıyla TAMAMLANDI** (tüm Python dosyaları
port edildi, 73/73 test geçiyor, `dart analyze` 0 uyarı).

## Ne var (Python dosyasına göre)

- `colorspace.py` -> `lib/src/colorspace.dart` — RGB↔Lab + ΔE (CIEDE2000).
  scikit-image'ın kaynak kodundan birebir kopyalandı (icat edilmedi).
- `calibration.py` -> `lib/src/calibration.dart` — 5 yöntem (A-E, `learned`
  hariç — Python tarafında da uygulanmadı). `multicolor_patch` için
  numpy.linalg.lstsq yerine normal denklemler + Gauss-Jordan (elle
  yazılmış, dış bağımlılık yok) — gerçek Python matrisiyle doğrulandı.
- `homography.py` -> `lib/src/homography.dart` — `getPerspectiveTransform`
  + `warpToCanonical` (geriye-doğru bilinear örnekleme, BORDER_CONSTANT=0).
  `opencv_dart` GEREKMEDİ — cv2'nin algoritması elle port edildi, gerçek
  `cv2` çıktısıyla (ara matris + piksel piksel bilinear sonuç) doğrulandı.
- `roi.py` -> `lib/src/roi.dart` — ROI yama çıkarma + medyan (parlama/gölge
  elenmiş, HER KANAL BAĞIMSIZ medyan — numpy `axis=0` ile aynı).
- `quality.py` -> `lib/src/quality.dart` — gri tonlama (BGR2GRAY ağırlıkları)
  + Laplacian keskinlik (BORDER_REFLECT_101 dahil, gerçek `cv2.Laplacian`
  çıktısıyla piksel piksel doğrulandı) + parlama/parlaklık skorları.
- `matching.py` -> `lib/src/matching.dart` — en yakın scale_point (ΔE),
  §7.2 kritik kuralı (`hasClassThresholds` yoksa `freshnessClass` HER ZAMAN
  null) dahil.
- `pipeline.py` -> `lib/src/pipeline.dart` — hepsini birleştiren
  `analyzeFrame()`. Orkestrasyon mantığı (kalibrasyon düşme sırası, notlar,
  confidence formülü, köşe tutarlılık notu) BİREBİR port edildi.
- `linalg.dart` — küçük, dış bağımlılıksız lineer cebir (Gauss-Jordan),
  `calibration.dart` ve `homography.dart` arasında paylaşılıyor.
- `finder_pattern.dart` — `packages/qr_layout/colors.py`'den SADECE
  `pipeline.dart`'ın ihtiyaç duyduğu küçük alt küme (finder modül
  sabitleri, kenar referans renkleri). qr_layout'un TAMAMI port edilmedi.

## Mimari sapmalar (Python'dan KASITLI, her biri kodda ayrıca belgeli)

1. **BGR/RGB karışıklığı YOK.** Python'da `image` BGR sırasındaydı (cv2
   sözleşmesi) — bu geçmişte gerçek bir hataya yol açmıştı. Bu portta TÜM
   `Rgb`/`RgbImage` HER ZAMAN gerçek RGB'dir; BGR kaynaklı ham kamera
   baytlarını bu pakete vermeden ÖNCE çağıran taraf kanalları değiştirmelidir.
2. **QR tespiti bu paketin işi DEĞİL.** `analyzeFrame`'de `qrCorners`
   ZORUNLU parametredir (Python'daki gibi içeride cv2/pyzbar ile
   decode ETMEZ) — Flutter'da QR tespiti muhtemelen ML Kit ile ayrı bir
   katmanda yapılacak (bkz. `apps/flutter_camera_spike`).
3. `profile_schema` (JSON şema doğrulama) port edilmedi — `SensorProfile`/
   `LayoutVersion` şimdilik sadece pipeline'ın okuduğu alanları taşıyan
   minimal Dart sınıfları.

## Test yöntemi

TÜM referans sayılar **gerçek Python fonksiyonları/cv2 çalıştırılarak**
üretildi (tahmin/uydurma DEĞİL) — kırpma/kesme davranışı dahil (Python
`.astype(uint8)` yuvarlamaz, sıfıra doğru KESER; Dart `.toInt()` ile aynı).
`pipeline_test.dart` ise orkestrasyon mantığını (hangi kalibrasyona
düşülüyor, hangi notlar ekleniyor, §7.2 kuralı) hedefler — alt bileşenler
zaten ayrı ayrı doğrulandığı için gerçek fotoğraf/homografi yerine
`qrCorners = canonicalQrCorners(...)` (kimlik dönüşüm) ile sadeleştirilmiş
bir "zaten canonical" test görüntüsü kullanır.

```
cd packages_dart/color_engine
dart test
dart analyze
```

Kamera spike'ının (`apps/flutter_camera_spike`) aksine bu paket kameraya/
cihaza İHTİYAÇ DUYMAZ — saf Dart, her ortamda (Windows/Linux/macOS/web/
mobil) çalışır.

## Sırada ne var

- `packages/qr_layout`'un TAMAMININ portu (QR üretimi, reaktif hücre
  yerleşimi) — şu an sadece `finder_pattern.dart`'taki küçük alt küme var.
- `packages/profile_schema` portu (JSON okuma/doğrulama).
- Gerçek kamera/ML Kit entegrasyonu ile bu paketin birleştirilmesi
  (`apps/flutter_camera_spike`'ın `color_pipeline_stub.dart`'ı bu paketle
  değiştirilecek).
- `multicolor_patch` kalibrasyon YOLUNUN `pipeline_test.dart`'ta ayrıca
  uçtan uca test edilmesi (şu an sadece `calibration_test.dart`'ta izole
  test edildi, pipeline orkestrasyonu içinde henüz değil).
