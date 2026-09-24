// Basılabilir etiketin PDF'i — packages/qr_layout/render.py::save_label_pdf'in
// Dart karşılığı (rapor s.12: "300 dpi"). Sayfa boyutu = görüntü piksel
// sayısının `dpi` çözünürlüğündeki fiziksel ölçüsü; kenar boşluğu YOK,
// görüntü sayfayı tam kaplar (baskıda modül boyutu birebir korunur).
//
// MİMARİ SAPMA: `pdf` paketi KULLANILMADI — `pdf -> barcode -> qr ^3`
// bağımlılığı, QR üretimi için seçtiğimiz `qr ^4` ile çakışıyor
// (`pub` çözemiyor). Tek bir görüntüyü sayfaya koyan PDF'in yapısı küçük
// ve sabit (katalog, sayfa listesi, sayfa, içerik akışı, görüntü nesnesi,
// xref), o yüzden elle yazıldı; dış bağımlılık yok. Görüntü ham RGB +
// FlateDecode olarak gömülür (kayıpsız).

import 'dart:convert';
import 'dart:io' show zlib;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

const double _pointsPerInch = 72.0;

String _num(double v) => v.toStringAsFixed(3);

Uint8List labelPdfBytes(img.Image image, {double dpi = 300}) {
  final rgb = image.convert(numChannels: 3);
  final raw = rgb.getBytes(order: img.ChannelOrder.rgb);
  final compressed = Uint8List.fromList(zlib.encode(raw));

  final w = image.width * _pointsPerInch / dpi;
  final h = image.height * _pointsPerInch / dpi;
  final content = latin1.encode('q ${_num(w)} 0 0 ${_num(h)} 0 0 cm /Im0 Do Q\n');

  final out = BytesBuilder(copy: false);
  final offsets = <int>[];
  var length = 0;
  void write(List<int> bytes) {
    out.add(bytes);
    length += bytes.length;
  }

  void writeStr(String s) => write(latin1.encode(s));

  void obj(int n, String dict, {List<int>? stream}) {
    offsets.add(length);
    writeStr('$n 0 obj\n');
    if (stream == null) {
      writeStr('$dict\nendobj\n');
    } else {
      writeStr('${dict.replaceFirst('>>', '/Length ${stream.length}>>')}\nstream\n');
      write(stream);
      writeStr('\nendstream\nendobj\n');
    }
  }

  writeStr('%PDF-1.4\n');
  write(const [0x25, 0xE2, 0xE3, 0xCF, 0xD3, 0x0A]); // ikili içerik işareti
  obj(1, '<</Type/Catalog/Pages 2 0 R>>');
  obj(2, '<</Type/Pages/Kids[3 0 R]/Count 1>>');
  obj(
    3,
    '<</Type/Page/Parent 2 0 R/MediaBox[0 0 ${_num(w)} ${_num(h)}]'
    '/Resources<</XObject<</Im0 5 0 R>>>>/Contents 4 0 R>>',
  );
  obj(4, '<<>>', stream: content);
  obj(
    5,
    '<</Type/XObject/Subtype/Image/Width ${image.width}/Height ${image.height}'
    '/ColorSpace/DeviceRGB/BitsPerComponent 8/Filter/FlateDecode>>',
    stream: compressed,
  );

  final xrefOffset = length;
  writeStr('xref\n0 ${offsets.length + 1}\n0000000000 65535 f \n');
  for (final o in offsets) {
    writeStr('${o.toString().padLeft(10, '0')} 00000 n \n');
  }
  writeStr('trailer\n<</Size ${offsets.length + 1}/Root 1 0 R>>\nstartxref\n$xrefOffset\n%%EOF\n');
  return out.toBytes();
}
