"""Standart QR üretimi (segno) ve reaktif hücre aday havuzunun çıkarılması."""

from __future__ import annotations

from packages.qr_layout.function_mask import function_mask, matrix_size


def generate_qr(payload: str, *, error: str = "h", version: int | None = None):
    """Standart bir QR üretir.

    error='h' -> ECC-H (rapor §5: prototipte yüksek hata düzeltme; dağıtılmış
    reaktif modüller için tampon sağlar). Dönen nesne segno.QRCode.
    """
    import segno

    qr = segno.make(payload, error=error, version=version, micro=False)
    if qr.version is None or isinstance(qr.version, str):
        raise ValueError("Micro QR desteklenmiyor; normal QR üretin.")
    return qr


def module_matrix(qr) -> list[list[int]]:
    """QR'ın 0/1 modül matrisi (quiet zone hariç)."""
    return [list(row) for row in qr.matrix]


def reactive_candidates(qr) -> list[tuple[int, int]]:
    """Reaktif hücre olabilecek (satır, sütun) modülleri: yalnızca data/ECC alanı.

    Rapor §5.2/2: adaylar yalnızca izin verilen data/ECC modüllerinden seçilir.
    """
    version = qr.version
    n = matrix_size(version)
    mask = function_mask(version)
    return [(r, c) for r in range(n) for c in range(n) if not mask[r][c]]
