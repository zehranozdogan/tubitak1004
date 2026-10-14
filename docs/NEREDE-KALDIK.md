# Nerede kaldık — devam etmek için okunacak ilk dosya

**Son güncelleme:** 14 Ekim 2026

Bu dosya, projeye yeni katılan (ya da aradan sonra dönen) birinin bağlamı
tek seferde toparlaması içindir. Ayrıntılar için sondaki yönlendirmelere
bakın.

---

## Tek cümleyle

Yazılım çalışıyor ve test edilmiş durumda; **projeyi bekleten şey yazılım
değil, kimya tarafından gelecek iki sayı.**

---

## Şu an çalışan sistem

Flutter uygulaması (`apps/freshqr`) — Android'de gerçek cihazda çalışıyor:

- **Yönetici**: etiket üretir (QR + reaktif hücre yerleşimi + sentetik
  durum görselleri), paylaşır, galeriye kaydeder
- **Kullanıcı**: kamerayla tarar (ML Kit birincil, zxing2 yedek),
  galeriden fotoğraf analiz eder, okuma geçmişi tutar
- **Etiketlerim**: üretilen etiketleri listeler, kamerasız test ettirir

Motor iki dilde: Python referans (`packages/`) + Dart portu
(`packages_dart/`). Ürün tamamen Dart'tır; Python referans/prototip.

**Testler:** Python 136 · qr_layout 57 · color_engine 87 · label_export 26
· freshqr 84. Hepsi geçiyor.

---

## Bekleyen dört iş (sırasıyla)

### 1. Damla çapı → QR tasarımı  ⏳ kimyadan bekleniyor

İndikatör **elle damlatılacak** (planlanan printer temin edilememiş).
Mevcut tasarımda reaktif hücreler tek tek dağıtılmış ve 5 cm etikette
modül **0,68 mm** — bir damla kâğıtta 2–4 mm yayıldığı için bu tasarım
fiziksel olarak uygulanamaz.

Çözüm hazır: hücreler **bitişik bloklara** gruplanacak, blokların içi boş
(beyaz kâğıt) basılıp yalnızca bir modüllük çerçevesi çizilecek — operatör
nereye damlatacağını görsün, indikatör beyaz kâğıda insin diye.

**Gereken tek bilgi: damlanın oluşturduğu lekenin çapı (mm).**

Seçenekler üretilmiş ve her biri doğrulanmış durumda:
- `tests/device/build_qr_options.py` — seçenekleri üretir, QR'ın hâlâ
  çözüldüğünü kontrol eder
- `tests/device/QR_Tasarim_Secenekleri.docx` — gerçek boyutta basılabilir,
  kimya cetvelle ölçüp karar verebilir

Doğrulandı: hem zxing2 hem **ML Kit** bloklu QR'ları çözüyor (blok %13,6'ya
kadar). Mevcut payload biçimiyle (65×65) her damla çapı çalışıyor — **şema
değişikliği gerekmiyor.**

### 2. Tazelik eşikleri  ⏳ kimyadan bekleniyor (deney haftaya)

`GENIPIN_PUTRESIN_v2*` profillerinde `class_thresholds: null`. Bu yüzden
uygulama "Taze/Geçiş/Bozuk" diyemiyor, yalnızca "Renk seviyesi N" gösteriyor
(§7.2: eşik yoksa sınıf uydurulmaz).

**İki tuzak var**, ikisi de kontrol listesinde yazılı:
- `class_thresholds` doldurmak TEK BAŞINA yetmez; altı noktaya `state`
  etiketi de yazılmalı (yoksa yine sınıf çıkmaz)
- Putresin LOD **0,15 mM**; profilin ilk ÜÇ noktası (0,03125 / 0,0625 /
  0,125) bu sınırın ALTINDA, yani fiziksel olarak ayırt edilemez. Ölçek
  yeniden tanımlanmalı.

### 3. Blok tasarımının koda geçirilmesi  → 1 ve 2 gelince

Üç şey **birlikte** değişmeli, biri eksik kalırsa sessiz yanlış okuma olur:

1. Üretici blokları yerleştirsin (`reactive.py` + `reactive.dart`)
2. Okuyucu **aynı** blokları türetsin (ortak sözleşme, karar 0006)
3. **Yeni `layout_version`** verilsin (ör. `QR_SENSOR_v5`)

3. madde şart: sürüm adı değişmezse güncellenmemiş telefonlar yeni etiketi
sessizce yanlış okur. Değişirse dürüstçe reddeder (doğrulandı).

Ayrıca: damla bloğu **tek renge** boyar, QR bitini taşımaz. Bu yüzden
sınıf-farkındalıklı okuma (açık/koyu ayrımı) işlevsiz kalacak — blok başına
tek ölçüm olacak (9 blok = 9 bağımsız örnek, medyan).

### 4. Kalibrasyon yöntemi kararı (A/B/C)  — karar 0004 hâlâ AÇIK

Şimdiye kadarki tüm turlar geçersiz çıktı (sebepleri 0004'te tek tek
yazılı). Baskı testi dosyası hazır: `tests/device/Baski_Testi_v3_ABC.docx`.

**Dikkat:** 3. madde yapılınca ölçülen hücrelerin QR biti kalmayacağı için
yöntemlerin göreli avantajı değişebilir — karşılaştırmayı yeni tasarımla
yapmak daha doğru olabilir.

---

## Bu hafta öğrenilenler (tekrarlanmasın diye)

- **Üretici ve okuyucu aynı motordan olmalı.** Python ve Dart aynı payload
  için farklı QR üretiyor; Python etiketi Dart uygulamasıyla okunamaz.
  Etiketler artık yalnızca Dart'tan üretiliyor.
- **Kalibrasyon yöntemi profilin özelliğidir**, etiketin değil. Okuyucu
  payload'daki `sensor_profile_id` ile paketli profili yükleyip onun
  yöntemini uygular — bu yüzden A/B/C için ayrı profil varyantları var.
- **Sistem kendinden emin yanlış cevap verebiliyor.** Bu hafta üç kez
  yaşandı (uyumsuz etiket, bulanık görüntü, yanlış layout). Eklenen
  korumalar: desen-eşleşme kontrolü, doyma/parlama kontrolü, kalite eşiği
  0,5 → 0,75.
- **ΔE güvenilirlik ölçütü DEĞİL.** Parlamalı yanlış bir okuma ΔE 0,73
  verebildi; gölgedeki doğru okuma 9,69.

---

## Nereye bakmalı

| Konu | Dosya |
|---|---|
| Güncel durum, açık işler, danışman yanıtları | `docs/saha-hazirlik-kontrol-listesi.md` |
| Alınmış kararlar ve gerekçeleri | `docs/decisions/0001–0006` |
| Mimari, çalışan/çalışmayan kısımlar | `README.md` |
| Cihaz test sonuçları | `tests/device/results_*.md` |
| Etiket üretimi (Dart) | `packages_dart/label_export/tool/generate_calibration_labels.dart` |

