// Cihazdan seçilmiş bir fotoğrafı (galeri/dosya) tüm okuyucu zincirinden
// geçirir — canlı kamera akışının (widgets/camera_scanner.dart) STATİK
// görüntü karşılığı. Aynı iki decoder (ML Kit + zxing2 yedek) kullanılır.
//
// EXIF DÖNDÜRME: `package:image`'in `decodeImage`'i EXIF orientation
// etiketini pikselleri fiilen döndürmeden SADECE metadata olarak taşır
// (elle doğrulandı — jpeg_decoder.dart'ta `bakeOrientation` ayrı, opt-in
// bir adım). Bu yüzden zxing2/kendi RGB analizimiz için `img.bakeOrientation`
// AÇIKÇA çağrılıyor. ML Kit'in `InputImage.fromFilePath` yolu ise Google'ın
// KENDİ dokümante ettiği standart davranışla EXIF-farkında (canlı kamera
// akışındaki NV21+sensorOrientation varsayımının aksine bu, cihaz testine
// muhtaç, DOĞRULANMAMIŞ bir varsayım DEĞİL — dosya tabanlı QR tarama için
// yaygın, belgeli bir kullanım deseni).

import 'dart:io';

import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:image/image.dart' as img;
import 'package:qr_layout/qr_layout.dart' show QrFinderPoints, decodeQrZxing;

import '../data/reference_data.dart';
import '../screens/user/widgets/camera_scanner.dart' show cameraScanSupported;
import 'scan_service.dart';

Future<ScanOutcome> analyzePickedImagePath(String path, ReferenceData reference) async {
  final bytes = await File(path).readAsBytes();
  img.Image? decoded;
  try {
    // Çok kısa/bozuk dosyalarda bazı format dedektörleri (ör. PSD header
    // kontrolü) null DÖNMEK yerine İSTİSNA fırlatıyor — elle doğrulandı
    // (test/static_image_scan_test.dart). Bu yüzden try/catch de gerekli,
    // sadece null kontrolü YETERSİZ.
    decoded = img.decodeImage(bytes);
  } catch (_) {
    decoded = null;
  }
  if (decoded == null) return const ScanInvalidQr('Görsel çözülemedi (desteklenmeyen biçim/bozuk dosya)');
  final oriented = img.bakeOrientation(decoded);

  String? qrText;
  List<List<double>>? corners;
  QrFinderPoints? finderPoints;

  if (cameraScanSupported) {
    final scanner = BarcodeScanner(formats: [BarcodeFormat.qrCode]);
    try {
      final barcodes = await scanner.processImage(InputImage.fromFilePath(path));
      for (final barcode in barcodes) {
        final text = barcode.rawValue;
        final points = barcode.cornerPoints;
        if (barcode.format == BarcodeFormat.qrCode && text != null && points.length == 4) {
          qrText = text;
          corners = [for (final p in points) [p.x.toDouble(), p.y.toDouble()]];
          break;
        }
      }
    } catch (_) {
      // ML Kit bu görüntüde başarısız oldu — zxing2 yedeği denenecek.
    } finally {
      await scanner.close();
    }
  }

  if (qrText == null) {
    final zx = decodeQrZxing(oriented);
    if (zx != null && zx.finderPoints != null) {
      qrText = zx.text;
      finderPoints = zx.finderPoints;
    }
  }

  if (qrText == null) {
    return const ScanInvalidQr('Görselde okunabilir bir FreshQR etiketi bulunamadı.');
  }

  return analyzeCapturedLabel(
    qrText: qrText,
    image: rgbImageFromImage(oriented),
    corners: corners,
    finderPoints: finderPoints,
    reference: reference,
  );
}
