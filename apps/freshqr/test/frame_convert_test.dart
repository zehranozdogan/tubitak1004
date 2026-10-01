// Kamera karesi dönüşümleri — saf hesap, cihaz gerektirmez.

import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:freshqr/services/frame_convert.dart';
import 'package:image/image.dart' as img;
import 'package:qr_layout/qr_layout.dart' as qr_layout;

void main() {
  group('nv21ToRgbImage', () {
    test('nötr kroma (U=V=128): gri, R=G=B=Y', () {
      // 4x2: Y düzlemi 8 bayt, ardından (2x1 chroma çifti) 4 bayt VU.
      final data = Uint8List.fromList([0, 64, 128, 255, 10, 20, 30, 40, 128, 128, 128, 128]);
      final img = nv21ToRgbImage(data, 4, 2);
      expect(img.width, 4);
      expect(img.height, 2);
      expect(img.at(1, 0).r, 64);
      expect(img.at(1, 0).g, 64);
      expect(img.at(1, 0).b, 64);
      expect(img.at(3, 1).r, 40);
    });

    test('kırmızımsı kroma: V yüksek -> R artar, B/G düşer (BT.601)', () {
      // 2x2, Y=100, V=200 (V-128=72), U=128.
      final data = Uint8List.fromList([100, 100, 100, 100, 200, 128]);
      final p = nv21ToRgbImage(data, 2, 2).at(0, 0);
      expect(p.r, closeTo(100 + 1.402 * 72, 1));
      expect(p.g, closeTo(100 - 0.714136 * 72, 1));
      expect(p.b, closeTo(100, 1));
    });

    test('taşma 0..255 aralığına kırpılır', () {
      final data = Uint8List.fromList([255, 255, 255, 255, 255, 255]);
      final p = nv21ToRgbImage(data, 2, 2).at(0, 0);
      expect(p.r, 255);
      expect(p.b, 255);
    });

    test('çok kısa veri -> ArgumentError', () {
      expect(() => nv21ToRgbImage(Uint8List(5), 4, 2), throwsArgumentError);
    });

    test('satır dolgusu (bytesPerRow > width) doğru atlanır', () {
      // width=2, stride=4: her satırda 2 dolgu baytı (999 gibi anlamsız değer).
      final data = Uint8List.fromList([10, 20, 0, 0, 30, 40, 0, 0, 128, 128, 0, 0]);
      final img = nv21ToRgbImage(data, 2, 2, bytesPerRow: 4);
      expect(img.at(1, 0).r, 20);
      expect(img.at(0, 1).r, 30);
    });
  });

  group('döndürme (saat yönü)', () {
    // 3x2 gri görüntü: Y değerleri farklı, kroma nötr.
    //  10 20 30
    //  40 50 60
    Uint8List src() => Uint8List.fromList([10, 20, 30, 40, 50, 60, 128, 128, 128, 128]);

    List<int> ys(dynamic img) => [
          for (var y = 0; y < img.height; y++)
            for (var x = 0; x < img.width; x++) img.at(x, y).r.round() as int,
        ];

    test('0: aynı', () {
      final img = nv21ToRgbImage(src(), 3, 2, bytesPerRow: 3, rotation: 0);
      expect(ys(img), [10, 20, 30, 40, 50, 60]);
    });

    test('90: 2x3, sol sütun alttan yukarı', () {
      final img = nv21ToRgbImage(src(), 3, 2, rotation: 90);
      expect((img.width, img.height), (2, 3));
      expect(ys(img), [40, 10, 50, 20, 60, 30]);
    });

    test('180', () {
      final img = nv21ToRgbImage(src(), 3, 2, rotation: 180);
      expect(ys(img), [60, 50, 40, 30, 20, 10]);
    });

    test('270', () {
      final img = nv21ToRgbImage(src(), 3, 2, rotation: 270);
      expect((img.width, img.height), (2, 3));
      expect(ys(img), [30, 60, 20, 50, 10, 40]);
    });
  });

  group('repackNv21', () {
    test('dolgu yok (bytesPerRow == width): olduğu gibi birleştirir', () {
      final y = Uint8List.fromList([10, 20, 30, 40]); // 2x2
      final vu = Uint8List.fromList([128, 128]); // 1x1 (2x2 -> chroma 1x1 çift)
      final out = repackNv21(y, 2, vu, 2, 2, 2);
      expect(out, [10, 20, 30, 40, 128, 128]);
    });

    test('Y ve VU düzlemleri FARKLI dolguyla (gerçek cihaz senaryosu): dolgu atılır', () {
      // width=2, height=2. Y stride=4 (2 dolgu baytı/satır), VU stride=6.
      final y = Uint8List.fromList([10, 20, 0, 0, 30, 40, 0, 0]);
      final vu = Uint8List.fromList([128, 129, 0, 0, 0, 0]);
      final out = repackNv21(y, 4, vu, 6, 2, 2);
      // Y: 2 satır x 2 bayt (dolgusuz) + VU: 1 satır x 2 bayt (dolgusuz).
      expect(out, [10, 20, 30, 40, 128, 129]);
    });

    test('çıktı boyutu her zaman width*height + width*(height~/2)', () {
      final y = Uint8List(4 * 4);
      final vu = Uint8List(4 * 2);
      final out = repackNv21(y, 4, vu, 4, 4, 4);
      expect(out.length, 4 * 4 + 4 * 2);
    });
  });

  test('bgraToRgbImage: kanal sırası B,G,R,A -> R,G,B', () {
    final data = Uint8List.fromList([1, 2, 3, 255, 4, 5, 6, 255]); // 2x1
    final img = bgraToRgbImage(data, 2, 1);
    expect((img.at(0, 0).r, img.at(0, 0).g, img.at(0, 0).b), (3, 2, 1));
    expect((img.at(1, 0).r, img.at(1, 0).g, img.at(1, 0).b), (6, 5, 4));
  });

  group('nv21LumaDownsampled (30 Eylül, "kamera çok donuyor" düzeltmesi)', () {
    // 3x2 gri, nötr kroma — yukarıdaki "döndürme" grubuyla AYNI veri.
    Uint8List src() => Uint8List.fromList([10, 20, 30, 40, 50, 60, 128, 128, 128, 128]);

    List<int> lumaOf(LumaFrame f) => [for (var i = 0; i < f.width * f.height; i++) f.rgb[i * 3]];

    for (final rotation in [0, 90, 180, 270]) {
      test('step=1, rotation=$rotation: nv21ToRgbImage ile AYNI piksel sırası ve boyut', () {
        final full = nv21ToRgbImage(src(), 3, 2, rotation: rotation);
        final luma = nv21LumaDownsampled(src(), 3, 2, step: 1, rotation: rotation);
        expect((luma.width, luma.height), (full.width, full.height));
        expect(lumaOf(luma), [
          for (var y = 0; y < full.height; y++)
            for (var x = 0; x < full.width; x++) full.at(x, y).r.round(),
        ]);
      });
    }

    test('R=G=B (gri) ve satır dolgusu atlanır', () {
      final data = Uint8List.fromList([10, 20, 0, 0, 30, 40, 0, 0, 128, 128, 0, 0]);
      final f = nv21LumaDownsampled(data, 2, 2, bytesPerRow: 4, step: 1);
      expect(f.rgb, [10, 10, 10, 20, 20, 20, 30, 30, 30, 40, 40, 40]);
    });

    test('step=2: her iki pikselde bir örnekler, boyut yarıya iner', () {
      // 4x4 Y: değer = y*4+x
      final y = Uint8List.fromList(List.generate(16, (i) => i));
      final data = Uint8List.fromList([...y, ...List.filled(8, 128)]);
      final f = nv21LumaDownsampled(data, 4, 4, step: 2);
      expect((f.width, f.height), (2, 2));
      expect(lumaOf(f), [0, 2, 8, 10]);
    });

    test('detectionStep: en uzun kenar <= max ise 1, değilse tavan bölme', () {
      expect(detectionStep(640, 480, 640), 1);
      expect(detectionStep(1280, 720, 640), 2);
      expect(detectionStep(1920, 1080, 640), 3);
      expect(detectionStep(1921, 1080, 640), 4);
    });
  });

  group('uçtan uca: gerçek etiket → NV21 kare → küçük gri kare → zxing2', () {
    // Gerçek (render edilmiş) bir etiketi, gerçek cihazdaki gibi SATIR
    // DOLGULU bir NV21 karesine gömer (Y = parlaklık, kroma nötr).
    ({Uint8List nv21, int width, int height, int stride, int offX, int offY}) cameraFrame() {
      final label = qr_layout.renderColoredImage(
        qr_layout.generateQr(_payload, error: 'h'),
        qr_layout.buildLayout(version: 12, eccLevel: 'H', sensorModules: const [], layoutVersion: 'QR_SENSOR_v4'),
        scale: 10,
        border: 4,
      );
      const width = 1280, height = 1280, stride = 1296; // 16 bayt dolgu
      const offX = (width - 730) ~/ 2, offY = (height - 730) ~/ 2;
      final nv21 = Uint8List(stride * height + stride * (height ~/ 2))..fillRange(0, stride * height, 200);
      nv21.fillRange(stride * height, nv21.length, 128);
      for (var y = 0; y < label.height; y++) {
        for (var x = 0; x < label.width; x++) {
          final p = label.getPixel(x, y);
          nv21[(y + offY) * stride + x + offX] = ((p.r * 299 + p.g * 587 + p.b * 114) ~/ 1000).toInt();
        }
      }
      return (nv21: nv21, width: width, height: height, stride: stride, offX: offX, offY: offY);
    }

    test('küçük karede decode edilir, geri ölçeklenen köşeler TAM karedeki gerçek köşelerle 1 modül içinde', () {
      final f = cameraFrame();
      final step = detectionStep(f.width, f.height, 640);
      expect(step, 2);
      final luma = nv21LumaDownsampled(f.nv21, f.width, f.height, bytesPerRow: f.stride, step: step);
      final frame = img.Image.fromBytes(width: luma.width, height: luma.height, bytes: luma.rgb.buffer, numChannels: 3);

      final result = qr_layout.decodeQrZxing(frame);
      expect(result, isNotNull);
      expect(result!.text, _payload);

      final p = result.finderPoints!;
      ({double x, double y}) s(({double x, double y}) q) => (x: q.x * step, y: q.y * step);
      final scaled = qr_layout.QrFinderPoints(
        topLeft: s(p.topLeft),
        topRight: s(p.topRight),
        bottomLeft: s(p.bottomLeft),
        alignment: p.alignment == null ? null : s(p.alignment!),
      );
      final corners = qr_layout.estimateOuterCorners(scaled, 65);
      final truth = [
        [f.offX + 40.0, f.offY + 40.0],
        [f.offX + 690.0, f.offY + 40.0],
        [f.offX + 690.0, f.offY + 690.0],
        [f.offX + 40.0, f.offY + 690.0],
      ];
      for (var i = 0; i < 4; i++) {
        expect(corners[i][0], closeTo(truth[i][0], 10), reason: 'köşe $i x');
        expect(corners[i][1], closeTo(truth[i][1], 10), reason: 'köşe $i y');
      }
    });

    test('decode ARKA PLAN isolate\'inde çalışır ve sonuç (ZxingDecodeResult) geri gönderilebilir', () async {
      final f = cameraFrame();
      final luma = nv21LumaDownsampled(f.nv21, f.width, f.height, bytesPerRow: f.stride, step: 2, rotation: 90);
      final result = await Isolate.run(() {
        final frame = img.Image.fromBytes(width: luma.width, height: luma.height, bytes: luma.rgb.buffer, numChannels: 3);
        return qr_layout.decodeQrZxing(frame, thorough: false);
      });
      expect(result?.text, _payload);
      expect(result?.finderPoints, isNotNull);
    });

    // KÖŞE HASSASİYETİ (30 Eylül, gerçek cihazda A/B/C'nin ÜÇÜ de yanlış
    // sonuç verdi — bkz. camera_scanner.dart'taki aynı başlıklı not):
    // küçültülmüş kare QR'ı ÇÖZMEK için yeterli ama köşeleri RENK OKUMAK
    // için değil. Yukarıdaki küçültme testinin toleransı 10 piksel = TAM
    // BİR MODÜL (scale=10) — renk okuması her modülün merkezini tek tek
    // örneklediği için bu kadarlık bir kayma hücreleri KOMŞU modülden
    // okutabiliyor. Bu test, yakalama anında kullanılan tam çözünürlüklü
    // yolun (`_refineFinderPointsFullRes`, step=1) çok daha sıkı bir
    // toleransı tutturduğunu kanıtlar: 2 piksel = 0.2 modül.
    test('TAM çözünürlüklü (step=1) tespit, köşeleri 0.2 modül hassasiyetle bulur', () {
      final f = cameraFrame();
      final luma = nv21LumaDownsampled(f.nv21, f.width, f.height, bytesPerRow: f.stride, step: 1);
      expect(luma.width, f.width, reason: 'step=1 tam çözünürlük olmalı');
      final frame = img.Image.fromBytes(width: luma.width, height: luma.height, bytes: luma.rgb.buffer, numChannels: 3);

      final result = qr_layout.decodeQrZxing(frame, thorough: false);
      expect(result, isNotNull);
      expect(result!.text, _payload);

      // step=1 olduğu için ölçekleme YOK — noktalar zaten tam çözünürlüklü
      // (döndürülmüş) kare uzayında, `_frameToRgb`'nin çıktısıyla aynı.
      final corners = qr_layout.estimateOuterCorners(result.finderPoints!, 65);
      final truth = [
        [f.offX + 40.0, f.offY + 40.0],
        [f.offX + 690.0, f.offY + 40.0],
        [f.offX + 690.0, f.offY + 690.0],
        [f.offX + 40.0, f.offY + 690.0],
      ];
      for (var i = 0; i < 4; i++) {
        expect(corners[i][0], closeTo(truth[i][0], 2), reason: 'köşe $i x');
        expect(corners[i][1], closeTo(truth[i][1], 2), reason: 'köşe $i y');
      }
    });
  });
}

const _payload = '{"product_id":"TR45678","product_type":"LEVREK","production_date":"2026-09-25",'
    '"sensor_profile_id":"GENIPIN_PUTRESIN_v2","layout_version":"QR_SENSOR_v4"}';
