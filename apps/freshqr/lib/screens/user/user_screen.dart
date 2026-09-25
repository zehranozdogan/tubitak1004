// consumer/views/user_view.py'nin Dart portu — tarama + sonuç akışı
// (rapor §7). Python'daki tek-sayfa içerik-değişimi (Flet 0.86 routing
// kısıtı) yerine burada gerçek Flutter State + IndexedStack-benzeri bir
// switch kullanıldı (Flutter'da routing zaten var, o kısıtlama YOK).
//
// Kamera+ML Kit/zxing2 gerçek; "Test senaryoları" mock_results.dart'taki
// GERÇEK ColorEngineResult tipiyle sabit verileri gösterir (BİLEREK geçmişe
// KAYDEDİLMEZ — bkz. data/scan_history.dart dosya başlığı). "Dosyadan test
// et" ve kamera taraması GERÇEK sonuç üretir — ikisi de tamamlanınca
// (rescanRecommended=false) geçmişe kaydedilir.

import 'dart:io';

import 'package:color_engine/color_engine.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/label_store.dart';
import '../../data/reference_data.dart';
import '../../data/scan_history.dart';
import '../../services/file_scan.dart';
import '../../services/scan_service.dart';
import '../../services/static_image_scan.dart';
import '../../widgets/app_screen.dart';
import 'mock_results.dart';
import 'widgets/camera_scanner.dart';
import 'widgets/invalid_qr_view.dart';
import 'widgets/permission_denied_view.dart';
import 'widgets/result_view.dart';
import 'widgets/scan_view.dart';

enum _ViewState { scan, camera, result, permissionDenied, invalidQr }

class UserScreen extends StatefulWidget {
  /// Test için enjekte edilebilir; null ise uygulama belge dizini/labels,
  /// scan_history.json ve rootBundle.
  final Directory? labelsDir;
  final File? historyFile;
  final ReferenceData? reference;

  const UserScreen({super.key, this.labelsDir, this.historyFile, this.reference});

  @override
  State<UserScreen> createState() => _UserScreenState();
}

class _UserScreenState extends State<UserScreen> {
  _ViewState _view = _ViewState.scan;
  ColorEngineResult? _result;
  LabelInfo? _labelInfo;
  List<StoredLabel> _storedLabels = const [];
  List<ScanHistoryEntry> _history = const [];
  Directory? _dir;
  File? _historyFile;
  bool _isAnalyzingPhoto = false;
  String? _invalidQrReason;
  late final ReferenceData _reference = widget.reference ?? ReferenceData();
  late final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadStoredLabels();
    _loadHistory();
  }

  Future<void> _loadStoredLabels() async {
    try {
      final dir = widget.labelsDir ?? await defaultLabelsDir();
      final labels = await loadLabels(dir);
      if (mounted) {
        setState(() {
          _dir = dir;
          _storedLabels = labels;
        });
      }
    } catch (_) {
      // Yerel depolama yok (ör. web): dosya testi kartı boş görünür.
    }
  }

  Future<void> _loadHistory() async {
    try {
      final file = widget.historyFile ?? await defaultScanHistoryFile();
      final history = await loadScanHistory(file);
      if (mounted) {
        setState(() {
          _historyFile = file;
          _history = history;
        });
      }
    } catch (_) {
      // Yerel depolama yok (ör. web): "Son okumalar" boş görünür.
    }
  }

  /// GERÇEK (mock DEĞİL) bir sonucu geçmişe kaydeder — SADECE tamamlanmış
  /// okumalar (bkz. data/scan_history.dart dosya başlığı).
  Future<void> _record(ColorEngineResult result, LabelInfo labelInfo) async {
    final file = _historyFile;
    if (file == null || result.rescanRecommended) return;
    try {
      final updated = await appendScanHistory(
        file,
        ScanHistoryEntry(
          productType: labelInfo.productType,
          productId: labelInfo.productId,
          when: DateTime.now(),
          freshnessClass: result.freshnessClass,
          technicalLevel: result.technicalLevel,
        ),
      );
      if (mounted) setState(() => _history = updated);
    } catch (_) {
      // Geçmiş yazılamadı — sonucu göstermeye engel değil, sessizce geç.
    }
  }

  Future<void> _fileScan(StoredLabel label, String state) async {
    final dir = _dir;
    if (dir == null) return;
    final outcome = await scanStoredLabel(dir: dir, stem: label.stem, state: state, reference: _reference);
    if (!mounted) return;
    switch (outcome) {
      case ScanSuccess(:final result, :final labelInfo):
        await _record(result, labelInfo);
        _runScan(result, labelInfo);
      case ScanInvalidQr(:final reason):
        _showInvalidQr(reason);
    }
  }

  void _showScan() => setState(() => _view = _ViewState.scan);

  /// "Tazelik Tara": Android/iOS'ta gerçek kamera; diğer platformlarda
  /// (web/masaüstü — ML Kit yok) eskisi gibi mock sonuç.
  void _startScan() {
    if (cameraScanSupported) {
      setState(() => _view = _ViewState.camera);
    } else {
      _runScan(mockOk);
    }
  }

  Future<void> _onCapture(CameraCapture capture) async {
    final outcome = await analyzeCapturedLabel(
      qrText: capture.qrText,
      image: capture.image,
      corners: capture.corners,
      finderPoints: capture.finderPoints,
      reference: _reference,
    );
    if (!mounted) return;
    switch (outcome) {
      case ScanSuccess(:final result, :final labelInfo):
        await _record(result, labelInfo);
        _runScan(result, labelInfo);
      case ScanInvalidQr(:final reason):
        _showInvalidQr(reason);
    }
  }

  void _runScan(ColorEngineResult result, [LabelInfo labelInfo = mockLabelInfo]) {
    setState(() {
      _result = result;
      _labelInfo = labelInfo;
      _view = _ViewState.result;
    });
  }

  /// "Cihazdan Fotoğraf Yükle": galeriden/dosyadan bir görsel seçip GERÇEK
  /// zincirden geçirir (bkz. services/static_image_scan.dart) — tüm
  /// platformlarda çalışır (kamera aksine).
  Future<void> _uploadPhoto() async {
    final XFile? picked;
    try {
      picked = await _picker.pickImage(source: ImageSource.gallery);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fotoğraf seçilemedi: $e')));
      }
      return;
    }
    if (picked == null) return; // kullanıcı vazgeçti

    setState(() => _isAnalyzingPhoto = true);
    try {
      final outcome = await analyzePickedImagePath(picked.path, _reference);
      if (!mounted) return;
      switch (outcome) {
        case ScanSuccess(:final result, :final labelInfo):
          await _record(result, labelInfo);
          _runScan(result, labelInfo);
        case ScanInvalidQr(:final reason):
          _showInvalidQr(reason);
      }
    } finally {
      if (mounted) setState(() => _isAnalyzingPhoto = false);
    }
  }

  void _showPermissionDenied() => setState(() => _view = _ViewState.permissionDenied);

  void _showInvalidQr([String? reason]) => setState(() {
    _invalidQrReason = reason;
    _view = _ViewState.invalidQr;
  });

  @override
  Widget build(BuildContext context) {
    final testScenarios = <(String, VoidCallback)>[
      ('Taze', () => _runScan(mockFresh)),
      ('Geçiş', () => _runScan(mockTransition)),
      ('Bozuk', () => _runScan(mockSpoiled)),
      ('Düşük kalite', () => _runScan(mockRescan)),
      ('İzin yok', _showPermissionDenied),
      ('Geçersiz QR', _showInvalidQr),
    ];

    final Widget body = switch (_view) {
      _ViewState.scan => ScanView(
        onScan: _startScan,
        testScenarios: testScenarios,
        storedLabels: _storedLabels,
        onFileScan: _fileScan,
        recentReads: _history,
        onUploadPhoto: _uploadPhoto,
        isAnalyzingPhoto: _isAnalyzingPhoto,
      ),
      _ViewState.camera => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CameraScanner(
            onCapture: _onCapture,
            onPermissionDenied: _showPermissionDenied,
            onError: (message) => _showInvalidQr(message),
          ),
          const SizedBox(height: 16),
          OutlinedButton(onPressed: _showScan, child: const Text('Vazgeç')),
        ],
      ),
      _ViewState.result => ResultView(result: _result!, labelInfo: _labelInfo!, onRescan: _showScan),
      _ViewState.permissionDenied => PermissionDeniedView(onRetry: _showScan),
      _ViewState.invalidQr => InvalidQrView(onRetry: _showScan, reason: _invalidQrReason),
    };

    return AppScreen(
      title: 'Tazelik',
      onBack: () => Navigator.of(context).pop(),
      children: [body],
    );
  }
}
