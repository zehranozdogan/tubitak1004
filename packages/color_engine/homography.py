"""Homografi ile canonical (düz, cepheden) koordinat sistemine hizalama
(rapor §6.2 adım 2).

QR köşe koordinatları (fotoğrafta, herhangi bir açı/perspektifte) ile
bilinen canonical hedef koordinatlar arasında bir perspektif dönüşüm
çözülür; tüm görüntü bu dönüşümle "düzleştirilir". Sonuç, etiket sanki
kameraya tam dik çekilmiş gibi bir görüntüdür —
`packages.qr_layout.colors.module_pixel_center` ile üretilen piksel
koordinatları bu canonical görüntüde DOĞRUDAN geçerlidir.
"""

from __future__ import annotations

from typing import Any

import cv2
import numpy as np

Image = np.ndarray


def canonical_size(matrix_size: int, *, scale: int = 10, border: int = 4) -> int:
    """Canonical (kare) görüntünün kenar uzunluğu (piksel)."""
    return (matrix_size + 2 * border) * scale


def canonical_qr_corners(matrix_size: int, *, scale: int = 10, border: int = 4) -> np.ndarray:
    """Canonical görüntüde QR'ın 4 köşesi (sol-üst, sağ-üst, sağ-alt, sol-alt).

    `packages.qr_layout.render`'daki rasterize kuralıyla AYNI:
    `x0 = (c + border) * scale` (§6.2 adım 1-2 arası tutarlılık).
    """
    n = matrix_size
    return np.array(
        [
            [border * scale, border * scale],
            [(n + border) * scale, border * scale],
            [(n + border) * scale, (n + border) * scale],
            [border * scale, (n + border) * scale],
        ],
        dtype=np.float32,
    )


def warp_to_canonical(
    image: Image,
    qr_corners: Any,
    *,
    matrix_size: int,
    scale: int = 10,
    border: int = 4,
) -> Image:
    """Fotoğraftaki QR köşelerinden canonical (düz) görüntüye perspektif düzeltme.

    `qr_corners`: (4,2) — sol-üst, sağ-üst, sağ-alt, sol-alt sırasında
    (bkz. `packages.qr_layout.decode.decode_qr_image_with_corners`).
    `matrix_size`: QR'ın modül cinsinden kenar uzunluğu (`layout_version.matrix_size`).
    """
    size = canonical_size(matrix_size, scale=scale, border=border)
    dst = canonical_qr_corners(matrix_size, scale=scale, border=border)
    src = np.asarray(qr_corners, dtype=np.float32).reshape(4, 2)
    transform = cv2.getPerspectiveTransform(src, dst)
    return cv2.warpPerspective(image, transform, (size, size))
