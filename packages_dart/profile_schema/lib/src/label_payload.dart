// label_payload.schema.json'ın Dart portu —
// packages/profile_schema/schema/label_payload.schema.json (rapor §10.1
// ortak veri sözleşmesi — QR içine gömülen makine-okur içerik).

import 'validation.dart';

final RegExp _datePattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');

class LabelPayload {
  final String productId;
  final String productType;
  final String productionDate; // YYYY-MM-DD
  final String sensorProfileId;
  final String layoutVersion;
  final String? profileUri;

  const LabelPayload({
    required this.productId,
    required this.productType,
    required this.productionDate,
    required this.sensorProfileId,
    required this.layoutVersion,
    this.profileUri,
  });

  static const Set<String> _allowedTopLevelKeys = {
    'product_id',
    'product_type',
    'production_date',
    'sensor_profile_id',
    'layout_version',
    'profile_uri',
  };

  factory LabelPayload.fromJson(Map<String, dynamic> json) {
    forbidExtraKeys(json, _allowedTopLevelKeys, 'label_payload');
    requireKeys(
      json,
      ['product_id', 'product_type', 'production_date', 'sensor_profile_id', 'layout_version'],
      'label_payload',
    );

    final productionDate = json['production_date'] as String;
    requirePattern(productionDate, _datePattern, 'label_payload.production_date');

    return LabelPayload(
      productId: json['product_id'] as String,
      productType: json['product_type'] as String,
      productionDate: productionDate,
      sensorProfileId: json['sensor_profile_id'] as String,
      layoutVersion: json['layout_version'] as String,
      profileUri: json['profile_uri'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'product_id': productId,
        'product_type': productType,
        'production_date': productionDate,
        'sensor_profile_id': sensorProfileId,
        'layout_version': layoutVersion,
        if (profileUri != null) 'profile_uri': profileUri,
      };
}
