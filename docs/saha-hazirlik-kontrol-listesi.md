# Sahaya çıkmadan önce — durum denetimi ve yapılacaklar

**Tarih:** 2 Ekim 2026. Tüm bileşenler (Python motoru, Dart portu, Flutter
uygulaması, görüntü işleme zinciri) gözden geçirilerek hazırlandı.

## Özet

Yazılım tarafı büyük ölçüde hazır: motor çalışıyor, uygulama çalışıyor,
testler yeşil (Python 136, Dart paketleri 182, Flutter 73 — toplam 391).
**Sahaya çıkmayı engelleyen şey yazılım değil, bilimsel veri eksikliği.**
Uygulama şu an "Profil noktası P4" diyebiliyor ama "bu balık bozulmuş"
diyemiyor — çünkü o eşikler henüz ölçülmedi.

Aşağıdaki liste üç gruba ayrıldı: **(A) sahaya çıkmayı engelleyenler**,
**(B) saha öncesi yapılması gerekenler**, **(C) sonraya kalabilecekler**.

---

## A. Sahaya çıkmayı ENGELLEYENLER

### A1. Tazelik eşikleri yok — uygulama sınıf üretemiyor

> **⚠️ EŞİKLER GELİNCE KONTROL EDİLECEK (4 Ekim'de bulundu):**
> `class_thresholds` alanını doldurmak TEK BAŞINA YETMEZ. Motor sınıfı,
> ölçülen renge en yakın profil noktasının **kendi `state` etiketinden**
> alıyor (`matching.dart::matchProfilePoint`); `class_thresholds` ise
> yalnızca bir açma/kapama anahtarı gibi davranıyor (`hasClassThresholds`)
> — içindeki `fresh_max` / `transition_max` sayıları ŞU AN HİÇ
> KULLANILMIYOR.
>
> GENIPIN profillerinde altı noktanın da `state` değeri `null`. Yani
> sadece `class_thresholds` yazılırsa **yine sınıf üretilmez**.
>
> Laboratuvardan gelmesi gereken asıl bilgi: altı derişim noktasından
> (0.03125 / 0.0625 / 0.125 / 0.25 / 0.5 / 1.0 mM putresin) hangileri
> taze, hangileri geçiş, hangileri bozuk sayılıyor.
>
> İki seçenek:
> 1. **Etiketleme** — `class_thresholds`'u doldur ve altı noktaya `state`
>    yaz. İki satırlık iş, mevcut kodla çalışır.
> 2. **Gerçek eşik mantığı** — `fresh_max`/`transition_max` sayılarını
>    kullanıp sınıfı derişimden hesapla. Daha doğru (ara değerlerde de
>    çalışır) ama kod değişikliği + Python tarafıyla eşitleme gerektirir.
>
> Referans: DEMO_QR_STATE_COLORS_v1 bunun çalışan örneği — hem
> `class_thresholds` dolu hem noktalar `fresh/transition/spoiled` etiketli.
`GENIPIN_PUTRESIN_v2` profilinde `class_thresholds: null`. Bu yüzden
`freshness_class` üretilmiyor; kullanıcı "Taze / Geçiş / Bozuk" yerine
"Renk seviyesi 4 / Profil noktası P4" görüyor (rapor §7.2'nin bilinçli
kuralı: bilimsel eşik yoksa sınıf UYDURULMAZ).

Sahada bir denetçi/balıkçı "P4" ile işlem yapamaz. Bu, listedeki **en
kritik eksik** ve çözümü yazılımda değil laboratuvarda: TVB-N ölçümü ya
da duyusal panel ile ground-truth üretilip eşiklerin belirlenmesi gerekiyor.

> İyi haber: eşikler profile eklendiği anda **kod değişmeden**
> `freshness_class` dolu gelir ve ekran otomatik sınıf göstermeye başlar.
> Zincir buna hazır.

### A2. Profil renkleri gerçek ölçüm değil
Profildeki 6 renk noktası (P1–P6) varsayılan değerler — gerçek mürekkebin
gerçek putresin konsantrasyonlarına verdiği tepkiden ölçülmedi. Renk →
tazelik eşlemesinin tamamı bu sayılara dayanıyor.

### A3. Gerçek reaktif mürekkep/baskı yok
Etiketler normal yazıcı mürekkebiyle, durumlar **simüle edilerek**
basılıyor. Gerçek pigment reaksiyonu kimya tarafının kapsamında ve henüz
doğrulanmadı. Sahada okunacak şey gerçek reaksiyon olacağı için, mevcut
tüm doğrulamalar "simülasyon üzerinde" geçerli.

> **⏸️ DANIŞMANA SORULACAK (6 Ekim) — reaktif maddenin baskıya nasıl
> uygulanacağı**
>
> Şu anki "basılacak dosya" reaktif hücreleri **nötr gri** çiziyor. Ama
> gerçek üretimde oraya reaktif madde uygulanacak; mürekkep grinin üstüne
> gelirse renk kirlenir, çünkü profildeki referans renkler BEYAZ kağıt
> üzerinde tanımlı.
>
> Bu amaçla iki katmanlı bir çıktı geliştirildi (baskı ustası: reaktif
> hücreler boş + reaktif katman maskesi: maddenin uygulanacağı hücreler),
> sonra **bilinçli olarak geri alındı** — karar danışmanla verilecek.
> Geri getirmek için: `git revert` ile `15d624c`, `7ffe08d`, `041977f`
> commit'lerinin revert'leri tersine çevrilir (kod ve testler hazır).
>
> **Geri almanın sebebi, çözülmemiş iki soru:**
>
> 1. **Hizalama.** 5cm etikette 73 modül var → modül başına **~0.68 mm**;
>    reaktif maddenin hücre içinde kalması için kayma **~0.3 mm'yi**
>    geçmemeli. Tek baskı makinesinde çok mürekkepli geçişte kayma
>    0.05–0.1 mm (sorun yok); kağıdı çıkarıp tekrar beslemede ya da elle
>    hizalamada 0.5–2 mm (olmaz). Yani iki ayrı işlem olarak YAPILAMAZ.
> 2. **Üretim gerçekliği.** Etiketleri kimin, hangi makineyle basacağı
>    belirlenmeden doğru çıktı biçimi seçilemez.
>
> **Danışmana sorulacak asıl soru:** reaktif madde, QR ile **aynı baskı
> geçişinde** (ayrı mürekkep kanalı olarak) uygulanabiliyor mu?
>
> - **Evet** ise: iki katmanlı çıktı geri getirilir, mevcut tasarım korunur.
> - **Hayır** ise: reaktif hücreleri QR'ın içine serpiştirmek yerine,
>   QR'ın yanında **tek parça reaktif alan** kullanmak gündeme gelir.
>   Hizalama toleransı milimetreye çıkar ve QR saf siyah-beyaz kalır — ama
>   bu, raporun §5.2'sindeki "QR'ın kendisinin sensör olması" fikrini
>   değiştirir, yani tasarım düzeyinde bir karardır.

---

## B. Saha ÖNCESİ yapılması gerekenler

### B1. Kalibrasyon yöntemi kararı (0004 hâlâ AÇIK)
A/B/C karşılaştırması **doğru (Dart) etiketlerle, kontrollü ışıkta, gerçek
baskıda** sıfırdan tekrarlanmalı. Önceki tüm turlar geçersiz:
- 17 Eylül turu: ekrandan fotoğraf
- 22 Eylül turu: kenar yaması border hatası vardı (Python tarafı hâlâ açık)
- 30 Eylül turu: etiketler Python motoruyla üretilmişti (uyumsuz)

Test etiketleri: `dart run tool/generate_calibration_labels.dart`
(`packages_dart/label_export` içinden).

### B2. ✅ YAPILDI (2 Ekim) — Işık/parlama tespiti
Parlama altında ölçüm bozuluyor ama uygulama bunu fark etmiyor; üstelik
ΔE güvenilir bir gösterge değil (parlamalı yanlış okuma ΔE=0.73 verebildi).
Mevcut köşe-tutarlılığı (cv) göstergesi doygunluğu yakalamıyor.

**Eklendi:** reaktif hücrelerin doyma (clipping) oranı ölçülüyor —
DÜZELTİLMEMİŞ görüntüden, çünkü doyma yakalanan verinin özelliği,
kalibrasyon geri getiremez. Beyaz REFERANS 255 olabilir (normaldir), bu
yüzden sadece reaktif hücrelere bakılıyor: en açık profil noktası bile
(214,205,196) 250'nin altında, dolayısıyla 250+ okunan bir reaktif hücre
yanmış demektir. Yarısı yanmışsa → yeniden tara; %20'de bilgi notu.

Eşikler ilke bazlı (ince ayar değil): yarısı yanmışsa ölçüm nesnel olarak
yok olmuştur. **Gerçek parlama fotoğraflarıyla ince ayar hâlâ yapılmalı.**

### B3. ✅ YAPILDI (2 Ekim) — Eşleşmeyen etiket tespiti
**Eklendi:** okunan QR, payload'dan yeniden üretilen desenle
karşılaştırılıyor; uyum %80'in altındaysa sonuç ÜRETİLMİYOR, "yeniden
tara" deniyor. Pahalı olan köşe arama/ince ayardı (`e6a80a3` → `443ba8e`),
bu kontrol değil — arama yok, her 2 modülde bir tek örnekleme var.

Eşik tahmin değil: doğru etikette ~1.00, uyumsuz etikette ~0.55 ölçüldü.
Dokuz gerçek etikette yanlış alarm vermediği doğrulandı.

### B4. Cihaz çeşitliliği
Yalnızca 2 Android cihazda test edildi (Samsung Galaxy S21, Redmi Note 9).
Sahada farklı kamera/ekran/Android sürümleri olacak. En az 4–5 farklı
cihazda, özellikle **düşük segment** telefonlarda doğrulanmalı.

iOS: kod yolları var (`bgraLumaDownsampled` vb.) ama **hiç derlenmedi/
test edilmedi**. iPhone kullanılacaksa ayrı bir doğrulama turu gerekir.

### B5. Saha test protokolü
Şu an her test farklı koşulda yapılıyor (mesafe, açı, ışık, ekran/kağıt)
— bu yüzden sonuçlar karşılaştırılamıyor ve iki gün bu yüzden kaybedildi.
Sahaya çıkmadan **sabit bir protokol** yazılmalı: mesafe, açı, ışık
koşulu, tekrar sayısı, kayıt formu.

### B6. Yönetici girişi için parola/yetki (PLANLANDI)
Giriş ekranı şu an sadece rol seçimi yapıyor, parola istemiyor
("Prototip — parola istenmez", `screens/login_screen.dart`). Yönetici rolü
etiket üretebildiği (ve dolayısıyla sahte etiket üretilebileceği) için
saha kullanımında parola/yetki kontrolü gerekli. **Eklenmesi planlandı.**

### B7. İmzalama ve dağıtım
`android/app/build.gradle.kts` hâlâ **debug anahtarıyla** imzalıyor
("TODO: Add your own signing config"). Saha dağıtımı için gerçek bir
release imzası gerekli; aksi halde kurulum uyarıları ve güncelleme
sorunları çıkar.

---

## C. Sonraya kalabilecekler

### C1. Kayıt/izlenebilirlik
Okumalar yalnızca cihazda yerel `scan_history.json`'a yazılıyor. Merkezi
kayıt, denetim izi veya parti takibi gerekiyorsa DB kararı açılmalı
(0003 AÇIK; 0005 şimdilik "DB yok" diyor).

### C2. Yeni etiket sürümleri
Profil ve layout tarifleri uygulamaya **paketli** geliyor. Sahada yeni bir
`layout_version` ile basılmış etiket çıkarsa uygulama onu okuyamaz
(`Bilinmeyen profil/layout` der — yani sessizce yanlış yapmaz, bu doğru
davranış). Etiket sürümü değişecekse uygulama güncellemesi gerekir.

### C3. Kullanıcı yönlendirmesi
Tarama ekranında tek satır ipucu var ("QR kodu çerçeveye alın"). Işık ve
mesafe kritik olduğuna göre, sahada kullanacak kişiye kısa bir görsel
yönerge faydalı olur.

### C4. Python/Dart motor ayrışması
İki motor aynı payload için farklı QR üretiyor. **Karar verildi:** etiketler
yalnızca Dart'tan üretilecek, Python referans/prototip kalacak (bkz. 0004).
Python bir gün gerçek etiket üretecekse bu düzeltilmeli.

---

## Durum tablosu

| Alan | Durum |
|---|---|
| Python referans motoru | ✅ Çalışıyor (136 test) |
| Dart portu | ✅ Çalışıyor (182 test) |
| Flutter uygulaması | ✅ Çalışıyor (73 test) |
| Kamera / QR okuma | ✅ ML Kit + zxing2 yedek, donma yok |
| Etiket üretimi | ✅ Dart, okuyucuyla uyumlu |
| Kalite kapısı | ✅ Uygulanıyor (`min_quality_score`) |
| Eşleşmeyen etiket koruması | ✅ Var |
| Kalibrasyon yöntemi | ⚠️ Karar verilmedi (0004) |
| Parlama/ışık koruması | ✅ Var (ince ayar bekliyor) |
| Tazelik eşikleri | ❌ Yok — **saha engeli** |
| Gerçek mürekkep/profil | ❌ Yok — **saha engeli** |
| İmzalama | ❌ Debug anahtarı |
| Kimlik doğrulama | ⚠️ Yok — eklenmesi planlandı |
