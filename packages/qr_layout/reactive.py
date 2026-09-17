"""Dağıtılmış reaktif modül seçimi ve layout_version JSON üretimi.

DİKKAT — bu dosya ORTAK sorumluluktadır (Öğrenci 1 + Öğrenci 2, rapor §9).

Rapor §5.2'nin tam algoritması:
  1. her reaktif rengin gri-seviye/binary davranışının incelenmesi
     -> ZATEN GARANTİ: `colors.module_color()` her modülün orijinal bitine
        göre 'dark'/'light' tonunu seçer, pozisyondan bağımsız (bkz. o dosya
        ve test_module_color_preserves_dark_light_class). Bu yüzden burada
        "hangi hücre seçilirse seçilsin" sınıf bozulmaz.
  2. orijinal siyah/beyaz sınıfını bozmayan pozisyonların tercihi
     -> `_safety_score()`: fonksiyon modüllerine (finder/timing/alignment/
        format/version) VE QR'ın dış kenarına Chebyshev mesafesi. DAYANAK
        (uydurma değil, ölçüldü): tests/synthetic/benchmark_distortion.py
        açı taramasında başarısızlık köşe/kenarlarda yoğunlaşıyor (45°'de
        %0->ArUco ile %67); bu skor o ölçüme dayanarak riskli bölgelerden
        kaçınıyor.
  3. kaçınılmazsa kontrollü "intentional error" + ECC/boyut deneysel karş.
     -> `select_intentional_errors()`: modülün GERÇEK bitinin tersiyle
        render edilmesi gereken hücreleri seçer (ör. sabit renkli bir
        kalibrasyon referansı, §6.1 B/C — kullanım kararı henüz alınmadı,
        alt yapı hazır). Kaç tanesinin güvenle tolere edilebileceği
        `tests/synthetic/benchmark_intentional_errors.py` ile DENEYSEL
        ölçülür (ISO tablosundan uydurulmaz). ECC Q/H VE boyut karşılaştırması
        da yapıldı (`benchmark_ecc_levels.py`) — H'de karar kılındı, bkz.
        `generator.generate_qr()` docstring'i (M/Q/H tam sayısal sonuçlar).
  4. en iyi layout'un layout_version ile sürümlenmesi
     -> `seed_from_layout_version()`: aynı sürüm = aynı yerleşim.

DOĞRULANDI (tests/synthetic/test_decode_verification.py + benchmark):
üç yoğunluk × dört renk durumunun tamamı OpenCV/ArUco ile okunuyor. Reaktif
hücre YOĞUNLUĞUNUN üst sınırı da elle taranarak belirlendi — bkz.
DENSITY_FRACTION altındaki not. Rapor ">= 2 decoder" istiyor — ikinci
decoder (ör. pyzbar) henüz eklenmedi.
"""

from __future__ import annotations

import random
import zlib
from collections import deque

from packages.qr_layout.colors import FINDER_BLACK_MODULE, FINDER_WHITE_MODULE
from packages.qr_layout.function_mask import matrix_size

# Yoğunluk -> hedef reaktif hücre ORANI (aday havuzunun yüzdesi olarak; rapor
# §8: düşük/orta/yüksek 3 aday). SABİT SAYI değil — QR versiyonu (dolayısıyla
# aday havuzunun boyutu) payload'un uzunluğuna göre değişir; oran, her boyutta
# görsel olarak orantılı ve decode-güvenliği açısından tutarlı kalmasını sağlar.
#
# ÜST SINIR NASIL BELİRLENDİ (elle ölçüldü, benchmark_distortion.py mantığıyla
# açı×bulanıklık×parlaklık×3 durum × 4 FARKLI ÜRÜN PAYLOAD'I taranıp
# ORTALAMASI alınarak — tek payload'a güvenmek yanıltıcı, QR versiyonuna
# göre sonuç %81-%100 arası oynayabiliyor, bu yüzden 4'ün ortalaması esas
# alındı):
#   %2-%4  -> %88.9 (düz, hiç düşüş yok)
#   %5     -> %88.4      %6 -> %87.7      %7 -> %85.4 (düşüş başlıyor)
# "high" bu yüzden %6'da tutuluyor: düz bölgenin hemen dışında değil, kenarda
# ama hâlâ ölçülebilir düşüşün (%7+) altında, güvenli marj bırakılarak.
DENSITY_FRACTION = {"low": 0.02, "medium": 0.04, "high": 0.06}
_MIN_CELLS = 5  # çok küçük QR'larda (az aday) bile görünür bir yerleşim olsun


def seed_from_layout_version(layout_version: str) -> int:
    """`layout_version` metninden DETERMİNİSTİK bir seed türetir.

    Amaç: aynı layout_version her zaman aynı reaktif hücre yerleşimini
    üretsin (fiziksel şablon/kalıp tekrarlanabilir olmalı, §5.2/7), ama
    farklı bir layout_version farklı bir yerleşim versinler — koda gömülü
    tek bir sabit seed (ör. hep 0) kullanırsak tüm sürümler aynı geometriye
    çakışır ve "layout_version" versiyonlamanın anlamı kalmaz.
    `zlib.crc32` kullanılır (Python'un `hash()`'i süreçler arası kararlı
    değildir, PYTHONHASHSEED'e bağlıdır).
    """
    return zlib.crc32(layout_version.encode("utf-8"))


def _chebyshev(a: tuple[int, int], b: tuple[int, int]) -> int:
    return max(abs(a[0] - b[0]), abs(a[1] - b[1]))


def _boundary_distance(cell: tuple[int, int], n: int) -> int:
    """Hücrenin QR'ın DIŞ kenarına Chebyshev mesafesi (0 = en kenarda)."""
    r, c = cell
    return min(r, c, n - 1 - r, n - 1 - c)


def _function_distance_transform(candidate_set: set[tuple[int, int]], n: int) -> list[list[int]]:
    """Her hücre için EN YAKIN fonksiyon modülüne (finder/timing/alignment/
    format/version) Chebyshev mesafesi. Çok-kaynaklı BFS (8-komşuluk =
    Chebyshev mesafe). Fonksiyon modülleri `candidate_set`'in TAMLAYANIdır
    (bkz. generator.reactive_candidates — adaylar zaten yalnızca data/ECC
    modülleridir), bu yüzden ayrıca `function_mask()` çağırmaya gerek yok.
    """
    dist = [[-1] * n for _ in range(n)]
    q: deque[tuple[int, int]] = deque()
    for r in range(n):
        for c in range(n):
            if (r, c) not in candidate_set:
                dist[r][c] = 0
                q.append((r, c))
    while q:
        r, c = q.popleft()
        d = dist[r][c] + 1
        for dr in (-1, 0, 1):
            for dc in (-1, 0, 1):
                if dr == 0 and dc == 0:
                    continue
                nr, nc = r + dr, c + dc
                if 0 <= nr < n and 0 <= nc < n and dist[nr][nc] == -1:
                    dist[nr][nc] = d
                    q.append((nr, nc))
    return dist


def _safety_score(cell: tuple[int, int], func_dist: list[list[int]], n: int) -> int:
    """Bir adayın 'güvenlik' skoru: hem fonksiyon modüllerine HEM de QR'ın
    dış kenarına olan minimum mesafe. Yüksek skor = decoder'ın köşe/
    kalibrasyon yapılarına ve perspektif bozulmasına (§11.2) daha az maruz
    kalan hücre (dayanak için modül başlığına bkz.)."""
    r, c = cell
    return min(func_dist[r][c], _boundary_distance(cell, n))


def select_reactive_modules(
    candidates: list[tuple[int, int]],
    *,
    density: str = "low",
    min_spacing: int = 3,
    seed: int = 0,
) -> list[tuple[int, int]]:
    """Aday havuzdan hedef sayıda, mekânsal dağıtılmış VE güvenli bir alt
    küme seçer.

    Greedy: adayları güvenlik skoruna göre (yüksek->düşük) sırala (eşitlerde
    seed'e bağlı deterministik karışım), aralarında en az `min_spacing`
    Chebyshev mesafesi kalacak şekilde hedef sayıya kadar seç. Saf rastgele
    seçime göre ölçülebilir şekilde daha yüksek decode başarısı verir (bkz.
    modül başlığı) — bu yüzden artık sadece "dağıtılmış" değil, riskli
    bölgelerden (kenar/fonksiyon-modülü yakını) de kaçınıyor.
    """
    if density not in DENSITY_FRACTION:
        raise ValueError(f"density 'low'|'medium'|'high' olmalı, verilen: {density!r}")
    target = max(_MIN_CELLS, round(len(candidates) * DENSITY_FRACTION[density]))
    target = min(target, len(candidates))

    candidate_set = set(candidates)
    n = max(max(r, c) for r, c in candidates) + 1
    func_dist = _function_distance_transform(candidate_set, n)

    rnd = random.Random(seed)
    pool = sorted(
        candidates,
        key=lambda cell: (-_safety_score(cell, func_dist, n), rnd.random()),
    )

    chosen: list[tuple[int, int]] = []
    for cell in pool:
        if len(chosen) >= target:
            break
        if all(_chebyshev(cell, c) >= min_spacing for c in chosen):
            chosen.append(cell)
    return sorted(chosen)


def select_intentional_errors(
    candidates: list[tuple[int, int]],
    *,
    count: int,
    exclude: set[tuple[int, int]] | None = None,
    min_spacing: int = 2,
    seed: int = 0,
) -> list[tuple[int, int]]:
    """Kasıtlı olarak GERÇEK bitinin TERSİYLE render edilecek hücreleri seçer
    (rapor §5.2/4: "Binary sınıf değişimi kaçınılmazsa kontrollü hata
    modülleri").

    Ne zaman gerekir: bir modülün QR'ın kendi verisinden bağımsız, SABİT bir
    referans rengi göstermesi gerektiğinde (ör. §6.1 B/C'nin gri/çoklu-yama
    kalibrasyon referansı — bu modüllerin gerçek biti '0' da olsa '1' de
    olsa aynı sabit tonu göstermesi lazım). Reaktif hücrelerin aksine
    (bkz. `colors.module_color` — HER ZAMAN gerçek bite göre ton seçer),
    burada modülün GERÇEK sınıfı bilerek göz ardı edilir; QR'ın hata
    düzeltmesi (ECC) bunu telafi etmeli.

    Bu fonksiyon SADECE hangi hücrelerin seçileceğine karar verir — kaç
    tanesinin güvenle tolere edilebileceği ISO/IEC 18004 tablosundan değil,
    DENEYSEL olarak ölçülür (bkz. tests/synthetic/benchmark_intentional_
    errors.py) çünkü modül-sayısı <-> kod kelimesi/ECC-bütçesi eşlemesi
    QR'ın interleaving düzenine bağlıdır ve elle türetmek hataya açıktır.

    `select_reactive_modules` ile AYNI güvenlik skorunu kullanır: hatalar
    kenara/fonksiyon modüllerine yakın değil, dağılmış olsun — tek bir
    Reed-Solomon bloğunda kümelenip o bloğun düzeltme kapasitesini aşma
    riskini azaltır. `exclude` ile reaktif hücrelerle çakışma engellenir
    (bir modül aynı anda hem reaktif hem kasıtlı-hata OLAMAZ).
    """
    exclude = exclude or set()
    pool = [cell for cell in candidates if cell not in exclude]
    if count > len(pool):
        raise ValueError(
            f"count ({count}) dışlananlar sonrası aday havuzundan ({len(pool)}) büyük olamaz."
        )

    candidate_set = set(candidates)
    n = max(max(r, c) for r, c in candidates) + 1
    func_dist = _function_distance_transform(candidate_set, n)

    rnd = random.Random(seed)
    ranked = sorted(pool, key=lambda cell: (-_safety_score(cell, func_dist, n), rnd.random()))

    chosen: list[tuple[int, int]] = []
    for cell in ranked:
        if len(chosen) >= count:
            break
        if all(_chebyshev(cell, c) >= min_spacing for c in chosen):
            chosen.append(cell)
    return sorted(chosen)


def build_layout(
    qr,
    sensor_modules: list[tuple[int, int]],
    *,
    layout_version: str,
    density: str = "low",
    reference_regions: dict[str, list[tuple[int, int]]] | None = None,
    intentional_errors: list[tuple[int, int]] | None = None,
) -> dict:
    """layout_version.schema.json'a uyan sözlük üretir (koordinatlar dışarıda tutulur).

    `reference_regions` verilmezse (None), QR'ın kendi finder pattern'indeki
    GARANTİ siyah/beyaz iki modüle (rapor §6.1 D: `qr_fixed_regions`, ek
    baskılı referans yaması gerektirmez) otomatik varsayılan atanır — bu
    yüzden üretici tarafında hiçbir şey yapılmasa bile layout_version.json
    her zaman geçerli, kullanılabilir bir referans taşır (§10.1: "okuyucu
    koordinatları hard-code etmez, bu dosyadan okur" ilkesi budur).
    Gri/çoklu-yama gerektiren yöntemler (§6.1 B, C) için ek anahtarlar
    ("gray", "captured"/"true") hâlâ elle sağlanmalı — bunlar fiziksel
    baskı yaması ya da kasıtlı hata (`intentional_errors`) gerektirir,
    burada otomatik üretilmez.
    """
    version = qr.version
    if reference_regions is None:
        reference_regions = {"black": [FINDER_BLACK_MODULE], "white": [FINDER_WHITE_MODULE]}
    return {
        "layout_version": layout_version,
        "qr_version": version,
        "matrix_size": matrix_size(version),
        "ecc_level": (qr.error or "H").upper(),
        "module_density": density,
        "sensor_modules": [[r, c] for r, c in sensor_modules],
        "reference_regions": {
            k: [[r, c] for r, c in v] for k, v in reference_regions.items()
        },
        "intentional_errors": [[r, c] for r, c in (intentional_errors or [])],
        "decoder_check": {
            "decoders": [],
            "color_states": ["fresh", "transition", "spoiled"],
            "decode_success_rate": 0.0,
        },
    }
