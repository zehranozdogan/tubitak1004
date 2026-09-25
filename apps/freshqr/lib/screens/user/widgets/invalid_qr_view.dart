// user_view.py::_invalid_qr_view'in Dart portu.

import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../../../widgets/section_card.dart';

class InvalidQrView extends StatelessWidget {
  final VoidCallback onRetry;
  /// Gerçek başarısızlık sebebi (bkz. ScanInvalidQr.reason) — teşhis için.
  /// UI-metni KASITLI OLARAK genel/kullanıcı-dostu kalıyor (rapor §7:
  /// kullanıcıya teknik ayrıntı yerine anlaşılır sonuç), bu sadece EKSTRA
  /// bir detay satırı olarak ekleniyor.
  final String? reason;

  const InvalidQrView({super.key, required this.onRetry, this.reason});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionCard(
          title: 'Geçersiz QR kodu',
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.error_outline, color: AppStateColors.spoiled),
                const SizedBox(width: AppSpacing.s),
                Expanded(
                  child: Text(
                    'Bu QR kodu bir FreshQR tazelik etiketine ait değil ya da '
                    'okunamadı. Ürün etiketindeki QR kodunu çerçeveye alıp '
                    'tekrar deneyin.',
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
            if (reason != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.s),
                child: Text(
                  'Ayrıntı: $reason',
                  style: TextStyle(fontSize: AppTextSizes.caption, color: scheme.onSurfaceVariant),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.m),
        SizedBox(
          height: 52,
          child: FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Tekrar Dene')),
        ),
      ],
    );
  }
}
