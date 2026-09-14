"""qr_layout — standart QR üretimi + fonksiyon maskesi + dağıtılmış reaktif modül yerleşimi.

Rapor §5: QR'ın ortasında tek büyük sensör penceresi YOKTUR. Sensör etkisi, QR'ın
makine-okur fonksiyon bölgeleri (finder / timing / alignment / format / version /
quiet zone) korunarak, veri+ECC alanındaki seçilmiş modüllere dağıtılmış küçük
reaktif hücreler biçiminde tasarlanır.

Akış (§5.2):
  1. generate_qr()            -> standart QR
  2. function_mask()          -> fonksiyon modüllerini programatik çıkar
  3. reactive_candidates()    -> yalnızca data/ECC modülleri (aday havuz)
  4. select_reactive_modules()-> küçük, mekânsal dağıtılmış alt küme  [TODO: tam algoritma]
  5. build_layout()           -> layout_version JSON (koordinatlar dışarıda)
"""

from packages.qr_layout.function_mask import function_mask, matrix_size
from packages.qr_layout.generator import generate_qr, module_matrix, reactive_candidates
from packages.qr_layout.reactive import build_layout, seed_from_layout_version, select_reactive_modules

__all__ = [
    "generate_qr",
    "module_matrix",
    "function_mask",
    "matrix_size",
    "reactive_candidates",
    "select_reactive_modules",
    "seed_from_layout_version",
    "build_layout",
]
