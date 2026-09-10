# apps/producer — Üretici / Etiket Oluşturma

Rapor §8. **ERP değildir.** Ürün/parti + `sensor_profile_id` + `layout_version`
girdilerinden tekrarlanabilir, sürümlenebilir QR-sensör etiketi üretir.

## Çalıştırma

```bash
pip install -r ../../requirements.txt      # veya repo kökünden: pip install -r requirements.txt
flet run apps/producer/main.py             # repo kökünden
```

## Ne yapıyor (bugün)

- Form → `label_payload` (JSON, §10.1 sözleşmesi, şemaya doğrulanır)
- `packages.qr_layout` ile standart QR (ECC-H) + fonksiyon maskesi + **dağıtılmış**
  reaktif modül seçimi → `layout_version` JSON (§5, koordinatlar dosyada)
- `out/` altına: `*.label_payload.json`, `*.layout_version.json`, `*.png`, `*.pdf`

## Eksik (TODO)

- Reaktif hücrelerin renkli gösterimi + sentetik taze/geçiş/bozulma görselleri
  (`packages/qr_layout/render.py::save_synthetic_states`, Pillow gerekiyor)
- 300 dpi fiziksel ölçek/boyut ayarı
- Profil/sürüm açılır menüsünü `packages/profile_schema/examples/` ile doldurma
- `select_reactive_modules` tam algoritması (bkz. `packages/qr_layout/reactive.py`)
