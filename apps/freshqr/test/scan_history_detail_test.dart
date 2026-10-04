// "Son okumalar" listesindeki bir kayda dokununca ölçüm detaylarının
// açıldığını doğrular (4 Ekim). Detaylar kaydedilmeye başlanmadan önce
// liste tıklanamıyordu ve saha turunda her sonucu ekrandan elle not almak
// gerekiyordu — bu testin koruduğu davranış o.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freshqr/data/scan_history.dart';
import 'package:freshqr/screens/user/widgets/scan_view.dart';

void main() {
  final kayit = ScanHistoryEntry(
    productType: 'Levrek',
    productId: 'KALIB-C',
    when: DateTime.parse('2026-10-04T12:30:00Z'),
    technicalLevel: 'Renk seviyesi 4 / Profil noktası P4',
    deltaE: 2.08,
    confidence: 1.0,
    qualityScore: 0.93,
    calibrationMethod: 'multicolor_patch',
    usedDecoder: 'ML Kit',
  );

  Widget ekran(ScanHistoryEntry e) => MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ScanView(
              onScan: () {},
              testScenarios: const [],
              onUploadPhoto: () {},
              recentReads: [e],
            ),
          ),
        ),
      );

  testWidgets('kayda dokununca ölçüm detayları açılır', (tester) async {
    await tester.pumpWidget(ekran(kayit));
    expect(find.text('Okuma detayı'), findsNothing);

    await tester.ensureVisible(find.text('Levrek · KALIB-C'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Levrek · KALIB-C'));
    await tester.pumpAndSettle();

    expect(find.text('Okuma detayı'), findsOneWidget);
    expect(find.text('2.08'), findsOneWidget);              // ΔE
    expect(find.text('multicolor_patch'), findsOneWidget);  // kalibrasyon
    expect(find.text('ML Kit'), findsOneWidget);            // okuyucu
  });

  testWidgets('eski kayıtta (detay yok) ekran çökmez, "—" gösterir', (tester) async {
    final eski = ScanHistoryEntry(
      productType: 'Levrek',
      productId: 'TR45678',
      when: DateTime.parse('2026-09-30T10:00:00Z'),
      technicalLevel: 'Renk seviyesi 2 / Profil noktası P2',
    );
    await tester.pumpWidget(ekran(eski));
    await tester.ensureVisible(find.text('Levrek · TR45678'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Levrek · TR45678'));
    await tester.pumpAndSettle();

    expect(find.text('Okuma detayı'), findsOneWidget);
    expect(find.text('—'), findsWidgets); // ΔE/güven/kalibrasyon/okuyucu boş
  });
}
