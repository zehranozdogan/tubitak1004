// JSON metninden doğrulanmış nesneler üretir —
// packages/profile_schema/loader.py'nin Dart portu.
//
// MİMARİ SAPMA: Python dosya YOLU alıyordu (`open(path)`); burada JSON
// METNİ alınır — gerçek dosya okuma platforma özgü bir iştir (Flutter'da
// `rootBundle.loadString` ya da `dart:io File`, platforma göre değişir)
// ve bu paketin sorumluluğu DEĞİL; çağıran taraf dosyayı okuyup metni
// buraya verir.

import 'dart:convert';

import 'label_payload.dart';
import 'layout_version.dart';
import 'sensor_profile.dart';

SensorProfile parseSensorProfile(String jsonText) {
  return SensorProfile.fromJson(json.decode(jsonText) as Map<String, dynamic>);
}

LayoutVersionData parseLayoutVersion(String jsonText) {
  return LayoutVersionData.fromJson(json.decode(jsonText) as Map<String, dynamic>);
}

LabelPayload parseLabelPayload(String jsonText) {
  return LabelPayload.fromJson(json.decode(jsonText) as Map<String, dynamic>);
}
