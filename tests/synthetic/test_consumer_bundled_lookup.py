"""docs/decisions/0005: tüketici okuma akışı, ÜRETİCİNİN yerel `out/`
klasörüne değil, uygulamayla PAKETLENMİŞ (`profile_schema/examples/`)
referans dosyalarına bağımlı olmalı — bir yabancının telefonunda `out/`
zaten yok.

Bu dosya `user_view.py::on_file_scan`'in KENDİ MANTIĞINI (Flet UI'sız)
birebir tekrarlayarak, sadece QR'dan decode edilen payload + bundled
örnekler kullanılarak uçtan uca gerçek bir okuma yapılabildiğini kanıtlar.
"""

from __future__ import annotations

import json

import numpy as np
import pytest
from PIL import Image

cv2 = pytest.importorskip("cv2", reason="opencv-python-headless kurulu değil")

from packages.color_engine.pipeline import analyze  # noqa: E402
from packages.label_export import build_label_payload, export_label  # noqa: E402
from packages.profile_schema.loader import EXAMPLES_DIR, load_layout_version, load_sensor_profile  # noqa: E402
from packages.qr_layout.decode import decode_qr_image  # noqa: E402


def test_consumer_can_read_a_label_using_only_bundled_examples_and_qr_payload(tmp_path):
    """Etiketi `out_dir`'e (üreticinin yerel makinesi) export edip, okuma
    sırasında SADECE o klasörün DIŞINDaki bundled `EXAMPLES_DIR` + QR'dan
    decode edilen payload'ı kullanarak analiz edebilmeli — `out_dir`'in
    kendisine (layout_version.json'ına) bir yabancı telefon gibi HİÇ
    dokunmadan."""
    payload = build_label_payload(
        "TR-BUNDLE-1", "LEVREK", "2026-09-22", "GENIPIN_PUTRESIN_v2", "QR_SENSOR_v4",
    )
    # out_dir tmp_path — "üreticinin yerel makinesi", okuma sırasında BİLEREK kullanılmıyor.
    result = export_label(payload, tmp_path, density="low")

    img = Image.open(result["paths"]["state_fresh"])
    decoded = decode_qr_image(img)
    assert decoded is not None
    decoded_payload = json.loads(decoded)
    assert decoded_payload == payload

    # --- Buradan sonrası user_view.py::on_file_scan ile BİREBİR aynı yol,
    # ama `tmp_path`/`out_dir` yerine SADECE bundled EXAMPLES_DIR kullanıyor.
    layout_version = load_layout_version(
        EXAMPLES_DIR / f"{decoded_payload['layout_version']}.layout_version.json"
    )
    sensor_profile = load_sensor_profile(
        EXAMPLES_DIR / f"{decoded_payload['sensor_profile_id']}.sensor_profile.json"
    )

    array = np.array(img.convert("RGB"))[:, :, ::-1]
    out = analyze(array, sensor_profile, layout_version)

    assert out.rescan_recommended is False
    assert len(out.module_readings) == len(layout_version["sensor_modules"])


def test_unknown_layout_version_or_profile_id_raises_cleanly():
    """Bundled örnekler arasında olmayan bir sürüm/ID gelirse (ör. henüz
    uygulamaya paketlenmemiş yeni bir etiket) — sessizce yanlış bir dosya
    okumak yerine temiz bir hata vermeli (`on_file_scan` bunu yakalayıp
    "Geçersiz QR" ekranına düşürüyor, bkz. docs/decisions/0005)."""
    with pytest.raises(OSError):
        load_layout_version(EXAMPLES_DIR / "HENUZ_PAKETLENMEMIS_v99.layout_version.json")
