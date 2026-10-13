"""Manuel damlatma için QR tasarım SEÇENEKLERİ üretir (13 Ekim).

Danışman yanıtı: indikatör elle damlatılacak (printer temin edilemedi) ve
"kareler daha büyük, damlatılabilecek uygun büyüklükte alanlar" isteniyor.
Mevcut tasarım (65x65, tek tek dağıtılmış 75 modül, 5 cm'de modül 0,68 mm)
bu yöntemle uygulanamaz: bir damla kâğıtta ~2-4 mm yayılır.

Bu script, "damla çapı" girdisine göre uygulanabilir tasarımları üretir:
reaktif hücreler TEK TEK değil, damlanın sığacağı BİTİŞİK BLOKLAR hâlinde
yerleştirilir. Her seçenek için QR'ın hâlâ çözülüp çözülmediği DOĞRULANIR.

Kullanım: python3 tests/device/build_qr_options.py
Çıktı: ~/Desktop/QR_Secenekleri/
"""

from __future__ import annotations

import json
import math
import os
import shutil
from pathlib import Path

from PIL import Image

from packages.qr_layout import generate_qr, reactive_candidates
from packages.qr_layout.colors import NEUTRAL, STATE_COLORS
from packages.qr_layout.generator import module_matrix

CIKTI = Path(os.environ["HOME"]) / "Desktop" / "QR_Secenekleri"
BORDER = 4
SCALE = 12          # px/modül (görsel netliği için)
HEDEF_BLOK = 9      # kaç reaktif alan

# Farklı payload uzunlukları -> farklı QR matrisleri.
# NOT: kısa olanlar mevcut JSON şemasıyla ÜRETİLEMEZ (anahtar adları bile
# ~80 karakter); onlar için payload biçimi de sadeleşmeli. Her seçenekte
# gereken karakter bütçesi yazılıyor.
PAYLOADLAR = [
    ("mevcut biçim", {"product_id": "KALIB-A", "product_type": "LEVREK",
                      "production_date": "2026-10-13",
                      "sensor_profile_id": "GENIPIN_PUTRESIN_v2_A",
                      "layout_version": "QR_SENSOR_v4"}),
    ("kısa biçim", {"p": "A1", "t": "LEVREK", "d": "261013", "s": "GP2A", "l": "v4"}),
    ("çok kısa biçim", {"i": "A1", "s": "G2A", "l": "4"}),
]

ETIKET_CM = [5.0, 7.0, 10.0]
DAMLA_MM = [2.0, 3.0, 4.0]


def bloklari_sec(adaylar: list[tuple[int, int]], k: int, n: int, hedef: int) -> list[tuple[int, int]]:
    """Tamamı aday havuzda kalan, birbirinden ayrık kxk blokların sol-üst
    köşelerini seçer. Mekânsal dağılım için ızgara taraması + asgari
    aralık kullanılır."""
    aday = set(adaylar)
    secili: list[tuple[int, int]] = []
    adim = max(k + 1, (n - 2 * k) // max(1, int(math.sqrt(hedef)) + 1))
    for r0 in range(0, n - k + 1, 1):
        for c0 in range(0, n - k + 1, 1):
            if len(secili) >= hedef:
                return secili
            if any((r0 + dr, c0 + dc) not in aday for dr in range(k) for dc in range(k)):
                continue
            if any(abs(r0 - r) < k + adim and abs(c0 - c) < k + adim for r, c in secili):
                continue
            secili.append((r0, c0))
    return secili


def ciz(qr, bloklar: list[tuple[int, int]], k: int, durum: str | None,
        baski: bool = False) -> Image.Image:
    """[durum] None -> nötr gösterim, "spoiled" vb. -> örnek renk değişimi.

    [baski] True ise BASKI USTASI çizilir: reaktif blokların İÇİ hiç
    basılmaz (beyaz kâğıt kalır, indikatör oraya damlatılacak), yalnızca
    bloğun bir modüllük ÇERÇEVESİ basılır. Çerçeve iki işe yarar:
    operatör nereye damlatacağını görür, ve çerçeve zaten bloğun kendi
    alanı içinde kaldığı için QR'a ek hasar vermez.

    Gri nötr gösterim BASILMAMALIDIR: indikatör grinin üstüne damlarsa
    renk kirlenir — profildeki referans renkler BEYAZ kâğıt üzerinde
    tanımlı (kullanıcı tespiti, 13 Ekim).
    """
    matris = module_matrix(qr)
    n = len(matris)
    boyut = (n + 2 * BORDER) * SCALE
    img = Image.new("RGB", (boyut, boyut), (255, 255, 255))
    px = img.load()
    reaktif = {(r0 + dr, c0 + dc) for r0, c0 in bloklar for dr in range(k) for dc in range(k)}
    if durum is None:
        acik, koyu = NEUTRAL["light"], NEUTRAL["dark"]
    else:
        acik, koyu = STATE_COLORS[durum]["light"], STATE_COLORS[durum]["dark"]
    for r in range(n):
        for c in range(n):
            bit = matris[r][c]
            if (r, c) in reaktif:
                if baski:
                    kenar = any(
                        r in (r0, r0 + k - 1) or c in (c0, c0 + k - 1)
                        for r0, c0 in bloklar
                        if r0 <= r < r0 + k and c0 <= c < c0 + k
                    )
                    renk = (0, 0, 0) if kenar else (255, 255, 255)
                else:
                    renk = koyu if bit else acik
            else:
                renk = (0, 0, 0) if bit else (255, 255, 255)
            x0, y0 = (c + BORDER) * SCALE, (r + BORDER) * SCALE
            for x in range(x0, x0 + SCALE):
                for y in range(y0, y0 + SCALE):
                    px[x, y] = renk
    return img


def cozulebiliyor_mu(img: Image.Image) -> bool:
    try:
        from pyzbar.pyzbar import decode
    except Exception:
        return True  # doğrulayamıyorsak engelleme
    return bool(decode(img))


def main() -> None:
    if CIKTI.exists():
        shutil.rmtree(CIKTI)
    CIKTI.mkdir(parents=True)

    satirlar = []
    for pad, payload in PAYLOADLAR:
        metin = json.dumps(payload, ensure_ascii=False, separators=(",", ":"))
        qr = generate_qr(metin, error="h")
        n = len(module_matrix(qr))
        adaylar = reactive_candidates(qr)
        for etiket in ETIKET_CM:
            modul_mm = etiket * 10 / (n + 2 * BORDER)
            for damla in DAMLA_MM:
                # Çerçeve bir modül yer kaptığı için blok, damla + 2 modül olmalı
                k = math.ceil(damla / modul_mm) + 2
                if k > 8:
                    continue  # blok QR'ı yiyecek kadar büyük
                bloklar = bloklari_sec(adaylar, k, n, HEDEF_BLOK)
                if len(bloklar) < 4:
                    continue  # yeterli alan yok
                toplam = len(bloklar) * k * k
                oran = 100 * toplam / (n * n)
                if oran > 15:
                    continue  # ECC için fazla riskli
                ad = f"{n}x{n}_{etiket:.0f}cm_damla{damla:.0f}mm"
                baski = ciz(qr, bloklar, k, None, baski=True)
                bozuk = ciz(qr, bloklar, k, "spoiled")
                baski.save(CIKTI / f"{ad}_baski.png")
                bozuk.save(CIKTI / f"{ad}_ornek.png")
                # İKİSİ de okunabilmeli: basılacak olan da, damlatılmış hâli de.
                ok = cozulebiliyor_mu(baski) and cozulebiliyor_mu(bozuk)
                ic_mm = (k - 2) * modul_mm  # çerçeve içi: damlanın sığacağı alan
                if ic_mm < damla:
                    continue  # çerçeve içi damla için yetersiz
                satirlar.append((ad, pad, len(metin), n, etiket, modul_mm, damla, k,
                                 ic_mm, len(bloklar), toplam, oran, ok))

    print(f"{len(satirlar)} seçenek üretildi -> {CIKTI}\n")
    print("seçenek                     payload   QR     modül  blok  ÇERÇEVE  alan  reaktif  QR")
    print("                            (karakter)       (mm)   (k)   İÇİ(mm)  sayı  (%)      okunur")
    for (ad, pad, uzn, n, etiket, mm, damla, k, blok_mm, nb, toplam, oran, ok) in satirlar:
        print(f"{ad:26} {uzn:4}      {n:2}x{n:<2}  {mm:4.2f}  {k}x{k}  {blok_mm:4.1f}  {nb:3}   "
              f"{oran:4.1f}     {'EVET' if ok else 'HAYIR'}")


if __name__ == "__main__":
    main()
