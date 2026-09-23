# label_export (Dart portu)

`packages/label_export/export.py` (Python) etiket üretim orkestrasyonunun
Dart'a taşınmış hâli — **SADECE render-ÖNCESİ kısım**.

## Kapsam: neden "render-öncesi"

Python `export_label()` şu adımları izliyordu:

```
generate_qr -> reactive_candidates -> select_reactive_modules -> build_layout
  -> validate -> [render.py: PNG/PDF + kalibrasyon yöntemine göre
     reference_regions'a ekstra kenar yaması ekleme] -> TEKRAR validate
  -> dosyaya yaz
```

Render adımı (PNG/PDF rasterize'ı VE — daha da önemlisi — kalibrasyon
yöntemi `white_black`/`qr_fixed_regions`/`algorithmic_white_balance`
DIŞINDAYSA `layout['reference_regions']`'a ekstra kenar yaması (gray/red/
green/blue, §6.1 B/C) EKLEME mantığı) `render.py` içinde — bu, Flutter
tarafında `CustomPainter` ile ayrıca yazılıyor (zehra yapıyor), bu paketin
işi DEĞİL. Bu yüzden `generateLabel()` Python'ın `export_label()`'ının
TAMAMI değil, ondan render'a kadarki kısmın portu.

**Sonuç:** `generateLabel()`'ın ürettiği `layout`, varsayılan referans
bölgeleriyle (sadece finder white/black) GEÇERLİ bir `layout_version`'dur,
ama `white_black`/`qr_fixed_regions`/`algorithmic_white_balance` DIŞINDA
bir kalibrasyon yöntemi kullanan bir `sensor_profile` için EKSİKTİR — render
entegre olduğunda ekstra referans eklenip TEKRAR doğrulanmalı (Python'daki
gibi).

## Ne var

- `buildLabelPayload(...)` — Python `export.build_label_payload`: alanları
  normalize eder (trim + `product_type` BÜYÜK HARF) ve `profile_schema`'nın
  `LabelPayload.fromJson` doğrulamasından geçirir (kendi doğrulaması YOK,
  tekrarlanmadı).
- `labelPayloadQrText(payload)` — Python `_payload_qr_text`: QR'a gömülecek
  kompakt JSON metni. Gerçek Python `json.dumps(..., separators=(",",":"))`
  ile BİREBİR aynı biçimde üretildiğini doğrulandı (alan sırası dahil).
- `generateLabel(payload, {density, seed})` — Python `export_label()`'ın
  render-öncesi kısmı: `generateQr` + `reactiveCandidatesForVersion` +
  `selectReactiveModules` + `buildLayout` + `LayoutVersionData.fromJson`
  (doğrulama) zincirini çalıştırıp `GeneratedLabel` (payload + qr + layout +
  ham layout JSON haritası) döner.

## Doğrulama

Gerçek Python (`generate_qr`+`reactive_candidates`+`select_reactive_modules`
+`build_layout`+`validate`) AYNI payload/density/seed için çalıştırıldı:
`qr.version` (12), `qr.error` (H), `layout.matrix_size` (65) VE seçilen
reaktif hücre SAYISI (75 — RNG'den ÖNCEKİ, saf geometriden türeyen hedef)
BİREBİR eşleşiyor. HANGİ hücrelerin seçildiği RNG algoritma farkı yüzünden
Python'la eşleşmiyor — bu `qr_layout/reactive.dart`'ta ZATEN belgelenmiş,
kasıtlı bir mimari sapma (bkz. o paketin README'si), burada tekrar
tartışılmadı.

## Test etme

```
cd packages_dart/label_export
dart test
dart analyze
```

## Sırada ne var

- Render (`render.py` -> `CustomPainter`, zehra) entegre olunca: kalibrasyon
  yöntemine göre `layout.reference_regions`'a ekstra yama ekleme + TEKRAR
  doğrulama adımı bu pakete (veya render'ın kendisine) eklenmeli.
- Dosyaya yazma (payload_json/layout_json) BİLİNÇLİ OLARAK YOK — platforma
  özgü (`dart:io File` ya da Flutter web'de indirme), `profile_schema`'nın
  "dosya okuma bu paketin işi değil" ilkesiyle AYNI gerekçe (bkz. o paketin
  README'si) — çağıran taraf `label.payload.toJson()`/`label.layoutJson`'ı
  kendi platformunda yazar.
