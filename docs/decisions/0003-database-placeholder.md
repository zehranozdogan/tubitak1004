# 0003 — Veritabanı Entegrasyonu (yer tutucu)

**Durum:** AÇIK — DB seçimi ve şema henüz yapılmadı. Bu belge, ne zaman DB'ye
geçilirse kodun hangi noktalarının değişeceğini işaretlemek için var.

## Şu an her şey dosya tabanlı

| Veri | Şu an nerede | Fonksiyon |
|---|---|---|
| Kalibrasyon profilleri | `packages/profile_schema/examples/*.sensor_profile.json` | `consumer/profiles.py::load_sensor_profiles` |
| Etiket sürümleri | `packages/profile_schema/examples/*.layout_version.json` | `consumer/profiles.py::load_layout_versions` |
| Üretilen etiketler | `out/*.json`, `*.png`, `*.pdf` | `packages/label_export/export.py::export_label` |
| Parti no sayacı | `out/` klasörü taranarak | `admin_view.py::_next_batch_no` |
| Tarama kayıtları (ileride) | henüz yok — `color_engine` sonucu hiçbir yere kaydedilmiyor | — |

## Kural: imza sabit kalsın

Yukarıdaki her fonksiyonun **girdi/çıktı tipi** (ör. `list[dict]`, `str`,
`{"qr","layout","paths"}` anahtarları) korunursa, gövdesi dosya işleminden DB
sorgusuna değiştiğinde çağıran kod (`admin_view.py`, ekranlar) **hiç
değişmeden** çalışmaya devam eder. Yani DB entegrasyonu bu dosyaların
içini değiştirmek olacak, ekranları değil.

## DB seçildiğinde yapılacaklar (özet)

1. `consumer/profiles.py`: dosya taramasını DB sorgusuna çevir.
2. `admin_view.py::_next_batch_no`: DB'de otomatik artan sütun veya sayaç
   tablosuna çevir (dosya taraması kaldırılır).
3. `packages/label_export/export.py::export_label`: dosya yazımına ek olarak
   `batches` tablosuna kayıt ekle.
4. Tüketici tarama akışı (§7) geliştirilince: `packages/color_engine`
   sonuçlarını kaydedecek bir `scans` tablosu/fonksiyonu eklenir.
5. `packages/profile_schema` JSON şemaları **kalır** — DB şeması da bu
   alanlara (profile_id, layout_version, scale_points, sensor_modules, …)
   dayanmalı; şema tek doğruluk kaynağı olmaya devam eder.
