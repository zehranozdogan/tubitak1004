// Canlı kamera önizlemesi + İKİ decoder: ML Kit (birincil, hızlı/donanım
// hızlandırmalı) ve saf-Dart zxing2 (yedek — rapor §11: "en az iki decoder").
// ML Kit ardışık `_fallbackAfterFailures` karede QR bulamazsa, AYNI karede
// ayrıca zxing2 denenir (bkz. qr_layout/decode.dart). ML Kit'in başarısız
// olduğu HER karede zxing2'yi de çalıştırmak yerine (renkli QR'ın RGB'ye
// çevrilmesi + tam decode denemesi ucuz değil) sadece "ML Kit zorlanıyor"
// sinyali alınca devreye giriyor — mutlu yolda (ML Kit hemen buluyorsa)
// hiç ekstra maliyet yok.
//
// SADECE Android/iOS: ML Kit başka platformu desteklemiyor (bkz.
// `cameraScanSupported`) — zxing2 platform bağımsız ama kamera erişimi
// zaten bu ikisine özel.
//
// GERÇEK CİHAZ HATASI (27 Eylül, ilk gerçek telefon testinde bulundu):
// Y/VU düzlemlerini ham bayt olarak art arda ekleyip (`_concatenatePlanes`)
// TEK bir `bytesPerRow` varsaymak, gerçek telefonlarda donanım hizalaması
// yüzünden satır dolgusu (padding, `bytesPerRow > width`) olduğunda ML
// Kit'te `PlatformException(InputImageConverterError)` fırlatıyordu —
// emülatörde/webcam-relay'de dolgu olmadığı için gizli kalmıştı. Düzeltme:
// `frame_convert.dart::repackNv21` (bkz. o dosyanın başlığı) her düzlemi
// KENDİ satır adımına göre okuyup dolgusuz, sıkı paketlenmiş bir tampon
// üretiyor — hem ML Kit'e hem `nv21ToRgbImage`'a artık `bytesPerRow: width`
// veriliyor.

import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:color_engine/color_engine.dart' show RgbImage;
import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:qr_layout/qr_layout.dart' show QrFinderPoints, decodeQrZxing;

import '../../../services/frame_convert.dart';
import '../../../theme/app_theme.dart';

bool get cameraScanSupported =>
    !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

class CameraCapture {
  final String qrText;
  final RgbImage image;
  // Tam olarak biri dolu: ML Kit yolunda `corners` (4 gerçek köşe), zxing2
  // yedek yolunda `finderPoints` (sadece finder merkezleri — gerçek köşe
  // `analyzeCapturedLabel` içinde, matrixSize bilinince kestirilir).
  final List<List<double>>? corners;
  final QrFinderPoints? finderPoints;

  const CameraCapture({required this.qrText, required this.image, this.corners, this.finderPoints})
      : assert((corners == null) != (finderPoints == null), 'corners ile finderPoints\'ten tam olarak biri verilmeli');
}

class CameraScanner extends StatefulWidget {
  final void Function(CameraCapture capture) onCapture;
  final VoidCallback onPermissionDenied;
  final void Function(String message) onError;

  const CameraScanner({super.key, required this.onCapture, required this.onPermissionDenied, required this.onError});

  @override
  State<CameraScanner> createState() => _CameraScannerState();
}

class _CameraScannerState extends State<CameraScanner> {
  // Her karede ML Kit çağırmak yerine her N karede bir (gereksiz CPU/pil).
  static const int _detectEveryNFrames = 3;
  // ML Kit bu kadar ardışık ÖRNEKLENEN karede QR bulamazsa (yaklaşık
  // 15*3/30fps ≈ 1.5sn), zxing2 de denenmeye başlanır (bkz. dosya başlığı).
  static const int _fallbackAfterFailures = 15;

  final BarcodeScanner _scanner = BarcodeScanner(formats: [BarcodeFormat.qrCode]);
  CameraController? _controller;
  int _frameCounter = 0;
  int _mlKitFailureStreak = 0;
  bool _busy = false;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    try {
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        widget.onPermissionDenied();
        return;
      }
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        widget.onError('Kamera bulunamadı.');
        return;
      }
      final camera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      // Renk okuması için çözünürlük önemli: 65+ modüllük bir QR'da düşük
      // çözünürlük modül başına birkaç piksel bırakır.
      final controller = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: defaultTargetPlatform == TargetPlatform.android
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _controller = controller);
      await controller.startImageStream(_onFrame);
    } catch (e) {
      widget.onError('Kamera başlatılamadı: $e');
    }
  }

  Future<void> _onFrame(CameraImage image) async {
    if (_busy || _done) return;
    _frameCounter++;
    if (_frameCounter % _detectEveryNFrames != 0) return;
    _busy = true;
    try {
      final controller = _controller;
      if (controller == null) return;
      final rotation = controller.description.sensorOrientation;
      final input = _toInputImage(image, rotation);
      if (input == null) return;

      final barcodes = await _scanner.processImage(input);
      for (final barcode in barcodes) {
        final text = barcode.rawValue;
        final points = barcode.cornerPoints;
        if (barcode.format != BarcodeFormat.qrCode || text == null || points.length != 4) continue;

        await _finish(
          controller,
          qrText: text,
          rgb: _frameToRgb(image, rotation),
          corners: [for (final p in points) [p.x.toDouble(), p.y.toDouble()]],
        );
        return;
      }

      // ML Kit bu karede bulamadı — yedek decoder devreye girene kadar sayacı ilerlet.
      _mlKitFailureStreak++;
      if (_mlKitFailureStreak < _fallbackAfterFailures) return;

      final rgbForZxing = _frameToRgb(image, rotation);
      final zx = decodeQrZxing(rgbToImgImage(rgbForZxing));
      if (zx != null && zx.finderPoints != null) {
        await _finish(controller, qrText: zx.text, rgb: rgbForZxing, finderPoints: zx.finderPoints);
      }
    } catch (e) {
      if (!_done && mounted) {
        _done = true;
        widget.onError('Tarama hatası: $e');
      }
    } finally {
      _busy = false;
    }
  }

  RgbImage _frameToRgb(CameraImage image, int rotation) {
    if (defaultTargetPlatform == TargetPlatform.android) {
      final nv21 = _nv21Data(image);
      return nv21ToRgbImage(nv21.bytes, image.width, image.height, bytesPerRow: nv21.bytesPerRow, rotation: rotation);
    }
    return bgraToRgbImage(
      image.planes.first.bytes,
      image.width,
      image.height,
      bytesPerRow: image.planes.first.bytesPerRow,
      rotation: rotation,
    );
  }

  Future<void> _finish(
    CameraController controller, {
    required String qrText,
    required RgbImage rgb,
    List<List<double>>? corners,
    QrFinderPoints? finderPoints,
  }) async {
    _done = true;
    await controller.stopImageStream();
    if (!mounted) return;
    widget.onCapture(CameraCapture(qrText: qrText, image: rgb, corners: corners, finderPoints: finderPoints));
  }

  @override
  void dispose() {
    _done = true;
    _controller?.dispose();
    _scanner.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final controller = _controller;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: SizedBox(
        height: 320,
        child: controller != null && controller.value.isInitialized
            ? CameraPreview(controller)
            : ColoredBox(color: scheme.secondaryContainer, child: const Center(child: CircularProgressIndicator())),
      ),
    );
  }
}

InputImage? _toInputImage(CameraImage image, int sensorOrientation) {
  final rotation = InputImageRotationValue.fromRawValue(sensorOrientation) ?? InputImageRotation.rotation0deg;
  final format = InputImageFormatValue.fromRawValue(image.format.raw);
  if (format == null) return null;

  if (defaultTargetPlatform == TargetPlatform.android && format == InputImageFormat.nv21) {
    final nv21 = _nv21Data(image);
    return InputImage.fromBytes(
      bytes: nv21.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: nv21.bytesPerRow,
      ),
    );
  }
  if (defaultTargetPlatform == TargetPlatform.iOS && format == InputImageFormat.bgra8888) {
    return InputImage.fromBytes(
      bytes: image.planes.first.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes.first.bytesPerRow,
      ),
    );
  }
  return null;
}

/// Android NV21 karesini (dosya başlığındaki notta açıklanan gerçek-cihaz
/// hatasına karşı) tek, tutarlı bir (bayt, satır-adımı) çiftine çevirir.
///
/// GERÇEK CİHAZ HATASI #2 (27 Eylül, aynı gün): `image.planes` cihaza göre
/// FARKLI sayıda eleman verebiliyor — bazı cihazlar Y ve VU'yu AYRI iki
/// `Plane` olarak verir (aşağıdaki `repackNv21` yolu), bazıları NV21'i
/// (Y+VU bitişik) TEK bir `Plane` olarak verir. İkinciyi de sabit
/// `image.planes[1]` ile okumaya çalışmak `RangeError` fırlatıyordu — bu
/// yüzden burada gerçek uzunluk kontrol ediliyor.
({Uint8List bytes, int bytesPerRow}) _nv21Data(CameraImage image) {
  if (image.planes.length < 2) {
    // Tek düzlem: Y+VU zaten bitişik TEK bir tamponda — `nv21ToRgbImage`
    // (ve ML Kit) bu düzlemin KENDİ satır adımını her iki bölüm için de
    // (Y ve VU) aynı kabul edip doğru okuyor, dolayısıyla yeniden
    // paketlemeye gerek yok.
    final plane = image.planes.first;
    return (bytes: plane.bytes, bytesPerRow: plane.bytesPerRow);
  }
  final y = image.planes[0];
  final vu = image.planes[1];
  final packed = repackNv21(y.bytes, y.bytesPerRow, vu.bytes, vu.bytesPerRow, image.width, image.height);
  return (bytes: packed, bytesPerRow: image.width); // repackNv21 dolgusuz (stride==width) üretir
}
