# qr_layout (Dart portu)

`packages/qr_layout` (Python) — reaktif hücre yerleşimi, renk mantığı VE
(23 Eylül) gerçek QR encoding'in Dart'a taşınmış hâli. Segno'nun yerini
`qr` paketi (pub.dev, kevmoo/qr.dart — saf Dart, ISO/IEC 18004 uyumlu,
`qr_flutter`'ın da alt motoru) alıyor — bkz. `lib/src/generator.dart`.
Decoder tarafında ML Kit kullanımının onaylanmasıyla (hoca görüşmesi)
aynı oturumda, onu tamamlayan karar olarak seçildi.

## Ne var (Python dosyasına göre)

- `function_mask.py` -> `lib/src/function_mask.dart` — hangi modüllerin
  "fonksiyon" (finder/timing/alignment/format/version bilgisi, DOKUNULMAZ)
  olduğunu hesaplar. SAF ISO/IEC 18004 matematiği. Gerçek Python
  çıktısıyla (4 versiyon toplam işaretli hücre sayısı + versiyon 1 TAM
  matris + versiyon 7/25 nokta kontrolleri) doğrulandı.
- `colors.py` (kısmi) -> `lib/src/colors.dart` — `STATE_COLORS`,
  `moduleColor`, `modulePixelCenter`, finder/kenar referans yama
  konumları. Gerçek Python çıktısıyla doğrulandı.
- `reactive.py` -> `lib/src/reactive.dart` + `lib/src/crc32.dart` —
  `selectReactiveModules`, `selectIntentionalErrors`, `buildLayout`,
  `seedFromLayoutVersion` (CRC-32, dış bağımlılık yok, gerçek
  `zlib.crc32` çıktısıyla birebir doğrulandı).
- `generator.py` -> `lib/src/generator.dart` — `generateQr`, `moduleMatrix`,
  `reactiveCandidatesForVersion` (Python: `reactive_candidates`). Segno
  yerine `qr` paketi (bkz. yukarı). DOĞRULAMA: 'HELLO'+v1+H için gerçek
  segno çıktısıyla TAM (bit bit) eşleşiyor (alfanümerik-sadece, tek
  segment — segmentasyon belirsizliği yok). Karışık/uzun (JSON) bir
  payload'da version/ecc seçimi segno ile AYNI (11, H) ama iç modül
  matrisi FARKLI OLABİLİR (mod segmentasyonu/maske seçimi ISO 18004'in
  izin verdiği ölçüde kütüphaneye özgü) — bu bir hata DEĞİL; gerçek
  decode round-trip'i (pyzbar, projenin kendi decoder'larından biri) ile
  ayrıca doğrulandı: Dart'ın ürettiği matris orijinal payload'a BİREBİR
  geri decode ediliyor.

## Mimari sapma: RNG (ÖNEMLİ, mutlaka oku)

Python `random.Random(seed)` (Mersenne Twister); Dart `dart:math`'ın
`Random`'ı FARKLI bir algoritma. **Aynı seed, iki dilde FARKLI (ama her
biri kendi içinde deterministik) bir hücre seçimi üretir.** Bu SORUN
DEĞİL: `buildLayout()` seçilen hücreleri layout_version JSON'una SOMUT
koordinat olarak yazıyor — bir Dart TÜKETİCİSİ (analiz/okuma tarafı,
`color_engine` paketi) bunları JSON'dan okur, seed'den yeniden TÜRETMEZ.
Yalnızca bir Dart ÜRETİCİSİ (yeni etiket basan bir admin ekranı) gerçekten
`selectReactiveModules`'ı çağırır — orada "aynı seed → aynı Dart sonucu"
yeterlidir, Python'un ürettiği geçmiş yerleşimlerle bit-bit eşleşmesi
gerekmez. Testler bu yüzden RNG'ye bağlı fonksiyonları (`selectReactive
Modules`, `selectIntentionalErrors`) YAPISAL özellikleriyle doğruluyor
(doğru sayı, min_spacing'e uyum, determinizm) — exact-match DEĞİL.
Deterministik/rastgelesiz kısımlar (chebyshev, boundary distance, function
distance transform, safety score, crc32) ise gerçek Python ile BİREBİR.

## Sırada ne var

- `render.py` (SVG/PNG rasterize) — Flutter'da `CustomPainter` ile yeniden
  yazılacak (zehra bunu yapıyor), doğrudan port değil.
- `label_export/export.py` orkestrasyonu (generate_qr -> reactive_candidates
  -> select_reactive_modules -> build_layout -> validate -> render -> kaydet)
  henüz Flutter tarafında BİRLEŞTİRİLMEDİ — parçalar (bu paket, profile_schema,
  render) ayrı ayrı hazır, uçtan uca "etiket üret" akışı henüz yok.

`packages_dart/color_engine` artık bu pakete BAĞIMLI (23 Eylül'de
temizlendi — önceden `finder_pattern.dart` diye kısmi bir kopyası vardı,
kaldırıldı).

## Test etme

```
cd packages_dart/qr_layout
dart test
dart analyze
```
