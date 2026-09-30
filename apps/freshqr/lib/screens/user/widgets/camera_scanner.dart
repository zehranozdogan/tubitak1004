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
// GERÇEK CİHAZ HATASI #4 (27 Eylül, aynı gün — #1/#2/#3 veri paketleme
// hatalarını düzeltmemize RAĞMEN devam etti): ML Kit'in kendi native
// dönüştürücüsü bu cihazda bir `NullPointerException` ile çöküyor
// (Play Services/ML Kit kurulumuna özgü olabilir, bizim kontrolümüzde
// değil). Çözüm: veriyi düzeltmeye çalışmak yerine SAVUNMACI ol —
// `_scanner.processImage` çökerse `_mlKitBroken=true` işaretlenir ve o
// karede DERHAL (15 kare beklemeden) zxing2'ye (saf Dart, ML Kit'in bu iç
// sorunundan tamamen bağımsız) düşülür; sonraki karelerde ML Kit HİÇ
// denenmez.
//
// #4'ÜN OLASI KÖK NEDENİ (29 Eylül, masabaşı araştırma — Google'ın kendi
// resmi "known issues" sayfası: developers.google.com/ml-kit/known-issues):
// "Task callback'leri, kaydedildikleri Activity/Fragment yok edildikten
// SONRA çalışabilir; bu, kapatılmış bir dedektöre erişmeye çalışırsa
// NullPointerException'a yol açabilir." Kodumuzda TAM bu senaryoya izin
// veren bir yarış durumu VARDI: `dispose()`, `_scanner.processImage()`
// hâlâ devam ederken (`_busy=true`) KONTROLSÜZ `_scanner.close()`
// çağırıyordu. Kullanıcı "Vazgeç"e basarsa (ya da ekrandan uzaklaşılırsa)
// ve o anda ML Kit hâlâ bir kareyi işliyorsa (ESKİ/ZAYIF bir cihazda bu
// saniyeler sürebilir — pencere ne kadar uzun açık kalırsa yarış o kadar
// olası, tam olarak eski/yavaş cihazlarda daha sık görülmesini açıklıyor),
// dispose native dedektörü kapatır, gecikmeli gelen sonuç kapatılmış
// dedektöre erişmeye çalışır. Düzeltme: `_mlKitCallInFlight` — devam eden
// bir `processImage()` çağrısı varsa, `_scanner.close()` o çağrı
// TAMAMLANANA kadar ertelenir (bkz. `dispose()`). Bu KANITLANMIŞ bir
// düzeltme değil (gerçek cihazda henüz doğrulanmadı) — ama Google'ın
// KENDİ belgelediği bir mekanizmayla BİREBİR eşleşen, kodumuzda GERÇEKTEN
// var olan bir yarış durumunu kapatıyor.
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
import 'package:image/image.dart' as img;
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
  // ML Kit bu karede çöktüyse (bkz. _onFrame) GERÇEK hata metni — teşhis
  // için: önceden yutuluyordu (`catch (_)`), "hiç çalışmadı" ötesinde bir
  // bilgi edinilemiyordu. corners doluysa (ML Kit başarılıysa) hep null.
  final String? mlKitError;

  const CameraCapture({
    required this.qrText,
    required this.image,
    this.corners,
    this.finderPoints,
    this.mlKitError,
  }) : assert((corners == null) != (finderPoints == null), 'corners ile finderPoints\'ten tam olarak biri verilmeli');
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
  // Devam eden bir `_scanner.processImage()` çağrısı varsa burada tutulur
  // — bkz. dosya başlığı "#4'ÜN OLASI KÖK NEDENİ": `dispose()` bunu görürse
  // `_scanner.close()`'u çağrı TAMAMLANANA kadar erteler.
  Future<List<Barcode>>? _mlKitCallInFlight;
  // ML Kit bu cihazda GERÇEKTEN çöküyorsa (bkz. _onFrame — Play Services/ML
  // Kit kurulumuna özgü bir NullPointerException gözlendi, 27 Eylül gerçek
  // cihaz testi) bir kere işaretlenir; sonraki karelerde ML Kit'i HİÇ
  // denemeden doğrudan zxing2'ye geçilir (gereksiz gecikme/tekrar çökme yok).
  bool _mlKitBroken = false;
  // GERÇEK hata metni (28 Eylül eklendi) — önceden `catch (_)` ile tamamen
  // yutuluyordu, "NullPointerException" ötesinde teşhis bilgisi yoktu.
  String? _mlKitError;
  bool _busy = false;
  bool _done = false;
  // zxing2'nin pahalı yedek katmanlarını (hafif-denoise + blok-kontrast-
  // germe, bkz. qr_layout/decode.dart "PERFORMANS UYARISI") CANLI kamerada
  // HER örneklenen karede denemek, ML Kit çöken bir cihazda (decodeQrZxing
  // o zaman HER karede çağrılıyor) görünür bir yavaşlamaya/takılmaya yol
  // açtı (zehra'nın telefonunda 29 Eylül'de gözlendi) — QR henüz kadraja
  // girmemişken bile 6 binarizer denemesinin TAMAMI her karede tüketiliyordu.
  // Artık sadece her `_thoroughZxingEveryNAttempts` zxing2 denemesinden
  // birinde pahalı katmanlar da denenir; aradaki karelerde SADECE hızlı
  // ham deneme yapılır (mutlu yolda -- QR zaten kadrajdaysa -- ekstra
  // maliyet yok, ham deneme genelde yeterli).
  static const int _thoroughZxingEveryNAttempts = 5;
  int _zxingAttemptCount = 0;
  // GERÇEK CİHAZ HATASI (30 Eylül, "kamera çok donuyor"): `thorough`
  // ortalama maliyeti düşürse de, HER örneklenen karede zxing2'ye TAM
  // ÇÖZÜNÜRLÜKLÜ (`ResolutionPreset.high`, gerçek cihazda 1280x720+ olabilir)
  // bir görüntü veriliyordu -- bu piksel-bazlı Dart döngüleri (NV21->RGB,
  // RGB->img.Image, zxing2'nin KENDİ binarizasyon/tarama işi) UI ile AYNI
  // isolate'te SENKRON çalışıyor; ne kadar hızlı olursa olsun bu iş UI
  // isolate'ini bloke ediyor -- "donma" ortalama hızdan değil, senkron
  // çalışmanın kendisinden kaynaklanıyor. Çözüm: zxing2 TESPİTİ için
  // görüntü küçük bir çalışma kopyasına indirgeniyor (`_zxingDetectionMaxDimension`)
  // -- QR TESPİTİ birkaç piksel/modül yeterliyken, RENK OKUMASI (bkz.
  // dosya başlığı "Renk okuması için çözünürlük önemli") hâlâ TAM
  // çözünürlüklü `rgbForZxing`'den yapılıyor, sadece bulunan köşeler ölçek
  // faktörüyle geri büyütülüyor (bkz. `_onFrame`). Bu, hem her karenin
  // piksel işi ~O(scale²) azaltıyor hem de daha az frame düşürülmesini
  // sağlıyor.
  static const int _zxingDetectionMaxDimension = 640;

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

      if (!_mlKitBroken) {
        try {
          final input = _toInputImage(image, rotation);
          if (input != null) {
            final call = _scanner.processImage(input);
            _mlKitCallInFlight = call;
            final List<Barcode> barcodes;
            try {
              barcodes = await call;
            } finally {
              _mlKitCallInFlight = null;
            }
            for (final barcode in barcodes) {
              final text = barcode.rawValue;
              // DOĞRULANMAMIŞ VARSAYIM (28 Eylül, bkz. proje notu): ML Kit'in
              // `cornerPoints`'inin sol-üst, sağ-üst, sağ-alt, sol-alt (saat
              // yönünde) sırasında olduğu varsayılıyor —
              // `color_engine.canonicalQrCorners`'ın beklediği AYNI sıra.
              // Google'ın ML Kit `Barcode.getCornerPoints()` dokümantasyonu
              // bunu böyle tanımlıyor, ama native (Android/iOS) tarafta
              // olduğu için bu repoda KAYNAKTAN doğrulanamıyor/test edilemiyor
              // — gerçek cihazda yanlış/döndürülmüş bir homografi görülürse
              // (ör. renk örnekleme sistematik olarak yanlış köşeden yapılıyor
              // gibi görünürse) BURASI ilk şüpheli.
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
          }
        } catch (e, st) {
          // ML Kit bu cihazda GERÇEKTEN çalışmıyor (dosya başlığındaki
          // gerçek-cihaz notuna bkz.) — beklemeden zxing2'ye geç, sonraki
          // karelerde ML Kit'i hiç denemeyelim. Hatayı ARTIK yutmuyoruz:
          // hem terminale/logcat'e (debugPrint) hem de _finish üzerinden
          // sonuç ekranındaki "Okuyucu" satırına taşınıyor (bkz. o dosya).
          _mlKitBroken = true;
          _mlKitError = e.toString();
          debugPrint('ML Kit processImage çöktü, zxing2\'ye geçiliyor: $e\n$st');
        }
      }

      final rgbForZxing = _frameToRgb(image, rotation);
      _zxingAttemptCount++;
      final thorough = _zxingAttemptCount % _thoroughZxingEveryNAttempts == 0;
      final fullImg = rgbToImgImage(rgbForZxing);
      final longestSide = fullImg.width > fullImg.height ? fullImg.width : fullImg.height;
      final detectionScale = longestSide > _zxingDetectionMaxDimension ? _zxingDetectionMaxDimension / longestSide : 1.0;
      final detectionImg = detectionScale == 1.0
          ? fullImg
          : img.copyResize(
              fullImg,
              width: (fullImg.width * detectionScale).round(),
              height: (fullImg.height * detectionScale).round(),
            );
      final zx = decodeQrZxing(detectionImg, thorough: thorough);
      if (zx != null && zx.finderPoints != null) {
        await _finish(
          controller,
          qrText: zx.text,
          rgb: rgbForZxing,
          // Tespit küçültülmüş bir kopyada yapıldıysa (bkz. yukarıdaki
          // "kamera çok donuyor" notu), köşeler TAM çözünürlüklü `rgb`'ye
          // (color_engine'in homografi/renk örneklemesi bunu kullanıyor)
          // göre ölçeklenmeli -- yoksa renk yanlış pikselden okunur.
          finderPoints: _scaleFinderPoints(zx.finderPoints!, 1 / detectionScale),
          mlKitError: _mlKitError,
        );
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
    String? mlKitError,
  }) async {
    _done = true;
    await controller.stopImageStream();
    if (!mounted) return;
    widget.onCapture(CameraCapture(
      qrText: qrText,
      image: rgb,
      corners: corners,
      finderPoints: finderPoints,
      mlKitError: mlKitError,
    ));
  }

  @override
  void dispose() {
    _done = true;
    _controller?.dispose();
    // Bkz. dosya başlığı "#4'ÜN OLASI KÖK NEDENİ": devam eden bir
    // processImage() çağrısı varsa, native dedektörü HEMEN kapatmak
    // Google'ın kendi belgelediği NullPointerException riskine yol
    // açabilir — kapatmayı o çağrı TAMAMLANANA (başarı ya da hata) kadar
    // ertele. `dispose()` senkron olmak zorunda, bu yüzden burada await
    // EDİLMİYOR (bilerek fire-and-forget).
    final pending = _mlKitCallInFlight;
    if (pending != null) {
      pending.then((_) => _scanner.close(), onError: (_) => _scanner.close());
    } else {
      _scanner.close();
    }
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

/// zxing2'nin küçültülmüş tespit kopyasında bulduğu köşeleri `factor`
/// (`1 / detectionScale`) ile TAM çözünürlüklü görüntüye geri ölçekler —
/// bkz. `_onFrame`'deki "kamera çok donuyor" notu.
QrFinderPoints _scaleFinderPoints(QrFinderPoints points, double factor) {
  ({double x, double y}) scale(({double x, double y}) p) => (x: p.x * factor, y: p.y * factor);
  final alignment = points.alignment;
  return QrFinderPoints(
    topLeft: scale(points.topLeft),
    topRight: scale(points.topRight),
    bottomLeft: scale(points.bottomLeft),
    alignment: alignment == null ? null : scale(alignment),
  );
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
/// hatasına karşı) her zaman DOLGUSUZ/sıkı paketlenmiş (stride==width) bir
/// (bayt, satır-adımı) çiftine çevirir.
///
/// GERÇEK CİHAZ HATASI #2 (27 Eylül, aynı gün): `image.planes` cihaza göre
/// FARKLI sayıda eleman verebiliyor — bazı cihazlar Y ve VU'yu AYRI iki
/// `Plane` olarak verir, bazıları NV21'i (Y+VU bitişik) TEK bir `Plane`
/// olarak verir. İkinciyi sabit `image.planes[1]` ile okumaya çalışmak
/// `RangeError` fırlatıyordu.
///
/// GERÇEK CİHAZ HATASI #3 (aynı gün, #2'nin düzeltmesi YETERSİZDİ): tek
/// düzlem durumunda "ham veriyi kendi satır adımıyla olduğu gibi ML Kit'e
/// ver" yeterli değilmiş — `InputImageConverterError` AYNEN devam etti.
/// Artık HER iki durumda da `repackNv21` ile dolgu temizleniyor; tek
/// düzlemde VU bölümü, Y bölümünün BİTTİĞİ bayt konumundan (`height *
/// bytesPerRow`) başlayan bir GÖRÜNÜM (`Uint8List.sublistView`, kopyasız)
/// olarak, Y ile AYNI satır adımıyla veriliyor (aynı bitişik tampon).
({Uint8List bytes, int bytesPerRow}) _nv21Data(CameraImage image) {
  final Uint8List yBytes;
  final int yStride;
  final Uint8List vuBytes;
  final int vuStride;
  if (image.planes.length >= 2) {
    yBytes = image.planes[0].bytes;
    yStride = image.planes[0].bytesPerRow;
    vuBytes = image.planes[1].bytes;
    vuStride = image.planes[1].bytesPerRow;
  } else {
    final plane = image.planes.first;
    yBytes = plane.bytes;
    yStride = plane.bytesPerRow;
    vuBytes = Uint8List.sublistView(plane.bytes, image.height * yStride);
    vuStride = yStride;
  }
  final packed = repackNv21(yBytes, yStride, vuBytes, vuStride, image.width, image.height);
  return (bytes: packed, bytesPerRow: image.width); // repackNv21 dolgusuz (stride==width) üretir
}
