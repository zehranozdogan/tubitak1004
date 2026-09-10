# Ortak Veri Sözleşmesi ve Entegrasyon Kuralları (Rapor §10)

## label_payload — QR içine gömülen içerik (§10.1)

`packages/profile_schema/schema/label_payload.schema.json`

```json
{
  "product_id": "TR45678",
  "product_type": "LEVREK",
  "production_date": "2026-09-10",
  "sensor_profile_id": "GENIPIN_PUTRESIN_v2",
  "layout_version": "QR_SENSOR_v4"
}
```

## sensor_profile (§6.3)

`schema/sensor_profile.schema.json` — alanlar: `profile_id`, `analyte_axis`,
`scale_points[{value, rgb?, lab, state|null}]`, `calibration_method{code, params}`,
`class_thresholds|null`, `quality_gate`, `output_fields`.

> `class_thresholds == null` → uygulama "taze/geçiş/bozuk" göstermez, `technical_level` gösterir.

## layout_version (§5, §8)

`schema/layout_version.schema.json` — alanlar: `layout_version`, `qr_version`,
`matrix_size`, `ecc_level`, `module_density`, `sensor_modules[[r,c]]`,
`reference_regions{name:[[r,c]]}`, `intentional_errors`, `decoder_check`.

## Entegrasyon için zorunlu sözleşmeler (§10.2)

- Üretici, okuyucunun anlayacağı `sensor_profile_id` + `layout_version` üretir.
- QR-layout motoru reaktif/referans koordinatlarını **dosya üzerinden** verir;
  okuyucu kod koordinat gömmez.
- `color_engine.analyze()` standart çıktı döndürür (`ColorEngineResult`):
  `normalized_color`, `lab`, `quality_score`, `matched_profile_point`,
  `freshness_class|None`, `technical_level`, `rescan_recommended`.
- Okuyucu, düşük `quality_score` durumunda sınıf üretmez → taramayı reddeder.
- Her modül bağımsız birim test + ortak entegrasyon testi ile teslim edilir.

## Çalışma kuralları (§9.3)

Tek backlog · yardımcı PR açar, teknik lider merge · haftalık çalışan demo ·
ortak test seti (aynı layout + profil + görseller) · hard-code yok · her testte
telefon/ışık/mesafe/açı/profil/layout sürümü loglanır.
