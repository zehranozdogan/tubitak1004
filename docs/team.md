# Ekip, Sorumluluklar ve 10 Haftalık Plan (Rapor §9, §13)

## Roller

### Öğrenci 1 — ana sorumlu / teknik lider (§9.1)
- Yeni repo + temel mimari; tüm merge/release kararları.
- QR layout motoru, üretici modülü, tüketici uygulaması, **uçtan uca entegrasyon**.
- Yardımcının renk/kalibrasyon/test modüllerini ana sisteme entegre eder.
- Ortak veri sözleşmesi, issue takibi, test planı, build/release, final demo.
- "Uçtan uca çalışıyor mu?" sorusunun sahibi.

### Öğrenci 2 — yardımcı / algoritma ve doğrulama (§9.2)
- Kalibrasyon adaylarını (§6.1 A–E) karşılaştırır, ölçülebilir sonuç tablosu.
- Homografi / ROI / renk örnekleme / Lab / ΔE, gerekirse robust clustering.
- QR reaktif modül yerleşim varyantlarının sentetik/decoder testleri.
- Farklı telefon / ışık / mesafe / açı testleri; test logları + hata analizi.
- Kodları ana repo içinde **modül** olarak teslim eder (ayrı proje yürütmez).

## 10 haftalık plan (§13)

| Hafta | Teknik lider | Yardımcı | Ortak teslim |
|---|---|---|---|
| 1 | Gereksinim + temiz repo + **framework spike** + temel QR generator | Veri seti düzeni + ilk kalibrasyon benchmark iskeleti | Mimari, repo, test veri klasörü |
| 2 | QR function mask + 3 dağıtılmış layout adayı | Layout'ların sentetik renk/decoder testi | Layout v0.1 + decode tablosu |
| 3 | Producer panel + PNG/PDF/JSON export | Sentetik fresh/mid/spoiled profil üretimi | Üretici demosu + test etiketleri |
| 4 | Consumer scanner + QR köşe/metadata akışı | Homografi + canonical image + ROI debug | Telefonla QR+etiket hizalama demosu |
| 5 | Color engine API entegrasyon iskeleti | Kalibrasyon A–E karşılaştırması | Kalibrasyon benchmark raporu |
| 6 | Profile/layout loader + color engine entegrasyonu | Lab/ΔE, robust ROI, quality score | Tek görüntüden teknik renk sonucu |
| 7 | Consumer UI: tarama/sonuç/retry/detay | Kötü görüntü kalite kriterleri + testler | Uçtan uca sentetik demo |
| 8 | Basılı etiket / build / release stabilizasyonu | Telefon/ışık/mesafe/açı test matrisi | Cihaz testi + hata logları |
| 9 | Layout/performans optimizasyonu | Kalibrasyon ve renk hata analizi | Seçilmiş final layout + yöntem |
| 10 | Final entegrasyon, README, release, demo/video | Metrikler, grafikler, test sonuç paketi | Final demo + kod + rapor + test verisi |

## Definition of Done (§13.1)

- [ ] Üretici modülü ürün/parti + sensor_profile + layout seçerek basılabilir etiket üretiyor.
- [ ] Dağıtılmış reaktif hücreler renk durumları değişince QR kimliği güvenilir okunuyor.
- [ ] Tüketici uygulaması: etiketi bulma + geometrik düzeltme + kalibrasyon + renk ölçümü.
- [ ] Renk motoru profile göre sonuç üretiyor; profil değişince **kod değişmeden** yeni skala.
- [ ] ≥ 2 telefon + farklı koşullarda decode ve renk hata metrikleri raporlanmış.
- [ ] Spot/süpermarket ışığında başarı ölçütüyle (≈ ≤ %5) ilişkili hata analizi.
- [ ] Kod + README + setup + örnek profile/layout + test images + test CSV/JSON + demo build + teknik rapor.
