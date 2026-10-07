// consumer/views/label_detail_view.py'nin Dart portu — tek bir etiketin
// bilgileri + 3 tazelik durumunun renkli QR görselleri + silme.
//
// "Test et" düğmeleri (4 Ekim): bu etiketin sentetik durum görselini
// GERÇEK analiz zincirinden geçirir — kamerasız. Daha önce bu yetenek
// kullanıcı ekranındaki "Dosyadan test et" kartındaydı; kamera
// çalışmaya başladıktan sonra oradan kaldırılıp buraya taşındı (kullanıcı
// akışı sadeleşsin, yetenek kaybolmasın). Sonuç kullanıcı tarafındakiyle
// AYNI ekranda (ResultView) gösterilir ve tamamlanmış okumalar aynı
// şekilde geçmişe yazılır.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:gal/gal.dart';

import '../../data/label_store.dart';
import '../../data/reference_data.dart';
import '../../data/scan_history.dart';
import '../../services/file_scan.dart';
import '../../services/scan_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_screen.dart';
import '../../widgets/kv_row.dart';
import '../../widgets/section_card.dart';
import '../user/widgets/result_view.dart';

const Map<String, String> _stateLabels = {'fresh': 'Taze', 'transition': 'Geçiş', 'spoiled': 'Bozuk'};

class LabelDetailScreen extends StatefulWidget {
  final Directory dir;
  final String stem;

  /// Test için enjekte edilebilir; null ise paketli varlıklar / uygulama
  /// belge dizinindeki scan_history.json kullanılır.
  final ReferenceData? reference;
  final File? historyFile;

  const LabelDetailScreen({
    super.key,
    required this.dir,
    required this.stem,
    this.reference,
    this.historyFile,
  });

  @override
  State<LabelDetailScreen> createState() => _LabelDetailScreenState();
}

class _LabelDetailScreenState extends State<LabelDetailScreen> {
  Map<String, dynamic>? _payload;
  Map<String, dynamic>? _layout;
  late final ReferenceData _reference = widget.reference ?? ReferenceData();
  bool _testing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final payload = await readJson(File('${widget.dir.path}/${widget.stem}.label_payload.json'));
    final layout = await readJson(File('${widget.dir.path}/${widget.stem}.layout_version.json'));
    if (mounted) {
      setState(() {
        _payload = payload;
        _layout = layout;
      });
    }
  }

  Future<void> _confirmDelete(String productId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Etiketi sil'),
        content: Text(
          '"$productId" etiketi ve tüm dosyaları (PNG, JSON, 3 tazelik görseli) '
          'kalıcı olarak silinecek. Bu geri alınamaz.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Vazgeç')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppStateColors.spoiled),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await deleteLabel(widget.dir, widget.stem);
    if (mounted) Navigator.of(context).pop();
  }

  /// Seçilen tazelik durumunun sentetik görselini GERÇEK zincirden
  /// geçirir (kamerasız) ve sonucu kullanıcı tarafındakiyle AYNI ekranda
  /// gösterir. Tamamlanmış okumalar geçmişe yazılır — yarım kalan
  /// ("yeniden tara" ile biten) okumalar YAZILMAZ (§7.1).
  Future<void> _testState(String stateKey) async {
    if (_testing) return;
    setState(() => _testing = true);
    try {
      final outcome = await scanStoredLabel(
        dir: widget.dir,
        stem: widget.stem,
        state: stateKey,
        reference: _reference,
      );
      if (!mounted) return;
      switch (outcome) {
        case ScanSuccess(:final result, :final labelInfo):
          if (!result.rescanRecommended) {
            try {
              final file = widget.historyFile ?? await defaultScanHistoryFile();
              await appendScanHistory(
                file,
                ScanHistoryEntry(
                  productType: labelInfo.productType,
                  productId: labelInfo.productId,
                  when: DateTime.now(),
                  freshnessClass: result.freshnessClass,
                  technicalLevel: result.technicalLevel,
                  deltaE: result.deltaE,
                  confidence: result.confidence,
                  qualityScore: result.qualityScore,
                  calibrationMethod: labelInfo.calibrationMethod,
                ),
              );
            } catch (_) {
              // Geçmiş yazılamadı — sonucu göstermeye engel değil.
            }
          }
          if (!mounted) return;
          await Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (ctx) => AppScreen(
              title: 'Tazelik sonucu',
              onBack: () => Navigator.of(ctx).pop(),
              children: [
                ResultView(
                  result: result,
                  labelInfo: labelInfo,
                  onRescan: () => Navigator.of(ctx).pop(),
                ),
              ],
            ),
          ));
        case ScanInvalidQr(:final reason):
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(reason)));
      }
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  /// Üç tazelik durumunun sentetik görselini telefonun galerisine
  /// kaydeder (7 Ekim). Bunlar TEST hedefleridir — basılacak dosya değil.
  /// Nötr önizlemeyi (gri reaktif hücreler) taramak anlamsız sonuç verir:
  /// gri, profildeki hiçbir renge karşılık gelmez, yalnızca parlaklık
  /// olarak tesadüfen bir noktaya düşer.
  Future<void> _saveStatesToGallery() async {
    var kaydedilen = 0;
    String? hata;
    for (final key in _stateLabels.keys) {
      final png = File('${widget.dir.path}/${widget.stem}.state_$key.png');
      if (!png.existsSync()) continue;
      try {
        await Gal.putImage(png.path, album: 'FreshQR');
        kaydedilen++;
      } catch (ex) {
        hata = '$ex';
      }
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(hata != null
          ? 'Kaydedilemedi: $hata'
          : '$kaydedilen durum görseli galeriye kaydedildi (FreshQR albümü).'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final payload = _payload;
    final layout = _layout;
    if (payload == null || layout == null) {
      return const AppScreen(title: 'Etiket', children: [Center(child: CircularProgressIndicator())]);
    }
    final productId = (payload['product_id'] as String?) ?? widget.stem;
    final sensorModules = (layout['sensor_modules'] as List?) ?? const [];

    return AppScreen(
      title: productId,
      onBack: () => Navigator.of(context).pop(),
      actions: [
        IconButton(
          icon: const Icon(Icons.delete_outline),
          tooltip: 'Etiketi sil',
          onPressed: () => _confirmDelete(productId),
        ),
      ],
      children: [
        SectionCard(
          title: 'Etiket bilgisi',
          children: [
            KvRow('Parti no', '${payload['product_id'] ?? '—'}'),
            KvRow('Ürün türü', '${payload['product_type'] ?? '—'}'),
            KvRow('Üretim tarihi', '${payload['production_date'] ?? '—'}'),
            KvRow('sensor_profile_id', '${payload['sensor_profile_id'] ?? '—'}'),
            KvRow('layout_version', '${payload['layout_version'] ?? '—'}'),
          ],
        ),
        SectionCard(
          title: 'Layout bilgisi',
          children: [
            KvRow('QR versiyonu', 'v${layout['qr_version'] ?? '—'}'),
            KvRow('Matris', '${layout['matrix_size'] ?? '—'}'),
            KvRow('Reaktif modül', '${sensorModules.length}'),
            KvRow('Yoğunluk', '${layout['module_density'] ?? '—'}'),
          ],
        ),
        SectionCard(
          title: 'Tazelik durumları (§8: sentetik görseller)',
          children: [
            Text(
              'Bu görseller TEST hedefidir. Basılacak dosya bunlar değil, '
              'nötr etikettir — ama nötr etiketi taramak anlamsız sonuç verir '
              '(reaktif hücreler gri, bir tazelik durumu taşımaz).',
              style: TextStyle(
                fontSize: AppTextSizes.caption,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.s),
            OutlinedButton.icon(
              icon: const Icon(Icons.image_outlined, size: 18),
              label: const Text('Durum görsellerini galeriye kaydet'),
              onPressed: _saveStatesToGallery,
            ),
            const SizedBox(height: AppSpacing.s),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: AppSpacing.m,
              runSpacing: AppSpacing.m,
              children: [
                for (final entry in _stateLabels.entries)
                  _StateImage(
                    dir: widget.dir,
                    stem: widget.stem,
                    stateKey: entry.key,
                    label: entry.value,
                    onTest: _testing ? null : () => _testState(entry.key),
                  ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class _StateImage extends StatelessWidget {
  final Directory dir;
  final String stem;
  final String stateKey;
  final String label;
  final VoidCallback? onTest;

  const _StateImage({
    required this.dir,
    required this.stem,
    required this.stateKey,
    required this.label,
    this.onTest,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final png = File('${dir.path}/$stem.state_$stateKey.png');
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 150,
          height: 150,
          padding: const EdgeInsets.all(AppSpacing.s),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: png.existsSync()
              ? Image.file(
                  png,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => Icon(Icons.broken_image_outlined, color: scheme.onSurfaceVariant),
                )
              : Text('Yok', style: TextStyle(fontSize: AppTextSizes.caption, color: scheme.onSurfaceVariant)),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: AppTextSizes.caption, color: scheme.onSurfaceVariant)),
        OutlinedButton(onPressed: onTest, child: Text('$label test et')),
      ],
    );
  }
}
