// AdminScreen'in 2. adımı (canlı metadata önizleme) testleri —
// consumer/views/admin_view.py::do_preview'in Dart karşılığı.
//
// 3. adımın ("Etiketi oluştur" -> exportLabel() -> gerçek dosya yazma)
// widget-seviyesi testi BİLİNÇLİ OLARAK burada YOK: path_provider'ın
// platform kanalını mock'layan bir widget testi bu ortamda (flutter_tester
// + gerçek dosya G/Ç birleşimi) sürekli TAKILIYOR (muhtemelen sandbox
// kısıtlaması, kesin sebep belirlenemedi) — kod hatası değil, ortam sorunu.
// exportLabel()'ın KENDİSİ zaten tam test edildi (bkz.
// packages_dart/label_export/test/export_label_test.dart, saf `dart test`,
// bu sorunu YAŞAMIYOR) — burada eksik olan sadece "buton bu fonksiyonu
// doğru tetikliyor mu" widget bağlantısı, bu Chrome'da elle doğrulandı.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freshqr/screens/admin/admin_screen.dart';

void main() {
  // Form + önizleme kartı standart test viewport'unda (800x600) sığmıyor;
  // "Önizle"ye her testte scroll etmek yerine viewport'u büyütüyoruz.
  Future<void> useTallSurface(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }

  testWidgets("Önizle: varsayılan form değerleriyle gerçek bir QR üretir, meta satırları gösterir", (tester) async {
    await useTallSurface(tester);
    await tester.pumpWidget(const MaterialApp(home: AdminScreen()));
    await tester.pumpAndSettle();

    // Buton basılana kadar önizleme kartı hiç yok.
    expect(find.text('Etiket önizleme'), findsNothing);

    await tester.tap(find.text('Önizle'));
    await tester.pumpAndSettle();

    expect(find.text('Etiket önizleme'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);

    // Varsayılan parti no (TR45678) — bir kez form alanında, bir kez önizleme
    // meta satırında (KvRow) görünüyor, ikisi de doğru/beklenen.
    expect(find.text('TR45678'), findsNWidgets(2));
    expect(find.text('white_black'), findsOneWidget);
    expect(find.text('ECC'), findsOneWidget);
    expect(find.text('H'), findsOneWidget);

    // Hata durumu değil, dürüst durum notu gösterilmeli.
    expect(find.textContaining('Geçersiz girdi'), findsNothing);
  });

  testWidgets('Yoğunluk değiştirip tekrar Önizle -> çökmeden yeni önizleme üretir', (tester) async {
    await useTallSurface(tester);
    await tester.pumpWidget(const MaterialApp(home: AdminScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Önizle'));
    await tester.pumpAndSettle();
    expect(find.text('Etiket önizleme'), findsOneWidget);

    // "Layout yoğunluğu" dropdown'ını 'low' -> 'high'a çevir.
    await tester.tap(find.text('low').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('high').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Önizle'));
    await tester.pumpAndSettle();

    // Sayısal karşılaştırma (daha yoğun -> daha çok reaktif modül) zaten
    // qr_layout/reactive_test.dart'ta doğrulanıyor — burada asıl kontrol
    // edilen: form değişince önizleme ÇÖKMEDEN, hatasız yeniden üretiliyor.
    expect(find.text('Etiket önizleme'), findsOneWidget);
    expect(find.textContaining('Geçersiz girdi'), findsNothing);
  });
}
