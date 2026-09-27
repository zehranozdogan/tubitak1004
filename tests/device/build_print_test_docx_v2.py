"""Kalibrasyon karşılaştırması için 2. tur baskı testi etiketleri.

A/B/C hepsi AYNI QR modül fiziksel boyutunda (5x5cm) basılsın diye — B/C'nin
kenar yaması şeridi QR'ın kendi boyutunu KüçÜLTMESİN, bunun yerine QR'ın
DIŞINA taşsın. Bu yüzden B/C, docx'e A'dan büyük bir fiziksel boyutta
gömülüyor (canvas piksel oranıyla orantılı) — QR'ın kendisi (modül başına
piksel) A ile birebir aynı kalıyor, sadece toplam etiket (yama dahil) daha
büyük çıkıyor.

Kullanım: python3 tests/device/build_print_test_docx_v2.py
Çıktı: tests/device/Baski_Testi_v2_ABC.docx
"""

from __future__ import annotations

from pathlib import Path

from docx import Document
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.shared import Cm, Pt
from PIL import Image

REGEN_ROOT = Path("/tmp/kalibrasyon_test_2")
OUT = Path(__file__).parent / "Baski_Testi_v2_ABC.docx"

METHODS = ["A", "B", "C"]
STATES = [("state_fresh", "Taze"), ("state_transition", "Geçiş"), ("state_spoiled", "Bozuk")]

BASE_CM = 5.0  # A'nın (yamasız) fiziksel boyutu


def _embed_size_cm(letter: str) -> float:
    """B/C'nin canvas'ı (yama şeridi yüzünden) A'dan büyük — aynı oranda
    büyütülmüş bir fiziksel boyutta gömülürse QR'ın kendi modül boyutu A
    ile birebir eşleşir (yama sadece dışarıda ekstra yer kaplar)."""
    a_png = next((REGEN_ROOT / "A").glob("*.png"))
    this_png = next((REGEN_ROOT / letter).glob("*.png"))
    a_w = Image.open(a_png).size[0]
    this_w = Image.open(this_png).size[0]
    return BASE_CM * this_w / a_w


def main() -> None:
    doc = Document()
    for letter in METHODS:
        folder = REGEN_ROOT / letter
        size = Cm(_embed_size_cm(letter))

        table = doc.add_table(rows=2, cols=3)
        table.autofit = False
        for col, (state_key, state_label) in enumerate(STATES):
            img_path = next(folder.glob(f"*.{state_key}.png"))

            cap_cell = table.cell(0, col)
            p = cap_cell.paragraphs[0]
            p.alignment = WD_ALIGN_PARAGRAPH.CENTER
            run = p.add_run(f"{letter} · {state_label}")
            run.bold = True
            run.font.size = Pt(9)

            img_cell = table.cell(1, col)
            img_p = img_cell.paragraphs[0]
            img_p.alignment = WD_ALIGN_PARAGRAPH.CENTER
            img_p.add_run().add_picture(str(img_path), width=size, height=size)

        doc.add_paragraph()

    doc.save(OUT)
    print(f"Yazıldı: {OUT}")


if __name__ == "__main__":
    main()
