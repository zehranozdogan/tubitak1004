/// packages/profile_schema (Python) JSON okuma/doğrulamasının Dart portu.
/// Genel amaçlı bir JSON Schema motoru DEĞİL — bu paketteki 3 bilinen
/// şemanın (sensor_profile, layout_version, label_payload) kuralları
/// doğrudan kod olarak uygulanır (bkz. lib/src/validation.dart başlığı).
library;

export 'src/validation.dart';
export 'src/sensor_profile.dart';
export 'src/layout_version.dart';
export 'src/label_payload.dart';
export 'src/loader.dart';
