// decode.dart testleri — bkz. lib/src/decode.dart dosya başlığı (seçim
// gerekçesi, köşe kestirim formülünün kaynağı ve sınırları).

import 'package:image/image.dart' as img;
import 'package:qr_layout/qr_layout.dart';
import 'package:test/test.dart';

const _matrixSize = 65; // gerçek: GENIPIN payload -> qr version 12
const _scale = 10;
const _border = 4;

img.Image _renderReal() {
  final qr = generateQr(
    '{"product_id":"TR45678","product_type":"LEVREK","production_date":"2026-09-25",'
    '"sensor_profile_id":"GENIPIN_PUTRESIN_v2","layout_version":"QR_SENSOR_v4"}',
    error: 'h',
  );
  expect(qr.version, 12); // matrixSize=65 varsayımını doğrula
  final layout = buildLayout(
    version: qr.version,
    eccLevel: qr.eccLevel,
    sensorModules: const [],
    layoutVersion: 'QR_SENSOR_v4',
  );
  return renderColoredImage(qr, layout, scale: _scale, border: _border);
}

void main() {
  group('decodeQrZxing', () {
    test('gerçek etiket görüntüsünü BİREBİR aynı metinle çözer, 3 finder noktası döner', () {
      final image = _renderReal();
      final result = decodeQrZxing(image);
      expect(result, isNotNull);
      expect(
        result!.text,
        '{"product_id":"TR45678","product_type":"LEVREK","production_date":"2026-09-25",'
        '"sensor_profile_id":"GENIPIN_PUTRESIN_v2","layout_version":"QR_SENSOR_v4"}',
      );
      expect(result.finderPoints, isNotNull);
    });

    test('QR içermeyen düz bir görüntüde null döner (istisna fırlatmaz)', () {
      final blank = img.Image(width: 200, height: 200, numChannels: 3);
      img.fill(blank, color: img.ColorRgb8(255, 255, 255));
      expect(decodeQrZxing(blank), isNull);
    });

    test('24 etikette (8 parti no × 3 durum) temiz görüntüde TAMAMI çözülür', () {
      var ok = 0;
      for (var n = 45678; n < 45686; n++) {
        final qr = generateQr(
          '{"product_id":"TR$n","product_type":"LEVREK","production_date":"2026-09-25",'
          '"sensor_profile_id":"GENIPIN_PUTRESIN_v2","layout_version":"QR_SENSOR_v4"}',
          error: 'h',
        );
        final candidates = reactiveCandidatesForVersion(qr.version);
        final modules = selectReactiveModules(candidates, density: 'low', seed: n);
        final layout = buildLayout(version: qr.version, eccLevel: qr.eccLevel, sensorModules: modules, layoutVersion: 'QR_SENSOR_v4');
        for (final state in ['fresh', 'transition', 'spoiled']) {
          final image = renderColoredImage(qr, layout, state: state, scale: _scale, border: _border);
          final result = decodeQrZxing(image);
          if (result != null &&
              result.text.contains('"product_id":"TR$n"') &&
              result.text.contains('"production_date":"2026-09-25"')) {
            ok++;
          }
        }
      }
      expect(ok, 24);
    });
  });

  group('estimateOuterCorners', () {
    test('gerçek zxing2 çıktısından kestirilen köşeler, eksen-hizalı (perspektifsiz) etikette GERÇEK köşelerle TAM eşleşir', () {
      final image = _renderReal();
      final result = decodeQrZxing(image)!;
      final estimated = estimateOuterCorners(result.finderPoints!, _matrixSize);
      // color_engine.canonicalQrCorners ile AYNI formül (qr_layout, color_engine'e
      // bağımlı OLAMAZ — ters yönlü bağımlılık olurdu — bu yüzden burada inline).
      const n = _matrixSize;
      final truth = [
        [(_border * _scale).toDouble(), (_border * _scale).toDouble()],
        [((n + _border) * _scale).toDouble(), (_border * _scale).toDouble()],
        [((n + _border) * _scale).toDouble(), ((n + _border) * _scale).toDouble()],
        [(_border * _scale).toDouble(), ((n + _border) * _scale).toDouble()],
      ];
      for (var i = 0; i < 4; i++) {
        expect(estimated[i][0], closeTo(truth[i][0], 1.0), reason: 'köşe $i x');
        expect(estimated[i][1], closeTo(truth[i][1], 1.0), reason: 'köşe $i y');
      }
    });

    test('elle kurulmuş finder noktalarında (dönme + öteleme, saf afin) formül KESİN doğru (analitik referans)', () {
      // moduleVector = (2, 0.5) piksel/modül (döndürülmüş eksen), matrixSize=21.
      // topLeft finder merkezi (modül 3.5,3.5) -> gerçek köşe (modül 0,0).
      const mCol = (x: 2.0, y: 0.5); // sütun ekseni yönü
      const mRow = (x: -0.5, y: 2.0); // satır ekseni yönü (dik)
      const originX = 100.0, originY = 50.0; // gerçek sol-üst köşenin piksel konumu
      ({double x, double y}) atModule(double row, double col) => (
            x: originX + col * mCol.x + row * mRow.x,
            y: originY + col * mCol.y + row * mRow.y,
          );
      final tl = atModule(3.5, 3.5);
      final tr = atModule(3.5, 21 - 3.5);
      final bl = atModule(21 - 3.5, 3.5);
      final points = QrFinderPoints(
        topLeft: (x: tl.x, y: tl.y),
        topRight: (x: tr.x, y: tr.y),
        bottomLeft: (x: bl.x, y: bl.y),
      );
      final estimated = estimateOuterCorners(points, 21);
      expect(estimated[0][0], closeTo(originX, 1e-9));
      expect(estimated[0][1], closeTo(originY, 1e-9));
      final trueTr = atModule(0, 21);
      expect(estimated[1][0], closeTo(trueTr.x, 1e-9));
      expect(estimated[1][1], closeTo(trueTr.y, 1e-9));
      final trueBl = atModule(21, 0);
      expect(estimated[3][0], closeTo(trueBl.x, 1e-9));
      expect(estimated[3][1], closeTo(trueBl.y, 1e-9));
    });

    test('matrixSize <= 7 -> ArgumentError', () {
      const points = QrFinderPoints(topLeft: (x: 0, y: 0), topRight: (x: 1, y: 0), bottomLeft: (x: 0, y: 1));
      expect(() => estimateOuterCorners(points, 7), throwsArgumentError);
    });
  });
}
