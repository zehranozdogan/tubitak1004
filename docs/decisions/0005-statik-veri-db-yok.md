# 0005 — Veri Dağıtımı: Statik/Paketli (Bundled), DB YOK

**Durum:** KARAR VERİLDİ (22 Eylül 2026, danışmanla görüşme sonrası).

## Soru neydi

Tüketici tarafı bir ürünün `sensor_profile` (renk skalası, kalibrasyon
yöntemi, eşikler) ve `layout_version` (reaktif hücre yerleşimi, referans
bölgeleri) verisine ihtiyaç duyuyor — ama bunları ÜRETEN taraf (etiketi
basan) ile OKUYAN taraf (markette bir yabancının telefonu) FİZİKSEL OLARAK
FARKLI CİHAZLAR. Yabancının telefonunda üreticinin yerel `out/` klasörü
yok. Bu veriye nasıl erişecek: bulut DB mi, yoksa uygulamayla birlikte mi
paketlensin (statik/bundled)?

## Karar: statik paketleme, DB yok

`sensor_profile` ve `layout_version` JSON dosyaları uygulamanın kendisiyle
birlikte paketlenir (Flet prototipinde `packages/profile_schema/examples/`,
Flutter'a geçince uygulama içi asset/bundle). Okuyucu QR'dan decode ettiği
`sensor_profile_id` / `layout_version` STRING'ini bu paketlenmiş dosyaları
aramak için anahtar olarak kullanır — uzak bir sunucuya/DB'ye hiç gitmez.

## Neden rapora uygun (raporla çelişmiyor, aksine örtüşüyor)

- **§13.1, Definition of Done altındaki "Kapsam dışı" tablosu:** "Kullanıcı
  hesabı, **bulut veritabanı**, ERP, ... bu prototipin zorunlu kapsamı
  değildir." — bulut DB zaten zorunlu değil, kullanmamak kapsamın dışına
  çıkmak değil.
- **§6.3 Sensör profili:** asıl gereksinim DB değil, "koda gömülmemek":
  "Renk skalası, sınıf eşikleri, layout koordinatları ve kalibrasyon
  parametreleri **kod içine gömülmemelidir**... yalnızca yeni profil
  eklenir." Statik ama KODUN DIŞINDA, ayrı/değiştirilebilir bir JSON dosyası
  bu gereksinimi birebir karşılıyor — "kod içine gömmemek" ile "DB'de
  tutmak" aynı şey değil.
- Zaten var olan desenle (`packages/profile_schema` — profiller Python
  koduna değil ayrı JSON dosyalarına yazılıyor) birebir tutarlı; Flutter'a
  taşınırken bu JSON dosyaları uygulama içi asset olarak paketlenecek,
  mimari değişmiyor.

## Bilinçli ödün (trade-off)

Yeni bir `layout_version`/`sensor_profile_id` üretime alınacaksa, karşılık
gelen JSON dosyasının önce OKUYUCU UYGULAMAYA da paketlenmesi (yani yeni
bir uygulama sürümü/güncellemesi) gerekir — sunucudan anlık çekme yok.
Prototip ölçeğinde (birkaç sensör profili, birkaç layout sürümü) bu kabul
edilebilir; ileride çok sayıda/sık değişen profil olursa (§14 kapsam dışı
büyümesi) DB'ye geçiş gerekebilir — bkz. `0003-database-placeholder.md`
(bu belge iptal edilmiyor, sadece şu an tetiklenmiyor).

## Kod tarafında ne değişti (22 Eylül 2026)

`apps/consumer/consumer/views/user_view.py::on_file_scan` gerçek boşluğu
gösteriyordu: `layout_version`'ı QR'dan decode edilen payload'tan DEĞİL,
test-harness'e özel `OUT_DIR`/`stem` yolundan okuyordu — bu SADECE aynı
makinede üretilmiş etiketler için çalışır, gerçek bir yabancı telefon için
anlamsız. Düzeltildi: artık `payload["layout_version"]` ile (sensor_profile
zaten öyle yapıyordu) `PROFILE_EXAMPLES_DIR` (paketlenmiş referans)
içinden aranıyor. `OUT_DIR` hâlâ kullanılıyor ama SADECE test görüntüsünün
(kamera yerine geçen dosya) kendisini okumak için — referans veri için
değil.

Admin (üretici) ekranı zaten yalnızca `load_layout_versions()`'ın
(`EXAMPLES_DIR` taraması) döndürdüğü sürümleri sunuyordu — yani üretilen
her etiketin `layout_version`'ı zaten paketli örnekler arasında olmak
zorunda; bu düzeltme üretici tarafıyla artık tutarlı.

## Bilinen sınır (henüz çözülmedi, kalibrasyon kararına bağlı)

`packages/profile_schema/examples/QR_SENSOR_v4.layout_version.json` TEK bir
STATİK anlık görüntü: `module_density="low"`, `reference_regions` sadece
`{white, black}` (yöntem A). Bu, admin ekranının BUGÜNKÜ varsayılanıyla
(GENIPIN_PUTRESIN_v2 → `white_black`, density="low") tutarlı. AMA aynı
`layout_version` ("QR_SENSOR_v4") ile biri farklı yoğunlukta ya da B/C
kalibrasyon yöntemiyle etiket basıp üretime sokarsa, bu bundled dosya
GÜNCELLENMEDEN tüketici okuyucusu (§6.1 B/C'nin ekstra referans yamalarını
göremeyeceği için) sessizce A'ya düşer (zaten var olan fallback mantığı,
bkz. `test_pipeline_reference_wiring.py`) — ÇÖKMEZ ama beklenenden zayıf
kalibrasyon kullanır. Kalibrasyon yöntemi (bu baskı testinin sonucuna göre)
kesinleşince bu örnek dosya SON haliyle yeniden üretilmeli — o zamana kadar
bilinen bir sınır olarak burada not edildi.

## Flutter'a geçince yapılacaklar (özet)

1. `packages/profile_schema/examples/*.json` dosyaları Flutter uygulama
   asset'i olarak paketlenir (`pubspec.yaml` assets girişi).
2. QR decode edilince `sensor_profile_id`/`layout_version` string'iyle bu
   asset'ler arasında dosya adı eşleştirmesiyle arama yapılır (bu belgedeki
   Python tarafındaki mantığın birebir Dart karşılığı).
3. Şema doğrulama (`profile_schema/schema/*.json`) Dart tarafında da aynı
   JSON Schema dosyalarıyla tekrarlanabilir (tek doğruluk kaynağı olarak
   şema dosyaları kalır, `0003`'teki ilke).
