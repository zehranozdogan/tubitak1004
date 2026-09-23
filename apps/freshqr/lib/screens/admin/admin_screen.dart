// consumer/views/admin_view.py'nin Dart portu — 1+2. adım: FORM + CANLI
// METADATA ÖNİZLEME.
//
// 2. adımda `packages_dart/label_export` (generateLabel) + `qr_layout`
// (renderLabelImage, bkz. render.dart) GERÇEKTEN bağlandı — "Önizle"
// artık gerçek bir QR/etiket üretip PNG olarak gösteriyor, mock değil.
//
// BİLİNEN EKSİK (TODO, sonraki adım): `_sensorProfile` şu an SABİT bir
// stub (`{'calibration_method': {'code': 'white_black'}}`) — gerçek
// sensor_profile.json dosyasının Flutter asset olarak paketlenip
// (`profile_schema` loader'ıyla) okunması ayrı bir iş (docs/decisions/
// 0005 — bundled statik veri). Bu yüzden B/C kalibrasyon yöntemleri
// önizlemede henüz seçilemez, hep A (white_black) davranır.
//
// "Etiketi oluştur" (gerçek dosya/yerel depolamaya export) hâlâ 3. adım —
// CustomPainter'a asıl ihtiyaç YOK aslında (renderLabelImage zaten piksel
// üretiyor, Image.memory ile gösterilebiliyor) — 3. adımda asıl eksik olan
// dosya/yerel depolama (path_provider) tarafı.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:label_export/label_export.dart' as label_export;
import 'package:profile_schema/profile_schema.dart' as schema;
import 'package:qr_layout/qr_layout.dart' as qr_layout;

import '../../theme/app_theme.dart';
import '../../widgets/app_screen.dart';
import '../../widgets/kv_row.dart';
import '../../widgets/section_card.dart';

const List<String> _commonSpecies = ['LEVREK', 'ÇİPURA', 'SOMON', 'ALABALIK'];

// packages/profile_schema/examples/ altında GERÇEKTEN var olan profil/
// sürümler — bundled asset okuma bağlanınca (TODO yukarıda) buradan gelecek,
// şimdilik tek örnekle sabit.
const List<String> _sensorProfileIds = ['GENIPIN_PUTRESIN_v2'];
const List<String> _layoutVersions = ['QR_SENSOR_v4'];

// 'medium' kaldırıldı — bkz. docs/decisions (medium/high ayırt edilemiyordu).
const List<String> _densityOptions = ['low', 'high'];

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  String _productType = _commonSpecies.first;
  final _productIdController = TextEditingController(text: 'TR45678');
  final _productionDateController = TextEditingController();
  String _sensorProfileId = _sensorProfileIds.first;
  String _layoutVersion = _layoutVersions.first;
  String _density = 'low';

  bool _previewVisible = false;
  Uint8List? _previewPngBytes;
  String? _statusText;
  bool _statusIsError = false;
  List<(String, String)> _meta = [];

  @override
  void initState() {
    super.initState();
    _productionDateController.text = _todayDdMmYyyy();
  }

  @override
  void dispose() {
    _productIdController.dispose();
    _productionDateController.dispose();
    super.dispose();
  }

  String _todayDdMmYyyy() {
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(now.day)}.${two(now.month)}.${now.year}';
  }

  void _resetProductionDate() {
    setState(() => _productionDateController.text = _todayDdMmYyyy());
  }

  /// Python `_to_iso_date`: "GG.AA.YYYY" -> "YYYY-AA-GG". Ayrıştırılamazsa
  /// girdiyi olduğu gibi döndürür (LabelPayload.fromJson zaten geçersiz
  /// değeri kullanıcıya bildirir).
  String _toIsoDate(String value) {
    final trimmed = value.trim();
    final parts = trimmed.split('.');
    if (parts.length != 3) return trimmed;
    final d = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final y = int.tryParse(parts[2]);
    if (d == null || m == null || y == null) return trimmed;
    try {
      final date = DateTime(y, m, d);
      if (date.day != d || date.month != m || date.year != y) return trimmed;
      String two(int n) => n.toString().padLeft(2, '0');
      return '$y-${two(m)}-${two(d)}';
    } catch (_) {
      return trimmed;
    }
  }

  /// TODO (yukarıdaki dosya başlığı): gerçek sensor_profile.json'dan
  /// (bundled asset) gelecek — şimdilik sabit.
  Map<String, dynamic> _sensorProfileStub() {
    return {
      'calibration_method': {'code': 'white_black'},
    };
  }

  void _preview() {
    try {
      final payload = label_export.buildLabelPayload(
        productId: _productIdController.text,
        productType: _productType,
        productionDate: _toIsoDate(_productionDateController.text),
        sensorProfileId: _sensorProfileId,
        layoutVersion: _layoutVersion,
      );
      final generated = label_export.generateLabel(payload, density: _density);
      final sensorProfile = _sensorProfileStub();

      // render.dart: gerekliyse (B/C) layoutJson['reference_regions']'ı
      // YERİNDE günceller — Python export.py'deki akışla birebir aynı sıra.
      final image = qr_layout.renderLabelImage(
        generated.qr,
        generated.layoutJson,
        sensorProfile,
        state: null,
      );
      // Render sırasında reference_regions değişmiş olabilir — Python'daki
      // gibi SON haliyle tekrar doğrula.
      schema.LayoutVersionData.fromJson(generated.layoutJson);

      final n = generated.layout.matrixSize;
      final calibrationCode =
          (sensorProfile['calibration_method'] as Map<String, dynamic>)['code'] as String;

      setState(() {
        _previewVisible = true;
        _previewPngBytes = Uint8List.fromList(img.encodePng(image));
        _meta = [
          ('Parti no', payload.productId),
          ('QR versiyonu', 'v${generated.qr.version}'),
          ('Modül', '$n × $n'),
          ('Reaktif modül', '${generated.layout.sensorModules.length}'),
          ('ECC', 'H'),
          ('Kalibrasyon', calibrationCode),
        ];
        _statusText = "Gri noktalar = reaktif sensör hücreleri. 'Etiketi oluştur' 3. adımda eklenecek.";
        _statusIsError = false;
      });
    } catch (ex) {
      setState(() {
        _previewVisible = true;
        _statusText = 'Geçersiz girdi: $ex';
        _statusIsError = true;
        _previewPngBytes = null;
        _meta = [];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final error = Theme.of(context).colorScheme.error;

    return AppScreen(
      title: 'Yönetici — Etiket Oluşturma',
      onBack: () => Navigator.of(context).pop(),
      children: [
        SectionCard(
          title: 'Etiket bilgisi',
          children: [
            DropdownButtonFormField<String>(
              initialValue: _productType,
              decoration: const InputDecoration(labelText: 'Ürün türü', prefixIcon: Icon(Icons.set_meal)),
              items: [for (final s in _commonSpecies) DropdownMenuItem(value: s, child: Text(s))],
              onChanged: (v) => setState(() => _productType = v ?? _productType),
            ),
            const SizedBox(height: AppSpacing.s),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _productIdController,
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: 'Parti / Lot no (otomatik)',
                      prefixIcon: Icon(Icons.tag),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Yeni parti no üret',
                  onPressed: null, // TODO 3. adım: yerel depolama taranarak gerçek sayaç
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _productionDateController,
                    decoration: const InputDecoration(
                      labelText: 'Üretim tarihi (GG.AA.YYYY)',
                      prefixIcon: Icon(Icons.calendar_month),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.today),
                  tooltip: 'Bugüne sıfırla',
                  onPressed: _resetProductionDate,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s),
            DropdownButtonFormField<String>(
              initialValue: _sensorProfileId,
              decoration: const InputDecoration(labelText: 'sensor_profile_id', prefixIcon: Icon(Icons.science)),
              items: [for (final p in _sensorProfileIds) DropdownMenuItem(value: p, child: Text(p))],
              onChanged: (v) => setState(() => _sensorProfileId = v ?? _sensorProfileId),
            ),
            const SizedBox(height: AppSpacing.s),
            DropdownButtonFormField<String>(
              initialValue: _layoutVersion,
              decoration: const InputDecoration(labelText: 'layout_version', prefixIcon: Icon(Icons.grid_view)),
              items: [for (final l in _layoutVersions) DropdownMenuItem(value: l, child: Text(l))],
              onChanged: (v) => setState(() => _layoutVersion = v ?? _layoutVersion),
            ),
            const SizedBox(height: AppSpacing.s),
            DropdownButtonFormField<String>(
              initialValue: _density,
              decoration: const InputDecoration(labelText: 'Layout yoğunluğu', prefixIcon: Icon(Icons.tune)),
              items: [for (final d in _densityOptions) DropdownMenuItem(value: d, child: Text(d))],
              onChanged: (v) => setState(() => _density = v ?? _density),
            ),
            const SizedBox(height: AppSpacing.m),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.visibility),
                    label: const Text('Önizle'),
                    onPressed: _preview,
                  ),
                ),
                const SizedBox(width: AppSpacing.s),
                Expanded(
                  child: FilledButton.icon(
                    icon: const Icon(Icons.qr_code_2),
                    label: const Text('Etiketi oluştur'),
                    onPressed: null, // TODO 3. adım: yerel depolamaya export
                  ),
                ),
              ],
            ),
          ],
        ),
        if (_previewVisible)
          SectionCard(
            title: 'Etiket önizleme',
            children: [
              Text(
                "Girdiğin bilgilere göre oluşan QR'ın canlı önizlemesi — henüz "
                'hiçbir dosya kaydedilmedi. Gri noktalar reaktif sensör hücrelerinin '
                'yerleşimini gösterir (henüz bir tazelik durumu değil).',
                style: TextStyle(color: muted, fontSize: AppTextSizes.caption),
              ),
              const SizedBox(height: AppSpacing.s),
              if (_previewPngBytes != null)
                Center(
                  child: Container(
                    width: 280,
                    height: 280,
                    padding: const EdgeInsets.all(AppSpacing.m),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                      borderRadius: BorderRadius.circular(AppRadius.card),
                    ),
                    child: Image.memory(_previewPngBytes!, fit: BoxFit.contain),
                  ),
                ),
              if (_statusText != null) ...[
                const SizedBox(height: AppSpacing.s),
                Text(
                  _statusText!,
                  style: TextStyle(color: _statusIsError ? error : muted, fontSize: AppTextSizes.caption),
                ),
              ],
              if (_meta.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.s),
                for (final entry in _meta) KvRow(entry.$1, entry.$2),
              ],
            ],
          ),
      ],
    );
  }
}
