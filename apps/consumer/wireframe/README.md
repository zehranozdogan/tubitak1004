# Tüketici — Ekran Akışı (wireframe)

Rapor §7. Son tasarım değişebilir; **fonksiyonlar korunmalıdır**.

```
[ Ana ekran ]            [ Tarama ]                 [ Sonuç ]
 Akıllı Tazelik           ┌ ─  ─ ─ ┐                RENK SEVİYESİ 3 / P4
 "Balık etiketindeki      │  QR +   │               (veya: TAZE / GEÇİŞ / BOZUK
  sensör QR'ı tara"       │ çerçeve │                — YALNIZ doğrulanmış eşik varsa)
                          └ ─ ─  ─ ┘
 [  TAZELİK TARA  ]       "QR'ı çerçeveye al"        Ürün: Levrek · Parti: TR45678
                          Işık yetersizse uyarı     Okuma kalitesi: Uygun
 giriş / üyelik YOK                                  [ Teknik detayları göster > ]
                                                     [ Yeniden tara ]
```

## Minimum fonksiyonlar (§7.1)

1. Kamera izni + canlı tarama ekranı
2. QR verisini çöz → `label_payload` (`sensor_profile_id`, `layout_version`)
3. Profili/layout'u `packages/profile_schema` ile yükle (koordinat hard-code YOK)
4. QR/etiket perspektifini düzelt, referans + sensör bölgelerini bul
5. `packages/color_engine.analyze()` → renk ölçümü + `quality_score`
6. Profile göre eşleştir → **büyük, tek** anlaşılır sonuç
7. Bulanık / parlamalı / karanlık → **"Yeniden tara"** (yanlış sınıf üretme)
8. QR'daki ürün / parti / tarih bilgisini sonuç ekranında göster

## Sonuç ekranı kuralı (§7.2) — kritik

- `sensor_profile.class_thresholds == null` ise **"taze / geçiş / bozuk" gösterme.**
  Bunun yerine `technical_level` (ör. "Renk seviyesi 2 / Profil noktası P4").
- Doğrulanmış eşik geldiğinde aynı `profile` yapısı üzerinden tazelik sınıfı açılır.
- pH / amin / ΔE / tazelik % / raf ömrü / güven skoru: yalnızca "Teknik detaylar"
  ekranında ve final bilimsel eşleme olmadan **kesin sonuç gibi sunulmaz.**
- Sınıflar: **Taze / Geçiş / Bozuk** ("Şüpheli" değil).
