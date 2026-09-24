// Kamera karesi dönüşümleri — saf hesap, cihaz gerektirmez.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:freshqr/services/frame_convert.dart';

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

  test('bgraToRgbImage: kanal sırası B,G,R,A -> R,G,B', () {
    final data = Uint8List.fromList([1, 2, 3, 255, 4, 5, 6, 255]); // 2x1
    final img = bgraToRgbImage(data, 2, 1);
    expect((img.at(0, 0).r, img.at(0, 0).g, img.at(0, 0).b), (3, 2, 1));
    expect((img.at(1, 0).r, img.at(1, 0).g, img.at(1, 0).b), (6, 5, 4));
  });
}
