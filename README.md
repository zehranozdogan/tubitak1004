# QR Kod Tabanlı Akıllı Tazelik Sensörü

Balık ambalajında bozulmayla ilişkili uçucu aminler ve pH değişimi nedeniyle renk
değiştiren **kolorimetrik sensör yüzeyi + QR** etiketini standart bir telefon
kamerasıyla okuyup renk değişimini **nicel** ölçen ve kullanıcıya anlaşılır bir
tazelik sonucu (yoksa teknik renk seviyesi) veren **uçtan uca** prototip.

> Yapı ve kararlar **Öğrenci Teknik Devir Raporu**'na (10 Eylül 2026) göredir.
> Bu, eski uygulamanın devamı değildir — temiz repo, sıfırdan sistem (§2).

## Yapı (Rapor §3.2)

```
apps/
  consumer/     Tek çalışan uygulama (Flet-web prototip):
                login (parolasız) → Yönetici (etiket oluşturma, §8) / Kullanıcı (iskelet)
                Gerçek tüketici app'i: Flutter (docs/decisions/0002)
packages/
  qr_layout/        Standart QR + fonksiyon maskesi + DAĞITILMIŞ reaktif modül (§5)
  color_engine/     Kalibrasyon + ROI + Lab/ΔE + profil eşleştirme (§6) — iskelet
  profile_schema/   sensor_profile / layout_version / label_payload JSON şemaları (§6.3, §10.1)
  label_export/     Etiket paketi üretimi (§8) — framework'ten bağımsız iş mantığı
  ui_kit/           Flet prototipi için ortak tasarım sistemi
tests/
  synthetic/    QR / şema / motor birim testleri (§11 Aşama A çekirdeği)
  device/       Telefon / ışık / mesafe / açı test protokolü (§11 Aşama B)
docs/           Mimari, veri sözleşmesi, ekip planı, kararlar
```

**Ortak motor kuralı:** koordinat / eşik / kalibrasyon parametreleri koda gömülmez;
`packages/profile_schema` dosyalarından okunur. Okuyucu koordinat hard-code etmez (§10.2).

## Kurulum

```bash
python -m venv .venv && source .venv/bin/activate    # Windows: .venv\Scripts\activate
pip install -r requirements.txt

pytest                                # tests/synthetic
flet run -w apps/consumer/main.py     # tek uygulama, tarayıcıda (localhost) açılır
```

## İş bölümü (Rapor §9)

| | Klasör |
|---|---|
| **Öğrenci 1** (teknik lider) | `apps/consumer`, `packages/qr_layout`, `packages/profile_schema`, `packages/label_export`, entegrasyon |
| **Öğrenci 2** (algoritma/doğrulama) | `packages/color_engine`, `tests/device`, kalibrasyon benchmark |
| **Ortak** (iki onay) | `packages/qr_layout/reactive.py`, `packages/ui_kit`, `tests/synthetic`, `docs/`, `pyproject.toml` |

Detay: [docs/team.md](docs/team.md) · Git akışı: `main` korumalı, yardımcı PR açar, teknik lider merge.

## Şu an ne çalışıyor

- ✅ `packages/qr_layout`: QR üretimi, ISO/IEC 18004 fonksiyon maskesi, reaktif aday
  havuzu, mekânsal dağıtılmış modül seçimi (basit sürüm), `layout_version` JSON
- ✅ `packages/profile_schema`: 3 JSON şeması + örnekler + doğrulamalı yükleyici
- ✅ `packages/label_export` + **Yönetici** ekranı (`apps/consumer`): form →
  `label_payload` + `layout_version` + PNG/PDF/JSON `out/`
- ✅ `packages/qr_layout/render.py`: reaktif hücrelerin **renkli** gösterimi
  (Pillow) — taze/geçiş/bozuk sentetik görseller; her modül kendi açık/koyu
  sınıfını korur (§5.2), QR okunabilirliği bozulmaz
- ✅ `tests/synthetic`: QR/şema/motor/render testleri + **decode doğrulaması**
  (§11 Aşama A) — renklendirilmiş QR'lar gerçek bir decoder (OpenCV) ile
  3 yoğunluk × 4 renk durumunda okunuyor mu, otomatik test ediliyor
- 🚧 `packages/color_engine`: sözleşme + akış iskeleti; gerçek görüntü işleme TODO
- 🚧 `apps/consumer` **Kullanıcı** ekranı: iskelet, doldurulacak; gerçek tüketici
  uygulamasının framework'ü **Flutter** yönelimli, spike ile kesinleşir
  ([docs/decisions/0002](docs/decisions/0002-framework-spike.md))

## Açık kararlar

- **Framework** (tüketici): React Native / Flutter / native — Hafta-1 spike ([0002](docs/decisions/0002-framework-spike.md))
- **Kalibrasyon yöntemi**: §6.1 A–E karşılaştırması → `packages/color_engine/calibration.py`
- **Reaktif modül algoritması**: `packages/qr_layout/reactive.py` başlığındaki TODO listesi
- **Tazelik eşikleri**: bilimsel ground-truth gelene kadar `class_thresholds: null` → teknik seviye gösterilir (§7.2)

## Kapsam dışı (§13)

Kullanıcı hesabı / login, bulut veritabanı, ERP, çoklu fabrika, mağaza paneli,
blockchain, ödeme, app-store yayını.

## Kaynaklar

Onaylı proje dosyası: *Su Ürünlerinin Tazeliğinin Takibine Yönelik QR Kod Tabanlı
Akıllı Ambalaj Etiketi Geliştirilmesi* (TÜBİTAK 1004). Ayrıca Benito-Altamirano ve
ark. (2023/2024) back-compatible color QR çalışmaları; ColorSensing yaklaşımı.
