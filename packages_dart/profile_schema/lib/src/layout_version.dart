// layout_version.schema.json'ın Dart portu —
// packages/profile_schema/schema/layout_version.schema.json (rapor §5,
// §8, §10.1: "okuyucu koordinatları hard-code etmez, bu dosyadan okur").

import 'validation.dart';

final RegExp _idPattern = RegExp(r'^[A-Za-z0-9_.-]+$');
const List<String> eccLevelEnum = ['L', 'M', 'Q', 'H'];
const List<String> moduleDensityEnum = ['low', 'medium', 'high'];

typedef Cell = (int row, int col);

List<Cell> _cellList(dynamic value, String field, {int? minItems, bool nonNegative = false}) {
  final list = value as List;
  if (minItems != null) requireLength(list, minItems: minItems, field: field);
  return list.map((pair) {
    final p = asIntList(pair, '$field[]');
    requireLength(p, minItems: 2, maxItems: 2, field: '$field[]');
    // Sadece sensor_modules'da minimum:0 var (Python şeması) —
    // reference_regions/intentional_errors NEGATİF satırı kasıtlı olarak
    // kabul eder (kenar referans yamaları, §5.2/5, satır<0).
    if (nonNegative) {
      for (final v in p) {
        requireRange(v, min: 0, field: '$field[]');
      }
    }
    return (p[0], p[1]);
  }).toList();
}

class DecoderCheck {
  final List<String> decoders;
  final List<String> colorStates;
  final double decodeSuccessRate;

  const DecoderCheck({
    this.decoders = const [],
    this.colorStates = const [],
    this.decodeSuccessRate = 0.0,
  });

  factory DecoderCheck.fromJson(Map<String, dynamic> json) {
    forbidExtraKeys(json, {'decoders', 'color_states', 'decode_success_rate'}, 'decoder_check');
    final rate = (json['decode_success_rate'] as num?)?.toDouble() ?? 0.0;
    requireRange(rate, min: 0, max: 1, field: 'decoder_check.decode_success_rate');
    return DecoderCheck(
      decoders: ((json['decoders'] as List?) ?? const []).map((e) => e as String).toList(),
      colorStates: ((json['color_states'] as List?) ?? const []).map((e) => e as String).toList(),
      decodeSuccessRate: rate,
    );
  }
}

/// packages/profile_schema/schema/layout_version.schema.json'ın Dart portu.
class LayoutVersionData {
  final String layoutVersion;
  final int qrVersion;
  final int matrixSize;
  final String eccLevel;
  final String? moduleDensity;
  final List<Cell> sensorModules;
  final Map<String, List<Cell>> referenceRegions;
  final List<Cell> intentionalErrors;
  final DecoderCheck? decoderCheck;

  const LayoutVersionData({
    required this.layoutVersion,
    required this.qrVersion,
    required this.matrixSize,
    this.eccLevel = 'H',
    this.moduleDensity,
    required this.sensorModules,
    required this.referenceRegions,
    this.intentionalErrors = const [],
    this.decoderCheck,
  });

  static const Set<String> _allowedTopLevelKeys = {
    'layout_version',
    'qr_version',
    'matrix_size',
    'ecc_level',
    'module_density',
    'sensor_modules',
    'reference_regions',
    'intentional_errors',
    'decoder_check',
  };

  factory LayoutVersionData.fromJson(Map<String, dynamic> json) {
    forbidExtraKeys(json, _allowedTopLevelKeys, 'layout_version');
    requireKeys(
      json,
      ['layout_version', 'qr_version', 'matrix_size', 'sensor_modules', 'reference_regions'],
      'layout_version',
    );

    final layoutVersion = json['layout_version'] as String;
    requirePattern(layoutVersion, _idPattern, 'layout_version.layout_version');

    final qrVersion = json['qr_version'] as int;
    requireRange(qrVersion, min: 1, max: 40, field: 'layout_version.qr_version');

    final eccLevel = (json['ecc_level'] as String?) ?? 'H';
    requireEnum(eccLevel, eccLevelEnum, 'layout_version.ecc_level');

    final moduleDensity = json['module_density'] as String?;
    if (moduleDensity != null) {
      requireEnum(moduleDensity, moduleDensityEnum, 'layout_version.module_density');
    }

    final sensorModules = _cellList(
      json['sensor_modules'],
      'layout_version.sensor_modules',
      nonNegative: true,
    );

    final referenceRegionsJson = json['reference_regions'] as Map<String, dynamic>;
    final referenceRegions = {
      for (final entry in referenceRegionsJson.entries)
        entry.key: _cellList(entry.value, 'layout_version.reference_regions.${entry.key}'),
    };

    final intentionalErrors = json['intentional_errors'] == null
        ? const <Cell>[]
        : _cellList(json['intentional_errors'], 'layout_version.intentional_errors');

    final decoderCheckJson = json['decoder_check'] as Map<String, dynamic>?;

    return LayoutVersionData(
      layoutVersion: layoutVersion,
      qrVersion: qrVersion,
      matrixSize: json['matrix_size'] as int,
      eccLevel: eccLevel,
      moduleDensity: moduleDensity,
      sensorModules: sensorModules,
      referenceRegions: referenceRegions,
      intentionalErrors: intentionalErrors,
      decoderCheck: decoderCheckJson == null ? null : DecoderCheck.fromJson(decoderCheckJson),
    );
  }
}
