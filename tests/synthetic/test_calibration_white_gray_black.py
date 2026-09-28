"""white_gray_black() kalibrasyon yöntemi testleri (rapor §6.1 B)."""

import numpy as np

from packages.color_engine.calibration import get, white_black, white_gray_black


def test_white_gray_black_maps_references_to_targets():
    white_ref = (235, 235, 235)
    gray_ref = (120, 120, 120)
    black_ref = (20, 20, 20)
    image = np.array([[white_ref, gray_ref, black_ref]], dtype=np.uint8)

    references = {"white": white_ref, "gray": gray_ref, "black": black_ref}
    corrected = white_gray_black(image, references)

    assert np.allclose(corrected[0, 0], [255, 255, 255], atol=2)
    assert np.allclose(corrected[0, 1], [128, 128, 128], atol=3)
    assert np.allclose(corrected[0, 2], [0, 0, 0], atol=2)


def test_white_gray_black_beats_white_black_on_nonlinear_camera_response():
    """Kameranın tepkisi doğrusal değil de GAMA eğrisi (üs fonksiyonu)
    şeklindeyse, yalnızca iki uçtan (A) türetilen düz çizgi orta tonlarda
    büyük hata yapar; üçüncü (gri) referans noktası bu eğriyi yakalayıp
    hatayı belirgin biçimde azaltmalı."""
    black_cam, white_cam, camera_gamma = 20.0, 235.0, 1.8

    def captured(true_val: float) -> float:
        return black_cam + (white_cam - black_cam) * ((true_val / 255.0) ** camera_gamma)

    gray_cam = captured(128.0)
    true_test_value = 180.0
    test_cam = round(captured(true_test_value))

    white_ref = (white_cam,) * 3
    black_ref = (black_cam,) * 3
    gray_ref = (gray_cam,) * 3
    image = np.array([[[test_cam, test_cam, test_cam]]], dtype=np.uint8)

    corrected_a = white_black(image, {"white": white_ref, "black": black_ref})
    corrected_b = white_gray_black(image, {"white": white_ref, "gray": gray_ref, "black": black_ref})

    error_a = abs(float(corrected_a[0, 0, 0]) - true_test_value)
    error_b = abs(float(corrected_b[0, 0, 0]) - true_test_value)

    assert error_b < error_a
    assert error_b < 2.0  # gama modeli tam eşleştiği için hata neredeyse sıfıra iner


def test_white_gray_black_falls_back_to_linear_when_gray_reference_is_degenerate():
    """GERÇEK BASILI ETİKET BULGUSU (22 Eylül, docs/decisions/0004): gri
    referans yaması bazen QR'ın beyaz modülünden bile daha parlak ölçüldü
    (`btaze1.jpeg`: white=(221,218,209), gray=(226,220,213)) — ham formülle
    gama ~693000'e patlayıp görüntüyü neredeyse tamamen siyaha çöktürüyordu.
    Artık böyle dejenere (güvenilmez) bir gri referansta B, o kanal için A
    (white_black) ile TAMAMEN AYNI (gama=1) davranmalı — en kötü durumda
    bile A'dan daha kötü bir sonuç üretmemeli."""
    white_ref = (221, 218, 209)
    black_ref = (31, 21, 11)
    gray_ref = (226, 220, 213)  # beyazdan bile parlak -- dejenere
    image = np.array([[[150, 150, 150], white_ref, black_ref]], dtype=np.uint8)
    references = {"white": white_ref, "gray": gray_ref, "black": black_ref}

    corrected_b = white_gray_black(image, references)
    corrected_a = white_black(image, {"white": white_ref, "black": black_ref})

    assert np.array_equal(corrected_b, corrected_a)
    # Katastrofik (neredeyse siyah) çöküş YOK: orta-parlaklıktaki piksel
    # hâlâ orta-yüksek kalmalı — kelepçesiz eski davranışta 0'a çökerdi.
    assert corrected_b[0, 0].min() > 100


def test_get_returns_white_gray_black_implementation():
    assert get("white_gray_black") is white_gray_black
