# 0002 — Tüketici Uygulaması Framework Seçimi

**Durum:** AÇIK — 1. hafta spike ile **doğrulanacak**. Yönelim: **Flutter**.
**Kaynak:** Devir Raporu §10, §13 (Hafta-1)

## Kural

Framework 1. günde sabitlenmez; 1. hafta kısa teknik spike ile karşılaştırılır,
en **risksiz** olan seçilir (§10).

## Analiz — proje dosyasına göre

Tüketici tarafı ağır CV içerir (§6.2): homografi, ROI piksel örnekleme, CIE Lab,
CIEDE2000, ≥2 QR decoder, kalite skoru, offline. Bu gereksinimler ışığında:

| Aday | Kamera ham kare | QR köşe koord. | Görüntü işleme | Offline / build | Sonuç |
|---|---|---|---|---|---|
| **Flutter** | `camera` (`startImageStream`) | `google_mlkit_barcode_scanning` → `cornerPoints` | `opencv_dart` / FFI / `image` | AOT, tek kod tabanı iOS+Android, stabil | **Önerilen** |
| Native Android (Kotlin + CameraX + ML Kit) | En olgun | ML Kit `cornerPoints` | OpenCV Android | En düşük CV riski ama **yalnız Android** + çift kod | Yedek |
| React Native | Zayıf (köprü/native modül) | ML Kit sarmalayıcı | Zayıf | — | Önerilmez |
| Flet (Python) | Mobilde olgun değil | — | — | — | **Sadece bu prototip** (UX inceleme) |

## Şu anki durum

- `apps/consumer/` bir **Flet-web prototipi** içerir (login + admin + user iskeleti).
  Amaç: iki öğrencinin `localhost`'tan UX'i görüp tasarımı netleştirmesi.
  **Bağlayıcı değildir** — gerçek uygulama Flutter/native olacak.
- Ortak `packages/` (qr_layout, color_engine, profile_schema) framework'ten
  bağımsız kalır; JSON sözleşmesiyle bağlanır. Flutter'a geçişte UI yeniden yazılır,
  motor mantığı port edilir (ya da FFI/servis olarak kullanılır).

## Spike çıktısı (Hafta-1 sonu)

- [ ] Flutter + native Android için: kamera akışı + QR köşe + basit ROI okuma mini-denemesi
- [ ] Kriter bazlı puan tablosu (yukarıdaki tablo doldurulur)
- [ ] **Karar** + gerekçe → bu dosya "kabul edildi" yapılır
- [ ] `apps/consumer/` seçilen framework ile yeniden iskeletlenir
