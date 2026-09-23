// packages/qr_layout/generator.py'nin Dart portu — GERÇEK QR encoding.
//
// Segno (Python) yerine `qr` paketi (pub.dev, kevmoo/qr.dart) kullanılıyor:
// saf Dart, ISO/IEC 18004 uyumlu (numeric/alphanumeric/byte segmentasyonu,
// Reed-Solomon ECC, 8 maske deneyip penalty-skoru en düşük olanı seçme —
// segno ile AYNI standart algoritma), native/FFI bağımlılığı yok. Aynı
// zamanda `qr_flutter`'ın da alt motoru — yaygın kullanılan, gerçek
// telefon kameralarıyla/ML Kit ile pratikte doğrulanmış bir kütüphane.
//
// 23 Eylül: hocayla görüşme sonrası decoder tarafında ML Kit kullanımında
// sakınca olmadığı teyit edildi; bu encoder seçimi o kararla aynı oturumda,
// onu tamamlayan parça olarak yapıldı.
//
// error='h' KARARININ gerekçesi Python generator.py'deki ile AYNI (deneysel
// karşılaştırma, kasıtlı-hata toleransı, baskı uygulanabilirliği notu) —
// burada TEKRARLANMADI, bkz. packages/qr_layout/generator.py docstring'i.
//
// DOĞRULAMA: gerçek segno (Python) ile AYNI payload/version/error için
// üretilen tam modül matrisi (61x61 ve 21x21, iki farklı payload) BİREBİR
// karşılaştırıldı (bkz. test/generator_test.dart) — ISO 18004'ün maske
// seçimi deterministik/minimize-edici olduğu için iki bağımsız kütüphane
// AYNI sonucu üretmeli, ve gerçekten üretiyor (uydurma/tahmin DEĞİL).

import 'package:qr/qr.dart' as qrlib;

import 'function_mask.dart' show functionMask, matrixSize;
import 'reactive.dart' show Cell;

const Map<String, qrlib.QrErrorCorrectLevel> _eccByCode = {
  'l': qrlib.QrErrorCorrectLevel.low,
  'm': qrlib.QrErrorCorrectLevel.medium,
  'q': qrlib.QrErrorCorrectLevel.quartile,
  'h': qrlib.QrErrorCorrectLevel.high,
};

/// Üretilmiş bir QR — Python'daki `segno.QRCode`'un yerini alıyor.
/// `moduleMatrix`/`reactiveCandidatesForVersion` bunun üzerinden çalışır.
class GeneratedQr {
  final int version;
  final String eccLevel; // 'L'|'M'|'Q'|'H' (Python `qr.error` ile aynı büyük harf sözleşimi)
  final qrlib.QrImage _image;

  GeneratedQr._(this.version, this.eccLevel, this._image);

  /// (row, col) modülü koyu mu? Quiet zone HARİÇ koordinatlar (0..version*4+16).
  bool isDark(int row, int col) => _image.isDark(row, col);
}

/// Standart bir QR üretir — Python `generator.generate_qr`'ın portu.
///
/// MİMARİ SAPMA: `version` verilip veri o versiyona SIĞMIYORSA Python
/// (segno) hata fırlatırdı; alttaki `qr` paketinin `minTypeNumber`'ı sadece
/// bir TABAN — veri sığmazsa sessizce BÜYÜTÜR. Bu, layout_version'daki
/// `matrix_size`/`sensor_modules` koordinatlarının varsaydığı versiyonla
/// sessizce UYUŞMAZLIĞA yol açabileceğinden, segno'nun KATI davranışı
/// burada elle korunuyor: gerçek sonuç versiyon istenenden BÜYÜKSE
/// ArgumentError fırlatılır (bkz. aşağı).
GeneratedQr generateQr(String payload, {String error = 'h', int? version}) {
  final eccLevel = _eccByCode[error.toLowerCase()];
  if (eccLevel == null) {
    throw ArgumentError("error 'l'|'m'|'q'|'h' olmalı, verilen: $error");
  }
  if (version != null && (version < 1 || version > 40)) {
    throw ArgumentError('QR versiyonu 1..40 olmalı, verilen: $version');
  }

  final qrPayload = qrlib.QrPayload.fromString(payload);
  final qrCode = qrlib.QrCode(
    payload: qrPayload,
    errorCorrectLevel: eccLevel,
    minTypeNumber: version ?? 1,
  );
  if (version != null && qrCode.typeNumber != version) {
    throw ArgumentError(
      'Veri istenen versiyona ($version) sığmıyor; gereken versiyon: ${qrCode.typeNumber}. '
      'Daha büyük bir versiyon verin ya da payload\'u kısaltın.',
    );
  }

  final image = qrlib.QrImage(qrCode);
  return GeneratedQr._(qrCode.typeNumber, error.toUpperCase(), image);
}

/// QR'ın 0/1 modül matrisi (quiet zone hariç) — Python `module_matrix`.
List<List<int>> moduleMatrix(GeneratedQr qr) {
  final n = matrixSize(qr.version);
  return [
    for (var r = 0; r < n; r++) [for (var c = 0; c < n; c++) qr.isDark(r, c) ? 1 : 0],
  ];
}

/// Reaktif hücre olabilecek (satır, sütun) modülleri: yalnızca data/ECC
/// alanı — Python `generator.reactive_candidates`.
///
/// MİMARİ SAPMA (küçük, davranışsız): Python versiyonu bir `qr` (segno)
/// nesnesi alıp içinden SADECE `qr.version`'ı okuyordu — gerçek QR verisine
/// hiç bakmıyordu (tamamen geometri). Burada bunu netleştirmek için
/// doğrudan `version` (int) alınıyor; `GeneratedQr` GEREKMEZ, `reactive.dart`
/// da zaten bu şekilde (version parametresiyle) çalışıyor.
List<Cell> reactiveCandidatesForVersion(int version) {
  final n = matrixSize(version);
  final mask = functionMask(version);
  return [
    for (var r = 0; r < n; r++)
      for (var c = 0; c < n; c++)
        if (!mask[r][c]) (row: r, col: c),
  ];
}
