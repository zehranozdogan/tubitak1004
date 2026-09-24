// Kamera yerine, bu cihazda ÜRETİLMİŞ bir etiketin sentetik durum görselini
// (state_fresh/transition/spoiled.png) tüm okuyucu zincirinden geçirir —
// Python `user_view.py::on_file_scan`'in karşılığı. "Gerçekten çalışıyor mu"
// sorusunu kamerasız yanıtlar.
//
// QR DECODE ATLANIR: QR metni etiketin yanındaki label_payload.json'dan
// alınır (aynı `labelPayloadQrText` biçimiyle). Gerçek kamera akışında bu
// metin ML Kit'ten gelecek; geri kalan zincir (payload doğrulama, paketli
// profil/tarif, layout yeniden türetme, analyzeFrame) BİREBİR aynı kod.

import 'dart:io';

import 'package:color_engine/color_engine.dart' show canonicalQrCorners;
import 'package:image/image.dart' as img;
import 'package:label_export/label_export.dart' as label_export;
import 'package:profile_schema/profile_schema.dart' as schema;

import '../data/label_store.dart';
import '../data/reference_data.dart';
import 'scan_service.dart';

Future<ScanOutcome> scanStoredLabel({
  required Directory dir,
  required String stem,
  required String state,
  required ReferenceData reference,
}) async {
  final pngFile = File('${dir.path}/$stem.state_$state.png');
  if (!await pngFile.exists()) return ScanInvalidQr('Görsel yok: $stem.state_$state.png');

  final decoded = img.decodePng(await pngFile.readAsBytes());
  if (decoded == null) return const ScanInvalidQr('Görsel çözülemedi (PNG değil/bozuk)');

  final payloadJson = await readJson(File('${dir.path}/$stem.label_payload.json'));
  final layoutJson = await readJson(File('${dir.path}/$stem.layout_version.json'));
  final matrixSize = layoutJson['matrix_size'];
  if (payloadJson.isEmpty || matrixSize is! int) return const ScanInvalidQr('Etiket dosyaları eksik/bozuk');

  final String qrText;
  try {
    qrText = label_export.labelPayloadQrText(schema.LabelPayload.fromJson(payloadJson));
  } catch (e) {
    return ScanInvalidQr('label_payload geçersiz: $e');
  }

  return analyzeCapturedLabel(
    qrText: qrText,
    image: rgbImageFromImage(decoded),
    corners: canonicalQrCorners(matrixSize),
    reference: reference,
  );
}
