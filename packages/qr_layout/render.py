"""QR / etiket görsel çıktısı (rapor §8: basılabilir PNG/PDF + sentetik durumlar).

save_png / save_pdf / png_bytes : düz siyah-beyaz QR (segno, basılabilir dosya).
render_colored_image ve türevleri : reaktif hücrelerin RENKLİ gösterimi (Pillow) —
    her modülün açık/koyu sınıfı korunur ki QR hâlâ okunabilir kalsın (§5.2/3).
"""

from __future__ import annotations

from pathlib import Path

from packages.qr_layout.colors import (
    EDGE_PATCH_MARGIN,
    EDGE_PATCH_SIZE,
    EDGE_REFERENCE_COLORS,
    GRAY_REFERENCE_RGB,
    edge_gray_patch_position,
    edge_patch_positions,
    module_color,
    module_pixel_center,
)
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

    `layout['intentional_errors']` (rapor §5.2/4) listesindeki modüller
    GERÇEK bitlerinin TERSİYLE render edilir — QR'ın hata düzeltmesi (ECC)
    bunu telafi etmesi beklenir (bkz. reactive.select_intentional_errors).

    Döner: PIL.Image.Image
    """
    from PIL import Image, ImageDraw

    matrix = module_matrix(qr)
    n = len(matrix)
    sensor_set = {tuple(rc) for rc in layout.get("sensor_modules", [])}
    error_set = {tuple(rc) for rc in layout.get("intentional_errors", [])}

    size = (n + 2 * border) * scale
    img = Image.new("RGB", (size, size), "white")
    draw = ImageDraw.Draw(img)

    for r in range(n):
        for c in range(n):
            bit = matrix[r][c]
            if (r, c) in error_set:
                bit = 1 - bit  # kasıtlı hata: gerçek bitin tersini göster
            color = module_color(bit, (r, c) in sensor_set, state)
            x0 = (c + border) * scale
            y0 = (r + border) * scale
            draw.rectangle([x0, y0, x0 + scale - 1, y0 + scale - 1], fill=color)

    return img


def render_with_edge_gray_patch(qr, layout: dict, *, state: str | None = None, scale: int = 10, border: int = 4):
    """`render_colored_image` gibi, ama QR'ın DIŞINDA (zorunlu quiet zone'un
    da dışında) ek bir gri referans yaması basar — rapor §5.2/5'in "QR içinde
    VEYA etiket kenarında" alternatiflerinden ikincisi (bkz. colors.py'deki
    EDGE_PATCH_* sabitleri ve edge_gray_patch_position).

    `border` burada hâlâ GERÇEK/zorunlu quiet zone'un genişliği; yama için
    ek `EDGE_PATCH_MARGIN` modül otomatik eklenir (yani QR'ın zorunlu
    bölgeleri, §5.1, hiç değişmez — sadece etiket biraz daha büyür).

    Döner: (PIL.Image.Image, yamanın sanal (satır, sütun) konumu). Konumu
    `layout['reference_regions']['gray']`'e yazman gerekir ki okuyucu
    hard-code etmesin (§10.1).
    """
    total_border = border + EDGE_PATCH_MARGIN
    img = render_colored_image(qr, layout, state=state, scale=scale, border=total_border)

    from PIL import ImageDraw

    n = len(module_matrix(qr))
    patch_row, patch_col = edge_gray_patch_position(n, border=border)
    cy, cx = module_pixel_center(patch_row, patch_col, scale=scale, border=total_border)
    half = (EDGE_PATCH_SIZE * scale) // 2

    draw = ImageDraw.Draw(img)
    draw.rectangle([cx - half, cy - half, cx + half - 1, cy + half - 1], fill=GRAY_REFERENCE_RGB)

    return img, (patch_row, patch_col)


def render_with_edge_reference_patches(
    qr, layout: dict, *, state: str | None = None, scale: int = 10, border: int = 4,
    colors: dict | None = None,
):
    """`render_with_edge_gray_patch`'in genellenmişi — TEK gri yerine,
    çoklu FARKLI renkte referans yaması basar (rapor §6.1 C: "3x3/çok
    renkli düzeltme matrisi" — `calibration.multicolor_patch`, >=4 nokta
    gerektirir; QR'ın kendi beyaz/siyahıyla birlikte bu >=2 ek renk yeterli).

    Tek grinin (§6.1 B) YETERSİZLİĞİ elle ölçüldü: aynı grinin birden fazla
    noktadan örneklenip ortalanması işe yaramadı (tests/device/results_
    2026-09-17.md) — gerekli olan aynı rengin tekrarı değil, FARKLI
    renklerdi. Bu fonksiyon onu sağlar.

    `colors`: {isim: (r,g,b)} — None ise `colors.EDGE_REFERENCE_COLORS`.

    Döner: (PIL.Image.Image, {isim: (satır, sütun), ...}).
    """
    colors = colors if colors is not None else EDGE_REFERENCE_COLORS
    total_border = border + EDGE_PATCH_MARGIN
    img = render_colored_image(qr, layout, state=state, scale=scale, border=total_border)

    from PIL import ImageDraw

    n = len(module_matrix(qr))
    positions = edge_patch_positions(n, border=border, colors=colors)
    half = (EDGE_PATCH_SIZE * scale) // 2

    draw = ImageDraw.Draw(img)
    for name, (row, col) in positions.items():
        cy, cx = module_pixel_center(row, col, scale=scale, border=total_border)
        draw.rectangle([cx - half, cy - half, cx + half - 1, cy + half - 1], fill=colors[name])

    return img, positions


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
