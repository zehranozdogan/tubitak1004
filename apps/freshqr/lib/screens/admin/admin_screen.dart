// consumer/views/admin_view.py'nin Dart portu — 1+2+3. adım: FORM + CANLI
// METADATA ÖNİZLEME + GERÇEK EXPORT (yerel depolama).
//
// 3. adımda `label_export.exportLabel()` (bu adımda eklendi, bkz.
// packages_dart/label_export/lib/src/export.dart) + `path_provider`
// bağlandı — "Etiketi oluştur" artık gerçekten dosya yazıyor (uygulamanın
// kendi yerel belge klasörüne, `docs/decisions/0005`teki "statik/paketli,
// DB yok" ilkesiyle uyumlu: bu SADECE bu cihazın kendi ürettiği etiketlerin
// GEÇMİŞİ, dağıtılan referans verisiyle (sensor_profile/layout_version)
// KARIŞTIRILMASIN — o ayrı, bundled/statik kalıyor).
//
// CustomPainter'a hâlâ gerek yok — renderLabelImage zaten piksel üretiyor,
// Image.memory ile gösteriliyor (bkz. önceki adımın notu).
//
// 24 Eylül: sensor_profile ve layout tarifi artık paketli asset'ten
// (`data/reference_data.dart`, karar 0005) yükleniyor; yoğunluk kullanıcı
// seçimi değil, layout_version tarifinden geliyor (okuyucu aynı tarifle
// hücreleri yeniden türetiyor). PDF çıktısı label_export.exportLabel içinde (elle yazılmış,
// bağımlılıksız PDF yazıcı — `pdf` paketi qr ^3 istediği için kullanılmadı).

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:label_export/label_export.dart' as label_export;
import 'package:path_provider/path_provider.dart';
import 'package:profile_schema/profile_schema.dart' as schema;
import 'package:qr_layout/qr_layout.dart' as qr_layout;
import 'package:share_plus/share_plus.dart';

import '../../theme/app_theme.dart';
import '../../widgets/app_screen.dart';
import '../../widgets/kv_row.dart';
import '../../widgets/section_card.dart';
import '../../data/reference_data.dart';
import '../labels/labels_screen.dart';

const List<String> _commonSpecies = ['LEVREK', 'ÇİPURA', 'SOMON', 'ALABALIK'];

// Açılıştaki varsayılanlar; paketli referans veri (ReferenceData, karar 0005)
// yüklenince gerçek listelerle değiştirilir.
const List<String> _fallbackSensorProfileIds = ['GENIPIN_PUTRESIN_v2'];
const List<String> _fallbackLayoutVersions = ['QR_SENSOR_v4'];

const String _batchPrefix = 'TR';
const int _batchStart = 45678; // rapor örneğindeki ilk parti no (§8, §10.1)

const Map<String, String> _stateLabels = {'fresh': 'Taze', 'transition': 'Geçiş', 'spoiled': 'Bozuk'};

class AdminScreen extends StatefulWidget {
  /// Test için enjekte edilebilir (paketli asset okuyucusu); null ise rootBundle.
  final ReferenceData? reference;

  const AdminScreen({super.key, this.reference});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  String _productType = _commonSpecies.first;
  final _productIdController = TextEditingController(text: '$_batchPrefix$_batchStart');
  final _productionDateController = TextEditingController();
  late final ReferenceData _reference = widget.reference ?? ReferenceData();
  List<String> _sensorProfileIds = _fallbackSensorProfileIds;
  List<String> _layoutVersions = _fallbackLayoutVersions;
  String _sensorProfileId = _fallbackSensorProfileIds.first;
  String _layoutVersion = _fallbackLayoutVersions.first;
  // Yoğunluk KULLANICI SEÇİMİ DEĞİL: layout_version tarifinden gelir —
  // okuyucu hücreleri aynı tarifle yeniden türettiği için ikisi aynı olmak
  // zorunda (24 Eylül kararı, bkz. data/reference_data.dart).
  String _density = 'low';
  Map<String, dynamic>? _sensorProfileRaw;

  bool _previewVisible = false;
  Uint8List? _previewPngBytes;
  String? _statusText;
  bool _statusIsError = false;
  List<(String, String)> _meta = [];
  List<(String, Uint8List)> _statePreviews = [];
  Map<String, String> _outputFiles = {};
  bool _exporting = false;

  Directory? _labelsDir;

  @override
  void initState() {
    super.initState();
    _productionDateController.text = _todayDdMmYyyy();
    _initBatchNo();
    _loadReference();
  }

  Future<void> _loadReference() async {
    try {
      final profiles = await _reference.sensorProfileIds();
      final layouts = await _reference.layoutVersions();
      if (!mounted) return;
      setState(() {
        _sensorProfileIds = profiles;
        _layoutVersions = layouts;
        _sensorProfileId = profiles.first;
        _layoutVersion = layouts.first;
      });
      await _applySelection();
    } catch (_) {
      // Paketli veri okunamazsa varsayılanlarla (white_black, low) devam.
    }
  }

  /// Seçili sensor_profile'ı ve layout tarifini (yoğunluk) yükler.
  Future<void> _applySelection() async {
    try {
      final profile = await _reference.sensorProfile(_sensorProfileId);
      final recipe = await _reference.layoutRecipe(_layoutVersion);
      if (!mounted) return;
      setState(() {
        _sensorProfileRaw = profile.raw;
        _density = recipe.moduleDensity;
      });
    } catch (_) {
      // yüklenemedi: önceki değerler kalır.
    }
  }

  @override
  void dispose() {
    _productIdController.dispose();
    _productionDateController.dispose();
    super.dispose();
  }

  /// Python `_next_batch_no`: yerel klasördeki mevcut etiketleri tarayıp bir
  /// sonraki sıralı parti numarasını üretir — üretici parti no'yu elle
  /// girmiyor.
  ///
  /// Yerel depolamaya (path_provider) erişim başarısız olursa (ör. test
  /// ortamı, ya da henüz platform desteği kurulmamış bir hedef) SESSİZCE
  /// vazgeçer — ekran çökmez, sadece parti no varsayılan ($_batchStart)
  /// kalır; kullanıcı "Etiketi oluştur"a bastığında GERÇEK hata orada
  /// (try/catch'li `_export`'ta) görünür.
  Future<void> _initBatchNo() async {
    try {
      final dir = await _ensureLabelsDir();
      var used = <int>[];
      if (await dir.exists()) {
        await for (final entry in dir.list()) {
          if (entry is! File) continue;
          final name = entry.uri.pathSegments.last;
          if (!name.startsWith(_batchPrefix) || !name.endsWith('.label_payload.json')) continue;
          final digits = name.substring(_batchPrefix.length).split('_').first;
          final n = int.tryParse(digits);
          if (n != null) used.add(n);
        }
      }
      final next = used.isEmpty ? _batchStart : (used.reduce((a, b) => a > b ? a : b) + 1);
      if (mounted) setState(() => _productIdController.text = '$_batchPrefix$next');
    } catch (_) {
      // bkz. yukarıdaki doküman notu — best-effort, sessiz vazgeçiş.
    }
  }

  Future<Directory> _ensureLabelsDir() async {
    if (_labelsDir != null) return _labelsDir!;
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/labels');
    await dir.create(recursive: true);
    _labelsDir = dir;
    return dir;
  }

  String _todayDdMmYyyy() {
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(now.day)}.${two(now.month)}.${now.year}';
  }

  void _resetProductionDate() {
    setState(() => _productionDateController.text = _todayDdMmYyyy());
  }

  /// Ekrandaki mevcut parti no'yu 1 artırır (Python `regenerate_batch_no`
  /// ile aynı fikir: diski YENİDEN taramak, iki tıklama arasında hiçbir şey
  /// değişmediyse aynı sayıyı verir, görünürde "çalışmıyor" gibi durur —
  /// bunun yerine ekrandaki sayıyı ilerletiyoruz; ilk değer hâlâ
  /// `_initBatchNo` ile diskten güvenle başlatılıyor).
  Future<void> _regenerateBatchNo() async {
    final current = int.tryParse(_productIdController.text.replaceFirst(_batchPrefix, ''));
    if (current != null) {
      setState(() => _productIdController.text = '$_batchPrefix${current + 1}');
    } else {
      await _initBatchNo();
    }
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

  /// Seçili profilin GERÇEK (paketli) JSON'u; henüz yüklenmediyse white_black.
  Map<String, dynamic> _sensorProfileStub() {
    return _sensorProfileRaw ??
        {
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
        _statePreviews = [];
        _outputFiles = {};
        _statusText = "Gri noktalar = reaktif sensör hücreleri. 'Etiketi oluştur' ile dosyaları üret.";
        _statusIsError = false;
      });
    } catch (ex) {
      setState(() {
        _previewVisible = true;
        _statusText = 'Geçersiz girdi: $ex';
        _statusIsError = true;
        _previewPngBytes = null;
        _meta = [];
        _statePreviews = [];
        _outputFiles = {};
      });
    }
  }

  Future<void> _export() async {
    setState(() => _exporting = true);
    try {
      final payload = label_export.buildLabelPayload(
        productId: _productIdController.text,
        productType: _productType,
        productionDate: _toIsoDate(_productionDateController.text),
        sensorProfileId: _sensorProfileId,
        layoutVersion: _layoutVersion,
      );
      final sensorProfile = _sensorProfileStub();
      final dir = await _ensureLabelsDir();
      final result = await label_export.exportLabel(
        payload,
        dir,
        density: _density,
        sensorProfile: sensorProfile,
      );

      final neutralBytes = await result.paths['png']!.readAsBytes();
      final calibrationCode =
          (sensorProfile['calibration_method'] as Map<String, dynamic>)['code'] as String;

      final statePreviews = <(String, Uint8List)>[];
      for (final key in const ['fresh', 'transition', 'spoiled']) {
        final bytes = await result.paths['state_$key']!.readAsBytes();
        statePreviews.add((_stateLabels[key]!, bytes));
      }

      setState(() {
        _previewVisible = true;
        _previewPngBytes = neutralBytes;
        _meta = [
          ('Parti no', payload.productId),
          ('QR versiyonu', 'v${result.label.qr.version}'),
          ('Matris', '${result.label.layout.matrixSize}'),
          ('Reaktif modül', '${result.label.layout.sensorModules.length}'),
          ('Yoğunluk', _density),
          ('Kalibrasyon', calibrationCode),
        ];
        _statePreviews = statePreviews;
        _outputFiles = {for (final e in result.paths.entries) e.key: e.value.path};
        _statusText = "Dosyalar '${dir.path}' altına yazıldı.";
        _statusIsError = false;
      });
      await _regenerateBatchNo();
    } catch (ex) {
      setState(() {
        _previewVisible = true;
        _statusText = 'Hata: $ex';
        _statusIsError = true;
      });
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  /// Rapor §8: "Basılabilir etiket PNG/PDF" — asıl fiziksel çıktı bu.
  /// Ham dosya yolu göstermek yerine (kullanıcı için anlamsız), yerel
  /// paylaşım/yazdırma sayfasını açar (AirDrop, e-posta, doğrudan yazıcı...).
  Future<void> _sharePdf() async {
    final path = _outputFiles['pdf'];
    if (path == null) return;
    await SharePlus.instance.share(
      ShareParams(files: [XFile(path)], text: 'FreshQR etiketi — ${_productIdController.text}'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final error = Theme.of(context).colorScheme.error;

    return AppScreen(
      title: 'Yönetici — Etiket Oluşturma',
      onBack: () => Navigator.of(context).pop(),
      actions: [
        IconButton(
          icon: const Icon(Icons.inventory_2_outlined),
          tooltip: 'Üretilen etiketler',
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LabelsScreen())),
        ),
      ],
      children: [
        SectionCard(
          title: 'Etiket bilgisi',
          children: [
            DropdownButtonFormField<String>(
              isExpanded: true,
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
                  onPressed: () => _regenerateBatchNo(),
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
              isExpanded: true,
              initialValue: _sensorProfileId,
              decoration: const InputDecoration(labelText: 'sensor_profile_id', prefixIcon: Icon(Icons.science)),
              items: [for (final p in _sensorProfileIds) DropdownMenuItem(value: p, child: Text(p))],
              onChanged: (v) async {
                setState(() => _sensorProfileId = v ?? _sensorProfileId);
                await _applySelection();
              },
            ),
            const SizedBox(height: AppSpacing.s),
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: _layoutVersion,
              decoration: const InputDecoration(labelText: 'layout_version', prefixIcon: Icon(Icons.grid_view)),
              items: [for (final l in _layoutVersions) DropdownMenuItem(value: l, child: Text(l))],
              onChanged: (v) async {
                setState(() => _layoutVersion = v ?? _layoutVersion);
                await _applySelection();
              },
            ),
            const SizedBox(height: AppSpacing.s),
            InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Layout yoğunluğu (layout_version tarifinden)',
                prefixIcon: Icon(Icons.tune),
              ),
              child: Text(_density),
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
                    label: Text(_exporting ? 'Oluşturuluyor…' : 'Etiketi oluştur'),
                    onPressed: _exporting ? null : _export,
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
                "Girdiğin bilgilere göre oluşan QR'ın canlı önizlemesi. Gri "
                'noktalar reaktif sensör hücrelerinin yerleşimini gösterir '
                '(henüz bir tazelik durumu değil).',
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
              if (_statePreviews.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.m),
                Text(
                  'Sentetik durumlar (§8)',
                  style: TextStyle(color: muted, fontSize: AppTextSizes.caption, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.s,
                  runSpacing: AppSpacing.s,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final entry in _statePreviews)
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 110,
                            height: 110,
                            child: Image.memory(entry.$2, fit: BoxFit.contain),
                          ),
                          Text(entry.$1, style: TextStyle(color: muted, fontSize: AppTextSizes.caption)),
                        ],
                      ),
                  ],
                ),
              ],
              if (_outputFiles.containsKey('pdf')) ...[
                const SizedBox(height: AppSpacing.m),
                OutlinedButton.icon(
                  icon: const Icon(Icons.ios_share),
                  label: const Text('Etiketi paylaş / yazdır (PDF)'),
                  onPressed: _sharePdf,
                ),
              ],
            ],
          ),
      ],
    );
  }
}
