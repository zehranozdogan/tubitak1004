"""QR / etiket görsel çıktısı (rapor §8: basılabilir PNG/PDF).

segno saf-python PNG ve PDF yazabilir. Fiziksel 300 dpi ölçeklendirme ve
reaktif hücrelerin renkli gösterimi + sentetik taze/geçiş/bozulma görselleri
TODO (Pillow gerektirir).
"""

from __future__ import annotations

from pathlib import Path


def save_png(qr, path: str | Path, *, scale: int = 10, border: int = 4) -> Path:
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    qr.save(str(path), scale=scale, border=border)
    return path


def save_pdf(qr, path: str | Path, *, scale: int = 10, border: int = 4) -> Path:
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    qr.save(str(path), kind="pdf", scale=scale, border=border)
    return path


def png_bytes(qr, *, scale: int = 6, border: int = 2) -> bytes:
    """Önizleme için PNG baytları (ör. Flet ft.Image src_base64)."""
    import io

    buf = io.BytesIO()
    qr.save(buf, kind="png", scale=scale, border=border)
    return buf.getvalue()


def save_synthetic_states(qr, layout: dict, out_dir: str | Path):  # pragma: no cover
    """Rapor §8/§11: her renk durumunda (fresh/transition/spoiled) sentetik etiket.

    TODO: reaktif hücreleri layout['sensor_modules'] koordinatlarında
    ilgili renge boyayıp kaydet (Pillow). Şimdilik uygulanmadı.
    """
    raise NotImplementedError("Sentetik renk-durumu görselleri henüz uygulanmadı (Pillow gerekiyor).")
