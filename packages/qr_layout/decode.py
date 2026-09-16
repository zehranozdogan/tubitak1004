"""QR içeriğini görüntüden çözer (rapor §11 Aşama A: sanal QR dayanıklılık testi).

`packages.color_engine.pipeline`'ın 1. adımı da (§6.2: "QR/etiket tespiti ve
köşe koordinatları") aynı mekanizmayı kullanacak — bu modül o
entegrasyonun da başlangıç noktasıdır.

DEDEKTÖR SEÇİMİ — ÇİFT DEDEKTÖR (§11 Aşama A: "en az iki decoder"):
Önce `cv2.QRCodeDetectorAruco` denenir (sentetik 45° açı testinde,
tests/synthetic/benchmark_distortion.py, temel dedektör %0 iken bu %67
başarılıydı). AMA gerçek bir ekran fotoğrafıyla elle test edildiğinde
(2026-09-16) roller TERS döndü: ArUco köşeleri buldu ama metni ÇÖZEMEDİ,
temel `cv2.QRCodeDetector` ise aynı fotoğrafı sorunsuz okudu — muhtemelen
moiré deseni (ekran piksel ızgarası + kamera sensörü çakışması) ArUco'nun
iç işaretçi tespitini bozuyor. Sentetik testler bunu YAKALAYAMADI; bu da
gerçek cihaz testinin (§11 Aşama B) neden atlanamayacağının somut kanıtı.
Bu yüzden artık FALLBACK zinciri var: ArUco başarısız olursa temel
dedektör denenir, o da başarısız olursa None döner.

NOT: `detectAndDecode` (TEKİL) kullanılır, `detectAndDecodeMulti` DEĞİL —
tek QR içeren görüntülerde çoklu-QR modu güvenilir sonuç vermeyebiliyor
(bu dosya yazılırken elle doğrulandı, ilk denemede yanlış-negatif üretmişti).
"""

from __future__ import annotations

from typing import Any


def decode_qr_image(image: Any) -> str | None:
    """PIL.Image ya da BGR numpy dizisinden QR metnini çözer.

    Okunamazsa None döner (hata fırlatmaz) — çağıran taraf bunu §7.1'deki
    "Yeniden tara" durumu gibi ele alabilir.
    """
    text, _corners = decode_qr_image_with_corners(image)
    return text


def decode_qr_image_with_corners(image: Any) -> tuple[str | None, Any]:
    """`decode_qr_image` ile aynı, ama QR'ın 4 köşe piksel koordinatını da
    döndürür — `packages.color_engine.pipeline`'ın homografi adımı (§6.2/2)
    bunu kullanır. Köşe sırası: sol-üst, sağ-üst, sağ-alt, sol-alt (saat
    yönünde) — elle doğrulandı (her iki dedektörde de aynı).

    Önce ArUco tabanlı dedektör denenir; o başarısız olursa (metin boş)
    temel dedektöre düşülür (yukarıdaki modül notuna bkz.).

    Döner: (metin ya da None, (4,2) numpy dizisi ya da None).
    """
    import cv2
    import numpy as np

    if hasattr(image, "convert"):  # PIL.Image
        array = np.array(image.convert("RGB"))[:, :, ::-1]  # RGB -> BGR
    else:
        array = image

    for detector in (cv2.QRCodeDetectorAruco(), cv2.QRCodeDetector()):
        text, points = detector.detectAndDecode(array)[:2]
        if text and points is not None and len(points) > 0:
            return (text, points.reshape(4, 2))
    return (None, None)
