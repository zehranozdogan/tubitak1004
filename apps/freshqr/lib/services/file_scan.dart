// Üretilmiş bir etiketin sentetik durum görselini (state_fresh/transition/
// spoiled.png) GERÇEK okuyucu zincirinden geçirir — kamerasız. Python
// `user_view.py::on_file_scan`'in karşılığı. Etiket detay ekranındaki
// "… test et" düğmeleri bunu çağırır.
//
// 7 EKİM: QR ARTIK GERÇEKTEN ÇÖZÜLÜYOR.
//
// Eskiden bu yol kod çözmeyi ATLIYORDU: QR metni yanındaki
// label_payload.json'dan okunuyor, köşeler de aranmak yerine
// `canonicalQrCorners` ile VARSAYILIYORDU. Gerekçe, analiz zincirini
// decoder'dan bağımsız test etmekti — ama bu varsayımın gerçek bir bedeli
// oldu: B/C etiketleri kenar yaması yüzünden border=8 ile basılırken kod
// border=4 varsayıyordu ve TÜM modüller 4 modül kaymış yerden okunuyordu
// (bkz. 4 Ekim, commit 538b78d). Köşeler gerçekten tespit edilseydi o hata
// sınıfı hiç oluşamazdı.
//
// Artık "Cihazdan Fotoğraf Yükle" ile AYNI yol kullanılıyor
// (`analyzePickedImagePath`): kod çözme (ML Kit -> zxing2 yedeği), finder
// noktalarından köşe kestirimi, profil yükleme, layout yeniden türetme,
// kalibrasyon, ΔE — hepsi gerçek. Varsayım kalmadı, kod yolu tekleşti.

import 'dart:io';

import '../data/reference_data.dart';
import 'scan_service.dart';
import 'static_image_scan.dart';

Future<ScanOutcome> scanStoredLabel({
  required Directory dir,
  required String stem,
  required String state,
  required ReferenceData reference,
}) async {
  final pngFile = File('${dir.path}/$stem.state_$state.png');
  if (!await pngFile.exists()) return ScanInvalidQr('Görsel yok: $stem.state_$state.png');
  return analyzePickedImagePath(pngFile.path, reference);
}
