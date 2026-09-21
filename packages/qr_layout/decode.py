"""QR içeriğini görüntüden çözer (rapor §11 Aşama A: sanal QR dayanıklılık testi).

`packages.color_engine.pipeline`'ın 1. adımı da (§6.2: "QR/etiket tespiti ve
köşe koordinatları") aynı mekanizmayı kullanacak — bu modül o
entegrasyonun da başlangıç noktasıdır.

DEDEKTÖR SEÇİMİ — ÜÇLÜ DEDEKTÖR (§11 Aşama A: "en az iki decoder", 21
Eylül'de üçüncüye çıkarıldı):
Önce `cv2.QRCodeDetectorAruco` denenir (sentetik 45° açı testinde,
tests/synthetic/benchmark_distortion.py, temel dedektör %0 iken bu %67
başarılıydı). AMA gerçek bir ekran fotoğrafıyla elle test edildiğinde
(2026-09-16) roller TERS döndü: ArUco köşeleri buldu ama metni ÇÖZEMEDİ,
temel `cv2.QRCodeDetector` ise aynı fotoğrafı sorunsuz okudu — muhtemelen
moiré deseni (ekran piksel ızgarası + kamera sensörü çakışması) ArUco'nun
iç işaretçi tespitini bozuyor. Sentetik testler bunu YAKALAYAMADI; bu da
gerçek cihaz testinin (§11 Aşama B) neden atlanamayacağının somut kanıtı.

ÜÇÜNCÜ dedektör (pyzbar/zbar, GERÇEK bir fotoğrafla bulundu, 21 Eylül):
her iki cv2 dedektörü de (Aruco/temel) bir fotoğrafta köşeleri buluyor ama
metni ÇÖZEMİYORDU (`quality_score`=1.0 — net, parlamasız, iyi ışıklı bir
fotoğraftı, kamera kalitesiyle ilgili değildi). pyzbar ham görüntüde de
başarısızdı; SADECE Otsu eşiklemesiyle (gri tonlama + `cv2.threshold(...,
THRESH_OTSU)`) ön işlendiğinde çözebildi — muhtemelen zbar'ın ikili
(binary) modül sınırı tespiti, cv2'nin kullandığı yönteme göre farklı bir
kontrast/gürültü profiline daha dayanıklı. Otsu ön işleme cv2 dedektörlerini
GEREKSİZ KILMIYOR (elle test edildi: aynı ön işlemeyle pyzbar, cv2'nin
kolayca çözdüğü bir fotoğrafı çözemedi) — üçü birbirini TAMAMLIYOR, biri
diğerinin yerini almıyor.

NOT: `detectAndDecode` (TEKİL) kullanılır, `detectAndDecodeMulti` DEĞİL —
tek QR içeren görüntülerde çoklu-QR modu güvenilir sonuç vermeyebiliyor
(bu dosya yazılırken elle doğrulandı, ilk denemede yanlış-negatif üretmişti).

NOT (pyzbar köşe sırası): zbar'ın `polygon` çıktısı ELLE doğrulanan gerçek
bir fotoğrafta [sol-üst, sol-alt, sağ-alt, sağ-üst] sırasındaydı (cv2'nin
[sol-üst, sağ-üst, sağ-alt, sol-alt] sırasından FARKLI) — bu yüzden
`_reorder_pyzbar_polygon` ile cv2 sırasına çevrilir. Bu sıralamanın HER
zbar sürümünde/görüntüde garanti olduğu doğrulanmadı; gerçek cihaz
testleriyle (rapor §11 Aşama B) daha fazla örnekle teyit edilecek.
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


def _reorder_pyzbar_polygon(polygon) -> Any:
    """zbar'ın [sol-üst, sol-alt, sağ-alt, sağ-üst] sırasını cv2'nin
    [sol-üst, sağ-üst, sağ-alt, sol-alt] (saat yönü) sırasına çevirir —
    bkz. modül docstring'indeki NOT."""
    import numpy as np

    pts = np.array([(p.x, p.y) for p in polygon], dtype=np.float32)
    return pts[[0, 3, 2, 1]]


def _decode_with_pyzbar(array: Any) -> tuple[str | None, Any]:
    """pyzbar/zbar ile dener — önce ham görüntüde, sonra Otsu eşiklemeli
    gri tonlamada (bkz. modül docstring'i, ikisi de gerekli: ikisi de
    kendi başına farklı bir fotoğraf sınıfını çözüyor)."""
    import cv2
    from pyzbar.pyzbar import decode as pyzbar_decode
    from PIL import Image

    gray = cv2.cvtColor(array, cv2.COLOR_BGR2GRAY)
    for candidate in (gray, cv2.threshold(gray, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)[1]):
        results = pyzbar_decode(Image.fromarray(candidate))
        if results:
            result = results[0]
            return (result.data.decode("utf-8"), _reorder_pyzbar_polygon(result.polygon))
    return (None, None)


def decode_qr_image_with_corners(image: Any) -> tuple[str | None, Any]:
    """`decode_qr_image` ile aynı, ama QR'ın 4 köşe piksel koordinatını da
    döndürür — `packages.color_engine.pipeline`'ın homografi adımı (§6.2/2)
    bunu kullanır. Köşe sırası: sol-üst, sağ-üst, sağ-alt, sol-alt (saat
    yönünde) — elle doğrulandı (üç dedektörde de aynı sıraya normalize edilir).

    Sırasıyla: ArUco tabanlı dedektör, temel cv2 dedektörü, pyzbar/zbar
    (yukarıdaki modül notuna bkz.) — ilk başarılı olan döner.

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

    return _decode_with_pyzbar(array)
