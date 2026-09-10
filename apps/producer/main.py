"""Üretici uygulaması girişi.

    pip install -r requirements.txt
    flet run -w apps/producer/main.py        # tarayıcıda (localhost)
    # veya masaüstü penceresi:  flet run apps/producer/main.py
"""

import sys
from pathlib import Path

# repo kökünü + app dizinini path'e ekle ki `packages/` ve `producer/` görünür olsun
_REPO_ROOT = Path(__file__).resolve().parents[2]
_APP_DIR = Path(__file__).resolve().parent
for _p in (str(_REPO_ROOT), str(_APP_DIR)):
    if _p not in sys.path:
        sys.path.insert(0, _p)

import flet as ft  # noqa: E402

from packages.ui_kit import theme  # noqa: E402
from producer.app import build_view  # noqa: E402


def main(page: ft.Page) -> None:
    page.title = "FreshQR — Üretici"
    theme.apply_page(page)
    page.add(build_view(page))


if __name__ == "__main__":
    ft.run(main)
