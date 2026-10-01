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

## ÖNEMLİ EK BULGU (28 Eylül): B/C'nin kötü performansının olası GERÇEK
## kök nedeni bulundu — yöntemin kendisi değil, bir uygulama hatası

Yukarıdaki A/B/C karşılaştırması "B ve C, yöntem olarak A'dan daha
kırılgan" şeklinde yorumlandı. Ama C'nin `multicolor_patch` için yeni
eklenen bir güvenlik kontrolünü (fit'in kendi referans noktalarını ne
kadar iyi açıkladığını ölçen `multicolor_patch_fit_residual`) test
ederken şu bulundu: **kenar referans yamaları (B'nin grisi, C'nin renkli
yamaları) GERÇEK RENDER EDİLMİŞ bir etikette okuyucu tarafından HİÇ
doğru örneklenmiyor.**

Sebep: bu yamalar QR'dan `border + EDGE_PATCH_MARGIN` (4+4=8) modül
kadar dışarıda basılıyor (`qr_layout/colors.py::edge_patch_positions`'ın
kendi docstring'i okuyucunun bunu bilmesi gerektiğini zaten söylüyor) —
ama `color_engine/pipeline.py`'deki okuyucu hem canonical (homografi
sonrası) görüntüyü hem de referans-pozisyon-piksel dönüşümünü SADECE
`border=4` ile yapıyor. Sonuç: canonical görüntü bu yamaları hiç
içermiyor, pozisyon hesabı negatif bir piksel koordinatına düşüyor ve
(Python'da numpy'nin negatif indekslemesi yüzünden) SESSİZCE yanlış bir
bölgeden okunuyor.

**Dart tarafında (28 Eylül) düzeltildi** — bkz.
`packages_dart/color_engine/lib/src/pipeline.dart` `_canonicalBorder`
yorumu; orada AYNI hata (Dart'ta RangeError ile ÇÖKME olarak tezahür
ediyordu) gerçek render+analyze zinciriyle kanıtlanıp düzeltildi (bkz.
`apps/freshqr/test/reference_patch_sampling_test.dart`).

**Python tarafı BİLEREK henüz düzeltilmedi** (kullanıcı talebi, 28 Eylül)
— `tests/synthetic/test_pipeline_reference_wiring.py`'deki ilgili test
`multicolor_patch` için `xfail` ile işaretlendi, sebebi orada ayrıntılı
açıklanıyor. `white_gray_black` (B) de muhtemelen AYNI hatayı taşıyor
ama onun için residual-benzeri bir kontrol olmadığından hâlâ fark
edilmeden "geçiyor" — B'nin sonucu da bu düzeltilene kadar GÜVENİLMEZ
sayılmalı.

**Bunun bu dosyanın kararı için anlamı:** A hâlâ en güvenilir/basit
seçenek olmaya devam ediyor (ek yama gerektirmiyor, bu sınıf hatasından
muaf). Ama B/C'nin yukarıdaki "gerçek baskıda kötü" bulgusu artık kesin
olarak "yöntemin kendi matematiksel kırılganlığı" diye OKUNMAMALI — en
azından KISMEN bu uygulama hatasından kaynaklanmış olabilir. Python
tarafı düzeltilip B/C gerçek baskıda TEKRAR test edilmeden, A/B/C
karşılaştırması nihai/güvenilir sayılmamalı.

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
- [x] **(28 Eylül, Dart)** Kenar referans yaması border uyumsuzluğu
      düzeltildi — bkz. yukarıdaki "ÖNEMLİ EK BULGU".
- [ ] **(28 Eylül, Python)** Aynı düzeltme `packages/color_engine/
      pipeline.py::_CANONICAL_BORDER`'a da uygulanmalı (bilerek ertelendi)
      — sonra B/C, 22 Eylül'deki GERÇEK basılı etiketlerle TEKRAR test
      edilmeli (bu düzeltmeden önceki A/B/C karşılaştırması B/C için
      güvenilmez olabilir, bkz. yukarı).
- [x] **(30 Eylül)** Canlı kamerada ışık etkisi ölçüldü — bkz.
      `tests/device/results_2026-09-30_isik_etkisi.md`. **Bu dosyadaki
      TÜM A/B/C karşılaştırmalarını doğrudan ilgilendiriyor**, aşağıya
      bakınız.
- [ ] **(30 Eylül'den sonra)** A/B/C karşılaştırması **kontrollü ışıkta**
      tekrarlanmalı — aksi halde ölçülen şey yöntem farkı değil ışık farkı
      olabilir.

## ⚠️ ÜRETİCİ/OKUYUCU UYUMSUZLUĞU (30 Eylül) — 30 Eylül turu geçersiz

Aynı payload için **Python ve Dart motorları farklı QR deseni üretiyor**
(sürüm/matris/ECC aynı, muhtemelen mask pattern farklı). Reaktif hücre
konumları yalnızca %21 örtüşüyor. 30 Eylül canlı kamera turunda kullanılan
etiketler Python ile üretilmiş, okuyucu ise Dart — yani o turun tamamı
uyumsuz bir zeminde yapıldı (ayrıntı:
`tests/device/results_2026-09-30_isik_etkisi.md` başındaki uyarı).

Dart üretimi etiketlerle aynı okuyucu, **A/B/C'nin dokuzunda da** doğru
sonuç ve **güven skoru 1.00** veriyor (kamerasız, doğrudan PNG'den).

**Alınan karar (30 Eylül):** etiketler **yalnızca Dart motoruyla**
üretilecek — ürün zaten Flutter/Dart, uygulama hem üretiyor hem okuyor,
yani kendi içinde tutarlı. Python tarafı referans/prototip olarak kalıyor,
**gerçek etiket üretmeyecek**. Dolayısıyla iki motorun farklı QR üretmesi
düzeltilmesi gereken bir hata olarak DEĞİL, bilinen ve kabul edilen bir
ayrışma olarak kaydediliyor.

Bundan çıkan iki pratik kural:

1. **Motorlar arası etiket alışverişi yapılmaz.** Python ile üretilmiş bir
   etiket Flutter uygulamasıyla okunamaz (ve tersi). Test etiketleri
   `packages_dart/label_export/tool/generate_calibration_labels.dart`
   ile üretilir.
2. **A/B/C karşılaştırması Dart üretimi etiketlerle sıfırdan
   tekrarlanmalı** — bu dosyadaki 30 Eylül turu geçersiz.

**Açık kalan risk:** eşleşmeyen bir etiket bir şekilde okutulursa
uygulama bunu fark etmez — "kendinden emin ama yanlış" sonuç verir (iki
gün boyunca yaşanan tam olarak buydu). Devrim'in `refineQrCorners`'ındaki
eşleşme-oranı kontrolü bunu yakalıyordu ama performans nedeniyle geri
alındı (e6a80a3 → 443ba8e). Sadece o kontrolü (refine olmadan) geri
getirmek ucuz bir güvenlik ağı olurdu.

Not: mükemmel (sentetik) görüntüde üç yöntem de **birebir aynı** sonucu
veriyor (ΔE 0.42/2.08/2.09) — kalibrasyonun düzeltecek bir şeyi olmadığı
için. Yani **A/B/C karşılaştırması sentetik görüntüyle YAPILAMAZ**,
yöntemler yalnızca gerçek kamera bozulması altında ayrışır.

### Yapısal gözlem — A'nın referansları içeride, B/C'ninkiler dışarıda

Kalibrasyonun temel varsayımı "referans ile ölçülen hücreler aynı ışığı
görür". A'nın referansları QR'ın **içinde**, reaktif hücrelerle aynı ışık
komşuluğunda; B/C'ninkiler etiketin **dış kenarında** — parlamaya ve
mercek köşe karartmasına (vignetting) daha açık, yani varsayımı ilk bozan
yer orası. Bu, A lehine "testlerde kazandı"dan daha güçlü, yapısal bir
gerekçe (henüz kontrollü ölçümle doğrulanmadı).

## AYDINLATMA UYARISI (30 Eylül) — önceki tüm turlar için geçerli

Canlı kamera testinde tek değişken ışık tutularak ölçüldü: **gölgede
A/B/C'nin ÜÇÜ de doğru sınıflandırdı**; ekrana parlama vururken üç
yanlış çıktı. Ayrıntı ve sayılar:
`tests/device/results_2026-09-30_isik_etkisi.md`.

Bunun bu dosya için iki sonucu var:

1. ~~ΔE, güvenilirlik ölçütü olarak kullanılamaz~~ — bu iddianın dayandığı
   ölçüm (parlamada ΔE=0.73 ile yanlış sonuç) uyumsuz etiketlerle
   yapıldığı için GEÇERSİZ. Mekanizma teorik olarak makul ama doğru
   etiketlerle tekrar ölçülmeden iddia edilmemeli.
2. **Seviyeleri ayıran bilginin %72–96'sı PARLAKLIK farkı** (profilin
   kendi sayılarından hesaplandı, ölçüme bağlı değil — GEÇERLİ).
   Aydınlatma hatası da bir parlaklık hatasıdır; yani sinyal ile gürültü
   aynı eksende. Kalibrasyonun bu projede neden belirleyici olduğunun
   yapısal açıklaması.
   **Not:** hata payının "dar" olduğu şeklindeki ilk değerlendirme
   YANLIŞTI — o da bozuk turun ölçümüne dayanıyordu. Doğru etiketlerle
   ölçülen hata ΔE 0.42–2.09, seviyeler arası mesafe ise 11–18 ΔE:
   yaklaşık 10 kat pay var.

Karar üzerindeki etkisi: A hâlâ en sağlam seçenek (bu turda da her iki
koşulda doğru), ama **B ve C'nin geçmiş turlardaki kötü performansının
ne kadarı yöntemden, ne kadarı ışıktan** sorusu açık. Nihai karar,
kontrollü ışıkta yapılmış bir turdan sonra verilmeli.
