// consumer/views/label_detail_view.py'nin Dart portu — tek bir etiketin
// bilgileri + 3 tazelik durumunun renkli QR görselleri + silme.

import 'dart:io';

import 'package:flutter/material.dart';

import '../../data/label_store.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_screen.dart';
import '../../widgets/kv_row.dart';
import '../../widgets/section_card.dart';

const Map<String, String> _stateLabels = {'fresh': 'Taze', 'transition': 'Geçiş', 'spoiled': 'Bozuk'};

class LabelDetailScreen extends StatefulWidget {
  final Directory dir;
  final String stem;

  const LabelDetailScreen({super.key, required this.dir, required this.stem});

  @override
  State<LabelDetailScreen> createState() => _LabelDetailScreenState();
}

class _LabelDetailScreenState extends State<LabelDetailScreen> {
  Map<String, dynamic>? _payload;
  Map<String, dynamic>? _layout;

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
            Wrap(
              alignment: WrapAlignment.center,
              spacing: AppSpacing.m,
              runSpacing: AppSpacing.m,
              children: [
                for (final entry in _stateLabels.entries) _StateImage(dir: widget.dir, stem: widget.stem, stateKey: entry.key, label: entry.value),
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

  const _StateImage({required this.dir, required this.stem, required this.stateKey, required this.label});

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
      ],
    );
  }
}
