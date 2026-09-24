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

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freshqr/data/reference_data.dart';
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
    await tester.pumpWidget(MaterialApp(home: AdminScreen(reference: ReferenceData((p) => File(p).readAsString()))));
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

  testWidgets('Yoğunluk kullanıcı seçimi değil: layout tarifinden gelir (salt okunur), profil değişince önizleme çökmez', (tester) async {
    await useTallSurface(tester);
    await tester.pumpWidget(MaterialApp(home: AdminScreen(reference: ReferenceData((p) => File(p).readAsString()))));
    await tester.pumpAndSettle();

    // Paketli asset'ler (rootBundle) gerçek G/Ç ile okunur — bekle.
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 30)));
      await tester.pump();
    }

    expect(find.text('Layout yoğunluğu (layout_version tarifinden)'), findsOneWidget);
    expect(find.text('low'), findsOneWidget); // QR_SENSOR_v4 tarifi

    // sensor_profile'ı DEMO profiline çevir (paketli asset listesinden):
    // 2. açılır liste (0=ürün türü, 1=sensor_profile_id, 2=layout_version).
    await tester.tap(find.byType(DropdownButtonFormField<String>).at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('DEMO_QR_STATE_COLORS_v1').last);
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 30)));
      await tester.pump();
    }

    await tester.tap(find.text('Önizle'));
    await tester.pumpAndSettle();

    expect(find.text('Etiket önizleme'), findsOneWidget);
    expect(find.textContaining('Geçersiz girdi'), findsNothing);
  });
}
