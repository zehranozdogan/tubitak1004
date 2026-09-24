// Uzun teknik seviye başlığı (eşiksiz profil) dar ekranda taşmamalı.

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
          body: ResultView(result: mockOk, labelInfo: mockLabelInfo, onRescan: () {}),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.textContaining('Renk seviyesi'), findsOneWidget);
  });
}
