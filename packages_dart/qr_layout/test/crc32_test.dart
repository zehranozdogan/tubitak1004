// crc32.dart testleri — REFERANS DEĞERLER gerçek Python zlib.crc32
// çalıştırılarak üretildi, TAHMİN EDİLMEDİ.

import 'package:qr_layout/qr_layout.dart';
import 'package:test/test.dart';

void main() {
  test('gerçek Python zlib.crc32 ile birebir eşleşir', () {
    expect(crc32('QR_SENSOR_v4'), 2229069714);
    expect(crc32('QR_TEST'), 744849471);
    expect(crc32(''), 0);
    expect(crc32('a'), 3904355907);
    expect(crc32('hello world'), 222957957);
  });

  test('seedFromLayoutVersion crc32 ile aynı sonucu verir', () {
    expect(seedFromLayoutVersion('QR_SENSOR_v4'), 2229069714);
    expect(seedFromLayoutVersion('QR_TEST'), 744849471);
  });
}
