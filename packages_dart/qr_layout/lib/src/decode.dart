// packages/qr_layout/decode.py'nin Dart karşılığı — GERÇEK QR çözme
// (rapor §11: "en az iki decoder ile otomatik okut"). ML Kit birincil
// decoder (bkz. apps/freshqr/lib/screens/user/widgets/camera_scanner.dart);
// burası SAF DART yedek decoder — `zxing2` paketi (ZXing'in gerçek Java
// kaynağının Dart portu: finder pattern tespiti, Reed-Solomon, tam
// algoritma — jsQR gibi basitleştirilmiş bir yeniden yazım DEĞİL).
//
// SEÇİM GEREKÇESİ (25 Eylül): `flutter_zxing` (C++ FFI) yerine bu saf-Dart
// paket seçildi — yerel derleme (CMake/NDK) GEREKTİRMİYOR, Windows/web
// dahil her platformda `dart pub get` ile çalışıyor, kurulum riski yok.
// Dart'ın kendi üretiği 24 etikette (3 durum × 8 parti no) DOĞRULANDI:
// temiz görüntüde 36/36, küçültülmüş+bulanık görüntüde kademeli bozulma
// (pyzbar/cv2'nin Python tarafında gösterdiğiyle aynı örüntü) — bkz.
// test/decode_test.dart.
//
// KÖŞE KESTİRİMİ (estimateOuterCorners) — MİMARİ SAPMA, KISMEN
// DOĞRULANMAMIŞ: zxing2'nin `Result.resultPoints`'i QR'ın GERÇEK dış
// köşelerini DEĞİL, finder pattern MERKEZLERİNİ verir (ZXing'in Java
// kaynağıyla aynı davranış, zxing2/lib/src/qrcode/detector/detector.dart
// elle okunarak doğrulandı: `points = [bottomLeft, topLeft, topRight]`).
// Gerçek dış köşe, her finder merkezinden `matrixSize` cinsinden 3.5 modül
// içeride — bu yüzden `matrixSize` bilinmeden köşe hesaplanamaz (ki
// `matrixSize` de ancak metin ÇÖZÜLDÜKTEN ve payload'daki layout_version
// üzerinden `label_export.resolveLabelLayout` çağrıldıktan SONRA bilinir
// — bkz. çağıran taraf, apps/freshqr/lib/services/scan_service.dart).
// Formül (moduleVector = (finder_merkezi_farkı) / (matrixSize - 7), gerçek
// köşe = topLeft_merkezi - 3.5*moduleVector) zxing2'nin KENDİ iç
// `modulesBetweenFPCenters = dimensionForVersion - 7` ilişkisiyle BİREBİR
// aynı — elle doğrulandı. EKSEN-HİZALI (perspektif YOK) sentetik testte
// TAM eşleşiyor (bkz. test/decode_test.dart). GERÇEK KAMERA AÇISI/
// PERSPEKTİFİ ALTINDA DOĞRULANMADI — bu extrapolasyon sadece AFİN
// (döndürme/öteleme/hafif eğiklik) durumda kesin doğru; güçlü perspektif
// altında (ML Kit'in doğrudan verdiği 4 köşeye göre) bir miktar hata
// payı olabilir. Cihaz testinde doğrulanacak (bkz. proje hatırlatma notu).

import 'package:image/image.dart' as img;
import 'package:zxing2/qrcode.dart' as zx;

class QrFinderPoints {
  final ({double x, double y}) topLeft;
  final ({double x, double y}) topRight;
  final ({double x, double y}) bottomLeft;

  const QrFinderPoints({required this.topLeft, required this.topRight, required this.bottomLeft});
}

class ZxingDecodeResult {
  final String text;
  final QrFinderPoints? finderPoints;

  const ZxingDecodeResult(this.text, this.finderPoints);
}

/// `image`'de bir QR arar/çözer. Bulamazsa/çözemezse `null` (istisna
/// fırlatmaz — ML Kit'in bulamama davranışıyla tutarlı, çağıran tarafın
/// "dene, olmazsa diğerine geç" akışına uysun diye).
ZxingDecodeResult? decodeQrZxing(img.Image image) {
  final source = zx.RGBLuminanceSource(
    image.width,
    image.height,
    image.convert(numChannels: 4).getBytes(order: img.ChannelOrder.abgr).buffer.asInt32List(),
  );
  final bitmap = zx.BinaryBitmap(zx.GlobalHistogramBinarizer(source));
  final zx.Result result;
  try {
    result = zx.QRCodeReader().decode(bitmap);
  } catch (_) {
    return null;
  }

  final pts = result.resultPoints;
  QrFinderPoints? finderPoints;
  if (pts.length >= 3) {
    // Sıra zxing2'nin KENDİ Detector.detect()'inde sabit: [bottomLeft,
    // topLeft, topRight] (+ opsiyonel 4. hizalama noktası, burada kullanılmıyor).
    finderPoints = QrFinderPoints(
      bottomLeft: (x: pts[0].x, y: pts[0].y),
      topLeft: (x: pts[1].x, y: pts[1].y),
      topRight: (x: pts[2].x, y: pts[2].y),
    );
  }
  return ZxingDecodeResult(result.text, finderPoints);
}

/// Finder pattern merkezlerinden QR'ın GERÇEK dış köşelerini kestirir —
/// bkz. dosya başlığı notu. Dönen sıra `color_engine.analyzeFrame`'in
/// beklediğiyle AYNI: sol-üst, sağ-üst, sağ-alt, sol-alt.
List<List<double>> estimateOuterCorners(QrFinderPoints points, int matrixSize) {
  if (matrixSize <= 7) {
    throw ArgumentError('matrixSize (verilen: $matrixSize) finder pattern\'lardan (7 modül) büyük olmalı.');
  }
  final n = matrixSize.toDouble();
  final modulesBetweenCenters = n - 7;

  final tl = points.topLeft, tr = points.topRight, bl = points.bottomLeft;
  final mCol = (x: (tr.x - tl.x) / modulesBetweenCenters, y: (tr.y - tl.y) / modulesBetweenCenters);
  final mRow = (x: (bl.x - tl.x) / modulesBetweenCenters, y: (bl.y - tl.y) / modulesBetweenCenters);

  final trueTlX = tl.x - 3.5 * mCol.x - 3.5 * mRow.x;
  final trueTlY = tl.y - 3.5 * mCol.y - 3.5 * mRow.y;
  final trueTrX = trueTlX + n * mCol.x, trueTrY = trueTlY + n * mCol.y;
  final trueBlX = trueTlX + n * mRow.x, trueBlY = trueTlY + n * mRow.y;
  final trueBrX = trueTrX + n * mRow.x, trueBrY = trueTrY + n * mRow.y;

  return [
    [trueTlX, trueTlY],
    [trueTrX, trueTrY],
    [trueBrX, trueBrY],
    [trueBlX, trueBlY],
  ];
}
