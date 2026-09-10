# apps/consumer — Tüketici Uygulaması

Rapor §7. Etiketi kolay okutup **doğrulanmış bir tazelik sonucu** (yoksa teknik
renk seviyesi) veren uygulama.

## Framework — proje dosyasına göre öneri

Karar 1. hafta spike ile kesinleşir; **yönelim Flutter**. Ayrıntı ve gerekçe:
[`../../docs/decisions/0002-framework-spike.md`](../../docs/decisions/0002-framework-spike.md)

| | Neden |
|---|---|
| **Flutter** (önerilen) | `camera` ham kare + ML Kit barkod `cornerPoints` + OpenCV/FFI; tek kod tabanı iOS+Android; AOT performans; stabil build; offline |
| Native Android (Kotlin + CameraX + ML Kit) | Yedek — en düşük CV riski ama yalnız Android + çift kod |

## Bu klasördeki prototip (Flet-web) — BAĞLAYICI DEĞİL

Şu an burada **UX prototipi** var: iki öğrencinin `localhost`'tan tasarımı görüp
netleştirmesi için. Gerçek uygulama Flutter/native ile yazılacak; ortak
`packages/` (qr_layout, color_engine, profile_schema) framework'ten bağımsız kalır.

### Çalıştırma (arkadaşın da yapacağı)

```bash
git pull
python -m venv .venv && source .venv/bin/activate     # Windows: .venv\Scripts\activate
pip install -r requirements.txt
flet run -w apps/consumer/main.py                      # tarayıcıda açılır (localhost)
```

- Farklı port istersen: `flet run -w -p 8551 apps/consumer/main.py`
- Masaüstü penceresi: `flet run apps/consumer/main.py`
- Hardcode yok: yollar `Path(__file__)`'e göre; profil/sürüm bilgisi
  `packages/profile_schema/examples/` dosyalarından okunur.

### Ekranlar

Routing yok (Flet 0.86 uyumu): tek sayfa, içerik değişimi (`consumer/app.py` → `_Nav`).

| Ekran | Dosya | Ne |
|---|---|---|
| Giriş | `consumer/views/login_view.py` | Parola yok; **Yönetici** / **Kullanıcı** kutucuğu → ilgili ekran |
| Yönetici | `consumer/views/admin_view.py` | Basit panel — yüklü profil/sürüm bilgisi (dosyadan okunur) |
| Kullanıcı | `consumer/views/user_view.py` | **İSKELET** — arkadaş bunu geliştirecek |

### Arkadaş için

- Tasarım sistemi (producer ile ORTAK): [`packages/ui_kit/theme.py`](../../packages/ui_kit/theme.py)
  (renk/boşluk/yazı — çıplak sayı kullanma)
- Hazır bileşenler: [`packages/ui_kit/components.py`](../../packages/ui_kit/components.py) —
  `screen`, `app_header`, `section_card`, `kv`, `stat_card`, `nav_tile`, `text_field`, `primary_button`
- `consumer/views/user_view.py`'yi bu bileşenlerle doldur. Tarama akışı: kamera → QR decode →
  `packages/profile_schema` ile profil/layout yükle → `packages/color_engine.analyze()` → sonuç
- **Sonuç ekranı kuralı (§7.2):** `class_thresholds` yoksa "taze/geçiş/bozuk" gösterme,
  `technical_level` göster. Sınıflar: Taze / **Geçiş** / Bozuk.
