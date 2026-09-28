# 0004 — Kalibrasyon Yöntemi Seçimi (A/B/C karşılaştırması)

**Durum:** AÇIK (ekip/danışman onayı bekliyor), ŞİMDİLİK **A** (`white_black`,
QR-içi beyaz+siyah) — gerçek BASILI etiket testiyle (22 Eylül, §11 Aşama B)
doğrulandı, bkz. aşağıdaki güncel sonuçlar. Daha büyük örneklemle tekrar
gözden geçirilebilir.
**Kaynak:** Devir Raporu §5.2/5 ("Referansların QR içinde veya etiket kenarında
olması deneyle seçilebilir"), §6.1 (kalibrasyon aday karşılaştırması), §9.2
(Öğrenci 2 görevi: "ölçülebilir sonuç tablosu üretir"), §12 ("Tek bir
beyaz/siyah formülün kesin çözüm olduğunun söylenmesini beklememeli").

## Kural

Rapor tek bir kalibrasyon yöntemine baştan kilitlenmeyi yasaklıyor;
karar A-E adaylarının aynı test setinde ölçülüp karşılaştırılmasıyla
verilmeli, ve hiçbir yöntem "kesin çözüm" ilan edilmemeli (§12).

## Test edilen 3 aday

| Kod | Yöntem | Ek baskı maliyeti |
|---|---|---|
| A / D | QR'ın kendi finder pattern'inden beyaz+siyah (`white_black`) | Yok |
| B | + 1 gri referans yaması, etiket kenarında | 1 ek yama |
| C | + 4 farklı renkte referans yaması (`multicolor_patch`) | 4 ek yama |

## Ölçülen sonuçlar (ΔE, CIEDE2000 — düşük daha iyi)

**Sentetik** (`tests/synthetic/benchmark_edge_reference.py`,
`benchmark_multicolor_reference.py`):

| Bozulma türü | A | B | C |
|---|---|---|---|
| Doğrusal ışık kayması (sarımsı/mavimsi) | **0.00** | **0.00** | 0.02 |
| Gama / tonlama eğrisi | 10.67 | **0.36** | 5.17 |
| Kanallar arası karışım (sensör crosstalk) | 10.25 | 11.27 | **0.26** |

**Gerçek fotoğraf, EKRANDAN çekim** (`tests/device/results_2026-09-17*.md`):

| Tur | Foto sayısı | A kazandı | B kazandı | C kazandı |
|---|---|---|---|---|
| 1 (yalnız A/B, 1 gri yama) | 8 | 4 | 4 | — |
| 2 (A/B/C, 4 renkli yama) | 4 | 2 | 1 | 1 |

**Gerçek fotoğraf, GERÇEK BASILI etiket** (22 Eylül, 5x5cm %100 ölçek,
`tests/device/results_2026-09-22.md`) — bu maddenin "sonraki adım"ında
uzun süre AÇIK kalan TODO'su, çok daha net bir sonuçla tamamlandı:

| Yöntem | Decode/kalite OK | Doğru sınıf (OK olanlar içinde) |
|---|---|---|
| **A (white_black)** | 5/9 (%56) | **5/5 (%100)** |
| B (white_gray_black) | 6/8 (%75) | 2/6 (%33) |
| C (multicolor_patch) | 3/8 (%38) | 1/3 (%33) |

2. tur (aynı gün, sadece B/C, daha yakın çekim): B'de decode oranı
DÜŞTÜ (3/8), C'de YÜKSELDİ (8/11) ama C'nin doğru-sınıf oranı hâlâ
zayıf (4/8) — üstelik `cbozuk1.jpeg`'de gerçek durum "bozuk" iken
**"fresh" YÜKSEK güvenle (confidence=0.90, ΔE=33.64)** tahmin edildi:
"yanlış ama emin" — §7.1'in "dürüst belirsizlik" ilkesine aykırı,
B'nin sistematik hatasından bile daha riskli bir hata türü.

**B'de bulunan gerçek kırılganlık (2 bağımsız turda tekrarlandı):**
`white_gray_black()`'in gama formülü (`gamma = ln(0.5)/ln(norm_gray)`),
gri referans yamasının beyazdan GÖZLE GÖRÜLÜR ölçüde daha koyu
basılacağını varsayıyor. Gerçek baskıda gri yama kimi zaman QR'ın kendi
beyaz modülüne çok yakın (hatta bir turda ondan daha parlak) ölçüldü —
`norm_gray` 1.0'a dayanınca gama ~9 ile ~693.000 arasında patlıyor,
görüntüyü neredeyse tamamen siyaha çöken dejenere bir eğriyle
"düzeltiyor". **Bu bir yazılım hatası değil** — formül doğru uygulanmış,
kırılganlık yöntemin varsayımında (gri her zaman güvenilir şekilde
beyazdan koyu ölçülür).

## Karar ve gerekçe

**A'da kalınıyor — artık gerçek baskı verisiyle de doğrulanmış, daha
güçlü bir gerekçeyle:**

1. **Ücretsiz** — hiçbir ek baskı alanı gerektirmiyor.
2. **Gerçek basılı etikette (22 Eylül) kod çözebildiği HER fotoğrafta
   doğru sınıflandı (5/5)** — B ve C'nin aksine, bu artık "geride
   kalmadı" değil, aktif bir üstünlük sinyali.
3. B'nin gama kırılganlığı **iki bağımsız turda da** aynı örüntüyle
   tekrarlandı — tesadüf değil, yöntemin kendi varsayımının gerçek
   baskı/ışık koşullarında tutmadığının kanıtı.
4. C, en az bir **"yanlış ama emin"** vakası verdi (confidence=0.90 ile
   yanlış sınıf) — ΔE/confidence düşük görünse bile yöntem olarak daha
   riskli; daha fazla referans yaması, daha fazla baskı/ışık hata kaynağı
   demek.
5. **En basit, hata riski en düşük** — C'nin matematiği (çoklu nokta afin
   fit) az/gürültülü veride kırılgan olabiliyor; bunu bizzat bir kanal
   sırası (RGB/BGR) hatasıyla da gördük (bkz. `results_2026-09-17c.md`).

**Bu hâlâ "kesin çözüm" ilanı değildir (§12 uyarısı) — durum bilerek
AÇIK bırakılıyor:** nihai karar ekip + danışmanla birlikte verilecek
(kullanıcı: "kalibrasyon yöntemini kağıtta qr fotograflarını çektikten
sonra biz karar vericez"). Ama artık kararı destekleyen veri sentetik
+ ekran fotoğrafından ibaret değil, gerçek baskıyla iki bağımsız turda
doğrulanmış durumda.

## Sonraki adım

- [x] **(18 Eylül)** B/C artık gerçek üretim akışına bağlı —
      `export_label(..., sensor_profile=...)` ve Yönetici ekranı,
      `sensor_profile.calibration_method.code`'a bakıp gerekli referans
      yamasını (gri/çoklu-renk) gerçekten basıyor ve `layout_version.json`'a
      yazıyor (`render.render_label_image` / `save_synthetic_states_for_
      profile`). Önceden bu yalnızca deney scriptlerinde vardı; danışman
      A dışında bir yöntem seçerse artık KOD DEĞİŞİKLİĞİ GEREKMEDEN, sadece
      profildeki `calibration_method.code` değiştirilerek üretilebilir.
      Bu sırada bir şema hatası da bulunup düzeltildi: `layout_version.
      schema.json`'daki `reference_regions` alanı negatif koordinatlara
      (kenar yaması için gerekli) izin vermiyordu.
- [x] **(22 Eylül)** Gerçek BASILI etiketle (ekran değil) tekrar test —
      bkz. `results_2026-09-22.md`, yukarıdaki özet. A açık ara kazandı,
      B'nin gama kırılganlığı ve C'nin "yanlış ama emin" riski somut
      olarak belgelendi.
- [ ] Örneklem hâlâ küçük (25 foto tek turda, +19 yakın-çekim turu) —
      daha büyük örneklem, sabit çekim koşulları (tripod, sabit ışık)
      ile decode başarısızlığının (tüm yöntemlerde yüksek: A 4/9,
      B 2/8, C 5/8) çekim kalitesinden mi yoksa yöntemden mi
      kaynaklandığı ayrıştırılmalı.
- [ ] Gerçek Putresin verisi geldiğinde, hangi kalibrasyon hatasının
      sınıflandırmayı (freshness_class) fiilen bozduğu ölçülmeli — ΔE
      düşük olması otomatik olarak "yeterli" demek değil.
- [ ] Ekip + danışmanla nihai karar toplantısı — bu dosyadaki veri
      A lehine güçlü ama karar resmi olarak hâlâ verilmedi.
