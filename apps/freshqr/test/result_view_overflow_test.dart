// Uzun teknik seviye başlığı (eşiksiz profil) dar ekranda YATAY taşma
// yapmamalı (RenderFlex unbounded width) — asıl korunan kural bu.
//
// Kaydırma: gerçek uygulamada ResultView, AppScreen'in ListView'ı içinde
// yer alır (bkz. widgets/app_screen.dart), yani sayfa dikeyde kaydırılır.
// Test burada kaydırmasız bir Scaffold kullanıyordu; içerik 800px'i
// aşınca DİKEY taşma veriyordu — bu gerçek bir hata değil, test
// kurulumunun gerçek kullanımdan farkıydı (4 Ekim'de "Ne anlama
// geliyor?" kartı eklenince ortaya çıktı). Gerçek kullanıma uyduruldu.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freshqr/screens/user/mock_results.dart';
import 'package:freshqr/screens/user/widgets/result_view.dart';

void main() {
  testWidgets('uzun technicalLevel başlığı 320px genişlikte taşma hatası vermez', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ResultView(result: mockOk, labelInfo: mockLabelInfo, onRescan: () {}),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // Başlığa ÖZEL eşleşme: "Ne anlama geliyor?" kartı da teknik seviyeyi
    // alıntılıyor, bu yüzden textContaining iki sonuç veriyor.
    expect(find.text(mockOk.technicalLevel!), findsOneWidget);
  });
}
