// consumer/views/labels_view.py'nin Dart portu — üretilen etiketler listesi:
// her kayıt için küçük QR görseli + temel bilgiler.

import 'dart:io';

import 'package:flutter/material.dart';

import '../../data/label_store.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_screen.dart';
import 'label_detail_screen.dart';

class LabelsScreen extends StatefulWidget {
  /// Test için enjekte edilebilir; null ise uygulama belge dizini/labels.
  final Directory? dir;

  const LabelsScreen({super.key, this.dir});

  @override
  State<LabelsScreen> createState() => _LabelsScreenState();
}

class _LabelsScreenState extends State<LabelsScreen> {
  Directory? _dir;
  List<StoredLabel>? _labels;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final dir = widget.dir ?? await defaultLabelsDir();
      final labels = await loadLabels(dir);
      if (mounted) {
        setState(() {
          _dir = dir;
          _labels = labels;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  Future<void> _open(StoredLabel label) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => LabelDetailScreen(dir: _dir!, stem: label.stem)),
    );
    // Detayda silinmiş olabilir — listeyi tazele.
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final labels = _labels;
    final title = labels == null ? 'Üretilen Etiketler' : 'Üretilen Etiketler (${labels.length})';

    final List<Widget> body;
    if (_error != null) {
      body = [Text('Etiketler okunamadı: $_error', style: TextStyle(color: Theme.of(context).colorScheme.error))];
    } else if (labels == null) {
      body = const [Center(child: CircularProgressIndicator())];
    } else if (labels.isEmpty) {
      body = [
        Text(
          "Henüz etiket üretilmedi. Yönetici ekranında 'Etiketi oluştur' ile ilk etiketini üret.",
          style: TextStyle(fontSize: AppTextSizes.body, color: muted),
        ),
      ];
    } else {
      body = [for (final l in labels) _LabelCard(dir: _dir!, label: l, onTap: () => _open(l))];
    }

    return AppScreen(title: title, onBack: () => Navigator.of(context).pop(), children: body);
  }
}

class _LabelCard extends StatelessWidget {
  final Directory dir;
  final StoredLabel label;
  final VoidCallback onTap;

  const _LabelCard({required this.dir, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurfaceVariant;
    final png = File('${dir.path}/${label.stem}.png');
    final Widget thumb = png.existsSync()
        ? Container(
            width: 64,
            height: 64,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Image.file(
              png,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => Icon(Icons.broken_image_outlined, color: muted),
            ),
          )
        : Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(color: scheme.surfaceContainer, borderRadius: BorderRadius.circular(8)),
            child: Icon(Icons.qr_code_2, color: muted, size: 28),
          );

    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.card),
      onTap: onTap,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.m),
          child: Row(
            children: [
              thumb,
              const SizedBox(width: AppSpacing.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${label.productId} · ${label.productType}',
                      style: const TextStyle(fontSize: AppTextSizes.body, fontWeight: FontWeight.w600),
                    ),
                    Text(label.productionDate, style: TextStyle(fontSize: AppTextSizes.caption, color: muted)),
                    Text(
                      '${label.sensorProfileId} · ${label.layoutVersion}',
                      style: TextStyle(fontSize: AppTextSizes.caption, color: muted),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: muted),
            ],
          ),
        ),
      ),
    );
  }
}
