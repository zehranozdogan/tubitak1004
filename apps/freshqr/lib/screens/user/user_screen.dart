// consumer/views/user_view.py'nin Dart portu — tarama + sonuç akışı
// (rapor §7). Python'daki tek-sayfa içerik-değişimi (Flet 0.86 routing
// kısıtı) yerine burada gerçek Flutter State + IndexedStack-benzeri bir
// switch kullanıldı (Flutter'da routing zaten var, o kısıtlama YOK).
//
// UI-FIRST (bkz. proje kararı, 23 Eylül): kamera/gerçek color_engine
// bağlantısı YOK — "Tazelik Tara" ve test senaryoları mock_results.dart'taki
// GERÇEK ColorEngineResult tipiyle kurulmuş sabit verileri gösterir.
// Kamera entegrasyonu geldiğinde yalnızca `_runScan` çağrılarının kaynağı
// değişecek (mock -> analyzeFrame()), akış/ekranlar AYNI kalacak.

import 'package:color_engine/color_engine.dart';
import 'package:flutter/material.dart';

import '../../widgets/app_screen.dart';
import 'mock_results.dart';
import 'widgets/invalid_qr_view.dart';
import 'widgets/permission_denied_view.dart';
import 'widgets/result_view.dart';
import 'widgets/scan_view.dart';

enum _ViewState { scan, result, permissionDenied, invalidQr }

class UserScreen extends StatefulWidget {
  const UserScreen({super.key});

  @override
  State<UserScreen> createState() => _UserScreenState();
}

class _UserScreenState extends State<UserScreen> {
  _ViewState _view = _ViewState.scan;
  ColorEngineResult? _result;
  LabelInfo? _labelInfo;

  void _showScan() => setState(() => _view = _ViewState.scan);

  void _runScan(ColorEngineResult result, [LabelInfo labelInfo = mockLabelInfo]) {
    setState(() {
      _result = result;
      _labelInfo = labelInfo;
      _view = _ViewState.result;
    });
  }

  void _showPermissionDenied() => setState(() => _view = _ViewState.permissionDenied);

  void _showInvalidQr() => setState(() => _view = _ViewState.invalidQr);

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
      _ViewState.scan => ScanView(onScan: () => _runScan(mockOk), testScenarios: testScenarios),
      _ViewState.result => ResultView(result: _result!, labelInfo: _labelInfo!, onRescan: _showScan),
      _ViewState.permissionDenied => PermissionDeniedView(onRetry: _showScan),
      _ViewState.invalidQr => InvalidQrView(onRetry: _showScan),
    };

    return AppScreen(
      title: 'Tazelik',
      onBack: () => Navigator.of(context).pop(),
      children: [body],
    );
  }
}
