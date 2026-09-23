// sensor_profile.schema.json'ın Dart portu —
// packages/profile_schema/schema/sensor_profile.schema.json.

import 'validation.dart';

final RegExp _idPattern = RegExp(r'^[A-Za-z0-9_.-]+$');
const List<String> calibrationCodes = [
  'white_black',
  'white_gray_black',
  'multicolor_patch',
  'qr_fixed_regions',
  'algorithmic_white_balance',
  'learned',
];
const List<String?> stateEnum = ['fresh', 'transition', 'spoiled', null];
const List<String> outputFieldEnum = [
  'state',
  'analyte',
  'confidence',
  'delta_e',
  'technical_level',
  'estimated_ph',
  'estimated_amine',
  'freshness_percent',
  'shelf_life_days',
];

class ScalePointEntry {
  final double value;
  final List<double>? rgb;
  final List<double> lab;
  final String? state;

  const ScalePointEntry({required this.value, this.rgb, required this.lab, this.state});

  factory ScalePointEntry.fromJson(Map<String, dynamic> json) {
    forbidExtraKeys(json, {'value', 'rgb', 'lab', 'state'}, 'scale_points[]');
    requireKeys(json, ['value', 'lab'], 'scale_points[]');
    final lab = asDoubleList(json['lab'], 'scale_points[].lab');
    requireLength(lab, minItems: 3, maxItems: 3, field: 'scale_points[].lab');

    List<double>? rgb;
    if (json['rgb'] != null) {
      rgb = asDoubleList(json['rgb'], 'scale_points[].rgb');
      requireLength(rgb, minItems: 3, maxItems: 3, field: 'scale_points[].rgb');
      for (final c in rgb) {
        requireRange(c, min: 0, max: 255, field: 'scale_points[].rgb[]');
      }
    }

    final state = json['state'] as String?;
    requireEnum(state, stateEnum, 'scale_points[].state');

    return ScalePointEntry(
      value: (json['value'] as num).toDouble(),
      rgb: rgb,
      lab: lab,
      state: state,
    );
  }
}

class CalibrationMethod {
  final String code;
  final Map<String, dynamic>? params;

  const CalibrationMethod({required this.code, this.params});

  factory CalibrationMethod.fromJson(Map<String, dynamic> json) {
    requireKeys(json, ['code'], 'calibration_method');
    final code = json['code'] as String;
    requireEnum(code, calibrationCodes, 'calibration_method.code');
    return CalibrationMethod(code: code, params: json['params'] as Map<String, dynamic>?);
  }
}

class ClassThresholds {
  final double? freshMax;
  final double? transitionMax;
  final String? metric;

  const ClassThresholds({this.freshMax, this.transitionMax, this.metric});

  factory ClassThresholds.fromJson(Map<String, dynamic> json) {
    forbidExtraKeys(json, {'fresh_max', 'transition_max', 'metric'}, 'class_thresholds');
    return ClassThresholds(
      freshMax: (json['fresh_max'] as num?)?.toDouble(),
      transitionMax: (json['transition_max'] as num?)?.toDouble(),
      metric: json['metric'] as String?,
    );
  }
}

class QualityGate {
  final double minQualityScore;

  const QualityGate({this.minQualityScore = 0.5});

  factory QualityGate.fromJson(Map<String, dynamic> json) {
    forbidExtraKeys(json, {'min_quality_score'}, 'quality_gate');
    final raw = json['min_quality_score'];
    if (raw == null) return const QualityGate();
    final value = (raw as num).toDouble();
    requireRange(value, min: 0, max: 1, field: 'quality_gate.min_quality_score');
    return QualityGate(minQualityScore: value);
  }
}

/// packages/profile_schema/schema/sensor_profile.schema.json'ın Dart portu
/// (rapor §6.3). `classThresholds` null ise: bilimsel eşik yok -> §7.2
/// gereği uygulama sınıf göstermez.
class SensorProfile {
  final String profileId;
  final String analyteAxis;
  final List<ScalePointEntry> scalePoints;
  final CalibrationMethod calibrationMethod;
  final ClassThresholds? classThresholds;
  final QualityGate qualityGate;
  final List<String> outputFields;

  const SensorProfile({
    required this.profileId,
    required this.analyteAxis,
    required this.scalePoints,
    required this.calibrationMethod,
    this.classThresholds,
    this.qualityGate = const QualityGate(),
    required this.outputFields,
  });

  static const Set<String> _allowedTopLevelKeys = {
    'profile_id',
    'analyte_axis',
    'scale_points',
    'calibration_method',
    'class_thresholds',
    'quality_gate',
    'output_fields',
  };

  factory SensorProfile.fromJson(Map<String, dynamic> json) {
    forbidExtraKeys(json, _allowedTopLevelKeys, 'sensor_profile');
    requireKeys(
      json,
      ['profile_id', 'analyte_axis', 'scale_points', 'calibration_method', 'output_fields'],
      'sensor_profile',
    );

    final profileId = json['profile_id'] as String;
    requirePattern(profileId, _idPattern, 'sensor_profile.profile_id');

    final scalePointsJson = json['scale_points'] as List;
    requireLength(scalePointsJson, minItems: 2, field: 'sensor_profile.scale_points');
    final scalePoints = scalePointsJson
        .map((e) => ScalePointEntry.fromJson(e as Map<String, dynamic>))
        .toList();

    final outputFields = (json['output_fields'] as List).map((e) => e as String).toList();
    for (final f in outputFields) {
      requireEnum(f, outputFieldEnum, 'sensor_profile.output_fields[]');
    }

    final classThresholdsJson = json['class_thresholds'];
    final classThresholds = classThresholdsJson == null
        ? null
        : ClassThresholds.fromJson(classThresholdsJson as Map<String, dynamic>);

    final qualityGateJson = json['quality_gate'] as Map<String, dynamic>?;
    final qualityGate = qualityGateJson == null ? const QualityGate() : QualityGate.fromJson(qualityGateJson);

    return SensorProfile(
      profileId: profileId,
      analyteAxis: json['analyte_axis'] as String,
      scalePoints: scalePoints,
      calibrationMethod: CalibrationMethod.fromJson(json['calibration_method'] as Map<String, dynamic>),
      classThresholds: classThresholds,
      qualityGate: qualityGate,
      outputFields: outputFields,
    );
  }
}
