"""Geliştirme sırasında `apps/consumer` + `packages/` dahil TÜM repo'yu
hot-reload ile izlemek için sarmalayıcı.

`flet run -d -r <script>` yalnızca <script>'in bulunduğu dizini izler; gerçek
giriş noktamız apps/consumer/main.py olduğundan bu, packages/ altındaki
değişiklikleri (ui_kit, qr_layout, ...) KAÇIRIR. Bu dosya repo kökünde
olduğu için `-r` ile repo kökü tamamen izlenir.

Gerçek/kalıcı giriş noktası hâlâ apps/consumer/main.py'dir (README'de o
anlatılıyor); bu dosya yalnızca yerel geliştirme kolaylığıdır.

Kullanım:
    flet run -w -d -r --ignore-dirs .git,out,.venv,.pytest_cache,__pycache__,.flet \
        -p 8551 --host 127.0.0.1 dev_run.py
"""

import sys
from pathlib import Path

_REPO_ROOT = Path(__file__).resolve().parent
for _p in (str(_REPO_ROOT), str(_REPO_ROOT / "apps" / "consumer")):
    if _p not in sys.path:
        sys.path.insert(0, _p)

import flet as ft  # noqa: E402

from consumer.app import main  # noqa: E402

if __name__ == "__main__":
    ft.run(main)
