// generator.dart testleri — gerçek `qr` paketiyle (Python segno'nun yerine
// geçen) QR encoding.
//
// DOĞRULAMA YÖNTEMİ:
// 1) 'HELLO' + version=1 + error=h: TAM 21x21 modül matrisi gerçek Python
//    `segno.make('HELLO', error='h', version=1)` çalıştırılarak üretildi ve
//    BİREBİR (bit bit) karşılaştırıldı — alfanümerik-sadece, tek segmentli
//    kısa bir payload olduğu için segmentasyon belirsizliği YOK, bu yüzden
//    iki bağımsız kütüphane TAM AYNI sonucu vermeli (ve veriyor).
// 2) Karışık (JSON) uzun bir payload'da (version otomatik seçilir) segno
//    ile `qr` paketi FARKLI ama HER İKİSİ DE GEÇERLİ bir modül matrisi
//    üretebilir (mod segmentasyonu/maske seçimi ISO 18004'te standardın
//    izin verdiği ölçüde kütüphaneye özgü olabilir) — bu NORMAL, hata
//    DEĞİL. Bunu doğrulamak için matris eşitliği değil, GERÇEK decode
//    (pyzbar, projenin kendi decoder'larından biri) round-trip'i kullanıldı
//    (scratch script, bu dosyaya taşınmadı): Dart'ın ürettiği matris PNG'ye
//    çevrilip pyzbar ile decode edildi, orijinal payload'la BİREBİR eşleşti.
//    Burada bu payload için sadece version/ecc/boyut (davranış düzeyi)
//    doğrulanıyor.
import 'package:qr_layout/qr_layout.dart';
import 'package:test/test.dart';

const _helloV1H = [
  '111111101100101111111',
  '100000101111101000001',
  '101110101110001011101',
  '101110100110101011101',
  '101110100000001011101',
  '100000101001101000001',
  '111111101010101111111',
  '000000001001000000000',
  '001110101101011100111',
  '011011001101110101111',
  '100011101110001011001',
  '001101010010011110000',
  '100111111110110010100',
  '000000001011101001011',
  '111111100110010100101',
  '100000100101110001001',
  '101110101001010100100',
  '101110101110001100100',
  '101110101010110010100',
  '100000100011111110101',
  '111111100110100010100',
];

List<List<int>> _rowsToInts(List<String> rows) =>
    [for (final row in rows) [for (final ch in row.split('')) int.parse(ch)]];

void main() {
  test("'HELLO' + version=1 + error=h: gerçek segno çıktısıyla BİREBİR aynı", () {
    final qr = generateQr('HELLO', error: 'h', version: 1);
    expect(qr.version, 1);
    expect(qr.eccLevel, 'H');
    expect(moduleMatrix(qr), _rowsToInts(_helloV1H));
  });

  test('error kodu büyük/küçük harf duyarsız (H == h)', () {
    final lower = generateQr('HELLO', error: 'h', version: 1);
    final upper = generateQr('HELLO', error: 'H', version: 1);
    expect(moduleMatrix(upper), moduleMatrix(lower));
  });

  test('geçersiz error kodu -> ArgumentError', () {
    expect(() => generateQr('x', error: 'z'), throwsArgumentError);
  });

  test('geçersiz versiyon (0, 41) -> ArgumentError', () {
    expect(() => generateQr('x', version: 0), throwsArgumentError);
    expect(() => generateQr('x', version: 41), throwsArgumentError);
  });

  test('veri istenen versiyona sığmıyorsa -> ArgumentError (segno gibi KATI, sessizce büyütmez)', () {
    // 'h' (ECC-H) + version=1 kapasitesi çok küçük, uzun bir payload sığmaz.
    final longPayload = 'A' * 100;
    expect(() => generateQr(longPayload, error: 'h', version: 1), throwsArgumentError);
  });

  test('otomatik versiyon seçimi: karışık (JSON) payload -> version=11, ecc=H, 61x61', () {
    const payload = '{"product_id":"P1","product_type":"BALIK",'
        '"production_date":"2026-09-23","sensor_profile_id":"SP1","layout_version":"L1"}';
    final qr = generateQr(payload, error: 'h');
    expect(qr.version, 11); // gerçek segno da AYNI versiyonu seçiyor
    expect(qr.eccLevel, 'H');
    final m = moduleMatrix(qr);
    expect(m.length, 61);
    expect(m.every((row) => row.length == 61), isTrue);
    // Decode round-trip (pyzbar ile) ayrıca elle doğrulandı — bkz. dosya başlığı.
  });

  test('moduleMatrix: finder pattern köşeleri her zaman standart 7x7 desende', () {
    final qr = generateQr('HELLO', error: 'h', version: 1);
    final m = moduleMatrix(qr);
    // Sol-üst finder'ın merkez 3x3'ü hep koyu (ISO 18004, versiyon bağımsız).
    for (var r = 2; r <= 4; r++) {
      for (var c = 2; c <= 4; c++) {
        expect(m[r][c], 1, reason: 'finder merkezi ($r,$c) koyu olmalı');
      }
    }
    // Finder'ı çevreleyen ayırıcı (separator) hep açık.
    expect(m[7][0], 0);
    expect(m[0][7], 0);
  });

  test('reactiveCandidatesForVersion: functionMask\'in TAM tümleyeni (tautoloji değil, çapraz kontrol)', () {
    const version = 1;
    final candidates = reactiveCandidatesForVersion(version).toSet();
    final mask = functionMask(version); // aynı isimle export edilen gerçek fonksiyon
    final n = mask.length;
    var expectedCount = 0;
    for (var r = 0; r < n; r++) {
      for (var c = 0; c < n; c++) {
        final isFunctionModule = mask[r][c];
        final isCandidate = candidates.contains((row: r, col: c));
        expect(isCandidate, !isFunctionModule, reason: '($r,$c): functionMask=$isFunctionModule ama candidate=$isCandidate');
        if (!isFunctionModule) expectedCount++;
      }
    }
    expect(candidates.length, expectedCount);
    expect(candidates.length, greaterThan(0));
    expect(candidates.length, lessThan(n * n));
  });
}
