// QR / etiket görsel çıktısı — packages/qr_layout/render.py'nin Dart portu
// (rapor §8: basılabilir PNG/PDF + sentetik durumlar).
//
// renderColoredImage ve türevleri: reaktif hücrelerin RENKLİ gösterimi
// (`image` paketi, Pillow'un Dart karşılığı) — her modülün açık/koyu
// sınıfı korunur ki QR hâlâ okunabilir kalsın (§5.2/3).
// renderLabelImage: sensor_profile.calibration_method.code'a göre doğru
// render yolunu seçer VE gerekliyse layout['reference_regions']'a ek
// referans konumlarını YAZAR (in-place, Python'daki gibi — Dart'ta
// buildLayout()'un döndürdüğü Map<String, dynamic> literal, const
// DEĞİL, bu yüzden mutasyon mümkün ve burada bilinçli olarak kullanılıyor,
// tıpkı Python tarafında olduğu gibi).
//
// PDF export (Python: save_label_pdf, Pillow "PDF" formatı) burada YOK —
// `image` paketi PDF yazmıyor, ayrı bir paket (`pdf`, pub.dev) gerekiyor;
// bilinçli olarak sıradaki adıma bırakıldı (bkz. paket README'si).

import 'package:image/image.dart' as img;

import 'colors.dart';
import 'function_mask.dart' show matrixSize;
import 'generator.dart';
import 'reactive.dart' show Cell;

/// `layout['sensor_modules']` (ya da `intentional_errors`) gibi
/// `List<dynamic>` (her biri `[row, col]`) alanları `Set<Cell>`'e çevirir.
Set<Cell> _cellSet(dynamic raw) {
  if (raw == null) return const {};
  return {
    for (final pair in raw as List) (row: (pair[0] as num).toInt(), col: (pair[1] as num).toInt()),
  };
}

/// QR'ı rasterize eder; `layout['sensor_modules']` koordinatlarını
/// [state] rengiyle (null ise nötr gri), geri kalanını standart
/// siyah/beyaz çizer.
///
/// [reactiveBlank] true ise reaktif hücreler HİÇ BASILMAZ (beyaz kalır) —
/// gerçek üretimde oraya reaktif madde uygulanacağı için (6 Ekim). Nötr
/// gri yalnızca YERLEŞİM ÖNİZLEMESİdir: reaktif mürekkep grinin üstüne
/// uygulanırsa renk kirlenir, çünkü profildeki referans renkler BEYAZ
/// kağıt üzerinde tanımlı. [state] ile birlikte kullanılamaz (anlamsız).
///
/// QR hâlâ çözülür: reaktif hücreler ~%2 kadar (75/4225) ve ECC seviyesi
/// H (%30 kurtarma) bunu fazlasıyla tolere eder.
///
/// `layout['intentional_errors']` (rapor §5.2/4) listesindeki modüller
/// GERÇEK bitlerinin TERSİYLE render edilir — QR'ın hata düzeltmesi (ECC)
/// bunu telafi etmesi beklenir (bkz. reactive.selectIntentionalErrors).
img.Image renderColoredImage(
  GeneratedQr qr,
  Map<String, dynamic> layout, {
  String? state,
  int scale = 10,
  int border = 4,
  bool reactiveBlank = false,
}) {
  if (reactiveBlank && state != null) {
    throw ArgumentError('reactiveBlank ile state birlikte verilemez: '
        'baskı ustasında reaktif hücreler boş kalır, durum rengi basılmaz.');
  }
  final matrix = moduleMatrix(qr);
  final n = matrix.length;
  final sensorSet = _cellSet(layout['sensor_modules']);
  final errorSet = _cellSet(layout['intentional_errors']);

  final size = (n + 2 * border) * scale;
  final image = img.Image(width: size, height: size, numChannels: 3);
  img.fill(image, color: img.ColorRgb8(255, 255, 255));

  for (var r = 0; r < n; r++) {
    for (var c = 0; c < n; c++) {
      var bit = matrix[r][c];
      if (errorSet.contains((row: r, col: c))) {
        bit = 1 - bit; // kasıtlı hata: gerçek bitin tersini göster
      }
      final reaktif = sensorSet.contains((row: r, col: c));
      if (reactiveBlank && reaktif) continue; // basılmaz: beyaz kağıt kalır
      final rgb = moduleColor(bit, reaktif, state);
      final x0 = (c + border) * scale;
      final y0 = (r + border) * scale;
      img.fillRect(
        image,
        x1: x0,
        y1: y0,
        x2: x0 + scale - 1,
        y2: y0 + scale - 1,
        color: img.ColorRgb8(rgb.r, rgb.g, rgb.b),
      );
    }
  }
  return image;
}

/// `renderColoredImage` gibi, ama QR'ın DIŞINDA (zorunlu quiet zone'un da
/// dışında) ek bir gri referans yaması basar (rapor §5.2/5, §6.1 B).
///
/// [border] hâlâ GERÇEK/zorunlu quiet zone genişliği; yama için ek
/// [edgePatchMargin] modül otomatik eklenir (QR'ın zorunlu bölgeleri, §5.1,
/// hiç değişmez — sadece etiket biraz daha büyür).
///
/// Döner: (görüntü, yamanın sanal (row, col) konumu). Konumu
/// `layout['reference_regions']['gray']`'e yazman gerekir ki okuyucu
/// hard-code etmesin (§10.1) — `renderLabelImage` bunu otomatik yapar.
({img.Image image, ({int row, int col}) position}) renderWithEdgeGrayPatch(
  GeneratedQr qr,
  Map<String, dynamic> layout, {
  String? state,
  int scale = 10,
  int border = 4,
  bool reactiveBlank = false,
}) {
  final totalBorder = border + edgePatchMargin;
  final image = renderColoredImage(qr, layout,
      state: state, scale: scale, border: totalBorder, reactiveBlank: reactiveBlank);

  final n = moduleMatrix(qr).length;
  final pos = edgeGrayPatchPosition(n, border: border);
  final center = modulePixelCenter(pos.row, pos.col, scale: scale, border: totalBorder);
  final half = (edgePatchSize * scale) ~/ 2;

  img.fillRect(
    image,
    x1: center.x - half,
    y1: center.y - half,
    x2: center.x + half - 1,
    y2: center.y + half - 1,
    color: img.ColorRgb8(grayReferenceRgb.r, grayReferenceRgb.g, grayReferenceRgb.b),
  );

  return (image: image, position: pos);
}

/// `renderWithEdgeGrayPatch`'in genellenmişi — tek gri yerine, çoklu
/// FARKLI renkte referans yaması basar (rapor §6.1 C:
/// `calibration.multicolorPatch`, >=4 nokta gerektirir).
///
/// [colors]: {isim: rgb} — null ise [edgeReferenceColors].
/// Döner: (görüntü, {isim: (row, col), ...}).
({img.Image image, Map<String, ({int row, int col})> positions}) renderWithEdgeReferencePatches(
  GeneratedQr qr,
  Map<String, dynamic> layout, {
  String? state,
  int scale = 10,
  int border = 4,
  Map<String, Rgb3>? colors,
  bool reactiveBlank = false,
}) {
  final effectiveColors = colors ?? edgeReferenceColors;
  final totalBorder = border + edgePatchMargin;
  final image = renderColoredImage(qr, layout,
      state: state, scale: scale, border: totalBorder, reactiveBlank: reactiveBlank);

  final n = moduleMatrix(qr).length;
  final positions = edgePatchPositions(n, border: border, colors: effectiveColors);
  final half = (edgePatchSize * scale) ~/ 2;

  for (final entry in positions.entries) {
    final center = modulePixelCenter(entry.value.row, entry.value.col, scale: scale, border: totalBorder);
    final rgb = effectiveColors[entry.key]!;
    img.fillRect(
      image,
      x1: center.x - half,
      y1: center.y - half,
      x2: center.x + half - 1,
      y2: center.y + half - 1,
      color: img.ColorRgb8(rgb.r, rgb.g, rgb.b),
    );
  }

  return (image: image, positions: positions);
}

const String _needsGrayPatch = 'white_gray_black';
const String _needsMulticolorPatch = 'multicolor_patch';

/// `renderLabelImage` ile AYNI `layout['reference_regions']` güncellemesini
/// yapar ama HİÇ ÇİZMEZ (28 Eylül eklendi) — `sensorProfile['calibration_
/// method']['code']`'a göre ihtiyaç varsa `edgeGrayPatchPosition`/
/// `edgePatchPositions` (ucuz, saf pozisyon hesabı) çağrılır, tam bir
/// piksel tamponu (renderColoredImage) ASLA oluşturulmaz.
///
/// KULLANIM ALANI: `label_export::resolveLabelLayout` (okuyucunun
/// layout'u payload'dan yeniden türettiği yol, karar 0006) sadece BU
/// pozisyon bilgisine ihtiyaç duyuyordu ama önceden tüm etiketi render
/// edip SONUCU ATIYORDU — her taramada (kamera/dosya/fotoğraf) gereksiz
/// bir tam-çözünürlük render'a yol açıyordu, eski/zayıf cihazlarda
/// fark edilir bir gecikme kaynağı olabilir. `matrixSize(qr.version)`
/// kullanılıyor (`moduleMatrix(qr).length` DEĞİL) — tam modül matrisini
/// üretmek de gereksiz, versiyon zaten boyutu belirliyor.
void populateReferenceRegions(GeneratedQr qr, Map<String, dynamic> layout, Map<String, dynamic>? sensorProfile, {int border = 4}) {
  final code = ((sensorProfile?['calibration_method'] as Map<String, dynamic>?)?['code'] as String?) ?? 'white_black';
  if (code != _needsGrayPatch && code != _needsMulticolorPatch) return;

  final n = matrixSize(qr.version);
  final refs = (layout['reference_regions'] as Map<String, dynamic>?) ?? <String, dynamic>{};
  layout['reference_regions'] = refs;

  if (code == _needsGrayPatch) {
    final pos = edgeGrayPatchPosition(n, border: border);
    refs['gray'] = [
      [pos.row, pos.col],
    ];
    return;
  }

  final positions = edgePatchPositions(n, border: border);
  for (final entry in positions.entries) {
    refs[entry.key] = [
      [entry.value.row, entry.value.col],
    ];
  }
}

/// `sensorProfile['calibration_method']['code']`'a göre doğru render
/// yolunu seçer (rapor §6.1 A-E) VE gerekliyse
/// `layout['reference_regions']`'a ek referans konumlarını YAZAR (YERİNDE
/// — Python'daki `layout.setdefault(...)` ile birebir aynı davranış,
/// `layout` burada da bir `Map<String, dynamic>` referansı, const değil).
///
/// `sensorProfile` null ise (ya da kod tanınmıyorsa) QR-içi (A/D)
/// davranışına düşer — geriye dönük uyumlu.
img.Image renderLabelImage(
  GeneratedQr qr,
  Map<String, dynamic> layout,
  Map<String, dynamic>? sensorProfile, {
  String? state,
  int scale = 10,
  int border = 4,
  bool reactiveBlank = false,
}) {
  final code = ((sensorProfile?['calibration_method'] as Map<String, dynamic>?)?['code'] as String?) ??
      'white_black';

  if (code == _needsGrayPatch) {
    final result = renderWithEdgeGrayPatch(qr, layout,
        state: state, scale: scale, border: border, reactiveBlank: reactiveBlank);
    final refs = (layout['reference_regions'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    layout['reference_regions'] = refs;
    refs['gray'] = [
      [result.position.row, result.position.col],
    ];
    return result.image;
  }

  if (code == _needsMulticolorPatch) {
    final result = renderWithEdgeReferencePatches(qr, layout,
        state: state, scale: scale, border: border, reactiveBlank: reactiveBlank);
    final refs = (layout['reference_regions'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    layout['reference_regions'] = refs;
    for (final entry in result.positions.entries) {
      refs[entry.key] = [
        [entry.value.row, entry.value.col],
      ];
    }
    return result.image;
  }

  return renderColoredImage(qr, layout,
      state: state, scale: scale, border: border, reactiveBlank: reactiveBlank);
}

/// Rapor §8/§11: her renk durumunda (fresh/transition/spoiled) sentetik
/// etiketin PNG baytlarını üretir — `sensorProfile`'ın kalibrasyon
/// yönteminin (§6.1 B/C) ihtiyacı olan referans yamalarını da basar ve
/// `layout['reference_regions']`'ı günceller (`renderLabelImage` üzerinden).
Map<String, List<int>> syntheticStatesPngBytes(
  GeneratedQr qr,
  Map<String, dynamic> layout,
  Map<String, dynamic>? sensorProfile, {
  int scale = 10,
  int border = 4,
}) {
  final out = <String, List<int>>{};
  for (final state in const ['fresh', 'transition', 'spoiled']) {
    final image = renderLabelImage(qr, layout, sensorProfile, state: state, scale: scale, border: border);
    out[state] = img.encodePng(image);
  }
  return out;
}
