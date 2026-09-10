"""QR fonksiyon (makine-okur) modüllerinin maskesi — ISO/IEC 18004.

`function_mask(version)` -> 2B bool matris. True = fonksiyon modülü (DOKUNULMAZ,
rapor §5.1). False = data/ECC modülü (reaktif hücre adayı).

Kapsanan bölgeler: finder pattern + separator, timing pattern, alignment pattern,
format bilgisi (rezerve), version bilgisi (v>=7, rezerve), dark module.
Quiet zone segno matrisine dahil değildir.
"""

from __future__ import annotations

# Alignment pattern merkez koordinatları (versiyon -> merkez listesi). ISO/IEC 18004 Annex E.
ALIGNMENT_POSITIONS: dict[int, list[int]] = {
    1: [], 2: [6, 18], 3: [6, 22], 4: [6, 26], 5: [6, 30], 6: [6, 34],
    7: [6, 22, 38], 8: [6, 24, 42], 9: [6, 26, 46], 10: [6, 28, 50],
    11: [6, 30, 54], 12: [6, 32, 58], 13: [6, 34, 62], 14: [6, 26, 46, 66],
    15: [6, 26, 48, 70], 16: [6, 26, 50, 74], 17: [6, 30, 54, 78],
    18: [6, 30, 56, 82], 19: [6, 30, 58, 86], 20: [6, 34, 62, 90],
    21: [6, 28, 50, 72, 94], 22: [6, 26, 50, 74, 98], 23: [6, 30, 54, 78, 102],
    24: [6, 28, 54, 80, 106], 25: [6, 32, 58, 84, 110], 26: [6, 30, 58, 86, 114],
    27: [6, 34, 62, 90, 118], 28: [6, 26, 50, 74, 98, 122],
    29: [6, 30, 54, 78, 102, 126], 30: [6, 26, 52, 78, 104, 130],
    31: [6, 30, 56, 82, 108, 134], 32: [6, 34, 60, 86, 112, 138],
    33: [6, 30, 58, 86, 114, 142], 34: [6, 34, 62, 90, 118, 146],
    35: [6, 30, 54, 78, 102, 126, 150], 36: [6, 24, 50, 76, 102, 128, 154],
    37: [6, 28, 54, 80, 106, 132, 158], 38: [6, 32, 58, 84, 110, 136, 162],
    39: [6, 26, 54, 82, 110, 138, 166], 40: [6, 30, 58, 86, 114, 142, 170],
}


def matrix_size(version: int) -> int:
    """Bir QR versiyonunun kenar uzunluğu (modül)."""
    if not 1 <= version <= 40:
        raise ValueError(f"QR versiyonu 1..40 olmalı, verilen: {version}")
    return version * 4 + 17


def _fill(mask: list[list[bool]], r0: int, c0: int, r1: int, c1: int, n: int) -> None:
    for r in range(max(0, r0), min(n, r1 + 1)):
        for c in range(max(0, c0), min(n, c1 + 1)):
            mask[r][c] = True


def function_mask(version: int) -> list[list[bool]]:
    n = matrix_size(version)
    mask = [[False] * n for _ in range(n)]

    # --- Finder pattern + separator (8x8 blok, 3 köşe) ---
    _fill(mask, 0, 0, 7, 7, n)
    _fill(mask, 0, n - 8, 7, n - 1, n)
    _fill(mask, n - 8, 0, n - 1, 7, n)

    # --- Timing pattern (satır 6 ve sütun 6) ---
    for i in range(n):
        mask[6][i] = True
        mask[i][6] = True

    # --- Dark module ---
    mask[4 * version + 9][8] = True

    # --- Format bilgisi (rezerve) ---
    _fill(mask, 0, 8, 8, 8, n)          # sol-üst dikey şerit
    _fill(mask, 8, 0, 8, 8, n)          # sol-üst yatay şerit
    _fill(mask, 8, n - 8, 8, n - 1, n)  # sağ-üst yatay şerit
    _fill(mask, n - 7, 8, n - 1, 8, n)  # sol-alt dikey şerit

    # --- Version bilgisi (v >= 7, rezerve) ---
    if version >= 7:
        _fill(mask, 0, n - 11, 5, n - 9, n)   # sağ-üst 6x3
        _fill(mask, n - 11, 0, n - 9, 5, n)   # sol-alt 3x6

    # --- Alignment pattern (5x5), finder'larla çakışanlar hariç ---
    centers = ALIGNMENT_POSITIONS[version]
    if centers:
        last = centers[-1]
        skip = {(6, 6), (6, last), (last, 6)}
        for r in centers:
            for c in centers:
                if (r, c) in skip:
                    continue
                _fill(mask, r - 2, c - 2, r + 2, c + 2, n)

    return mask
