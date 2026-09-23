// matching.dart testleri — REFERANS DEĞERLER gerçek Python
// packages/color_engine/matching.py çalıştırılarak üretildi, TAHMİN EDİLMEDİ.

import 'package:color_engine/color_engine.dart';
import 'package:test/test.dart';

void main() {
  final scalePoints = const [
    ScalePoint(value: 0.0, lab: Lab(80.0, 2.0, 5.0), state: 'fresh'),
    ScalePoint(value: 1.0, lab: Lab(55.0, 5.0, 10.0), state: 'transition'),
    ScalePoint(value: 2.0, lab: Lab(25.0, 4.0, -2.0), state: 'spoiled'),
  ];
  const measured = Lab(56.0, 5.0, 9.0);

  test('en yakın noktayı bulur, class_thresholds VARSA freshnessClass dolar', () {
    final result = matchProfilePoint(measured, scalePoints: scalePoints, hasClassThresholds: true);
    expect(result.matchedProfilePoint, 1.0);
    expect(result.deltaE, closeTo(1.2032952934730354, 1e-6));
    expect(result.freshnessClass, 'transition');
    expect(result.technicalLevel, 'Renk seviyesi 2 / Profil noktası P2');
  });

  test('§7.2 KRİTİK: class_thresholds YOKSA freshnessClass null (state dolu olsa bile)', () {
    final result = matchProfilePoint(measured, scalePoints: scalePoints, hasClassThresholds: false);
    expect(result.matchedProfilePoint, 1.0);
    expect(result.deltaE, closeTo(1.2032952934730354, 1e-6));
    expect(result.freshnessClass, isNull);
    expect(result.technicalLevel, 'Renk seviyesi 2 / Profil noktası P2');
  });

  test('eşitlikte İLK (en düşük indeksli) nokta kazanır (numpy.argmin sözleşmesi)', () {
    const tiePoints = [
      ScalePoint(value: 0.0, lab: Lab(50.0, 0.0, 0.0), state: 'a'),
      ScalePoint(value: 1.0, lab: Lab(50.0, 0.0, 0.0), state: 'b'),
    ];
    final result = matchProfilePoint(const Lab(50.0, 0.0, 0.0), scalePoints: tiePoints, hasClassThresholds: true);
    expect(result.matchedProfilePoint, 0.0);
    expect(result.deltaE, 0.0);
    expect(result.freshnessClass, 'a');
    expect(result.technicalLevel, 'Renk seviyesi 1 / Profil noktası P1');
  });

  test('boş scalePoints hata fırlatır (Python: ValueError)', () {
    expect(
      () => matchProfilePoint(measured, scalePoints: const [], hasClassThresholds: false),
      throwsArgumentError,
    );
  });
}
