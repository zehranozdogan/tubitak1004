// BASKI USTASI (6 Ekim): gerçek üretimde reaktif hücrelere reaktif madde
// uygulanacağı için, basılacak dosyada o hücreler BOŞ (beyaz kağıt)
// kalmalı. Nötr gri çıktı yalnızca yerleşim önizlemesidir — reaktif
// mürekkep grinin üstüne uygulanırsa renk kirlenir, çünkü profildeki
// referans renkler beyaz kağıt üzerinde tanımlı.

import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:label_export/label_export.dart';
import 'package:qr_layout/qr_layout.dart' as qr_layout;
import 'package:test/test.dart';

void main() {
  late Directory tmp;

  setUp(() async => tmp = await Directory.systemTemp.createTemp('baski_'));
  tearDown(() async {
    try {
      await tmp.delete(recursive: true);
    } catch (_) {}
  });

  ({int row, int col}) _ilkReaktif(Map<String, dynamic> layout) {
    final ilk = (layout['sensor_modules'] as List).first as List;
    return (row: (ilk[0] as num).toInt(), col: (ilk[1] as num).toInt());
  }

  for (final (ad, profil) in [
    ('yamasız (A)', null),
    ('kenar yamalı (C)', {
      'calibration_method': {'code': 'multicolor_patch'}
    }),
  ]) {
    test('$ad: baskı ustasında reaktif hücreler BEYAZ, önizlemede değil', () async {
      final payload = buildLabelPayload(
        productId: 'BASKI-1',
        productType: 'levrek',
        productionDate: '2026-10-06',
        sensorProfileId: 'GENIPIN_PUTRESIN_v2',
        layoutVersion: 'QR_SENSOR_v4',
      );
      final sonuc = await exportLabel(payload, tmp, density: 'low', sensorProfile: profil);

      final hucre = _ilkReaktif(sonuc.label.layoutJson);
      final border = profil == null ? 4 : 4 + qr_layout.edgePatchMargin;
      const scale = 10;
      final x = (hucre.col + border) * scale + scale ~/ 2;
      final y = (hucre.row + border) * scale + scale ~/ 2;

      final baski = img.decodePng(await sonuc.paths['print_png']!.readAsBytes())!;
      final onizleme = img.decodePng(await sonuc.paths['png']!.readAsBytes())!;

      final bp = baski.getPixel(x, y);
      expect([bp.r, bp.g, bp.b], [255, 255, 255],
          reason: 'baskı ustasında reaktif hücre basılmamalı');

      final op = onizleme.getPixel(x, y);
      expect([op.r, op.g, op.b], isNot([255, 255, 255]),
          reason: 'önizlemede nötr gri görünmeli (yerleşim gösterimi)');
    });
  }

  test('reaktif hücreler boşken QR HÂLÂ çözülür (ECC-H toleransı)', () async {
    final payload = buildLabelPayload(
      productId: 'BASKI-2',
      productType: 'levrek',
      productionDate: '2026-10-06',
      sensorProfileId: 'GENIPIN_PUTRESIN_v2',
      layoutVersion: 'QR_SENSOR_v4',
    );
    final sonuc = await exportLabel(payload, tmp, density: 'low');
    final baski = img.decodePng(await sonuc.paths['print_png']!.readAsBytes())!;

    final cozulen = qr_layout.decodeQrZxing(baski);
    expect(cozulen, isNotNull, reason: 'baskı ustası okunamıyor');
    expect(cozulen!.text, labelPayloadQrText(payload));
  });

  test('reactiveBlank ile state birlikte verilemez', () {
    final uretilen = generateLabel(
      buildLabelPayload(
        productId: 'BASKI-3',
        productType: 'levrek',
        productionDate: '2026-10-06',
        sensorProfileId: 'GENIPIN_PUTRESIN_v2',
        layoutVersion: 'QR_SENSOR_v4',
      ),
      density: 'low',
    );
    expect(
      () => qr_layout.renderColoredImage(uretilen.qr, uretilen.layoutJson,
          state: 'fresh', reactiveBlank: true),
      throwsArgumentError,
    );
  });
}
