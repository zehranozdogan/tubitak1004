// Tarama sonrası analiz zinciri (rapor §6.2, §7) — kamera/QR-decode
// katmanından BAĞIMSIZ, saf Dart: elimizde (1) QR'dan çözülmüş metin,
// (2) RGB kare, (3) karedeki QR köşeleri varsa sonucu üretir.
//
// Akış: qrText -> LabelPayload (şema doğrulaması) -> paketli sensor_profile +
// layout tarifi -> layout'u payload'dan yeniden türet -> analyzeFrame.
// Geçersiz/tanınmayan QR (JSON değil, şemaya uymayan, bilinmeyen profil)
// ÇÖKMEZ, `ScanInvalidQr` döner (kullanıcıya "Geçersiz QR" ekranı).
//
// Kamera entegrasyonu geldiğinde tek eksik: ML Kit'ten gelen metin/köşeler
// + kamera karesinin RGB'ye çevrilmesi (bkz. color_engine README, BGR notu).

import 'dart:convert';

import 'package:color_engine/color_engine.dart';
import 'package:image/image.dart' as img;
import 'package:label_export/label_export.dart' as label_export;
import 'package:profile_schema/profile_schema.dart' as schema;
import 'package:qr_layout/qr_layout.dart' as qr_layout;

import '../data/reference_data.dart';
import '../screens/user/mock_results.dart' show LabelInfo;

sealed class ScanOutcome {
  const ScanOutcome();
}

class ScanSuccess extends ScanOutcome {
  final ColorEngineResult result;
  final LabelInfo labelInfo;

  const ScanSuccess(this.result, this.labelInfo);
}

class ScanInvalidQr extends ScanOutcome {
  final String reason;

  const ScanInvalidQr(this.reason);
}

/// `image` paketinin görüntüsünü color_engine'in `RgbImage`'ine çevirir.
/// Alfa yok sayılır; kanallar gerçek RGB (BGR sorunu yok).
RgbImage rgbImageFromImage(img.Image image) {
  final rgb = image.convert(numChannels: 3);
  final pixels = <Rgb>[];
  for (var y = 0; y < rgb.height; y++) {
    for (var x = 0; x < rgb.width; x++) {
      final p = rgb.getPixel(x, y);
      pixels.add(Rgb(p.r.toDouble(), p.g.toDouble(), p.b.toDouble()));
    }
  }
  return RgbImage(width: rgb.width, height: rgb.height, pixels: pixels);
}

/// "YYYY-AA-GG" -> "GG.AA.YYYY" (ekran biçimi); biçim tutmazsa olduğu gibi.
String _displayDate(String iso) {
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(iso);
  return m == null ? iso : '${m[3]}.${m[2]}.${m[1]}';
}

String _titleCase(String s) {
  if (s.isEmpty) return s;
  final lower = s.toLowerCase();
  return lower[0].toUpperCase() + lower.substring(1);
}

Future<ScanOutcome> analyzeCapturedLabel({
  required String qrText,
  required RgbImage image,
  required List<List<double>> corners,
  required ReferenceData reference,
}) async {
  final schema.LabelPayload payload;
  try {
    final decoded = jsonDecode(qrText);
    if (decoded is! Map<String, dynamic>) return const ScanInvalidQr('QR içeriği JSON nesnesi değil');
    payload = schema.LabelPayload.fromJson(decoded);
  } catch (e) {
    return ScanInvalidQr('QR içeriği FreshQR etiketi değil ($e)');
  }

  final LoadedSensorProfile loaded;
  final LayoutRecipe recipe;
  try {
    loaded = await reference.sensorProfile(payload.sensorProfileId);
    recipe = await reference.layoutRecipe(payload.layoutVersion);
  } catch (e) {
    return ScanInvalidQr('Bilinmeyen profil/layout: $e');
  }

  final resolved = label_export.resolveLabelLayout(payload, density: recipe.moduleDensity, sensorProfile: loaded.raw);
  // Her sensör hücresinin basılırken kullandığı bit (1 koyu, 0 açık ton) —
  // okuyucu QR matrisini zaten yeniden ürettiği için biliniyor. Kasıtlı hata
  // (intentional_errors) hücreleri gerçek bitin TERSİYLE basılır.
  final matrix = qr_layout.moduleMatrix(resolved.qr);
  final flipped = {for (final c in resolved.layout.intentionalErrors) c};
  final bits = [
    for (final c in resolved.layout.sensorModules)
      flipped.contains(c) ? 1 - matrix[c.$1][c.$2] : matrix[c.$1][c.$2],
  ];

  final result = analyzeFrame(
    image,
    sensorProfile: loaded.profile,
    layoutVersion: resolved.layout,
    qrCorners: corners,
    sensorModuleBits: bits,
  );

  return ScanSuccess(
    result,
    LabelInfo(
      productType: _titleCase(payload.productType),
      productId: payload.productId,
      productionDate: _displayDate(payload.productionDate),
    ),
  );
}
