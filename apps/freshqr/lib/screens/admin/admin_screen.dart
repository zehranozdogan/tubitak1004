// consumer/views/admin_view.py'nin Dart portu — SONRAKİ ADIM.
//
// Şimdilik sadece navigasyonun kırılmaması için minimal bir yer tutucu:
// gerçek ekran (parti no, ürün türü, tarih, sensor_profile_id, layout_
// version formu + label_export.generateLabel() ile canlı metadata önizleme
// + zehra'nın CustomPainter'ının bağlanacağı QR görsel alanı) bir SONRAKİ
// adımda eklenecek (bkz. Python admin_view.py — tam kapsam orada).

import 'package:flutter/material.dart';

import '../../widgets/app_screen.dart';
import '../../widgets/section_card.dart';

class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScreen(
      title: 'Yönetici — Etiket Oluşturma',
      onBack: () => Navigator.of(context).pop(),
      children: [
        SectionCard(
          title: 'Yakında',
          children: [
            Text(
              'Bu ekran bir sonraki adımda eklenecek: etiket bilgisi formu '
              '(parti no, ürün türü, üretim tarihi, sensor_profile_id, '
              'layout_version, yoğunluk), canlı metadata önizleme '
              '(packages_dart/label_export ile GERÇEK) ve QR görsel alanı '
              '(render/CustomPainter portu bağlanınca dolacak).',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ],
    );
  }
}
