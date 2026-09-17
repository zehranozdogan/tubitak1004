# tests/device — Basılı Etiket ve Telefon Testi (Rapor §11.2)

Sahibi: Öğrenci 2 (§9.2). Test protokolü + log şeması + sonuç özetleri +
`run_test.py` (gerçek fotoğrafları `pipeline.analyze()`'dan geçirip bu
şemadaki CSV'yi üreten araç).

## Çalıştırma

1. `manifest.example.csv`'yi `manifest.csv` olarak kopyala (bu, `.gitignore`'da —
   kişisel dosya yolları commit'lenmez), fotoğraf yollarını ve bildiğin
   meta verileri (telefon, ışık, mesafe, açı) doldur.
2. `python tests/device/run_test.py tests/device/manifest.csv`
3. Ham sonuç `tests/device/raw/results_*.csv`'ye yazılır (commit'lenmez);
   toplu metrikler `tests/device/summary.csv`'ye eklenir (commit'lenir).

`expected_state` (ground-truth) yalnızca `class_thresholds` tanımlı bir
profille (ör. `DEMO_QR_STATE_COLORS_v1`) üretilmiş etiketlerde anlamlıdır
— `GENIPIN_PUTRESIN_v2` gibi `class_thresholds: null` olan profillerde
`freshness_class` hep boş döner, "doğruluk" hesaplanamaz.

## Test matrisi

| Değişken | Değerler |
|---|---|
| Telefon | ≥ 2 model, mümkünse farklı kamera üreticisi |
| Işık | Ofis ışığı · spot/süpermarket · farklı renk sıcaklıkları |
| Mesafe | 5, 10, 20, 30 cm (aralık deneyle daraltılır) |
| Açı | 0°, 15°, 30°, 45° |
| Flaş | açık / kapalı |
| Etiket | temiz · hafif gölge · küçük baskı kusuru |

## Ölçüm logu (her satır bir okuma) — `raw/` altına, özet CSV commit'lenir

```
timestamp, phone_model, camera, lighting, color_temp_k, distance_cm, angle_deg, flash,
layout_version, sensor_profile_id, decode_ok, decode_attempts, decode_ms,
delta_e, quality_score, rescan, technical_level, freshness_class, total_ms, note
```

## Raporlanacak metrikler (§11.3)

- QR decode başarısı (tüm sensör renk durumlarında hatasız çözülme oranı)
- Pigment/renk ölçüm hatası — hedef: spot ışık altında **≈ ≤ %5** (proje başarı ölçütü, §1)
- Cihazlar arası renk farkı (aynı örnek, farklı telefon → Lab/ΔE)
- Tekrarlanabilirlik (ardışık taramalarda SD/CV, sınıf stabilitesi)
- Kalibrasyon kazancı (ham görüntüye göre ΔE/variance düşüşü)
- Okuma kalitesi reddi (kötü görüntüde yanlış sınıf yerine "Yeniden tara" oranı)
- Süre (QR tespiti + renk analizi + sonuç)
- Tazelik doğruluğu — **yalnızca** doğrulanmış ground-truth varsa (accuracy/confusion matrix)
