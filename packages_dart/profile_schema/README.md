# profile_schema (Dart portu)

`packages/profile_schema` (Python) JSON okuma/doğrulamasının Dart'a
taşınmış hâli. Python tarafı genel amaçlı `jsonschema` kütüphanesini
kullanıyordu; burada öyle bir kütüphane YOK (aşırı mühendislik olurdu) —
bu paketteki 3 bilinen şemanın (sensor_profile, layout_version,
label_payload) kuralları `lib/src/validation.dart`'taki küçük yardımcılarla
doğrudan kod olarak uygulanıyor.

## Ne var

- `sensor_profile.dart` — `SensorProfile`, `ScalePointEntry`,
  `CalibrationMethod`, `ClassThresholds`, `QualityGate`.
- `layout_version.dart` — `LayoutVersionData`, `DecoderCheck`.
- `label_payload.dart` — `LabelPayload`.
- `loader.dart` — `parseSensorProfile`/`parseLayoutVersion`/
  `parseLabelPayload` (JSON METNİ alır, dosya YOLU değil — bkz. aşağıdaki
  mimari sapma notu).

Geçerli/geçersiz durumlar gerçek Python `jsonschema` çalıştırılarak
doğrulandı (TAM hata mesajı metni değil — jsonschema'nın birden fazla
ihlalde hangisini önce raporlayacağı kendi iç uygulama detayı, ona
bağlı kalınmadı; hangi İHLAL TÜRLERİNİN yakalandığı doğrulandı). 23/23 test.

## Mimari sapma: dosya okuma YOK

Python `load_sensor_profile(path)` bir dosya YOLU alıyordu. Burada
`parseSensorProfile(jsonText)` JSON METNİ alır — gerçek dosya okuma
platforma özgüdür (Flutter'da `rootBundle.loadString` ya da `dart:io
File`, hedefe göre değişir) ve bu paketin sorumluluğu DEĞİL; çağıran
(uygulama katmanı) dosyayı okuyup metni buraya verir.

## Entegrasyon durumu (23 Eylül)

`packages_dart/color_engine` artık bu pakete BAĞIMLI — `analyzeFrame`
gerçek `SensorProfile`/`LayoutVersionData`'yı doğrudan alıyor.
`LayoutVersionData.sensorModules`'un hücre tipi (`(int row, int col)`,
konumsal kayıt) `color_engine`'in geri kalanında kullanılan isimli kayıt
(`({int row, int col})`) ile AYNI DEĞİL — bu paketin kendi API'sini
değiştirmedik (zaten test edilmişti), dönüşüm `color_engine/pipeline.dart::
_toNamedCell`'de TEK bir yerde yapılıyor.

## Test etme

```
cd packages_dart/profile_schema
dart test
dart analyze
```
