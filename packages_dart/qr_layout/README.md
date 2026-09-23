# qr_layout (Dart portu)

`packages/qr_layout` (Python) — reaktif hücre yerleşimi ve renk mantığının
Dart'a taşınmış hâli. **Gerçek QR encoding (segno'nun yaptığı iş) BURADA
YOK VE OLMAYACAK** — o iş, gerçek bir Dart QR kütüphanesine (pub.dev'de
mevcut, ör. `qr`) bırakılacak; ML Kit'i decode için kullanmaya karar
verdiğimiz mantığın aynısı (bkz. `apps/flutter_camera_spike`). Bu paket
sadece ISO/IEC 18004'ün YAPISAL GEOMETRİSİni ve projeye özgü reaktif hücre
seçim mantığını taşır — encoding'den TAMAMEN bağımsız, saf matematik.

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

- `generator.py`'nin geri kalanı port EDİLMEYECEK (segno'ya özgü) — bunun
  yerine gerçek bir Dart QR paketi seçilip entegre edilecek.
- `render.py` (SVG/PNG rasterize) — Flutter'da `CustomPainter` ile yeniden
  yazılacak (zehra bunu araştırıyor), doğrudan port değil.

`packages_dart/color_engine` artık bu pakete BAĞIMLI (23 Eylül'de
temizlendi — önceden `finder_pattern.dart` diye kısmi bir kopyası vardı,
kaldırıldı).

## Test etme

```
cd packages_dart/qr_layout
dart test
dart analyze
```
