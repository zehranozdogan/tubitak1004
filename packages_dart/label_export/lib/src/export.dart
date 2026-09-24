// packages/label_export/export.py'nin Dart portu — SADECE render-ÖNCESİ
// kısım.
//
// KAPSAM DIŞI (BİLİNÇLİ, render'a kadar): Python `export_label()` burada
// bittiği yerden DEVAM edip render.py'yi çağırıyordu — bu hem PNG/PDF/
// sentetik-durum rasterize'ı üretiyor HEM DE (kalibrasyon yöntemi
// 'white_black'/'qr_fixed_regions'/'algorithmic_white_balance' DIŞINDAYSA,
// ör. 'multicolor_patch'/'white_gray_black') `layout['reference_regions']`'a
// EKSTRA kenar referans yaması (gray/red/green/blue, §6.1 B/C) EKLEYİP
// layout'u YERİNDE değiştiriyordu — sonra TEKRAR `validate(layout, ...)`
// çağrılıyordu (bkz. export.py'deki "DİKKAT" yorumu). Bu render/CustomPainter
// portu HENÜZ Flutter tarafında yok (zehra yapıyor) — bu yüzden burada o
// mantık TAHMİN EDİLMEDİ/TEKRARLANMADI. Sonuç: `generateLabel()`'ın ürettiği
// `layout`, varsayılan referans bölgeleriyle (sadece finder white/black)
// GEÇERLİ bir layout_version'dur ama 'white_black'/'qr_fixed_regions'/
// 'algorithmic_white_balance' DIŞINDA bir kalibrasyon yöntemi kullanan bir
// sensor_profile için EKSİKTİR — render entegre olduğunda extra referans
// eklenip TEKRAR doğrulanmalı (Python'daki gibi).
//
// error='h' KARARI Python export.py'de de sabit (parametre DEĞİL) — burada
// da öyle bırakıldı.
//
// DOĞRULAMA: gerçek Python (`generate_qr`+`reactive_candidates`+
// `select_reactive_modules`+`build_layout`+`validate`) aynı payload/seed
// için çalıştırıldı — `seed`, `qr.version`, `qr.error`, `layout.matrix_size`
// VE seçilen reaktif hücre SAYISI (target — RNG'den ÖNCE, saf geometriden
// türeyen kısım) BİREBİR eşleşiyor; hangi HÜCRELERİN seçildiği RNG algoritma
// farkı yüzünden farklı (bkz. qr_layout/reactive.dart dosya başlığı, zaten
// belgeli mimari sapma) — bkz. test/export_test.dart.

import 'dart:convert';
import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:profile_schema/profile_schema.dart' as schema;
import 'package:qr_layout/qr_layout.dart' as qr_layout;

import 'pdf_export.dart';

/// Python `_payload_qr_text` — QR içine gömülecek KOMPAKT JSON metni.
/// `jsonEncode` zaten boşluksuz/kompakt üretir (Python'un
/// `separators=(",", ":")` ile AYNI biçim); alan sırası da `LabelPayload.
/// toJson()`'daki (ve Python `build_label_payload`'daki) sırayla AYNI.
String labelPayloadQrText(schema.LabelPayload payload) => jsonEncode(payload.toJson());

/// Python `export.build_label_payload`'ın portu: alanları normalize eder
/// (trim + product_type BÜYÜK HARF — Python ile AYNI kural) ve
/// `label_payload` şemasına göre doğrular (`LabelPayload.fromJson` üzerinden
/// — profile_schema'nın kendi doğrulamasıyla AYNI yol, tekrarlanmadı).
schema.LabelPayload buildLabelPayload({
  required String productId,
  required String productType,
  required String productionDate,
  required String sensorProfileId,
  required String layoutVersion,
}) {
  return schema.LabelPayload.fromJson({
    'product_id': productId.trim(),
    'product_type': productType.trim().toUpperCase(),
    'production_date': productionDate.trim(),
    'sensor_profile_id': sensorProfileId.trim(),
    'layout_version': layoutVersion.trim(),
  });
}

/// `generateLabel()`'ın sonucu — Python `export_label()`'ın döndürdüğü
/// `{"qr": qr, "layout": layout}`'ın (render-öncesi) karşılığı.
class GeneratedLabel {
  final schema.LabelPayload payload;
  final qr_layout.GeneratedQr qr;
  final schema.LayoutVersionData layout;

  /// `layout`'un ham (doğrulanmadan ÖNCEKİ/doğrulanmış) JSON haritası —
  /// `LayoutVersionData`'nın kendisi `toJson()` SUNMUYOR (profile_schema
  /// mimarisi: bu paket sadece OKUR/doğrular, geri YAZMAZ — bkz. o paketin
  /// README'si), bu yüzden dosyaya yazılacak/render'a verilecek ham harita
  /// burada AYRICA tutuluyor (Python'da zaten `layout` bir `dict`'ti).
  final Map<String, dynamic> layoutJson;

  const GeneratedLabel({required this.payload, required this.qr, required this.layout, required this.layoutJson});
}

/// Python `export_label()`'ın render-ÖNCESİ kısmının portu (bkz. dosya
/// başlığı). `seed=null` ise `payload.layoutVersion`'dan türetilir (Python
/// ile AYNI — aynı sürüm adı -> aynı reaktif hücre SAYISI/hedefi; HANGİ
/// hücrelerin seçildiği RNG farkı yüzünden Python'la eşleşmez, bkz. dosya
/// başlığı).
/// `exportLabel()`'ın sonucu — Python `export_label()`'ın döndürdüğü
/// `{"qr", "layout", "paths"}` sözlüğünün karşılığı.
class ExportedLabel {
  final GeneratedLabel label;
  final Map<String, File> paths;

  const ExportedLabel({required this.label, required this.paths});
}

/// Python `label_export/export.py::export_label()`'ın Dart portu — ARTIK
/// render (`qr_layout.renderLabelImage`) DAHİL, `generateLabel()`'daki
/// "render-öncesi" sınırı burada kalkıyor (bkz. o fonksiyonun dosya başlığı
/// notu — bu fonksiyon o notun "render entegre olunca" dediği adımdır).
///
/// `outDir`'i BU FONKSİYON İÇİNDE `path_provider` ile çözmüyoruz (o,
/// Flutter'a özel) — Python'daki gibi ÇAĞIRAN taraf hangi dizine
/// yazılacağını verir; bu paket bu yüzden hâlâ framework'ten (Flutter'dan)
/// bağımsız kalıyor, sadece saf `dart:io` kullanıyor.
///
/// Python sırası BİREBİR korunuyor: önce render (reference_regions'ı
/// gerekiyorsa YERİNDE günceller), SONRA layout_version.json yazılır —
/// tersi olursa dosyaya eksik/eski referans gider (bkz. Python export.py
/// "DİKKAT" yorumu).
Future<ExportedLabel> exportLabel(
  schema.LabelPayload payload,
  Directory outDir, {
  String density = 'low',
  int? seed,
  Map<String, dynamic>? sensorProfile,
}) async {
  await outDir.create(recursive: true);
  final generated = generateLabel(payload, density: density, seed: seed);

  final neutralImage = qr_layout.renderLabelImage(
    generated.qr,
    generated.layoutJson,
    sensorProfile,
    state: null,
  );
  final statePngs = qr_layout.syntheticStatesPngBytes(generated.qr, generated.layoutJson, sensorProfile);

  // Render sırasında reference_regions değişmiş olabilir (§6.1 B/C) —
  // diske yazmadan önce SON haliyle tekrar doğrula (Python export.py ile aynı).
  schema.LayoutVersionData.fromJson(generated.layoutJson);

  final stem = '${payload.productId}_${payload.layoutVersion}';
  final paths = <String, File>{
    'payload_json': File('${outDir.path}/$stem.label_payload.json'),
    'layout_json': File('${outDir.path}/$stem.layout_version.json'),
    'png': File('${outDir.path}/$stem.png'),
    'pdf': File('${outDir.path}/$stem.pdf'),
    'state_fresh': File('${outDir.path}/$stem.state_fresh.png'),
    'state_transition': File('${outDir.path}/$stem.state_transition.png'),
    'state_spoiled': File('${outDir.path}/$stem.state_spoiled.png'),
  };

  const encoder = JsonEncoder.withIndent('  ');
  await paths['payload_json']!.writeAsString(encoder.convert(payload.toJson()));
  await paths['layout_json']!.writeAsString(encoder.convert(generated.layoutJson));
  await paths['png']!.writeAsBytes(img.encodePng(neutralImage));
  await paths['pdf']!.writeAsBytes(labelPdfBytes(neutralImage));
  await paths['state_fresh']!.writeAsBytes(statePngs['fresh']!);
  await paths['state_transition']!.writeAsBytes(statePngs['transition']!);
  await paths['state_spoiled']!.writeAsBytes(statePngs['spoiled']!);

  return ExportedLabel(label: generated, paths: paths);
}

GeneratedLabel generateLabel(schema.LabelPayload payload, {String density = 'low', int? seed}) {
  final effectiveSeed = seed ?? qr_layout.seedFromLayoutVersion(payload.layoutVersion);

  final qr = qr_layout.generateQr(labelPayloadQrText(payload), error: 'h');
  final candidates = qr_layout.reactiveCandidatesForVersion(qr.version);
  final modules = qr_layout.selectReactiveModules(candidates, density: density, seed: effectiveSeed);
  final layoutJson = qr_layout.buildLayout(
    version: qr.version,
    eccLevel: qr.eccLevel,
    sensorModules: modules,
    layoutVersion: payload.layoutVersion,
    density: density,
  );
  final layout = schema.LayoutVersionData.fromJson(layoutJson);

  return GeneratedLabel(payload: payload, qr: qr, layout: layout, layoutJson: layoutJson);
}

/// OKUYUCU tarafı için: bir etiketin layout'unu (reaktif hücre konumları,
/// referans bölgeleri) `payload`'dan YENİDEN türetir — admin'in etiketi
/// basarken kullandığı `generateLabel` + `renderLabelImage` ile AYNI adımlar
/// (render, kalibrasyon yöntemi B/C ise `reference_regions`'a kenar
/// yamalarının konumunu yazar; görüntü atılır, sadece bu yan etki gerekli).
///
/// Neden var: karar 0005 (statik/paketli veri) tek başına yetmiyor — QR
/// boyutu payload uzunluğuna göre değiştiği için sabit bir layout dosyası
/// gerçek etiketlerle uyuşmaz. Bunun yerine paketli veri sadece "tarif"
/// (yoğunluk) tutar, hücreler `layout_version` seed'iyle her iki tarafta
/// AYNI Dart algoritmasıyla türetilir (bkz. apps/freshqr README, 24 Eylül).
GeneratedLabel resolveLabelLayout(
  schema.LabelPayload payload, {
  String density = 'low',
  Map<String, dynamic>? sensorProfile,
}) {
  final generated = generateLabel(payload, density: density);
  qr_layout.renderLabelImage(generated.qr, generated.layoutJson, sensorProfile, state: null);
  final layout = schema.LayoutVersionData.fromJson(generated.layoutJson);
  return GeneratedLabel(payload: payload, qr: generated.qr, layout: layout, layoutJson: generated.layoutJson);
}
