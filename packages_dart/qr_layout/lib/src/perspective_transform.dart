// GERÇEK bir projektif dönüşüm (homografi) — 4 kaynak + 4 hedef noktadan
// dönüşümü çözer (George Wolberg, "Digital Image Warping", §3.4.2).
//
// KAYNAK/DOĞRULAMA (28 Eylül): bu, `zxing2` paketinin KENDİ
// `lib/src/common/perspective_transform.dart` dosyasının BİREBİR portu
// (elle okunarak, sabit sabit doğrulanarak taşındı) — zxing2 bunu paket
// genel API'sinde dışa AÇMIYOR (`zxing2.dart`/`qrcode.dart` export
// listesinde yok), bu yüzden `package:zxing2/src/...` gibi kırılgan bir
// dahili yoldan içe aktarmak yerine küçük/kendi kendine yeten olduğu için
// burada bağımsız bir kopya tutuluyor.
//
// Neden önemli: zxing2'nin KENDİ `Detector._createTransform` fonksiyonu
// TÜM QR ızgarasını örneklemek için AYNI bu sınıfı kullanıyor — yani
// gerçek bir decode BAŞARILI olduğunda (checksum/Reed-Solomon geçtiğinde)
// bu dönüşümün doğruluğu zaten KANITLANMIŞ oluyor. `decode.dart` bunu
// TÜM ızgarayı örneklemek için değil, sadece QR'ın 4 gerçek dış köşesinin
// piksel konumunu (finder + hizalama deseni noktalarından) kestirmek için
// kullanıyor (bkz. estimateOuterCorners).
class PerspectiveTransform {
  final double a11, a12, a13, a21, a22, a23, a31, a32, a33;

  const PerspectiveTransform._(
    this.a11,
    this.a21,
    this.a31,
    this.a12,
    this.a22,
    this.a32,
    this.a13,
    this.a23,
    this.a33,
  );

  /// Kaynak dörtgen (x0,y0)-(x1,y1)-(x2,y2)-(x3,y3) -> hedef dörtgen
  /// (x0p,y0p)-...-(x3p,y3p) dönüşümünü çözer. Nokta sırası: TL, TR, BR, BL
  /// (saat yönünde, sol-üstten başlar) — zxing2'nin kendi kullanımıyla AYNI.
  static PerspectiveTransform quadrilateralToQuadrilateral(
    double x0,
    double y0,
    double x1,
    double y1,
    double x2,
    double y2,
    double x3,
    double y3,
    double x0p,
    double y0p,
    double x1p,
    double y1p,
    double x2p,
    double y2p,
    double x3p,
    double y3p,
  ) {
    final qToS = _quadrilateralToSquare(x0, y0, x1, y1, x2, y2, x3, y3);
    final sToQ = _squareToQuadrilateral(x0p, y0p, x1p, y1p, x2p, y2p, x3p, y3p);
    return sToQ._times(qToS);
  }

  /// `points` = [x0,y0, x1,y1, ...] — yerinde (in-place) dönüştürür.
  void transformPoints(List<double> points) {
    final maxI = points.length - 1;
    for (var i = 0; i < maxI; i += 2) {
      final x = points[i];
      final y = points[i + 1];
      final denominator = a13 * x + a23 * y + a33;
      points[i] = (a11 * x + a21 * y + a31) / denominator;
      points[i + 1] = (a12 * x + a22 * y + a32) / denominator;
    }
  }

  static PerspectiveTransform _squareToQuadrilateral(
    double x0,
    double y0,
    double x1,
    double y1,
    double x2,
    double y2,
    double x3,
    double y3,
  ) {
    final dx3 = x0 - x1 + x2 - x3;
    final dy3 = y0 - y1 + y2 - y3;
    if (dx3 == 0.0 && dy3 == 0.0) {
      // Afin (dörtgen zaten paralelkenar)
      return PerspectiveTransform._(x1 - x0, x2 - x1, x0, y1 - y0, y2 - y1, y0, 0.0, 0.0, 1.0);
    }
    final dx1 = x1 - x2;
    final dx2 = x3 - x2;
    final dy1 = y1 - y2;
    final dy2 = y3 - y2;
    final denominator = dx1 * dy2 - dx2 * dy1;
    final a13 = (dx3 * dy2 - dx2 * dy3) / denominator;
    final a23 = (dx1 * dy3 - dx3 * dy1) / denominator;
    return PerspectiveTransform._(
      x1 - x0 + a13 * x1,
      x3 - x0 + a23 * x3,
      x0,
      y1 - y0 + a13 * y1,
      y3 - y0 + a23 * y3,
      y0,
      a13,
      a23,
      1.0,
    );
  }

  static PerspectiveTransform _quadrilateralToSquare(
    double x0,
    double y0,
    double x1,
    double y1,
    double x2,
    double y2,
    double x3,
    double y3,
  ) {
    // Adjoint (kofaktör matrisin transpozu), 3x3'te tersle aynı işi görür.
    return _squareToQuadrilateral(x0, y0, x1, y1, x2, y2, x3, y3)._buildAdjoint();
  }

  PerspectiveTransform _buildAdjoint() {
    return PerspectiveTransform._(
      a22 * a33 - a23 * a32,
      a23 * a31 - a21 * a33,
      a21 * a32 - a22 * a31,
      a13 * a32 - a12 * a33,
      a11 * a33 - a13 * a31,
      a12 * a31 - a11 * a32,
      a12 * a23 - a13 * a22,
      a13 * a21 - a11 * a23,
      a11 * a22 - a12 * a21,
    );
  }

  PerspectiveTransform _times(PerspectiveTransform other) {
    return PerspectiveTransform._(
      a11 * other.a11 + a21 * other.a12 + a31 * other.a13,
      a11 * other.a21 + a21 * other.a22 + a31 * other.a23,
      a11 * other.a31 + a21 * other.a32 + a31 * other.a33,
      a12 * other.a11 + a22 * other.a12 + a32 * other.a13,
      a12 * other.a21 + a22 * other.a22 + a32 * other.a23,
      a12 * other.a31 + a22 * other.a32 + a32 * other.a33,
      a13 * other.a11 + a23 * other.a12 + a33 * other.a13,
      a13 * other.a21 + a23 * other.a22 + a33 * other.a23,
      a13 * other.a31 + a23 * other.a32 + a33 * other.a33,
    );
  }
}
