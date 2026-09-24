// Duman testi (smoke test): Login -> Kullanıcı -> "Taze" test senaryosu ->
// sonuç ekranında doğru başlık/renk göründüğünü doğrular. UI-first bu
// aşamada gerçek kamera/analiz YOK (bkz. lib/screens/user/user_screen.dart
// dosya başlığı) — sadece ekranların DOĞRU bağlandığını kanıtlar.

import 'package:flutter_test/flutter_test.dart';
import 'package:freshqr/main.dart';

void main() {
  testWidgets('Login -> Kullanıcı -> Taze senaryosu -> sonuç ekranı TAZE gösterir', (tester) async {
    await tester.pumpWidget(const FreshQrApp());
    await tester.pumpAndSettle();

    expect(find.text('FreshQR'), findsOneWidget);

    await tester.tap(find.text('Kullanıcı'));
    await tester.pumpAndSettle();

    expect(find.text('QR kodu çerçeveye alın'), findsOneWidget);

    await tester.tap(find.text('Taze'));
    await tester.pumpAndSettle();

    expect(find.text('TAZE'), findsOneWidget);
    expect(find.text('Levrek'), findsOneWidget);
  });

  testWidgets('Bozuk senaryosu -> BOZUK gösterir, Yeniden Tara ile tarama ekranına döner', (tester) async {
    await tester.pumpWidget(const FreshQrApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kullanıcı'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Bozuk'));
    await tester.pumpAndSettle();
    expect(find.text('BOZUK'), findsOneWidget);

    await tester.tap(find.text('Yeniden Tara'));
    await tester.pumpAndSettle();
    expect(find.text('QR kodu çerçeveye alın'), findsOneWidget);
  });

  testWidgets('Düşük kalite senaryosu -> rescan ekranı, sınıf/seviye GÖSTERİLMEZ (§7.2)', (tester) async {
    await tester.pumpWidget(const FreshQrApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kullanıcı'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Düşük kalite'));
    await tester.pumpAndSettle();

    expect(find.text('Okuma kalitesi yetersiz'), findsOneWidget);
    expect(find.text('TAZE'), findsNothing);
    expect(find.text('BOZUK'), findsNothing);
  });

  testWidgets('İzin yok senaryosu -> izin ekranı gösterir', (tester) async {
    await tester.pumpWidget(const FreshQrApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kullanıcı'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('İzin yok'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('İzin yok'));
    await tester.pumpAndSettle();

    expect(find.text('Kamera izni gerekli'), findsOneWidget);
  });

  testWidgets('Geçersiz QR senaryosu -> geçersiz QR ekranı gösterir', (tester) async {
    await tester.pumpWidget(const FreshQrApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kullanıcı'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Geçersiz QR'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Geçersiz QR'));
    await tester.pumpAndSettle();

    expect(find.text('Geçersiz QR kodu'), findsOneWidget);
  });

  testWidgets('Login -> Yönetici ekranı açılır', (tester) async {
    await tester.pumpWidget(const FreshQrApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Yönetici'));
    await tester.pumpAndSettle();

    expect(find.text('Yönetici — Etiket Oluşturma'), findsOneWidget);
  });
}
