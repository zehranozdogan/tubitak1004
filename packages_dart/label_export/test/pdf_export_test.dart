// El yazımı PDF çıktısının yapısal doğruluğu: xref ofsetleri, sayfa boyutu,
// gömülü görüntünün kayıpsızlığı.

import 'dart:convert';
import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:label_export/label_export.dart';
import 'package:test/test.dart';

void main() {
  final image = img.Image(width: 30, height: 20, numChannels: 3);
  for (var y = 0; y < 20; y++) {
    for (var x = 0; x < 30; x++) {
      image.setPixelRgb(x, y, x * 8, y * 12, (x + y) * 5);
    }
  }
  final bytes = labelPdfBytes(image, dpi: 300);
  final text = latin1.decode(bytes);

  test('başlık ve bitiş işareti', () {
    expect(text.startsWith('%PDF-1.4\n'), isTrue);
    expect(text.trimRight().endsWith('%%EOF'), isTrue);
  });

  test('xref: her giriş gerçekten "N 0 obj" başlangıcını gösterir; startxref xref\'i gösterir', () {
    final start = int.parse(RegExp(r'startxref\n(\d+)\n').firstMatch(text)!.group(1)!);
    expect(text.substring(start).startsWith('xref\n'), isTrue);
    final entries = RegExp(r'(\d{10}) 00000 n \n').allMatches(text.substring(start)).toList();
    expect(entries.length, 5);
    for (var i = 0; i < entries.length; i++) {
      final off = int.parse(entries[i].group(1)!);
      expect(text.substring(off).startsWith('${i + 1} 0 obj\n'), isTrue, reason: 'nesne ${i + 1}');
    }
  });

  test('sayfa boyutu = piksel * 72 / dpi (30x20 px @300dpi = 7.2 x 4.8 pt)', () {
    expect(text, contains('/MediaBox[0 0 7.200 4.800]'));
    expect(text, contains('q 7.200 0 0 4.800 0 0 cm /Im0 Do Q'));
  });

  test('gömülü görüntü kayıpsız: akış açılınca ham RGB piksellerle birebir aynı', () {
    final marker = latin1.decode(bytes).indexOf('/Filter/FlateDecode/Length ');
    expect(marker, greaterThan(0));
    final length = int.parse(RegExp(r'/Length (\d+)>>').firstMatch(text.substring(marker))!.group(1)!);
    final streamStart = text.indexOf('stream\n', marker) + 'stream\n'.length;
    final raw = zlib.decode(bytes.sublist(streamStart, streamStart + length));
    expect(raw.length, 30 * 20 * 3);
    final expected = image.getBytes(order: img.ChannelOrder.rgb);
    expect(raw, expected);
  });

  test('exportLabel PDF dosyasını da yazar', () async {
    final tmp = await Directory.systemTemp.createTemp('pdf_export_');
    try {
      final payload = buildLabelPayload(
        productId: 'TR-PDF-1',
        productType: 'levrek',
        productionDate: '2026-09-24',
        sensorProfileId: 'GENIPIN_PUTRESIN_v2',
        layoutVersion: 'QR_SENSOR_v4',
      );
      final result = await exportLabel(payload, tmp);
      final pdf = await result.paths['pdf']!.readAsBytes();
      expect(latin1.decode(pdf.sublist(0, 8)), '%PDF-1.4');
      // 65x65 modül + 2*4 border, scale 10 = 730 px @300dpi = 175.2 pt
      expect(latin1.decode(pdf), contains('/MediaBox[0 0 '));
    } finally {
      try {
        await tmp.delete(recursive: true);
      } catch (_) {}
    }
  });
}
