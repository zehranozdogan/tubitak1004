# 0006 — Okuyucu Layout'u Yeniden Türetir (0005'i tamamlar)

**Durum:** KARAR VERİLDİ (24 Eylül 2026, Devrim).

## Sorun

0005 "sensor_profile ve layout_version JSON'ları uygulamayla paketlenir" demişti.
Ama `layout_version` dosyası SABİT hücre listesi içeriyordu
(`QR_SENSOR_v4`: 33x33, 10 hücre). Admin'in ürettiği gerçek etiketler farklı:
QR boyutu payload uzunluğuna göre değişiyor (ör. `TR45678` payload'ı için
v12, 65x65, 75 hücre). Yani paketli sabit dosya hiçbir gerçek etiketle
uyuşmuyordu; okuyucu bir etiketi okuyamazdı.

## Karar

Paketli veri artık sadece bir **tarif** tutar
(`apps/freshqr/assets/reference/<layout_version>.layout_recipe.json`:
`module_density`, `ecc_level`). Okuyucu, QR'dan çözdüğü payload'dan:

1. QR matrisini yeniden üretir (aynı metin -> aynı matris),
2. reaktif hücreleri `layout_version` adından türetilen seed ile aynı Dart
   algoritmasıyla yeniden seçer (`label_export.resolveLabelLayout`),
3. kalibrasyon B/C ise kenar referans yamalarının konumlarını yeniden yazar.

Üretici (admin) ve okuyucu AYNI kodu çalıştırdığı için sunucu/DB/ek QR boyutu
gerekmez. Diğer seçenekler elendi: layout'u QR'a gömmek (QR büyür, baskı
sınırını zorlar), her (layout_version, QR versiyonu) için ayrı dosya paketlemek
(yeni ürün uzunluğu = yeni uygulama sürümü, kırılgan).

## Sonuçlar / kısıtlar

- **Yoğunluk kullanıcı seçimi değil**: layout_version tarifinden gelir (admin
  ekranında salt okunur). Aksi halde okuyucu hangi yoğunlukla basıldığını bilemez.
- Dart RNG (`dart:math`) Python'unkinden farklı: eski Python uygulamasının
  etiketleri bu yöntemle OKUNMAZ. Prototip için kabul edildi.
- Üretici ve okuyucu aynı seçim algoritmasına sahip olmalı: algoritma
  değişirse basılmış eski etiketler bozulur (sürüm disiplini gerekir).
- Hücrelerin açık/koyu bit'i okuyucuda bilindiği için `color_engine`
  sınıf-farkındalıklı okuma yapabiliyor (`analyzeFrame(sensorModuleBits:)`).

## Açık karar (gerçek deney verisi bekliyor)

Sentetik etikette aynı durumun açık/koyu tonu profilde iki farklı derişime denk
düşüyor; eşleştirme şimdilik KOYU sınıfla yapılıyor (sonuç P2/P4/P6). Gerçek
pigment tek renk mi veriyor, iki ton derişimle birlikte mi kayıyor — verisiz
karar verilmedi. Deneyle (pyzbar, sentetik): tek renkli hücreler de QR'ı
okutuyor (ECC-H), ama okuma sınırında iki ton biraz daha sağlam. Gerçek
kamerayla tekrarlanmalı.
