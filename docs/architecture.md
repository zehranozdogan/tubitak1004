# Hedef Uçtan Uca Mimari (Rapor §3)

## Dört temel bileşen

1. **Sensör / referans girdileri** — fiziksel sensör davranışı, renk skalası, örnek
   fotoğraflar, profile aktarılacak referans değerler.
2. **Üretici / etiket oluşturma** (`apps/producer`) — ürün + parti + sensör profili +
   QR layout sürümünden basılabilir etiket üretir.
3. **Fiziksel akıllı etiket** — standart QR fonksiyon alanları korunur; seçilmiş
   data/ECC modüllerinde **dağıtılmış** reaktif renk hücreleri + sabit kalibrasyon
   referansları.
4. **Tüketici uygulaması** (`apps/consumer`) — QR'ı bulur, geometrik düzeltir, renk
   ölçümünü normalize eder, sensör profiliyle eşleştirir, sonucu gösterir.

## Okuma hattı (§3, §6.2)

```
QR tespiti → homografi/hizalama → kalibrasyon → sensör ROI örnekleme
          → RGB/Lab + ΔE/model → profil ile eşleştirme → TAZELİK / TEKNİK SONUÇ
                                                         (kalite düşükse → "Yeniden tara")
```

## Kod haritası (§3.2)

| Rapor önerisi | Bu repo |
|---|---|
| `/apps/producer` | `apps/producer/` (Flet masaüstü) |
| `/apps/consumer` | `apps/consumer/` (framework spike sonrası — [0002](decisions/0002-framework-spike.md)) |
| `/packages/qr-layout` | `packages/qr_layout/` — QR üretimi + fonksiyon maskesi + reaktif modül |
| `/packages/color-engine` | `packages/color_engine/` — kalibrasyon + ROI + eşleştirme (iskelet) |
| `/packages/profile-schema` | `packages/profile_schema/` — sensor_profile / layout_version / label_payload JSON şemaları |
| `/tests/synthetic` | `tests/synthetic/` — QR/şema/motor birim testleri |
| `/tests/device` | `tests/device/` — telefon/ışık/mesafe/açı protokolü |
| `/docs` | `docs/` |

**Ortak motor kuralı:** veri modeli, QR-layout motoru ve renk motoru `packages/`
altında paylaşılır; `apps/` bunları tüketir. Koordinat / eşik / kalibrasyon
parametreleri koda gömülmez, `profile_schema` dosyalarından okunur.

## Kapsam dışı (§13)

Kullanıcı hesabı, bulut veritabanı, ERP, çoklu fabrika, mağaza paneli,
blockchain/izlenebilirlik, ödeme sistemi, app-store yayını.
