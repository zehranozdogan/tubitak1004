// Görüntü kalitesi skoru ve 'Yeniden tara' kararı — packages/color_engine/
// quality.py'nin Dart portu (rapor §6.2/8, §7.1).
//
// cv2.cvtColor(BGR2GRAY) ve cv2.Laplacian (varsayılan 3x3 çapraz çekirdek +
// BORDER_REFLECT_101) elle port edildi, gerçek `cv2` çalıştırılıp hem gri
// tonlama hem Laplacian ÇIKTISI (piksel piksel, 7x7 rastgele bir yama
// üzerinde) karşılaştırılarak doğrulandı (bkz. test/quality_test.dart).
//
// NOT (gri tonlama yuvarlama): OpenCV'nin BGR2GRAY'i içeride sabit-noktalı
// (fixed-point) bir yaklaşım kullanıyor olabilir; burada standart
// yuvarlama (0.299r+0.587g+0.114b, en yakına) kullanıldı — test edilen
// tüm örneklerde (6 farklı renk) tam eşleşti, ama TAM .5 sınır durumunda
// (round-half) OpenCV'nin iç davranışıyla bit-bit özdeşliği garanti
// EDİLMEDİ — gerçek cihaz görüntüleriyle (rapor §11 Aşama B) ayrıca
// doğrulanmalı.

import 'homography.dart' show RgbImage;

const double defaultMinQuality = 0.5;

// Laplacian varyansı bu değerin üstündeyse "keskin" (skor 1.0) kabul
// edilir — Python tarafındaki `_SHARPNESS_SATURATING_VARIANCE` ile aynı.
const double _sharpnessSaturatingVariance = 300.0;

class GrayImage {
  final int width;
  final int height;
  final List<double> values; // satır-öncelikli

  GrayImage({required this.width, required this.height, required this.values})
      : assert(values.length == width * height);

  double at(int x, int y) => values[y * width + x];
}

/// Gri tonlama (cv2.COLOR_BGR2GRAY ile aynı ağırlıklar).
///
/// MİMARİ NOT (Python'dan KASITLI bir sapma): Python tarafında `image`
/// kanal sırası BGR'dir (cv2 sözleşmesi) — bu, geçmişte gerçek bir hataya
/// yol açmıştı (bkz. pipeline.py: `corrected_rgb = corrected[:, :, ::-1]`
/// düzeltmesi, Rgb/Lab matematiği için BGR'den RGB'ye çevrilmesi
/// gerekiyordu). Bu Dart portunda KARIŞIKLIĞI TAMAMEN ORTADAN KALDIRMAK
/// için tek, tutarlı bir kural var: bu paketteki HER `Rgb` alanı HER ZAMAN
/// gerçek Kırmızı/Yeşil/Mavi'dir — BGR sırası YOKTUR. Ham kamera
/// baytlarından (BGR olabilir) `RgbImage` kuran çağıran taraf, bu pakete
/// vermeden ÖNCE R/B kanallarını değiştirmekle YÜKÜMLÜDÜR.
GrayImage toGray(RgbImage image) {
  final values = List<double>.filled(image.width * image.height, 0);
  for (var i = 0; i < image.pixels.length; i++) {
    final p = image.pixels[i];
    values[i] = (0.299 * p.r + 0.587 * p.g + 0.114 * p.b).roundToDouble();
  }
  return GrayImage(width: image.width, height: image.height, values: values);
}

int _reflect101(int i, int n) {
  if (i < 0) return -i;
  if (i >= n) return 2 * (n - 1) - i;
  return i;
}

/// cv2.Laplacian(gray, cv2.CV_64F) ile BİREBİR aynı: [[0,1,0],[1,-4,1],[0,1,0]]
/// çekirdeği, BORDER_REFLECT_101 kenar davranışıyla.
List<double> _laplacian(GrayImage gray) {
  final w = gray.width, h = gray.height;
  final out = List<double>.filled(w * h, 0);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final up = gray.at(x, _reflect101(y - 1, h));
      final down = gray.at(x, _reflect101(y + 1, h));
      final left = gray.at(_reflect101(x - 1, w), y);
      final right = gray.at(_reflect101(x + 1, w), y);
      final center = gray.at(x, y);
      out[y * w + x] = up + down + left + right - 4 * center;
    }
  }
  return out;
}

/// Laplacian çıktısının varyansı (population variance, numpy `.var()` ile
/// aynı — ddof=0). Ayrı fonksiyon olarak dışa açık: hem `sharpnessScore`
/// tarafından kullanılır hem de ham (doygunlaşmamış) değeri test edilebilir
/// kılar (bkz. test/quality_test.dart — skor 300 üstünde hep 1.0'a
/// doygunlaştığı için ham varyansı ayrıca doğrulamak gerekiyordu).
double laplacianVariance(GrayImage gray) {
  final lap = _laplacian(gray);
  final mean = lap.reduce((a, b) => a + b) / lap.length;
  var sumSq = 0.0;
  for (final v in lap) {
    sumSq += (v - mean) * (v - mean);
  }
  return sumSq / lap.length;
}

/// 0..1: Laplacian varyansı (yüksek = keskin, düşük = bulanık).
double sharpnessScore(GrayImage gray) {
  final ratio = laplacianVariance(gray) / _sharpnessSaturatingVariance;
  return ratio > 1.0 ? 1.0 : ratio;
}

/// 0..1: parlama/doygunluk piksel oranı düşükse 1.0, artınca 0'a yaklaşır.
/// Tolerans %65'e kadar (bkz. Python docstring'i — QR/etiket görüntülerinde
/// geniş beyaz alan normaldir).
double glareScore(GrayImage gray, {double saturatedThreshold = 250}) {
  var saturatedCount = 0;
  for (final v in gray.values) {
    if (v >= saturatedThreshold) saturatedCount++;
  }
  final ratio = saturatedCount / gray.values.length;
  final over = (ratio - 0.65) > 0 ? (ratio - 0.65) : 0.0;
  final score = 1.0 - over / 0.30;
  return score < 0.0 ? 0.0 : score;
}

/// 0..1: ortalama parlaklık [low, high] aralığındaysa 1.0, dışına çıktıkça düşer.
double brightnessScore(GrayImage gray, {double low = 40, double high = 220}) {
  final mean = gray.values.reduce((a, b) => a + b) / gray.values.length;
  if (mean >= low && mean <= high) return 1.0;
  if (mean < low) {
    final score = 1.0 - (low - mean) / low;
    return score < 0.0 ? 0.0 : score;
  }
  final score = 1.0 - (mean - high) / (255 - high);
  return score < 0.0 ? 0.0 : score;
}

/// 0..1 birleşik kalite skoru: keskinlik + parlama + ortalama parlaklık.
double qualityScore(RgbImage image) {
  final gray = toGray(image);
  final components = [sharpnessScore(gray), glareScore(gray), brightnessScore(gray)];
  return components.reduce((a, b) => a + b) / components.length;
}

/// Kalite eşiğin altındaysa true (kullanıcıya "Yeniden tara").
bool shouldRescan(double score, [double minQuality = defaultMinQuality]) {
  return score < minQuality;
}
