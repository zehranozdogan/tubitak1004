"""Tüketici prototipi girişi.

    pip install -r requirements.txt
    flet run -w apps/consumer/main.py        # tarayıcıda (localhost)
    # veya masaüstü penceresi:  flet run apps/consumer/main.py
"""

import sys
from pathlib import Path

# repo kökü + app dizini path'e -> `packages/` ve `consumer/` her yerden import edilir
_REPO_ROOT = Path(__file__).resolve().parents[2]
_APP_DIR = Path(__file__).resolve().parent
for _p in (str(_REPO_ROOT), str(_APP_DIR)):
    if _p not in sys.path:
        sys.path.insert(0, _p)

import flet as ft  # noqa: E402

from consumer.app import main  # noqa: E402

if __name__ == "__main__":
    ft.run(main)
