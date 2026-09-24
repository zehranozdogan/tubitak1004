// Canlı kamera önizlemesi + ML Kit ile QR tespiti. Bir QR bulunca kareyi dik
// (rotation uygulanmış) RGB'ye çevirip metin + köşelerle birlikte verir;
// analiz zinciri (services/scan_service.dart) bunun dışında, saf Dart.
//
// SADECE Android/iOS: ML Kit başka platformu desteklemiyor (bkz.
// `cameraScanSupported`). Bu dosya gerçek cihazda henüz DENENMEDİ — saf
// parçalar (frame_convert) test edildi, kamera/ML Kit kısmı derleniyor ama
// cihaz doğrulaması bekliyor (README "kamera testi").

import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:color_engine/color_engine.dart' show RgbImage;
import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../services/frame_convert.dart';
import '../../../theme/app_theme.dart';

bool get cameraScanSupported =>
    !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

class CameraCapture {
  final String qrText;
  final RgbImage image;
  final List<List<double>> corners; // sol-üst, sağ-üst, sağ-alt, sol-alt (dik görüntüde)

  const CameraCapture({required this.qrText, required this.image, required this.corners});
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

  final BarcodeScanner _scanner = BarcodeScanner(formats: [BarcodeFormat.qrCode]);
  CameraController? _controller;
  int _frameCounter = 0;
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

        _done = true;
        await controller.stopImageStream();
        final rgb = defaultTargetPlatform == TargetPlatform.android
            ? nv21ToRgbImage(
                _concatenatePlanes(image.planes),
                image.width,
                image.height,
                bytesPerRow: image.planes.first.bytesPerRow,
                rotation: rotation,
              )
            : bgraToRgbImage(
                image.planes.first.bytes,
                image.width,
                image.height,
                bytesPerRow: image.planes.first.bytesPerRow,
                rotation: rotation,
              );
        if (!mounted) return;
        widget.onCapture(CameraCapture(
          qrText: text,
          image: rgb,
          corners: [for (final p in points) [p.x.toDouble(), p.y.toDouble()]],
        ));
        return;
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
    return InputImage.fromBytes(
      bytes: _concatenatePlanes(image.planes),
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes.first.bytesPerRow,
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

Uint8List _concatenatePlanes(List<Plane> planes) {
  final builder = BytesBuilder(copy: false);
  for (final plane in planes) {
    builder.add(plane.bytes);
  }
  return builder.toBytes();
}
