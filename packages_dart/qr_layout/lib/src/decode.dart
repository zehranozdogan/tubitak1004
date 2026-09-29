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
// KÖŞE KESTİRİMİ (estimateOuterCorners) — MİMARİ SAPMA: zxing2'nin
// `Result.resultPoints`'i QR'ın GERÇEK dış köşelerini DEĞİL, finder
// pattern MERKEZLERİNİ (+ opsiyonel 4. hizalama deseni merkezini) verir
// (ZXing'in Java kaynağıyla aynı davranış, detector.dart elle okunarak
// doğrulandı). Gerçek dış köşe, her finder merkezinden `matrixSize`
// cinsinden 3.5 modül içeride — bu yüzden `matrixSize` bilinmeden köşe
// hesaplanamaz (ki `matrixSize` de ancak metin ÇÖZÜLDÜKTEN ve payload'daki
// layout_version üzerinden `label_export.resolveLabelLayout` çağrıldıktan
// SONRA bilinir — bkz. çağıran taraf, apps/freshqr/lib/services/
// scan_service.dart).
//
// İKİ YÖNTEM (28 Eylül, `points.alignment` varsa/yoksa dallanır):
// - HOMOGRAFİ (`_estimateOuterCornersViaHomography`, tercih edilen):
//   4. (hizalama deseni) nokta varsa GERÇEK bir projektif dönüşüm kurulur
//   — zxing2'nin KENDİ `Detector._createTransform`/`PerspectiveTransform`
//   matematiğinin BİREBİR portu (bkz. perspective_transform.dart başlığı),
//   TÜM ızgarayı örneklemek için zxing2'nin GERÇEKTEN kullandığı/güvendiği
//   aynı dönüşüm. BİLİNEN bir homografiden üretilen sentetik noktalarda
//   analitik olarak KESİN doğru (alt-piksel), GERÇEK (sentetik) perspektif
//   altında da afin kestirimden ÖLÇÜLEBİLİR ÖLÇÜDE (~80 kat, en uzak
//   köşede) daha doğru (bkz. test/decode_test.dart "GERÇEK PERSPEKTİF
//   ALTINDA").
// - AFİN (`_estimateOuterCornersAffine`, yedek): sadece 3 nokta varsa
//   (versiyon 1 — hizalama deseni yok — ya da desen bulunamadıysa).
//   Formül (moduleVector = (finder_merkezi_farkı) / (matrixSize - 7),
//   gerçek köşe = topLeft_merkezi - 3.5*moduleVector) zxing2'nin KENDİ iç
//   `modulesBetweenFPCenters = dimensionForVersion - 7` ilişkisiyle
//   BİREBİR aynı — elle doğrulandı. EKSEN-HİZALI (perspektif YOK) sentetik
//   testte TAM eşleşiyor. GERÇEK KAMERA AÇISI/PERSPEKTİFİ ALTINDA sadece
//   AFİN (döndürme/öteleme/hafif eğiklik) durumda kesin doğru — güçlü
//   perspektifte bir miktar hata payı olabilir (bu yüzden versiyon >= 2'de
//   artık HOMOGRAFİ tercih ediliyor, bu yedek sadece hizalama deseni
//   bulunamadığında devreye girer).

import 'package:image/image.dart' as img;
import 'package:zxing2/qrcode.dart' as zx;

import 'perspective_transform.dart';

class QrFinderPoints {
  final ({double x, double y}) topLeft;
  final ({double x, double y}) topRight;
  final ({double x, double y}) bottomLeft;
  // zxing2'nin opsiyonel 4. noktası (hizalama deseni merkezi, QR versiyon
  // >= 2'de genelde mevcut) — varsa `estimateOuterCorners` GERÇEK bir
  // projektif dönüşüm (homografi) kurar; yoksa (versiyon 1 ya da desen
  // bulunamadıysa) eski 3-noktalı afin kestirime düşer (bkz. o fonksiyon).
  final ({double x, double y})? alignment;

  const QrFinderPoints({
    required this.topLeft,
    required this.topRight,
    required this.bottomLeft,
    this.alignment,
  });
}

class ZxingDecodeResult {
  final String text;
  final QrFinderPoints? finderPoints;

  const ZxingDecodeResult(this.text, this.finderPoints);
}

/// `image`'de bir QR arar/çözer. Bulamazsa/çözemezse `null` (istisna
/// fırlatmaz — ML Kit'in bulamama davranışıyla tutarlı, çağıran tarafın
/// "dene, olmazsa diğerine geç" akışına uysun diye).
///
/// BİNARİZER SEÇİMİ (25 Eylül, gerçek cihaz testinde bulunan hata): önce
/// `GlobalHistogramBinarizer` kullanılıyordu (zxing2'nin README örneğindeki
/// gibi) — bu, TÜM görüntü için TEK bir eşik hesaplıyor, düzensiz ışık/
/// gölge altında (gerçek bir telefon fotoğrafı — basılı etiket, oda ışığı)
/// başarısız oluyordu (telefonla çekilmiş basılı etiket fotoğrafında "QR
/// bulunamadı", zxing2'nin kendi sınıf dokümanı bunu AÇIKÇA uyarıyor:
/// "tends to [fail] with severe shadows and gradients"). `HybridBinarizer`
/// (aynı dokümanda "recommended class for library users") BÖLGESEL eşik
/// hesaplıyor — önce bunu, olmazsa (görüntü çok küçükse HybridBinarizer
/// minimum boyut ister) Global'e düşer.
///
/// JPEG-ARTEFAKT YEDEĞİ (29 Eylül, gerçekçi BİRLEŞİK bozulma matrisiyle
/// bulundu — bkz. test/decode_test.dart "GERÇEK BİRLEŞİK BOZULMA"): 108
/// (perspektif × ışık × bulanıklık × JPEG kalitesi) kombinasyonluk bir
/// stres testinde başarısızlıkların TAMAMI düşük JPEG kalitesiyle (blok
/// artefaktı) ilişkiliydi — diğer üç faktör (perspektif/ışık/bulanıklık)
/// TEK BAŞINA sorun değildi, JPEG bloklamasıyla BİRLEŞİNCE eşiği
/// düşürüyordu. Hem Hybrid hem Global başarısız olursa artık 3x3 kutu
/// bulanıklaştırma (`_lightDenoise` — JPEG'in 8x8 DCT blok sınırlarındaki
/// yüksek-frekans gürültüsünü yumuşatır, gerçek modül yapısını bozacak
/// kadar güçlü DEĞİL) uygulanıp İKİ binarizer de tekrar denenir. Ölçülen
/// sonuç: aynı 108'lik matriste eski davranış 85/108, bu yedekle 108/108
/// — SIFIR regresyon (yedek sadece ikisi de başarısız OLURSA devreye
/// giriyor, mutlu yolda ekstra maliyet yok).
ZxingDecodeResult? decodeQrZxing(img.Image image) {
  final result = _decodeWithBothBinarizers(image) ?? _decodeWithBothBinarizers(_lightDenoise(image));
  if (result == null) return null;

  final pts = result.resultPoints;
  QrFinderPoints? finderPoints;
  if (pts.length >= 3) {
    // Sıra zxing2'nin KENDİ Detector.detect()'inde sabit: [bottomLeft,
    // topLeft, topRight, (opsiyonel) hizalama deseni] — bkz.
    // zxing2/lib/src/qrcode/detector/detector.dart processFinderPatternInfo,
    // elle okunarak doğrulandı.
    finderPoints = QrFinderPoints(
      bottomLeft: (x: pts[0].x, y: pts[0].y),
      topLeft: (x: pts[1].x, y: pts[1].y),
      topRight: (x: pts[2].x, y: pts[2].y),
      alignment: pts.length >= 4 ? (x: pts[3].x, y: pts[3].y) : null,
    );
  }
  return ZxingDecodeResult(result.text, finderPoints);
}

/// Hybrid, olmazsa Global binarizer ile TEK bir görüntüde decode dener.
/// Her ikisi de başarısızsa `null` (istisna fırlatmaz).
zx.Result? _decodeWithBothBinarizers(img.Image image) {
  zx.LuminanceSource source() => zx.RGBLuminanceSource(
        image.width,
        image.height,
        image.convert(numChannels: 4).getBytes(order: img.ChannelOrder.abgr).buffer.asInt32List(),
      );
  for (final binarizer in [zx.HybridBinarizer(source()), zx.GlobalHistogramBinarizer(source())]) {
    try {
      return zx.QRCodeReader().decode(zx.BinaryBitmap(binarizer));
    } catch (_) {
      continue;
    }
  }
  return null;
}

/// 3x3 kutu bulanıklaştırma — bkz. `decodeQrZxing` başlığındaki "JPEG-
/// ARTEFAKT YEDEĞİ" notu. Bilinçli olarak ÇOK KÜÇÜK (yarıçap 1): sadece
/// JPEG'in blok-sınırı gürültüsünü yumuşatmaya yeter, gerçek hareket
/// bulanıklığı testlerinde (bkz. aynı dosyadaki "GERÇEK CİHAZ BUG
/// REGRESYONU") kullanılan çok daha büyük yarıçaplarla KARIŞTIRILMAMALI —
/// o tür gerçek bulanıklığı düzeltmeye çalışmaz (denendi, işe yaramadı,
/// bkz. apps/freshqr/test/realistic_distortions_test.dart "DENENDİ, İŞE
/// YARAMADI" notu — BU fonksiyon o denemeden FARKLI: burada amaç JPEG
/// blok gürültüsü, orada amaç gerçek hareket bulanıklığını TERSİNE
/// ÇEVİRMEKTİ, işe yaramayan oydu).
img.Image _lightDenoise(img.Image image) {
  final out = img.Image.from(image);
  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      var r = 0, g = 0, b = 0, n = 0;
      for (var dy = -1; dy <= 1; dy++) {
        for (var dx = -1; dx <= 1; dx++) {
          final sx = (x + dx).clamp(0, image.width - 1);
          final sy = (y + dy).clamp(0, image.height - 1);
          final p = image.getPixel(sx, sy);
          r += p.r.toInt();
          g += p.g.toInt();
          b += p.b.toInt();
          n++;
        }
      }
      out.setPixelRgb(x, y, r ~/ n, g ~/ n, b ~/ n);
    }
  }
  return out;
}

/// Finder pattern merkezlerinden (+ varsa hizalama deseninden) QR'ın
/// GERÇEK dış köşelerini kestirir — bkz. dosya başlığı notu. Dönen sıra
/// `color_engine.analyzeFrame`'in beklediğiyle AYNI: sol-üst, sağ-üst,
/// sağ-alt, sol-alt.
///
/// `points.alignment` DOLUYSA (bkz. QrFinderPoints, genelde QR versiyon
/// >= 2'de mevcut) GERÇEK bir projektif dönüşüm (homografi, 28 Eylül
/// eklendi — bkz. perspective_transform.dart başlığı) kullanılır; bu,
/// gerçek kamera perspektifi/açısı altında saf afin kestirimden DAHA
/// DOĞRU olması beklenir (afin sadece 3 nokta ile kurulabiliyordu,
/// perspektif projeksiyonu tam temsil edemez — bkz. dosya başlığındaki
/// eski not). BOŞSA (versiyon 1 ya da desen bulunamadı) eski 3-noktalı
/// afin kestirime düşülür — o formülün doğrulama/sınırları için aşağıdaki
/// `_estimateOuterCornersAffine`'e bkz.
List<List<double>> estimateOuterCorners(QrFinderPoints points, int matrixSize) {
  if (matrixSize <= 7) {
    throw ArgumentError('matrixSize (verilen: $matrixSize) finder pattern\'lardan (7 modül) büyük olmalı.');
  }
  final alignment = points.alignment;
  if (alignment != null) {
    return _estimateOuterCornersViaHomography(points, alignment, matrixSize);
  }
  return _estimateOuterCornersAffine(points, matrixSize);
}

/// GERÇEK projektif dönüşüm — bkz. estimateOuterCorners. Kaynak (modül-
/// uzayı) ve hedef (piksel-uzayı) dörtgenleri zxing2'nin KENDİ
/// `Detector._createTransform`'uyla BİREBİR aynı kurulur (elle okunarak
/// doğrulandı, bkz. perspective_transform.dart başlığı): hizalama
/// deseninin modül-uzayı konumu `matrixSize - 6.5` (zxing2'nin TÜM
/// ızgarayı örneklemek için fiilen kullandığı değer — gerçek decode
/// başarılı olduğunda bu değerin doğruluğu zaten kanıtlanmış oluyor,
/// checksum/Reed-Solomon geçmemiş olurdu).
List<List<double>> _estimateOuterCornersViaHomography(
  QrFinderPoints points,
  ({double x, double y}) alignment,
  int matrixSize,
) {
  final n = matrixSize.toDouble();
  final dimMinusThree = n - 3.5;
  final transform = PerspectiveTransform.quadrilateralToQuadrilateral(
    3.5, 3.5, dimMinusThree, 3.5, n - 6.5, n - 6.5, 3.5, dimMinusThree, //
    points.topLeft.x, points.topLeft.y, //
    points.topRight.x, points.topRight.y, //
    alignment.x, alignment.y, //
    points.bottomLeft.x, points.bottomLeft.y,
  );
  final corners = [0.0, 0.0, n, 0.0, n, n, 0.0, n];
  transform.transformPoints(corners);
  return [
    [corners[0], corners[1]],
    [corners[2], corners[3]],
    [corners[4], corners[5]],
    [corners[6], corners[7]],
  ];
}

List<List<double>> _estimateOuterCornersAffine(QrFinderPoints points, int matrixSize) {
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
