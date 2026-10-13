// Sonuç ekranındaki "Ne anlama geliyor?" kartı (4 Ekim): sahada
// "Renk seviyesi 2 / Profil noktası P2" tek başına yorumlanamıyordu.
//
// KRİTİK (§7.2): tazelik sınıfı YOKSA kart sınıf UYDURMAZ — neden
// gösterilemediğini açıklar. Bu testin asıl koruduğu kural budur.

import 'package:color_engine/color_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freshqr/screens/user/mock_results.dart';
import 'package:freshqr/screens/user/widgets/result_view.dart';

void main() {
  Widget ekran(ColorEngineResult r) => MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ResultView(result: r, labelInfo: mockLabelInfo, onRescan: () {}),
          ),
        ),
      );

  testWidgets('sınıf VARSA ne yapılması gerektiğini anlatır', (tester) async {
    await tester.pumpWidget(ekran(const ColorEngineResult(
      qualityScore: 0.9,
      rescanRecommended: false,
      freshnessClass: 'spoiled',
      technicalLevel: 'Renk seviyesi 6 / Profil noktası P6',
      confidence: 1.0,
    )));
    expect(find.text('Ne anlama geliyor?'), findsOneWidget);
    expect(find.textContaining('bozulma aralığında'), findsOneWidget);
    // TÜKETİM TAVSİYESİ VERİLMEMELİ (13 Ekim, danışman yanıtı §7: "Tüketilebilir"
    // ifadesine açık onay yok). Bu, testin asıl koruduğu kurallardan biri.
    expect(find.textContaining('tüketil'), findsNothing);
  });

  testWidgets('sınıf YOKSA sınıf UYDURMAZ, sebebini açıklar (§7.2)', (tester) async {
    await tester.pumpWidget(ekran(const ColorEngineResult(
      qualityScore: 0.9,
      rescanRecommended: false,
      freshnessClass: null, // eşikler tanımlı değil
      technicalLevel: 'Renk seviyesi 2 / Profil noktası P2',
      confidence: 1.0,
    )));
    expect(find.text('Ne anlama geliyor?'), findsOneWidget);
    expect(find.textContaining('HENÜZ gösterilemiyor'), findsOneWidget);
    // Sınıf adları ekranda GEÇMEMELİ (uydurma yok).
    expect(find.textContaining('taze aralığında'), findsNothing);
    expect(find.textContaining('bozulma aralığında'), findsNothing);
  });
}
