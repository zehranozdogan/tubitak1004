// QR köşelerinin BİLİNEN modül matrisine göre ince ayarı (grid registration).
//
// GERÇEK CİHAZ HATASI (30 Eylül, "güven skoru hep 0.00" + "okuyor ama baya
// yanlış"): renk okuması, QR köşelerinin modül hassasiyetinde doğru olmasına
// dayanıyor — ama köşeler decoder'dan KABA geliyor (ML Kit `cornerPoints`
// tespit amaçlı bir dörtgen, piksel-hassas değil; zxing2 yolunda köşe finder
// merkezlerinden KESTİRİLİYOR). Sentetik tarama (test/grid_refine_test.dart):
// köşeler ~1 modül kayınca güven 1.00 -> 0.00 VE sonuç taze -> bozuk'a
// döndü; %0.5'lik bir ölçek hatası bile beyaz/siyah referansını (finder'ın
// 1 modül genişliğindeki halkası) kaydırıp yanlış profil noktası verdi —
// yani telefonda görülen İKİ belirtinin birebir aynısı.
//
// Çözüm: okuyucu QR matrisini zaten yeniden üretebiliyor (hangi modülün
// koyu/açık olması GEREKTİĞİNİ biliyor). Köşeler, modül merkezlerindeki
// parlaklığın beklenen koyu/açık desenle en iyi ayrıştığı konuma kaydırılır:
//   1. 4 döngüsel köşe sırası × ±2 modül öteleme ızgarası (kaba; ML Kit'in
//      köşe SIRASI varsayımı da doğrulanmamıştı — yanlışsa burada düzelir),
//   2. her köşe/eksen için azalan adımlarla koordinat inişi (ince).
// Skor, iki sınıfın ayrışma oranı (Fisher benzeri): kontrastın kendisi
// değil ayrışma ölçüldüğü için ışık seviyesinden bağımsız.
//
// `matchRate` (modüllerin kaçı DOĞRU tarafta) aynı zamanda bir GÜVENLİK
// AĞI: ızgara hizalanamadıysa renk okuması anlamsızdır; çağıran taraf
// "emin ama yanlış" bir sonuç yerine "yeniden tara" diyebilir.

import 'dart:math' as math;
import 'dart:typed_data';

import 'homography.dart';

class GridRefinement {
  /// İnce ayarlı köşeler (sol-üst, sağ-üst, sağ-alt, sol-alt).
  final List<List<double>> corners;

  /// Beklenen desene göre doğru tarafta kalan modül oranı (0..1). Doğru
  /// hizalanmış net bir karede ~0.95+; rastgele hizada ~0.5.
  final double matchRate;

  const GridRefinement({required this.corners, required this.matchRate});
}

/// `corners`'ı (QR modül ızgarasının DIŞ köşeleri, sol-üst/sağ-üst/sağ-alt/
/// sol-alt) `expected` matrisine (1 = koyu, 0 = açık; boyut n×n) göre ince
/// ayarlar. `exclude` içindeki hücreler (ör. renkli sensör hücreleri) skora
/// katılmaz.
GridRefinement refineQrCorners(
  RgbImage image,
  List<List<double>> corners,
  List<List<int>> expected, {
  Set<(int, int)> exclude = const {},
}) {
  final n = expected.length;
  final luma = _luma(image);
  final cells = <(int, int)>[];
  final dark = <bool>[];
  for (var r = 0; r < n; r++) {
    for (var c = 0; c < n; c++) {
      if (exclude.contains((r, c))) continue;
      cells.add((r, c));
      dark.add(expected[r][c] != 0);
    }
  }
  // Kaba aşama: sadece modül merkezi (hızlı). İnce aşama: modül içinde 3x3
  // nokta — merkez örneklemesi ±0.5 modül içinde DÜZ bir plato verir (her
  // merkez hâlâ aynı modülde), arama o platoda rastgele bir yerde durur.
  // Kenara yakın (0.1/0.9) noktalar komşu modüle taştığı an skor düşer, bu
  // yüzden tepe ancak ızgara ORTALANINCA oluşur.
  final coarse = _Sampler(luma, image.width, image.height, n, cells, dark, const [0.5]);
  final fine = _Sampler(luma, image.width, image.height, n, cells, dark, const [0.1, 0.5, 0.9]);

  double moduleSize(List<List<double>> q) {
    double d(List<double> a, List<double> b) => math.sqrt(math.pow(a[0] - b[0], 2) + math.pow(a[1] - b[1], 2));
    return (d(q[0], q[1]) + d(q[1], q[2]) + d(q[2], q[3]) + d(q[3], q[0])) / (4 * n);
  }

  final m = moduleSize(corners);

  // 1. Kaba: 4 döngüsel sıra × öteleme ızgarası.
  var best = [for (final p in corners) [...p]];
  var bestScore = coarse.score(best);
  for (var rot = 0; rot < 4; rot++) {
    final base = [for (var i = 0; i < 4; i++) [...corners[(i + rot) % 4]]];
    for (var ty = -2.0; ty <= 2.0; ty += 0.25) {
      for (var tx = -2.0; tx <= 2.0; tx += 0.25) {
        final cand = [for (final p in base) [p[0] + tx * m, p[1] + ty * m]];
        final s = coarse.score(cand);
        if (s > bestScore) {
          bestScore = s;
          best = cand;
        }
      }
    }
  }

  // 2. İnce: her köşe/eksen için koordinat inişi, adım yarılanarak.
  bestScore = fine.score(best);
  for (final stepModules in const [0.5, 0.25, 0.125, 0.0625]) {
    final step = stepModules * m;
    var improved = true;
    var guard = 0;
    while (improved && guard++ < 20) {
      improved = false;
      for (var i = 0; i < 4; i++) {
        for (var axis = 0; axis < 2; axis++) {
          for (final dir in const [-1.0, 1.0]) {
            final cand = [for (final p in best) [...p]];
            cand[i][axis] += dir * step;
            final s = fine.score(cand);
            if (s > bestScore) {
              bestScore = s;
              best = cand;
              improved = true;
            }
          }
        }
      }
    }
  }

  return GridRefinement(corners: best, matchRate: coarse.matchRate(best));
}

Float64List _luma(RgbImage image) {
  final out = Float64List(image.width * image.height);
  final px = image.pixels;
  for (var i = 0; i < px.length; i++) {
    final p = px[i];
    out[i] = 0.299 * p.r + 0.587 * p.g + 0.114 * p.b;
  }
  return out;
}

class _Sampler {
  final Float64List luma;
  final int width;
  final int height;
  final int n;
  final List<(int, int)> cells;
  final List<bool> dark;
  // Modül içi örnek noktaları (her eksende, modül biriminde).
  final List<double> offsets;
  final Float64List _values;

  _Sampler(this.luma, this.width, this.height, this.n, this.cells, this.dark, this.offsets)
      : _values = Float64List(cells.length * offsets.length * offsets.length);

  int get _perCell => offsets.length * offsets.length;

  /// Her modülün içindeki `offsets`×`offsets` noktayı (grid köşeleri ->
  /// `corners` homografisiyle) örnekler. Görüntü dışına düşen nokta varsa false.
  bool _sample(List<List<double>> corners) {
    final h = getPerspectiveTransform([
      [0.0, 0.0],
      [n.toDouble(), 0.0],
      [n.toDouble(), n.toDouble()],
      [0.0, n.toDouble()],
    ], corners);
    var k = 0;
    for (final (r, c) in cells) {
      for (final dv in offsets) {
        for (final du in offsets) {
          final u = c + du, v = r + dv;
          final w = h[2][0] * u + h[2][1] * v + h[2][2];
          final x = (h[0][0] * u + h[0][1] * v + h[0][2]) / w;
          final y = (h[1][0] * u + h[1][1] * v + h[1][2]) / w;
          if (x < 0 || y < 0 || x >= width - 1 || y >= height - 1) return false;
          final x0 = x.floor(), y0 = y.floor();
          final fx = x - x0, fy = y - y0;
          final i = y0 * width + x0;
          _values[k++] = (luma[i] * (1 - fx) + luma[i + 1] * fx) * (1 - fy) +
              (luma[i + width] * (1 - fx) + luma[i + width + 1] * fx) * fy;
        }
      }
    }
    return true;
  }

  double score(List<List<double>> corners) {
    if (!_sample(corners)) return double.negativeInfinity;
    var sd = 0.0, sl = 0.0, sdd = 0.0, sll = 0.0;
    var nd = 0, nl = 0;
    for (var k = 0; k < _values.length; k++) {
      final v = _values[k];
      if (dark[k ~/ _perCell]) {
        sd += v;
        sdd += v * v;
        nd++;
      } else {
        sl += v;
        sll += v * v;
        nl++;
      }
    }
    if (nd == 0 || nl == 0) return double.negativeInfinity;
    final md = sd / nd, ml = sl / nl;
    final vd = sdd / nd - md * md, vl = sll / nl - ml * ml;
    return (ml - md) / math.sqrt((vd + vl) / 2 + 1.0);
  }

  /// Sadece merkez örneklemeli (`offsets == [0.5]`) sampler'da anlamlı.
  double matchRate(List<List<double>> corners) {
    assert(_perCell == 1);
    if (!_sample(corners)) return 0.0;
    var sd = 0.0, sl = 0.0;
    var nd = 0, nl = 0;
    for (var k = 0; k < cells.length; k++) {
      if (dark[k]) {
        sd += _values[k];
        nd++;
      } else {
        sl += _values[k];
        nl++;
      }
    }
    if (nd == 0 || nl == 0) return 0.0;
    final threshold = (sd / nd + sl / nl) / 2;
    var ok = 0;
    for (var k = 0; k < cells.length; k++) {
      if ((_values[k] < threshold) == dark[k]) ok++;
    }
    return ok / cells.length;
  }
}
