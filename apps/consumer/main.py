"""Tüketici prototipi girişi.

    pip install -r requirements.txt
    flet run -w apps/consumer/main.py        # tarayıcıda (localhost)
    # veya masaüstü penceresi:  flet run apps/consumer/main.py
"""

import sys
from pathlib import Path

# repo kökü + app dizini + üretici dizini path'e -> `packages/`, `consumer/`,
# `producer/` her yerden import edilir. "Yönetici" ekranı üretici formunu
# (apps/producer/producer/app.py::build_form) doğrudan kullanır.
_REPO_ROOT = Path(__file__).resolve().parents[2]
_APP_DIR = Path(__file__).resolve().parent
_PRODUCER_DIR = _REPO_ROOT / "apps" / "producer"
for _p in (str(_REPO_ROOT), str(_APP_DIR), str(_PRODUCER_DIR)):
    if _p not in sys.path:
        sys.path.insert(0, _p)

import flet as ft  # noqa: E402

from consumer.app import main  # noqa: E402

if __name__ == "__main__":
    ft.run(main)
