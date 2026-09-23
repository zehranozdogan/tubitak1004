// consumer/views/admin_view.py'nin Dart portu — 1. adım: FORM.
//
// Sıradaki adımlar (bu dosyanın önceki yer tutucu sürümünde not edilmişti,
// hâlâ geçerli): 2. canlı metadata önizleme (packages_dart/label_export
// ile GERÇEK) + 3. QR görsel alanı (CustomPainter). Bu adımda SADECE form
// alanları var; "Önizle"/"Etiketi oluştur" butonları şimdilik boş (TODO).
//
// Python'daki dropdown_field(editable=True) hem listeden seçime hem elle
// yazmaya izin veriyordu (ör. sensor_profile_id) — burada basitlik için
// düz DropdownButtonFormField kullanıldı; serbest metin girişi istenirse
// Flutter'ın Autocomplete widget'ına yükseltilebilir (sonraki adım).

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../widgets/app_screen.dart';
import '../../widgets/section_card.dart';

const List<String> _commonSpecies = ['LEVREK', 'ÇİPURA', 'SOMON', 'ALABALIK'];

// packages/profile_schema/examples/ altında GERÇEKTEN var olan profil/
// sürümler — 2. adımda bundled dosyalardan (profile_schema Dart portu)
// otomatik okunacak, şimdilik tek örnekle sabit.
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

  @override
  Widget build(BuildContext context) {
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
                  onPressed: null, // TODO 2. adım: out/ (ya da yerel depolama) taranarak gerçek sayaç
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
                    onPressed: null, // TODO 2. adım: label_export ile canlı metadata önizleme
                  ),
                ),
                const SizedBox(width: AppSpacing.s),
                Expanded(
                  child: FilledButton.icon(
                    icon: const Icon(Icons.qr_code_2),
                    label: const Text('Etiketi oluştur'),
                    onPressed: null, // TODO 3. adım: export + CustomPainter QR görseli
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
