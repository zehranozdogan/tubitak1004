// "Güven skoru hep 0.00" (30 Eylül, gerçek cihaz) regresyonu: decoder'dan
// gelen KABA köşeler, bilinen QR desenine hizalanarak (color_engine
// `refineQrCorners`) düzeltilmeli — bkz. color_engine/lib/src/grid_refine.dart.

import 'dart:io';
import 'dart:math' as math;

import 'package:color_engine/color_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freshqr/data/reference_data.dart';
import 'package:freshqr/services/scan_service.dart';
import 'package:image/image.dart' as img;
import 'package:label_export/label_export.dart' as label_export;
import 'package:qr_layout/qr_layout.dart' as qr_layout;

Future<String> _fileReader(String path) => File(path).readAsString();

const _profileId = 'GENIPIN_PUTRESIN_v2';
// bkz. scan_service_test.dart: GENIPIN'de bu üç durumun beklenen profil noktası.
const _expectedPoint = {'fresh': 0.0625, 'transition': 0.25, 'spoiled': 1.0};

void main() {
  final ref = ReferenceData(_fileReader);
  late label_export.GeneratedLabel label;
  late Map<String, dynamic> profileRaw;
  late String qrText;

  setUpAll(() async {
    profileRaw = (await ref.sensorProfile(_profileId)).raw;
    label = label_export.generateLabel(
      label_export.buildLabelPayload(
        productId: 'TR45678',
        productType: 'levrek',
        productionDate: '2026-09-25',
        sensorProfileId: _profileId,
        layoutVersion: 'QR_SENSOR_v4',
      ),
      density: 'low',
    );
    qrText = label_export.labelPayloadQrText(label.payload);
  });

  img.Image render(String state) => qr_layout.renderLabelImage(label.qr, label.layoutJson, profileRaw, state: state);

  Future<ColorEngineResult> scan(RgbImage image, List<List<double>> corners) async {
    final outcome = await analyzeCapturedLabel(qrText: qrText, image: image, corners: corners, reference: ref);
    return (outcome as ScanSuccess).result;
  }

  group('kaba köşeler (düz etiket)', () {
    late RgbImage image;
    late List<List<double>> truth;
    setUpAll(() {
      image = rgbImageFromImage(render('fresh'));
      truth = canonicalQrCorners(label.layout.matrixSize);
    });

    final cases = <String, List<List<double>> Function(List<List<double>>)>{
      '1 modül öteleme': (t) => [for (final p in t) [p[0] + 10, p[1] + 10]],
      '1.5 modül dışa büyüme': (t) => [
            [t[0][0] - 15, t[0][1] - 15],
            [t[1][0] + 15, t[1][1] - 15],
            [t[2][0] + 15, t[2][1] + 15],
            [t[3][0] - 15, t[3][1] + 15],
          ],
      'tek köşe 1 modül kayık': (t) => [t[0], t[1], [t[2][0] + 10, t[2][1] + 10], t[3]],
      // ML Kit köşe SIRASI varsayımı (sol-üstten saat yönü) doğrulanmamıştı.
      'köşe sırası bir kaydırılmış': (t) => [t[1], t[2], t[3], t[0]],
    };
    for (final entry in cases.entries) {
      test('${entry.key}: doğru profil noktası, güven ~1', () async {
        final r = await scan(image, entry.value(truth));
        expect(r.rescanRecommended, isFalse);
        expect(r.matchedProfilePoint, _expectedPoint['fresh']);
        expect(r.confidence!, greaterThan(0.95));
      });
    }

    test('tamamen alakasız köşeler: "emin ama yanlış" DEĞİL, yeniden tara', () async {
      final r = await scan(image, [
        [0.0, 0.0],
        [200.0, 0.0],
        [200.0, 200.0],
        [0.0, 200.0],
      ]);
      expect(r.rescanRecommended, isTrue);
      expect(r.confidence, isNull);
      expect(r.notes.single, contains('hizalanamadı'));
    });
  });

  // Kamera benzeri kare: 1280x720, perspektifli, ~7 px/modül, bulanık; köşeler
  // gerçek konumdan birer modüle yakın rastgele sapmış (decoder kabalığı).
  for (final state in _expectedPoint.keys) {
    test('kamera benzeri perspektifli/bulanık kare ($state): doğru nokta, güven yüksek', () async {
      final label0 = render(state);
      final n = label.layout.matrixSize;
      const border = 4, scale = 10; // renderLabelImage varsayılanları
      // Etiket karede eğik bir dörtgene (QR ızgarasının dış köşeleri) oturur.
      final quad = [
        [420.0, 150.0],
        [880.0, 175.0],
        [860.0, 610.0],
        [400.0, 585.0],
      ];
      final gridInLabel = [
        [border * scale * 1.0, border * scale * 1.0],
        [(n + border) * scale * 1.0, border * scale * 1.0],
        [(n + border) * scale * 1.0, (n + border) * scale * 1.0],
        [border * scale * 1.0, (n + border) * scale * 1.0],
      ];
      final frameToLabel = getPerspectiveTransform(quad, gridInLabel);
      final frame = img.Image(width: 1280, height: 720, numChannels: 3);
      for (var y = 0; y < 720; y++) {
        for (var x = 0; x < 1280; x++) {
          final w = frameToLabel[2][0] * x + frameToLabel[2][1] * y + frameToLabel[2][2];
          final lx = (frameToLabel[0][0] * x + frameToLabel[0][1] * y + frameToLabel[0][2]) / w;
          final ly = (frameToLabel[1][0] * x + frameToLabel[1][1] * y + frameToLabel[1][2]) / w;
          if (lx < 0 || ly < 0 || lx >= label0.width || ly >= label0.height) {
            frame.setPixelRgb(x, y, 120, 110, 100);
          } else {
            final p = label0.getPixel(lx.toInt(), ly.toInt());
            // Hafif ışık düşüşü (sağa doğru %15 daha karanlık).
            final g = 1.0 - 0.15 * x / 1280;
            frame.setPixelRgb(x, y, (p.r * g).round(), (p.g * g).round(), (p.b * g).round());
          }
        }
      }
      final blurred = img.gaussianBlur(frame, radius: 1);
      final rnd = math.Random(7);
      final m = 460 / n; // ~modül boyu (px)
      final rough = [for (final p in quad) [p[0] + (rnd.nextDouble() * 2 - 1) * m, p[1] + (rnd.nextDouble() * 2 - 1) * m]];

      final sw = Stopwatch()..start();
      final r = await scan(rgbImageFromImage(blurred), rough);
      sw.stop();
      // ignore: avoid_print
      print('$state: güven=${r.confidence?.toStringAsFixed(2)} nokta=${r.matchedProfilePoint} '
          'ΔE=${r.deltaE?.toStringAsFixed(1)} süre=${sw.elapsedMilliseconds}ms');
      expect(r.rescanRecommended, isFalse);
      expect(r.matchedProfilePoint, _expectedPoint[state]);
      expect(r.confidence!, greaterThan(0.8));
    });
  }
}
