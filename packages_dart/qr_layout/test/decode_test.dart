// decode.dart testleri — bkz. lib/src/decode.dart dosya başlığı (seçim
// gerekçesi, köşe kestirim formülünün kaynağı ve sınırları).

import 'dart:math' as math;

import 'package:image/image.dart' as img;
import 'package:qr_layout/qr_layout.dart';
import 'package:qr_layout/src/perspective_transform.dart';
import 'package:test/test.dart';
import 'package:zxing2/qrcode.dart' as zx;

const _matrixSize = 65; // gerçek: GENIPIN payload -> qr version 12
const _scale = 10;
const _border = 4;

/// Üstten alta doğru KOYULAŞAN bir gölge — gerçek bir telefon fotoğrafındaki
/// düzensiz oda ışığını/gölgeyi taklit eder (tek yönlü ışık kaynağı).
img.Image _withGradientShadow(img.Image src, double darkFactor) {
  final out = src.clone();
  for (var y = 0; y < out.height; y++) {
    final factor = 1.0 - darkFactor * (y / out.height);
    for (var x = 0; x < out.width; x++) {
      final p = out.getPixel(x, y);
      out.setPixelRgb(x, y, (p.r * factor).round(), (p.g * factor).round(), (p.b * factor).round());
    }
  }
  return out;
}

/// Temiz (eksen-hizalı) bir etiket görüntüsünü GERÇEK bir projektif
/// dönüşümle (homografi) daha büyük bir "fotoğraf" tuvaline çarpıtır —
/// GERÇEK kamera açısını (yamuk/trapezoid, saf afin DEĞİL: kenarlar
/// paralel kalmıyor) simüle eder. `PerspectiveTransform`'un kendisini
/// kullanır (decode.dart'taki `estimateOuterCorners`'ın homografi dalıyla
/// AYNI sınıf) — ters (hedef -> kaynak) dönüşüm hesaplanıp her tuval
/// pikseli için en-yakın-komşu örnekleme yapılır.
({img.Image warped, List<List<double>> trueCorners}) _withPerspectiveWarp(
  img.Image clean, {
  required List<double> destTopLeft,
  required List<double> destTopRight,
  required List<double> destBottomRight,
  required List<double> destBottomLeft,
  required int canvasWidth,
  required int canvasHeight,
}) {
  final w = clean.width.toDouble();
  final h = clean.height.toDouble();

  final inverse = PerspectiveTransform.quadrilateralToQuadrilateral(
    destTopLeft[0], destTopLeft[1], destTopRight[0], destTopRight[1], //
    destBottomRight[0], destBottomRight[1], destBottomLeft[0], destBottomLeft[1], //
    0, 0, w, 0, w, h, 0, h,
  );

  final forward = PerspectiveTransform.quadrilateralToQuadrilateral(
    0, 0, w, 0, w, h, 0, h, //
    destTopLeft[0], destTopLeft[1], destTopRight[0], destTopRight[1], //
    destBottomRight[0], destBottomRight[1], destBottomLeft[0], destBottomLeft[1],
  );
  // DİKKAT: "gerçek dış köşe" QR MATRİSİNİN kendi sınırı (modül 0,0..n,n),
  // temiz görüntünün TÜM piksel alanı DEĞİL — clean image'da `_border`
  // modül kadar sessiz bölge (quiet zone) var (bkz. mevcut eksen-hizalı
  // testteki "truth" tablosu, AYNI ofset). Bunu unutmak (temiz görüntünün
  // ham (0,0)-(w,h) sınırını kullanmak) devasa, yanıltıcı bir "hata"
  // üretiyordu — ilk yazımda böyle bir hataya düşüldü, elle izole edilip
  // düzeltildi (bkz. sohbet geçmişi, 28 Eylül).
  final b = (_border * _scale).toDouble();
  final nb = w - b;
  final trueCornersFlat = [b, b, nb, b, nb, nb, b, nb];
  forward.transformPoints(trueCornersFlat);
  final trueCorners = [
    [trueCornersFlat[0], trueCornersFlat[1]],
    [trueCornersFlat[2], trueCornersFlat[3]],
    [trueCornersFlat[4], trueCornersFlat[5]],
    [trueCornersFlat[6], trueCornersFlat[7]],
  ];

  final out = img.Image(width: canvasWidth, height: canvasHeight, numChannels: 3);
  img.fill(out, color: img.ColorRgb8(255, 255, 255));
  for (var y = 0; y < canvasHeight; y++) {
    for (var x = 0; x < canvasWidth; x++) {
      final srcPoint = [x.toDouble(), y.toDouble()];
      inverse.transformPoints(srcPoint);
      final sx = srcPoint[0].round(), sy = srcPoint[1].round();
      if (sx >= 0 && sx < clean.width && sy >= 0 && sy < clean.height) {
        out.setPixel(x, y, clean.getPixel(sx, sy));
      }
    }
  }
  return (warped: out, trueCorners: trueCorners);
}

double _dist(List<double> a, List<double> b) {
  final dx = a[0] - b[0], dy = a[1] - b[1];
  return math.sqrt(dx * dx + dy * dy);
}

/// Tek eksenli kutu bulanıklaştırma — hareket bulanıklığının basit bir
/// simülasyonu (apps/freshqr/test/realistic_distortions_test.dart'taki
/// AYNI teknik).
img.Image _withBoxBlur(img.Image src, int radius) {
  if (radius == 0) return src;
  final out = img.Image.from(src);
  for (var y = 0; y < src.height; y++) {
    for (var x = 0; x < src.width; x++) {
      var r = 0, g = 0, b = 0, n = 0;
      for (var k = -radius; k <= radius; k++) {
        final sx = (x + k).clamp(0, src.width - 1);
        final p = src.getPixel(sx, y);
        r += p.r.toInt();
        g += p.g.toInt();
        b += p.b.toInt();
        n++;
      }
      out.setPixelRgb(x, y, r ~/ n, g ~/ n, b ~/ n);
    }
  }
  return out;
}

/// JPEG sıkıştırma round-trip'i (gerçek telefon fotoğrafları PNG değil).
img.Image _withJpeg(img.Image src, int quality) {
  return img.decodeJpg(img.encodeJpg(src, quality: quality))!;
}

/// `decodeQrZxing`'in KENDİ `_lightDenoise` yedeğini DEVRE DIŞI bırakan
/// eski davranış — SADECE karşılaştırma için (bkz. aşağıdaki test).
bool _decodeWithoutDenoiseFallback(img.Image image) {
  zx.LuminanceSource source() => zx.RGBLuminanceSource(
        image.width,
        image.height,
        image.convert(numChannels: 4).getBytes(order: img.ChannelOrder.abgr).buffer.asInt32List(),
      );
  for (final binarizer in [zx.HybridBinarizer(source()), zx.GlobalHistogramBinarizer(source())]) {
    try {
      zx.QRCodeReader().decode(zx.BinaryBitmap(binarizer));
      return true;
    } catch (_) {
      continue;
    }
  }
  return false;
}

bool _decodeWithGlobalHistogramOnly(img.Image image) {
  final source = zx.RGBLuminanceSource(
    image.width,
    image.height,
    image.convert(numChannels: 4).getBytes(order: img.ChannelOrder.abgr).buffer.asInt32List(),
  );
  try {
    zx.QRCodeReader().decode(zx.BinaryBitmap(zx.GlobalHistogramBinarizer(source)));
    return true;
  } catch (_) {
    return false;
  }
}

img.Image _renderReal() {
  final qr = generateQr(
    '{"product_id":"TR45678","product_type":"LEVREK","production_date":"2026-09-25",'
    '"sensor_profile_id":"GENIPIN_PUTRESIN_v2","layout_version":"QR_SENSOR_v4"}',
    error: 'h',
  );
  expect(qr.version, 12); // matrixSize=65 varsayımını doğrula
  final layout = buildLayout(
    version: qr.version,
    eccLevel: qr.eccLevel,
    sensorModules: const [],
    layoutVersion: 'QR_SENSOR_v4',
  );
  return renderColoredImage(qr, layout, scale: _scale, border: _border);
}

void main() {
  group('decodeQrZxing', () {
    test('gerçek etiket görüntüsünü BİREBİR aynı metinle çözer, 3 finder noktası döner', () {
      final image = _renderReal();
      final result = decodeQrZxing(image);
      expect(result, isNotNull);
      expect(
        result!.text,
        '{"product_id":"TR45678","product_type":"LEVREK","production_date":"2026-09-25",'
        '"sensor_profile_id":"GENIPIN_PUTRESIN_v2","layout_version":"QR_SENSOR_v4"}',
      );
      expect(result.finderPoints, isNotNull);
    });

    test('QR içermeyen düz bir görüntüde null döner (istisna fırlatmaz)', () {
      final blank = img.Image(width: 200, height: 200, numChannels: 3);
      img.fill(blank, color: img.ColorRgb8(255, 255, 255));
      expect(decodeQrZxing(blank), isNull);
    });

    test(
        'GERÇEK CİHAZ BUG REGRESYONU (25 Eylül): düzensiz ışık gölgesi altında '
        'HybridBinarizer çözer, GlobalHistogramBinarizer (eski, tek başına) ÇÖZEMEZ', () {
      final clean = _renderReal();
      // darkFactor 0.5/0.65: telefonla çekilmiş basılı bir etiketin
      // "Görselde okunabilir bir FreshQR etiketi bulunamadı" hatası
      // vermesine yol açan GERÇEK örüntü — bkz. dosya başlığı.
      for (final darkFactor in [0.5, 0.65]) {
        final shaded = _withGradientShadow(clean, darkFactor);
        expect(_decodeWithGlobalHistogramOnly(shaded), isFalse, reason: 'darkFactor=$darkFactor: eski davranış ZATEN başarısızdı (regresyon varsayımı)');
        expect(decodeQrZxing(shaded), isNotNull, reason: 'darkFactor=$darkFactor: HybridBinarizer içeren GÜNCEL decodeQrZxing çözebilmeli');
      }
    });

    test(
        'GERÇEK BİRLEŞİK BOZULMA (29 Eylül): JPEG blok artefaktı diğer '
        'bozulmalarla (perspektif/ışık/bulanıklık) BİRLEŞİNCE eski davranış '
        'başarısız olur, hafif-denoise yedeği düzeltir', () {
      // 108 kombinasyonluk (perspektif × ışık × bulanıklık × JPEG kalitesi)
      // bir stres matrisinde ÖLÇÜLDÜ: eski davranış 85/108, yeni (hafif
      // denoise yedeği) 108/108, SIFIR regresyon. Örüntü NET: başarısızlıkların
      // TAMAMI düşük JPEG kalitesiyle (12) ilişkiliydi — perspektif/ışık/
      // bulanıklık TEK BAŞINA sorun değildi, JPEG bloklamasıyla BİRLEŞİNCE
      // eşiği düşürüyordu (bkz. decode.dart "JPEG-ARTEFAKT YEDEĞİ" notu).
      // Burada o matristen 3 temsili (önceden başarısız, şimdi başarılı)
      // vaka kalıcı regresyon testi olarak tutuluyor.
      final clean = _renderReal();

      final cases = <String, img.Image>{
        'blur=5 jpeg=12': _withJpeg(_withBoxBlur(clean, 5), 12),
        'blur=7 jpeg=12': _withJpeg(_withBoxBlur(clean, 7), 12),
      };

      for (final entry in cases.entries) {
        expect(
          _decodeWithoutDenoiseFallback(entry.value),
          isFalse,
          reason: '${entry.key}: eski davranış ZATEN başarısızdı (regresyon varsayımı)',
        );
        expect(
          decodeQrZxing(entry.value),
          isNotNull,
          reason: '${entry.key}: hafif-denoise yedeği içeren GÜNCEL decodeQrZxing çözebilmeli',
        );
      }
    });

    test('24 etikette (8 parti no × 3 durum) temiz görüntüde TAMAMI çözülür', () {
      var ok = 0;
      for (var n = 45678; n < 45686; n++) {
        final qr = generateQr(
          '{"product_id":"TR$n","product_type":"LEVREK","production_date":"2026-09-25",'
          '"sensor_profile_id":"GENIPIN_PUTRESIN_v2","layout_version":"QR_SENSOR_v4"}',
          error: 'h',
        );
        final candidates = reactiveCandidatesForVersion(qr.version);
        final modules = selectReactiveModules(candidates, density: 'low', seed: n);
        final layout = buildLayout(version: qr.version, eccLevel: qr.eccLevel, sensorModules: modules, layoutVersion: 'QR_SENSOR_v4');
        for (final state in ['fresh', 'transition', 'spoiled']) {
          final image = renderColoredImage(qr, layout, state: state, scale: _scale, border: _border);
          final result = decodeQrZxing(image);
          if (result != null &&
              result.text.contains('"product_id":"TR$n"') &&
              result.text.contains('"production_date":"2026-09-25"')) {
            ok++;
          }
        }
      }
      expect(ok, 24);
    });
  });

  group('estimateOuterCorners', () {
    test(
        'GERÇEK PERSPEKTİF ALTINDA (28 Eylül): homografi (4. hizalama noktası) '
        'köşe hatasını eski 3-noktalı afin kestirimden BELİRGİN ÖLÇÜDE azaltır', () {
      final clean = _renderReal();
      // Simetrik olmayan yamuk (saf afin bir dönüşümle temsil EDİLEMEZ —
      // afin paralelkenarı paralelkenara götürür, bu dörtgen paralelkenar
      // DEĞİL) — gerçek kamera açısını taklit eder.
      final warp = _withPerspectiveWarp(
        clean,
        // Makul bir kamera açısı (elde tutulan telefon, hafif eğik) --
        // saf afin ile temsil EDİLEMEYEN gerçek bir yamuk.
        destTopLeft: [60, 60],
        destTopRight: [790, 90],
        destBottomRight: [770, 800],
        destBottomLeft: [80, 810],
        canvasWidth: 850,
        canvasHeight: 870,
      );

      final result = decodeQrZxing(warp.warped);
      expect(result, isNotNull, reason: 'bu ölçüdeki perspektifte zxing2 hâlâ çözebilmeli');
      final finderPoints = result!.finderPoints;
      expect(finderPoints, isNotNull);
      expect(finderPoints!.alignment, isNotNull, reason: 'versiyon 12 -> hizalama deseni olmalı');

      final viaHomography = estimateOuterCorners(finderPoints, _matrixSize);
      final viaAffineOnly = estimateOuterCorners(
        QrFinderPoints(topLeft: finderPoints.topLeft, topRight: finderPoints.topRight, bottomLeft: finderPoints.bottomLeft),
        _matrixSize,
      );

      double maxError(List<List<double>> estimated) {
        var maxErr = 0.0;
        for (var i = 0; i < 4; i++) {
          final err = _dist(estimated[i], warp.trueCorners[i]);
          if (err > maxErr) maxErr = err;
        }
        return maxErr;
      }

      final errorHomography = maxError(viaHomography);
      final errorAffineOnly = maxError(viaAffineOnly);

      // Ölçülen gerçek değerler (28 Eylül): homografi alt-piksel (~<1px,
      // zxing2'nin KENDİ finder tespiti kadar doğru), afin en uzak köşede
      // (finder noktalarından extrapolasyonun perspektifte saptığı nokta)
      // ~42px hata veriyor -- ~80 kat fark. Payla (10x) flaky olmayan ama
      // hâlâ "belirgin ölçüde daha iyi" iddiasını kanıtlayan bir eşik.
      expect(errorHomography, lessThan(2.0), reason: 'homografi hatası: $errorHomography px');
      expect(errorAffineOnly, greaterThan(errorHomography * 10), reason: 'afin: $errorAffineOnly px, homografi: $errorHomography px');
    });

    test('BİLİNEN bir homografiden üretilen finder+hizalama noktalarında formül KESİN doğru (analitik referans)', () {
      // _estimateOuterCornersViaHomography'nin matematiğini, gerçek zxing2
      // tespit gürültüsünden BAĞIMSIZ olarak izole doğrular: kurgusal ama
      // BİLİNEN bir projektif dönüşüm seçilir, finder/hizalama noktaları bu
      // dönüşümden TÜRETİLİR (gerçek zxing2'den değil) -- yani "gerçek dış
      // köşe" de AYNI dönüşümden hesaplanabilir ve tam eşleşme beklenir.
      const n = 65.0;
      final dimMinusThree = n - 3.5;
      final knownTransform = PerspectiveTransform.quadrilateralToQuadrilateral(
        0, 0, n, 0, n, n, 0, n, //
        90, 80, 980, 140, 920, 760, 140, 820,
      );
      ({double x, double y}) at(double mx, double my) {
        final p = [mx, my];
        knownTransform.transformPoints(p);
        return (x: p[0], y: p[1]);
      }

      final points = QrFinderPoints(
        topLeft: at(3.5, 3.5),
        topRight: at(dimMinusThree, 3.5),
        bottomLeft: at(3.5, dimMinusThree),
        alignment: at(n - 6.5, n - 6.5),
      );
      final estimated = estimateOuterCorners(points, 65);
      final truth = [at(0, 0), at(n, 0), at(n, n), at(0, n)];
      for (var i = 0; i < 4; i++) {
        expect(estimated[i][0], closeTo(truth[i].x, 1e-6), reason: 'köşe $i x');
        expect(estimated[i][1], closeTo(truth[i].y, 1e-6), reason: 'köşe $i y');
      }
    });

    test('gerçek zxing2 çıktısından kestirilen köşeler, eksen-hizalı (perspektifsiz) etikette GERÇEK köşelerle TAM eşleşir', () {
      final image = _renderReal();
      final result = decodeQrZxing(image)!;
      final estimated = estimateOuterCorners(result.finderPoints!, _matrixSize);
      // color_engine.canonicalQrCorners ile AYNI formül (qr_layout, color_engine'e
      // bağımlı OLAMAZ — ters yönlü bağımlılık olurdu — bu yüzden burada inline).
      const n = _matrixSize;
      final truth = [
        [(_border * _scale).toDouble(), (_border * _scale).toDouble()],
        [((n + _border) * _scale).toDouble(), (_border * _scale).toDouble()],
        [((n + _border) * _scale).toDouble(), ((n + _border) * _scale).toDouble()],
        [(_border * _scale).toDouble(), ((n + _border) * _scale).toDouble()],
      ];
      for (var i = 0; i < 4; i++) {
        expect(estimated[i][0], closeTo(truth[i][0], 1.0), reason: 'köşe $i x');
        expect(estimated[i][1], closeTo(truth[i][1], 1.0), reason: 'köşe $i y');
      }
    });

    test('elle kurulmuş finder noktalarında (dönme + öteleme, saf afin) formül KESİN doğru (analitik referans)', () {
      // moduleVector = (2, 0.5) piksel/modül (döndürülmüş eksen), matrixSize=21.
      // topLeft finder merkezi (modül 3.5,3.5) -> gerçek köşe (modül 0,0).
      const mCol = (x: 2.0, y: 0.5); // sütun ekseni yönü
      const mRow = (x: -0.5, y: 2.0); // satır ekseni yönü (dik)
      const originX = 100.0, originY = 50.0; // gerçek sol-üst köşenin piksel konumu
      ({double x, double y}) atModule(double row, double col) => (
            x: originX + col * mCol.x + row * mRow.x,
            y: originY + col * mCol.y + row * mRow.y,
          );
      final tl = atModule(3.5, 3.5);
      final tr = atModule(3.5, 21 - 3.5);
      final bl = atModule(21 - 3.5, 3.5);
      final points = QrFinderPoints(
        topLeft: (x: tl.x, y: tl.y),
        topRight: (x: tr.x, y: tr.y),
        bottomLeft: (x: bl.x, y: bl.y),
      );
      final estimated = estimateOuterCorners(points, 21);
      expect(estimated[0][0], closeTo(originX, 1e-9));
      expect(estimated[0][1], closeTo(originY, 1e-9));
      final trueTr = atModule(0, 21);
      expect(estimated[1][0], closeTo(trueTr.x, 1e-9));
      expect(estimated[1][1], closeTo(trueTr.y, 1e-9));
      final trueBl = atModule(21, 0);
      expect(estimated[3][0], closeTo(trueBl.x, 1e-9));
      expect(estimated[3][1], closeTo(trueBl.y, 1e-9));
    });

    test('matrixSize <= 7 -> ArgumentError', () {
      const points = QrFinderPoints(topLeft: (x: 0, y: 0), topRight: (x: 1, y: 0), bottomLeft: (x: 0, y: 1));
      expect(() => estimateOuterCorners(points, 7), throwsArgumentError);
    });
  });
}
