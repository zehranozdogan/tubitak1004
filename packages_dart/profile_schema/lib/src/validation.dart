// Küçük, dış bağımlılıksız doğrulama yardımcıları — packages/profile_schema/
// loader.py'nin (Python `jsonschema` kütüphanesini kullanıyordu) Dart
// portu için. Genel amaçlı bir JSON Schema motoru YAZILMADI (aşırı
// mühendislik olurdu) — sadece bu paketteki 3 bilinen şemanın (sensor_
// profile, layout_version, label_payload) kurallarını doğrudan kod olarak
// uygular. Hata TÜRLERİ (zorunlu alan eksik, enum dışı, desen uymuyor,
// aralık dışı, fazladan alan) gerçek Python `jsonschema` çıktısıyla
// karşılaştırılarak doğrulandı — TAM mesaj metni değil (jsonschema'nın
// birden fazla ihlalde hangisini önce raporlayacağı kendi iç uygulama
// detayıdır, buna bağlı kalınmadı).

class SchemaValidationException implements Exception {
  final String message;
  SchemaValidationException(this.message);
  @override
  String toString() => message;
}

void requireKeys(Map<String, dynamic> json, List<String> keys, String context) {
  for (final k in keys) {
    if (!json.containsKey(k)) {
      throw SchemaValidationException("'$k' is a required property ($context)");
    }
  }
}

void forbidExtraKeys(Map<String, dynamic> json, Set<String> allowed, String context) {
  for (final k in json.keys) {
    if (!allowed.contains(k)) {
      throw SchemaValidationException("Additional properties are not allowed ('$k' was unexpected) ($context)");
    }
  }
}

void requireEnum(dynamic value, List<dynamic> allowed, String field) {
  if (!allowed.contains(value)) {
    throw SchemaValidationException("'$value' is not one of $allowed ($field)");
  }
}

void requirePattern(String value, RegExp pattern, String field) {
  if (!pattern.hasMatch(value)) {
    throw SchemaValidationException("'$value' does not match the required pattern ($field)");
  }
}

void requireRange(num value, {num? min, num? max, required String field}) {
  if (min != null && value < min) {
    throw SchemaValidationException('$value is less than the minimum of $min ($field)');
  }
  if (max != null && value > max) {
    throw SchemaValidationException('$value is greater than the maximum of $max ($field)');
  }
}

void requireLength(List<dynamic> value, {int? minItems, int? maxItems, required String field}) {
  if (minItems != null && value.length < minItems) {
    throw SchemaValidationException('$value is too short ($field, min $minItems)');
  }
  if (maxItems != null && value.length > maxItems) {
    throw SchemaValidationException('$value is too long ($field, max $maxItems)');
  }
}

List<double> asDoubleList(dynamic value, String field) {
  if (value is! List) throw SchemaValidationException('$field must be an array');
  return value.map((e) => (e as num).toDouble()).toList();
}

List<int> asIntList(dynamic value, String field) {
  if (value is! List) throw SchemaValidationException('$field must be an array');
  return value.map((e) => (e as num).toInt()).toList();
}
