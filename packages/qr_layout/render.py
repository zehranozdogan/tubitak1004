"""QR / etiket görsel çıktısı (rapor §8: basılabilir PNG/PDF + sentetik durumlar).

save_png / save_pdf / png_bytes : düz siyah-beyaz QR (segno, basılabilir dosya).
render_colored_image ve türevleri : reaktif hücrelerin RENKLİ gösterimi (Pillow) —
    her modülün açık/koyu sınıfı korunur ki QR hâlâ okunabilir kalsın (§5.2/3).
"""

from __future__ import annotations

from pathlib import Path

from packages.qr_layout.colors import module_color
from packages.qr_layout.generator import module_matrix


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
    """Önizleme için düz (siyah/beyaz) PNG baytları (ör. Flet ft.Image.src (base64))."""
    import io

    buf = io.BytesIO()
    qr.save(buf, kind="png", scale=scale, border=border)
    return buf.getvalue()


def render_colored_image(qr, layout: dict, *, state: str | None = None, scale: int = 10, border: int = 4):
    """QR'ı rasterize eder; layout['sensor_modules'] koordinatlarını `state`
    rengiyle (None ise nötr gri), geri kalanını standart siyah/beyaz çizer.

    Döner: PIL.Image.Image
    """
    from PIL import Image, ImageDraw

    matrix = module_matrix(qr)
    n = len(matrix)
    sensor_set = {tuple(rc) for rc in layout.get("sensor_modules", [])}

    size = (n + 2 * border) * scale
    img = Image.new("RGB", (size, size), "white")
    draw = ImageDraw.Draw(img)

    for r in range(n):
        for c in range(n):
            bit = matrix[r][c]
            color = module_color(bit, (r, c) in sensor_set, state)
            x0 = (c + border) * scale
            y0 = (r + border) * scale
            draw.rectangle([x0, y0, x0 + scale - 1, y0 + scale - 1], fill=color)

    return img


def colored_png_bytes(qr, layout: dict, *, state: str | None = None, scale: int = 6, border: int = 2) -> bytes:
    """Önizleme için renkli PNG baytları (ör. Flet ft.Image.src (base64))."""
    import io

    buf = io.BytesIO()
    render_colored_image(qr, layout, state=state, scale=scale, border=border).save(buf, format="PNG")
    return buf.getvalue()


def save_colored_png(
    qr, layout: dict, path: str | Path, *, state: str | None = None, scale: int = 10, border: int = 4
) -> Path:
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    render_colored_image(qr, layout, state=state, scale=scale, border=border).save(path)
    return path


def save_synthetic_states(
    qr, layout: dict, out_dir: str | Path, *, stem: str, scale: int = 10, border: int = 4
) -> dict[str, Path]:
    """Rapor §8/§11: her renk durumunda (fresh/transition/spoiled) sentetik etiket.

    QR dayanıklılık testleri (§11 Aşama A) bu görselleri ≥2 decoder ile
    okuyarak decode başarısını ölçecek.
    """
    out = Path(out_dir)
    paths: dict[str, Path] = {}
    for state in ("fresh", "transition", "spoiled"):
        p = out / f"{stem}.state_{state}.png"
        save_colored_png(qr, layout, p, state=state, scale=scale, border=border)
        paths[state] = p
    return paths
