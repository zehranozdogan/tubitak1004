# 0004 — Kalibrasyon Yöntemi Seçimi (A/B/C karşılaştırması)

**Durum:** AÇIK, ŞİMDİLİK **A** (`white_black`, QR-içi beyaz+siyah) — daha büyük
gerçek fotoğraf örneklemiyle (§11 Aşama B) yeniden değerlendirilecek.
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

**Gerçek fotoğraf** (`tests/device/results_2026-09-17*.md`):

| Tur | Foto sayısı | A kazandı | B kazandı | C kazandı |
|---|---|---|---|---|
| 1 (yalnız A/B, 1 gri yama) | 8 | 4 | 4 | — |
| 2 (A/B/C, 4 renkli yama) | 4 | 2 | 1 | 1 |

## Karar ve gerekçe

**Şimdilik A'da kalınıyor.** Sebep:

1. **Ücretsiz** — hiçbir ek baskı alanı gerektirmiyor.
2. Gerçek fotoğraflarda hiçbir turda geride kalmadı (her turda en az
   yarı yarıya kazandı) — B ve C'nin niş üstünlükleri (gama → B, kanal
   karışımı → C) gerçek kamerada ne sıklıkla karşımıza çıkacağını henüz
   bilmiyoruz, küçük örneklem (4-8 foto, üstelik ekrandan çekim, henüz
   baskı değil) bunu netleştirmeye yetmiyor.
3. **En basit, hata riski en düşük** — C'nin matematiği (çoklu nokta afin
   fit) az/gürültülü veride kırılgan olabiliyor; bunu bizzat bir kanal
   sırası (RGB/BGR) hatasıyla da gördük (bkz. `results_2026-09-17c.md`).
4. Raporun kendi ifadesiyle de (§6.1) "iyi bir başlangıç yaklaşımı" —
   biz bunu körü körüne değil, ölçüp doğrulayarak koruyoruz.

**Bu "kesin çözüm" değildir (§12 uyarısı):** B, gama-ağırlıklı kameralarda;
C, kanal-karışımı belirginse gerekebilir. Gerçek baskılı, daha büyük bir
fotoğraf setiyle (§11 Aşama B) sonuç değişirse bu dosya güncellenecek.

## Sonraki adım

- [ ] Gerçek BASILI etiketle (ekran değil) tekrar test — mevcut ekran
      testlerinin baskıyı temsil edip etmediği hâlâ belirsiz.
- [ ] Örneklem büyütülmeli (şu an toplam 12 gerçek fotoğraf, 4-8 arası turlarda).
- [ ] Gerçek Putresin verisi geldiğinde, hangi kalibrasyon hatasının
      sınıflandırmayı (freshness_class) fiilen bozduğu ölçülmeli — ΔE
      düşük olması otomatik olarak "yeterli" demek değil.
