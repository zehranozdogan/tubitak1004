// GERÇEK CİHAZ HATASI (28 Eylül) — bulundu ve düzeltildi: B (white_gray_black)
// ve C (multicolor_patch) kalibrasyon yöntemlerinin kenar referans yamaları
// (QR'dan `border + edgePatchMargin` modül kadar dışarıda basılıyor, bkz.
// qr_layout/colors.dart edgePatchPositions'ın kendi docstring'i) GERÇEKTEN
// render edilmiş bir etikette pipeline tarafından HİÇ doğru örneklenmiyordu
// — `color_engine/pipeline.dart::_canonicalBorder` sadece 4 kullanıyordu,
// hem `warpToCanonical`'ın ürettiği canonical görüntü bu yamaları hiç
// İÇERMİYORDU (sadece 4 modül kenar payı vardı, yama 8 modül dışarıda) hem
// de pozisyon hesaplaması `sampleModuleRoi`'nin `.clamp(0, ...)` davranışı
// yüzünden SESSİZCE görüntünün SOL-ÜST köşesinden okuyordu.
//
// Bu, mevcut testlerde (pipeline_test.dart'taki "multicolor_patch kalibrasyonu:
// uçtan uca") YAKALANAMAMIŞTI çünkü o test `_buildCanonicalLikePhoto` ile
// pozisyonları KENDİSİ seçip AYNI (tutarlı ama gerçekçi olmayan) formülle
// geri okuyordu — gerçek `qr_layout.renderLabelImage`'ın ürettiği pozisyon/
// border ilişkisini hiç kullanmıyordu. Bu dosya GERÇEK render + GERÇEK
// pipeline zincirini test eder (Python tarafındaki eşdeğer bulgu: bkz.
// docs/decisions/0004 ve tests/synthetic/test_pipeline_reference_wiring.py).

import 'package:color_engine/color_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freshqr/services/scan_service.dart' show rgbImageFromImage;
import 'package:profile_schema/profile_schema.dart' as schema;
import 'package:qr_layout/qr_layout.dart' as qr_layout;

void main() {
  const scale = 10;
  const border = 4;

  ({qr_layout.GeneratedQr qr, Map<String, dynamic> layout}) buildQrAndLayout() {
    final qr = qr_layout.generateQr(
      '{"product_id":"TR-REFTEST","product_type":"LEVREK","production_date":"2026-09-28",'
      '"sensor_profile_id":"REF_TEST","layout_version":"QR_REFTEST"}',
      error: 'h',
    );
    final candidates = qr_layout.reactiveCandidatesForVersion(qr.version);
    final modules = qr_layout.selectReactiveModules(candidates, density: 'low', seed: 1);
    final layout = qr_layout.buildLayout(
      version: qr.version,
      eccLevel: qr.eccLevel,
      sensorModules: modules,
      layoutVersion: 'QR_REFTEST',
    );
    return (qr: qr, layout: layout);
  }

  /// Render edilen etiketin GERÇEK dış köşeleri -- `renderLabelImage`, B/C
  /// için render'ı `border + edgePatchMargin` (yama için gereken TOPLAM
  /// kenar payı) ile yapar, nominal `border` DEĞİL (bkz. dosya başlığı).
  List<List<double>> realCorners(int matrixSize, int totalBorder) {
    final n = matrixSize;
    return [
      [(totalBorder * scale).toDouble(), (totalBorder * scale).toDouble()],
      [((n + totalBorder) * scale).toDouble(), (totalBorder * scale).toDouble()],
      [((n + totalBorder) * scale).toDouble(), ((n + totalBorder) * scale).toDouble()],
      [(totalBorder * scale).toDouble(), ((n + totalBorder) * scale).toDouble()],
    ];
  }

  schema.SensorProfile testProfile(String code) => schema.SensorProfile(
        profileId: 'REF_TEST_v1',
        analyteAxis: 'test',
        scalePoints: [
          schema.ScalePointEntry(value: 0.0, lab: const [30.0, 5.0, 5.0], state: 'spoiled'),
          schema.ScalePointEntry(value: 1.0, lab: const [70.0, 5.0, 5.0], state: 'fresh'),
        ],
        calibrationMethod: schema.CalibrationMethod(code: code),
        outputFields: const ['state'],
      );

  test('multicolor_patch (C): gerçek render edilmiş kenar yamaları white_black\'e DÜŞMEDEN kullanılır', () {
    final built = buildQrAndLayout();
    final profileMap = {
      'calibration_method': {'code': 'multicolor_patch'},
    };
    final image = qr_layout.renderLabelImage(built.qr, built.layout, profileMap, state: 'fresh', scale: scale, border: border);

    final totalBorder = border + qr_layout.edgePatchMargin;
    final matrixSize = built.layout['matrix_size'] as int;
    final corners = realCorners(matrixSize, totalBorder);

    final result = analyzeFrame(
      rgbImageFromImage(image),
      sensorProfile: testProfile('multicolor_patch'),
      layoutVersion: schema.LayoutVersionData.fromJson(built.layout),
      qrCorners: corners,
    );

    expect(result.rescanRecommended, isFalse, reason: result.notes.join('; '));
    expect(
      result.notes.any((n) => n.contains('düşüldü')),
      isFalse,
      reason: 'multicolor_patch white_black\'e düşmemeliydi: ${result.notes}',
    );
  });

  test('white_gray_black (B): gerçek render edilmiş gri yama white_black\'e DÜŞMEDEN kullanılır', () {
    final built = buildQrAndLayout();
    final profileMap = {
      'calibration_method': {'code': 'white_gray_black'},
    };
    final image = qr_layout.renderLabelImage(built.qr, built.layout, profileMap, state: 'fresh', scale: scale, border: border);

    final totalBorder = border + qr_layout.edgePatchMargin;
    final matrixSize = built.layout['matrix_size'] as int;
    final corners = realCorners(matrixSize, totalBorder);

    final result = analyzeFrame(
      rgbImageFromImage(image),
      sensorProfile: testProfile('white_gray_black'),
      layoutVersion: schema.LayoutVersionData.fromJson(built.layout),
      qrCorners: corners,
    );

    expect(result.rescanRecommended, isFalse, reason: result.notes.join('; '));
    expect(
      result.notes.any((n) => n.contains('düşüldü')),
      isFalse,
      reason: 'white_gray_black white_black\'e düşmemeliydi: ${result.notes}',
    );
  });
}
