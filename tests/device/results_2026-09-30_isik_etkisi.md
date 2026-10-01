# Işığın ölçüme etkisi — canlı kamera, A/B/C (30 Eylül 2026)

> ## ⚠️ SONRADAN EKLENEN UYARI — bu turun verisi GEÇERSİZ
>
> Bu dosya yazıldıktan SONRA, aynı gün, çok daha temel bir hata bulundu:
> **bu turda kullanılan etiketler Python motoruyla üretilmişti, oysa onları
> okuyan uygulama Dart motorunu kullanıyor.** İki motor aynı payload için
> FARKLI QR deseni üretiyor (aynı sürüm/matris/ECC, muhtemelen farklı mask
> pattern) — bu yüzden reaktif hücre konumları yalnızca **%21 örtüşüyor**.
> Yani uygulama, hücrelerinin ~%79'u yanlış yerde olan bir etiketi okumaya
> çalışıyordu.
>
> Uçtan uca doğrulama (kamerasız, doğrudan PNG'den, aynı okuyucu):
>
> | Etiketi üreten | Sonuç |
> |---|---|
> | Python | Üç durumda da ızgara hizalanamadı (modüllerin %55'i uyuştu) |
> | Dart | taze→P2 (ΔE 0.42), geçiş→P4 (ΔE 2.08), bozuk→P6 (ΔE 2.09), **güven 1.00** |
>
> **Bunun aşağıdaki bulgular için anlamı:**
>
> - **Bulgu 4 GEÇERLİ** — profilin kendi sayılarından hesaplandı, ölçüme
>   hiç bağlı değil (seviyeleri ayıran bilginin %72–96'sı parlaklık).
> - **Bulgu 3'ün SONUCU YANLIŞ, TERSİNE DÖNÜYOR.** Profil noktaları arası
>   mesafe (11–18 ΔE) doğru, ama onunla karşılaştırılan "ölçüm hatası
>   6–10 ΔE" rakamı bu bozuk turdan geliyordu. Doğru (Dart) etiketlerle
>   aynı okuyucu **ΔE 0.42–2.09** veriyor — yani hata payı DAR değil,
>   yaklaşık **10 kat rahat**. "Komşu noktaya kayma beklenen bir sonuçtur"
>   çıkarımı bu veriyle desteklenmiyor.
> - **Bulgu 1, 2, 5 ve ham veri tablosu GÜVENİLMEZ** — hepsi uyumsuz
>   etiketle ölçüldü. Bulgu 1'in mekanizması (parlama renkleri yanlış bir
>   profil noktasının üstüne düşürebilir) teorik olarak makul ama ÖRNEĞİ
>   geçersiz; tekrar ölçülmeden iddia edilmemeli.
> - Işığın etkisi gerçek ve tekrarlanabilir gözlendi (gölge/ışık farkı
>   sonucu değiştiriyordu), ama **büyüklüğü bu veriden çıkarılamaz.**
>
> Doğru etiketlerle (Dart üretimi) yapılan ilk testte uygulama "çok iyi
> çalışıyor" olarak rapor edildi. A/B/C karşılaştırması bu etiketlerle
> SIFIRDAN tekrarlanmalı.
>
> Etiket üretimi artık Dart'tan yapılıyor:
> `packages_dart/label_export/tool/generate_calibration_labels.dart`.
> İki motorun aynı payload için aynı QR'ı üretmemesi AYRI ve AÇIK bir
> hata — portun temel varsayımına (karar 0002) aykırı, düzeltilmeli.

**Kurulum:** Redmi Note 9 (Android 12), `freshqr` canlı kamera taraması.
Etiketler **bilgisayar ekranından** okutuldu (kağıt baskı DEĞİL —
`results_2026-09-22.md` kağıt turuydu). Etiketler bu oturumda güncel kodla
üretildi (BASKI3-A/B/C, QR_SENSOR_v4, density=low, profil
GENIPIN_PUTRESIN_v2).

**Decoder:** zxing2. ML Kit bu cihazda her denemede çöküyor (ayrı konu,
bkz. `camera_scanner.dart` "GERÇEK CİHAZ HATASI #4" notu) — yani bu turun
tamamı yedek decoder ile yapıldı.

**Tek değişken:** ışık. Aynı etiket, aynı yöntem, aynı mesafe; bir okuma
oda ışığı ekrana vururken (parlama/yansıma), bir okuma ekrana elle gölge
yapılarak.

## Ham veri (kullanıcı ölçümü)

ΔE değerleri, sırayla taze / geçiş / bozuk:

| Yöntem | Işık vururken | Gölgede |
|---|---|---|
| A (white_black) | 9.87, 6.46, 8.69 | 9.95, 5.26, 4.85 |
| B (white_gray_black) | 9.51, 7.63, **8.25** | 6.17, 10.67, 6.64 |
| C (multicolor_patch) | 9.69, 6.70, **19.35** | 8.94, 10.11, **13.32** |

Kalın = yanlış sınıflandırma:

- Işıkta **B-bozuk → P4** (komşu noktaya kayma), **C-bozuk → P3** (iki
  nokta uzağa; kullanıcı notu: "ışık tam ortasında patlıyordu")
- Gölgede **C-bozuk → P4** (komşu noktaya kayma)
- A her iki koşulda da doğru sınıflandırdı.

Ayrıca tek etiket üzerinde yapılan ilk karşılaştırma (aynı gün, daha
önce):

| Okuma | Işık patlamış | Gölge |
|---|---|---|
| A – geçiş | ΔE 9.76 (**yanlış**) | ΔE 3.19 (doğru) |
| B – bozuk | ΔE **0.73** (**yanlış**) | ΔE 9.69 (doğru) |

## Bulgu 1 — ΔE bir GÜVENİLİRLİK ölçütü DEĞİL

Yukarıdaki B-bozuk satırı bunun kanıtı: **en kötü koşul (parlama), en
"mükemmel görünen" ΔE'yi üretti (0.73)** ve sınıfı YANLIŞ buldu. Doğru
okuma ise gölgede ΔE 9.69 verdi.

Mekanizma: parlama renkleri doyurup sıkıştırınca ölçülen renk tesadüfen
**yanlış bir profil noktasının tam üzerine** düşebiliyor. ΔE küçük çıkıyor,
sistem kendinden emin görünüyor, cevap yanlış.

Bu, `0004`'te zaten "en riskli hata türü" diye işaretlenen **"yanlış ama
emin"** vakasının en net örneği — ve bu kez A/B ayrımından bağımsız,
doğrudan ÖLÇÜM KOŞULUNDAN kaynaklanıyor.

**Sonuç:** ΔE ne kullanıcıya "iyi okuma" sinyali olarak gösterilmeli, ne
de bir eşik/kapı olarak kullanılmalı. Ek olarak tam tersi de geçerli:
yüksek ΔE ≠ yanlış (A-taze her iki koşulda da ΔE ~9.9 ile DOĞRU
sınıflandırdı).

## Bulgu 2 — mevcut ışık-düzensizliği göstergesi bu durumu yakalamıyor

`pipeline.dart::_referenceCornerConsistency` üç finder köşesindeki beyazı
örnekleyip değişim katsayısı (cv) hesaplıyor; cv > 0.25 olunca
bilgilendirici bir not düşüyor.

**Bu not iki koşulda da HİÇ çıkmadı** (kullanıcı kontrol etti) — yani cv
her iki durumda da 0.25'in altında kaldı, gösterge parlamayı fark etmedi.

Olası sebep (DOĞRULANMADI): parlama üç köşeyi de benzer şekilde etkileyip
beyazı hepsinde birden doyuruyorsa, köşeler arası *fark* küçük kalır —
cv "ışık gayet düzgün" der, oysa bilgi çoktan kaybolmuştur. Yani cv,
*gradyan* tipi düzensizliği yakalar ama *doygunluk* (clipping) tipini
yakalamaz.

**Öneri:** güvenilirlik sinyali renk uzayındaki mesafeden (ΔE) veya
köşeler arası farktan değil, **doğrudan görüntüden** gelmeli: beyaz
referans 255'e yapışmışsa (clipping) ölçüm baştan geçersiz sayılmalı.
Bu henüz uygulanmadı; eşik gerçek fotoğraflarla ölçülmeli (tahminle
konulan bir eşik Python'da bir kez denenip "aşırı sert" bulunarak geri
alınmıştı — aynı hataya düşmemek için önce veri).

## Bulgu 3 — hata payı, profilin çözünürlüğüne göre çok dar

GENIPIN_PUTRESIN_v2 profilinin komşu noktaları arasındaki mesafe
(hesaplandı):

| Adım | Toplam ΔE | ΔL (parlaklık) | Δab (renklilik) | ΔL payı |
|---|---|---|---|---|
| P1→P2 | 10.92 | 9.50 | 5.39 | %87 |
| P2→P3 | 17.64 | 17.00 | 4.72 | %96 |
| P3→P4 | 15.84 | 15.00 | 5.10 | %95 |
| P4→P5 | 13.61 | 11.50 | 7.28 | %84 |
| P5→P6 | 11.05 | 8.00 | 7.62 | %72 |

Yani komşu iki tazelik seviyesi arasındaki mesafe **11–18 ΔE**. Ölçülen
ΔE'ler ise (yukarıdaki tablo) **5–19**, tipik olarak 6–10.

**Ölçüm hatası, seviyeler arası mesafenin yarısı ile tamamı arasında.**
Bu şartlarda komşu bir noktaya kayma beklenen bir sonuçtur, anomali
değil. C-bozuk'un 19.35 ve 13.32'lik ΔE'leri ise mesafeyi tamamen aşıyor
— orada eşleşme fiilen rastgeleleşiyor.

## Bulgu 4 — sinyal ile gürültü AYNI eksende (yapısal)

Yukarıdaki tablonun son sütunu kritik: komşu noktaları ayıran bilginin
**%72–96'sı saf parlaklık (L)** farkı; renklilik (a,b) katkısı küçük.

Aydınlatma hatası da (parlama, gölge, pozlama) esasen bir **parlaklık**
hatasıdır. Yani:

> Profilin tazelik seviyelerini ayırt ettiği eksen ile ölçüm hatasının
> hareket ettiği eksen AYNI.

Bu, kalibrasyonun neden bu projede belirleyici olduğunu açıklıyor:
kalibrasyonun tek işi tam olarak bu parlaklık hatasını temizlemek. Işık
kalibrasyonu bozduğunda (doygunluk) geriye düzeltilecek bir şey kalmıyor,
ölçüm doğrudan profil ekseni boyunca kayıyor ve komşu seviyeye düşüyor.

## Bulgu 5 — hatalar "bozuk" ucunda yoğunlaşıyor

Bu turdaki üç yanlışın **üçü de bozuk** durumunda (B-bozuk ışıkta,
C-bozuk her iki koşulda). 22 Eylül kağıt turundaki "yanlış ama emin"
vakası da C-bozuk'tu.

İki farklı hata tipi ayırt ediliyor:

- **B-bozuk → P4**: komşu noktaya kayma. Bulgu 3'teki dar hata payıyla
  tutarlı, "beklenen" tip.
- **C-bozuk → P3**: iki nokta uzağa sıçrama. Dar hata payıyla
  açıklanamaz; C'nin çoklu-nokta uydurmasının bilinen kırılganlığıyla
  tutarlı (bkz. `0004`).

## Bu turun sınırları (dürüstlük notu)

- **Ekrandan okundu, kağıttan değil.** Parlama burada ekranın camlı
  yüzeyinden yansıyan oda ışığı; kağıtta (mat yüzey) daha hafif olabilir,
  ama kağıt da kendi ışığını yaymadığı için tek yönlü bir lamba kolayca
  gradyan yaratır. Kağıtta ne olacağı ÖLÇÜLMEDİ.
- Her hücre için **tek okuma** var, tekrar yok — sayılar tek tek
  güvenilir değil, örüntü anlamlı.
- ΔE değerleri kullanıcı tarafından ekrandan okunup aktarıldı.

## Çıkarımlar

1. **Sistem gölgede A/B/C'nin üçünde de doğru çalıştı.** Motor sağlam;
   belirleyici olan ölçüm koşulu.
2. **Nihai A/B/C karşılaştırması kontrollü ışıkta yapılmalı** — aksi
   halde ölçtüğümüz şey yöntem farkı değil, ışık farkı olur. Bu, bugüne
   kadarki tüm A/B/C turlarının (bu tur dahil) en büyük zayıflığı.
3. Uygulama, kötü ölçüm koşulunu **tespit edip reddetmeli** (rapor §7.1
   "dürüst belirsizlik"). Doğru sinyal ΔE değil, doygunluk/clipping
   tespiti. Eşik veriyle konmalı.
4. Profilin hata payı dar (Bulgu 3) ve sinyal-gürültü aynı eksende
   (Bulgu 4) — bu, danışmanla konuşulması gereken **tasarım düzeyinde**
   bir konu: gerçek sensör verisi geldiğinde seviyelerin ayrılabilirliği
   yeniden değerlendirilmeli.
