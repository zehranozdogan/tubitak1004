"""QR içeriğini görüntüden çözer (rapor §11 Aşama A: sanal QR dayanıklılık testi).

`packages.color_engine.pipeline`'ın 1. adımı da (§6.2: "QR/etiket tespiti ve
köşe koordinatları") aynı mekanizmayı kullanacak — bu modül o
entegrasyonun da başlangıç noktasıdır.

DEDEKTÖR SEÇİMİ (elle karşılaştırıldı, tests/synthetic/benchmark_distortion.py):
`cv2.QRCodeDetectorAruco` kullanılır, TEMEL `cv2.QRCodeDetector` DEĞİL.
Temel dedektör 45° görüntüleme açısında %0 başarılıydı (köşe/finder-pattern
tespiti bozuluyor); ArUco tabanlı dedektör kendi içinde daha güçlü köşe
tespiti yapıyor ve aynı 45° testlerinde başarılı oldu — ek bağımlılık
gerekmiyor, aynı opencv-python-headless paketinde geliyor.

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
    import cv2
    import numpy as np

    if hasattr(image, "convert"):  # PIL.Image
        array = np.array(image.convert("RGB"))[:, :, ::-1]  # RGB -> BGR
    else:
        array = image

    detector = cv2.QRCodeDetectorAruco()
    result = detector.detectAndDecode(array)
    text = result[0]
    return text or None
