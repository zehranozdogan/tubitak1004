// user_view.py::_result_view'in Dart portu.
//
// Sonuç ekranı kuralı (§7.2, kritik):
// - rescanRecommended ise sınıf/seviye GÖSTERME, "Yeniden tara" göster.
// - freshnessClass yoksa (bilimsel eşik tanımlı değilse) "Taze/Geçiş/Bozuk"
//   UYDURMA; technicalLevel göster. Eşik tanımlandığında kod DEĞİŞMEDEN
//   freshnessClass dolu gelir ve üstteki dal otomatik devreye girer.

import 'package:color_engine/color_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;

import '../../../theme/app_theme.dart';
import '../../../widgets/kv_row.dart';
import '../../../widgets/metric_bar.dart';
import '../../../widgets/section_card.dart';
import '../mock_results.dart';

class ResultView extends StatefulWidget {
  final ColorEngineResult result;
  final LabelInfo labelInfo;
  final VoidCallback onRescan;
  // Kamera taramasında hangi decoder'ın bulduğunu göstermek için (geçici
  // teşhis amaçlı, 27 Eylül — ML Kit'in bu cihazda arada çökmesi/zxing2'ye
  // düşmesi kullanıcı tarafından ayırt edilemiyordu). Kamera dışı yollarda
  // (dosya/mock) null — o zaman satır hiç gösterilmez.
  final String? usedDecoder;

  const ResultView({
    super.key,
    required this.result,
    required this.labelInfo,
    required this.onRescan,
    this.usedDecoder,
  });

  @override
  State<ResultView> createState() => _ResultViewState();
}

class _ResultViewState extends State<ResultView> {
  bool _showDetails = false;

  /// Sonucun KULLANICI İÇİN ne anlama geldiğini anlatır — teknik
  /// detaylardan ÖNCE (4 Ekim). Sahada "Renk seviyesi 2 / Profil noktası
  /// P2" tek başına yorumlanamıyor.
  ///
  /// §7.2 SINIRI: tazelik sınıfı YOKSA burada sınıf UYDURULMAZ. Onun
  /// yerine neden gösterilemediği ve teknik seviyenin ne demek olduğu
  /// dürüstçe anlatılır. Profile `class_thresholds` + nokta `state`
  /// etiketleri eklendiğinde (bkz. docs/saha-hazirlik-kontrol-listesi.md
  /// A1 notu) bu kart KOD DEĞİŞMEDEN sınıf anlatımına geçer.
  Widget _aciklamaKarti(BuildContext context, ColorEngineResult result) {
    final scheme = Theme.of(context).colorScheme;
    final cls = result.freshnessClass;

    const anlamlar = <String, (String, String)>{
      'fresh': (
        'Ürün taze görünüyor.',
        'Renk değişimi, profilin taze aralığında. Normal saklama koşullarında tüketilebilir.',
      ),
      'transition': (
        'Ürün geçiş aşamasında.',
        'Bozulma başlamış olabilir. Bekletmeden tüketilmesi ya da öncelikli sevk edilmesi önerilir.',
      ),
      'spoiled': (
        'Ürün bozulmuş görünüyor.',
        'Renk değişimi, profilin bozulma aralığında. Tüketilmesi önerilmez.',
      ),
    };

    if (cls != null && anlamlar.containsKey(cls)) {
      final (baslik, aciklama) = anlamlar[cls]!;
      final renk = freshnessColors[cls] ?? scheme.primary;
      return SectionCard(
        title: 'Ne anlama geliyor?',
        children: [
          Text(baslik, style: TextStyle(fontWeight: FontWeight.w600, color: renk)),
          const SizedBox(height: AppSpacing.xs),
          Text(aciklama, style: TextStyle(color: scheme.onSurfaceVariant)),
        ],
      );
    }

    // Sınıf yok: dürüst açıklama (§7.2).
    final nokta = result.matchedProfilePoint;
    return SectionCard(
      title: 'Ne anlama geliyor?',
      children: [
        Text(
          'Bu ürün için "taze / geçiş / bozuk" sınıfı HENÜZ gösterilemiyor: '
          'bu sensör profilinde bilimsel tazelik eşikleri tanımlı değil. '
          'Yanlış yönlendirmemek için sınıf üretilmiyor (§7.2).',
          style: TextStyle(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Gösterilen "${result.technicalLevel ?? 'renk seviyesi'}" şu demek: ölçülen renk, '
          'profildeki referans noktalarından bu numaralı olana en yakın çıktı. '
          'Numara büyüdükçe renk koyulaşır${nokta != null ? ' (ölçülen derişim ≈ $nokta)' : ''} — '
          'yani bozulma göstergesi artar.',
          style: TextStyle(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    final scheme = Theme.of(context).colorScheme;

    if (result.rescanRecommended) {
      // GERÇEK SEBEBİ GÖSTER (4 Ekim): motor neden reddettiğini `notes`'a
      // yazıyor (bulanıklık, desen uyuşmazlığı, parlama/doyma...). Burada
      // sabit bir "görüntü bulanık olabilir" metni gösteriliyordu; okuma
      // kalitesi 0.98 iken bile "Okuma kalitesi yetersiz" yazıyor, gerçek
      // sebep gizli kalıyordu. Artık başlık ve açıklama sebebe göre.
      final sebep = result.notes.isNotEmpty
          ? result.notes.first
          : 'Görüntü bulanık, parlamalı veya çok karanlık olabilir.';
      final kaliteDusuk = result.qualityScore < 0.5;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionCard(
            title: kaliteDusuk ? 'Okuma kalitesi yetersiz' : 'Sonuç üretilemedi',
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber_rounded, color: AppStateColors.transition),
                  const SizedBox(width: AppSpacing.s),
                  Expanded(
                    child: Text(
                      '$sebep\n\nYanlış sonuç göstermemek için tazelik sınıfı '
                      'üretilmedi (§7.2).',
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
              MetricBar(label: 'Okuma kalitesi', value: result.qualityScore),
            ],
          ),
          const SizedBox(height: AppSpacing.m),
          SizedBox(
            height: 52,
            child: FilledButton.icon(onPressed: widget.onRescan, icon: const Icon(Icons.refresh), label: const Text('Yeniden Tara')),
          ),
        ],
      );
    }

    final String headlineText;
    final Color headlineColor;
    final IconData? headlineIcon;
    if (result.freshnessClass != null) {
      headlineText = freshnessLabels[result.freshnessClass] ?? result.freshnessClass!.toUpperCase();
      headlineColor = freshnessColors[result.freshnessClass] ?? scheme.primary;
      headlineIcon = freshnessIcons[result.freshnessClass];
    } else {
      headlineText = result.technicalLevel ?? 'Sonuç yok';
      headlineColor = scheme.primary;
      headlineIcon = null;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionCard(
          title: 'Tazelik sonucu',
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (headlineIcon != null) ...[
                  Icon(headlineIcon, size: 28, color: headlineColor),
                  const SizedBox(width: AppSpacing.s),
                ],
                Flexible(
                  child: Text(
                    headlineText,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: AppTextSizes.title, fontWeight: FontWeight.bold, color: headlineColor),
                  ),
                ),
              ],
            ),
            KvRow('Ürün', widget.labelInfo.productType),
            KvRow('Parti', widget.labelInfo.productId),
            KvRow('Üretim tarihi', widget.labelInfo.productionDate),
            MetricBar(label: 'Okuma kalitesi', value: result.qualityScore),
          ],
        ),
        _aciklamaKarti(context, result),
        Center(
          child: TextButton(
            onPressed: () => setState(() => _showDetails = !_showDetails),
            child: Text(_showDetails ? 'Teknik detayları gizle' : 'Teknik detayları göster'),
          ),
        ),
        if (_showDetails)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.m),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.usedDecoder != null) KvRow('Okuyucu', widget.usedDecoder!),
                if (widget.labelInfo.calibrationMethod != null)
                  KvRow('Kalibrasyon', widget.labelInfo.calibrationMethod!),
                // GEÇİCİ (teşhis amaçlı, 1 Ekim): ML Kit çökme metni uzun ve
                // telefonda elle seçilemiyor — panoya kopyalayıp dışarı
                // aktarabilmek için. ML Kit sorunu kapanınca kaldırılacak.
                if (widget.usedDecoder != null && widget.usedDecoder!.contains('ML Kit çöktü'))
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: widget.usedDecoder!));
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Hata metni panoya kopyalandı')),
                        );
                      },
                      icon: const Icon(Icons.copy, size: 18),
                      label: const Text('Hata metnini kopyala'),
                    ),
                  ),
                MetricBar(label: 'Güven skoru', value: result.confidence),
                KvRow('ΔE', result.deltaE != null ? result.deltaE!.toStringAsFixed(2) : '—'),
                KvRow(
                  'Eşleşen profil noktası',
                  result.matchedProfilePoint != null ? result.matchedProfilePoint.toString() : '—',
                ),
                KvRow('Ölçülen modül', result.moduleReadings.length.toString()),
                for (final note in result.notes)
                  Text(note, style: TextStyle(fontSize: AppTextSizes.caption, color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
        SizedBox(
          height: 48,
          child: FilledButton.tonalIcon(onPressed: widget.onRescan, icon: const Icon(Icons.refresh), label: const Text('Yeniden Tara')),
        ),
      ],
    );
  }
}
