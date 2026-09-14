"""QR içeriğini görüntüden çözer (rapor §11 Aşama A: sanal QR dayanıklılık testi).

OpenCV'nin QRCodeDetector'ı kullanılır. `packages.color_engine.pipeline`'ın
1. adımı da (§6.2: "QR/etiket tespiti ve köşe koordinatları") aynı
mekanizmayı kullanacak — bu modül o entegrasyonun da başlangıç noktasıdır.

NOT: `detectAndDecode` (TEKİL) kullanılır, `detectAndDecodeMulti` DEĞİL —
tek QR içeren görüntülerde çoklu-QR modu güvenilir sonuç vermeyebiliyor
(bu dosya yazılırken elle doğrulandı).
"""

from __future__ import annotations

from typing import Any


def decode_qr_image(image: Any) -> str | None:
    """PIL.Image ya da BGR numpy dizisinden QR metnini çözer.

    Okunamazsa None döner (hata fırlatmaz) — çağıran taraf bunu §7.1'deki
    "Yeniden tara" durumu gibi ele alabilir.
    """
    import cv2
    import numpy as np

    if hasattr(image, "convert"):  # PIL.Image
        array = np.array(image.convert("RGB"))[:, :, ::-1]  # RGB -> BGR
    else:
        array = image

    detector = cv2.QRCodeDetector()
    text, _points, _ = detector.detectAndDecode(array)
    return text or None
