// InvalidQrView: gerçek başarısızlık sebebi (ScanInvalidQr.reason) artık
// ekranda GÖRÜNÜYOR — önceden hep aynı genel mesaj gösteriliyordu, hangi
// adımda (decode/şema/bilinmeyen profil) başarısız olunduğu anlaşılamıyordu.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freshqr/screens/user/widgets/invalid_qr_view.dart';

void main() {
  testWidgets('reason verilmezse "Ayrıntı" satırı gösterilmez', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: InvalidQrView(onRetry: () {}))));
    expect(find.textContaining('Ayrıntı'), findsNothing);
  });

  testWidgets('reason verilirse "Ayrıntı: ..." satırı gösterilir', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: InvalidQrView(onRetry: () {}, reason: 'Görsel çözülemedi (desteklenmeyen biçim/bozuk dosya)')),
    ));
    expect(find.textContaining('Ayrıntı: Görsel çözülemedi'), findsOneWidget);
  });
}
