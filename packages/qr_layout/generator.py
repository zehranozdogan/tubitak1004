"""Standart QR üretimi (segno) ve reaktif hücre aday havuzunun çıkarılması."""

from __future__ import annotations

from packages.qr_layout.function_mask import function_mask, matrix_size


def generate_qr(payload: str, *, error: str = "h", version: int | None = None):
    """Standart bir QR üretir.

    error='h' -> ECC-H. KARAR, rapor §5.2/4'ün istediği gibi DENEYSEL
    karşılaştırmayla verildi (M/Q/H, bkz. tests/synthetic/benchmark_ecc_
    levels.py), uydurulmadı:
      - Aynı payload'da M en küçük QR'ı verir ama gerçek bozulma altında
        (açı/bulanıklık/parlaklık) en düşük decode başarısını veriyor
        (yüksek yoğunlukta %78, Q/H %82-85) VE kasıtlı-hata toleransı
        SIFIR (§5.2/4'ün "intentional error" senaryosunda hiç işe yaramıyor).
      - Q ile H, normal bozulmada birbirine yakın (bazen Q hafif önde);
        ama H'nin kasıtlı-hata tolerans tavanı belirgin şekilde daha
        yüksek (daha büyük QR = daha çok yedek kodkelime).
      - Bedeli: H, M'ye göre daha büyük QR (aynı payload'da 69x69 vs 53x53
        modül) — baskı alanı kritikse Q bir uzlaşma olabilir, ama şimdilik
        önceliğimiz (kamera/gerçek fotoğraf altında) sağlamlık.
      - BASKI UYGULANABİLİRLİĞİ (aynı benchmark, 300dpi hesabıyla): H ile
        69x69 modülün güvenli kalması (~modül başına >=0.4-0.5mm, genel
        kural) için etiket en az ~30mm olmalı; 25mm'de modül 0.36mm'ye
        düşüyor (riskli). Bu HENÜZ fiziksel baskıyla doğrulanmadı (§11
        Aşama B), yalnızca yönlendirici bir hesap.
    Dağıtılmış reaktif modüller için tampon sağlar (rapor §5). Dönen nesne
    segno.QRCode.
    """
    import segno

    qr = segno.make(payload, error=error, version=version, micro=False)
    if qr.version is None or isinstance(qr.version, str):
        raise ValueError("Micro QR desteklenmiyor; normal QR üretin.")
    return qr


def module_matrix(qr) -> list[list[int]]:
    """QR'ın 0/1 modül matrisi (quiet zone hariç)."""
    return [list(row) for row in qr.matrix]


def reactive_candidates(qr) -> list[tuple[int, int]]:
    """Reaktif hücre olabilecek (satır, sütun) modülleri: yalnızca data/ECC alanı.

    Rapor §5.2/2: adaylar yalnızca izin verilen data/ECC modüllerinden seçilir.
    """
    version = qr.version
    n = matrix_size(version)
    mask = function_mask(version)
    return [(r, c) for r in range(n) for c in range(n) if not mask[r][c]]
