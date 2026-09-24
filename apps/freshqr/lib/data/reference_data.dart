// Paketli (bundled) referans veri — docs/decisions/0005-statik-veri-db-yok.md.
//
// `sensor_profile` JSON'ları uygulamayla birlikte paketlenir. Layout için
// SABİT bir hücre listesi paketlenmez (QR boyutu payload uzunluğuna göre
// değiştiği için gerçek etiketlerle uyuşmaz); bunun yerine sadece bir
// "tarif" (yoğunluk, ECC) paketlenir ve hücreler okuyucuda
// `label_export.resolveLabelLayout` ile yeniden türetilir (24 Eylül kararı).
//
// Asset okuma bir fonksiyon olarak enjekte edilir (`AssetReader`) — testte
// rootBundle olmadan sahte bir okuyucu verilebilir.

import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:profile_schema/profile_schema.dart' as schema;

typedef AssetReader = Future<String> Function(String path);

const String _base = 'assets/reference';
final RegExp _idPattern = RegExp(r'^[A-Za-z0-9_.-]+$');

class ReferenceDataException implements Exception {
  final String message;
  const ReferenceDataException(this.message);

  @override
  String toString() => message;
}

/// `<layout_version>.layout_recipe.json` içeriği.
class LayoutRecipe {
  final String layoutVersion;
  final String moduleDensity;
  final String eccLevel;

  const LayoutRecipe({required this.layoutVersion, required this.moduleDensity, required this.eccLevel});

  factory LayoutRecipe.fromJson(Map<String, dynamic> json) {
    final density = json['module_density'];
    if (density != 'low' && density != 'high') {
      throw const ReferenceDataException("layout_recipe.module_density 'low' veya 'high' olmalı");
    }
    return LayoutRecipe(
      layoutVersion: json['layout_version'] as String,
      moduleDensity: density as String,
      eccLevel: (json['ecc_level'] as String?) ?? 'H',
    );
  }
}

/// Bir sensor_profile: doğrulanmış tip + ham harita (render/kalibrasyon
/// yolu ham `calibration_method` haritasını istiyor).
class LoadedSensorProfile {
  final schema.SensorProfile profile;
  final Map<String, dynamic> raw;

  const LoadedSensorProfile({required this.profile, required this.raw});
}

class ReferenceData {
  final AssetReader _read;

  ReferenceData([AssetReader? reader]) : _read = reader ?? rootBundle.loadString;

  void _checkId(String id, String what) {
    if (!_idPattern.hasMatch(id)) {
      throw ReferenceDataException('Geçersiz $what: "$id"');
    }
  }

  Future<Map<String, dynamic>> _json(String path) async {
    try {
      return jsonDecode(await _read(path)) as Map<String, dynamic>;
    } catch (e) {
      throw ReferenceDataException('Referans veri okunamadı: $path ($e)');
    }
  }

  Future<List<String>> sensorProfileIds() async {
    final index = await _json('$_base/index.json');
    return [for (final id in index['sensor_profiles'] as List) id as String];
  }

  Future<List<String>> layoutVersions() async {
    final index = await _json('$_base/index.json');
    return [for (final id in index['layout_versions'] as List) id as String];
  }

  Future<LoadedSensorProfile> sensorProfile(String id) async {
    _checkId(id, 'sensor_profile_id');
    final raw = await _json('$_base/$id.sensor_profile.json');
    return LoadedSensorProfile(profile: schema.SensorProfile.fromJson(raw), raw: raw);
  }

  Future<LayoutRecipe> layoutRecipe(String layoutVersion) async {
    _checkId(layoutVersion, 'layout_version');
    return LayoutRecipe.fromJson(await _json('$_base/$layoutVersion.layout_recipe.json'));
  }
}
