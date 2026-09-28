"""Kalibrasyon yöntem aileleri (rapor §6.1 A–E) — tek yönteme kilitlenmez.

Öğrenci 2 görevi (§9.2): bu adayları aynı test setinde karşılaştırıp ortak
metriklerle (cihazlar arası ΔE, tekrarlanabilirlik, ışık dayanıklılığı, süre)
en kararlı olanı seçmek. Benchmark koşumu tests/synthetic altında olacak.

Her yöntem: apply(image, references) -> düzeltilmiş görüntü.  (Şimdilik stub.)
"""

from __future__ import annotations

from typing import Any, Callable

import numpy as np

Image = Any  # numpy.ndarray gelince daraltılacak


def _not_implemented(name: str) -> Callable[..., Image]:
    def _apply(image: Image, references: dict | None = None) -> Image:  # pragma: no cover
        raise NotImplementedError(f"Kalibrasyon yöntemi '{name}' henüz uygulanmadı (rapor §6.1).")

    return _apply


def white_black(image: Image, references: dict) -> Image:
    """Beyaz + siyah iki noktalı referans kalibrasyonu (rapor §6.1 A).

    `references`: {"white": (r,g,b), "black": (r,g,b)} — canonical (homografi
    sonrası) görüntüde `reference_regions`'tan örneklenmiş ortalama renkler.

    Her kanalı BAĞIMSIZ olarak doğrusal esnetir: referans siyah -> 0,
    referans beyaz -> 255. Bu hem genel pozlamayı (kazanç) hem de kanallar
    arası renk sıcaklığı kaymasını (ör. sarımsı ışıkta R kanalının şişmesi)
    tek işlemde düzeltir — klasik "white balance + black point" tekniği.
    """
    white = np.asarray(references["white"], dtype=np.float64)
    black = np.asarray(references["black"], dtype=np.float64)
    span = white - black
    span = np.where(span == 0, 1.0, span)  # sıfıra bölme koruması (dejenere referans)

    corrected = (image.astype(np.float64) - black) / span * 255.0
    return np.clip(corrected, 0, 255).astype(np.uint8)


# white_gray_black(): gri referansın gama çözümü için "güvenilir" sayılacağı
# normalize aralık (bkz. fonksiyonun kendi docstring'i ve docs/decisions/0004,
# "22 Eylül" bulgusu). Gerçek basılı etiket verisi: norm_gray ~0.65 -> doğru
# sınıflandırma (gama~1.5-1.8); norm_gray >= 0.925 -> hep yanlış/dejenere
# gama (12'den 693000'e kadar). Sınır bilinçli olarak muhafazakar seçildi —
# tam bir "doğru gama" eşiği değil, sadece dejenere uçları (gri ~ beyaz/siyah
# ile ayırt edilemez ölçülmüş) filtreleyen bir güvenlik bandı.
_MIN_RELIABLE_NORM_GRAY = 0.15
_MAX_RELIABLE_NORM_GRAY = 0.85


def white_gray_black(image: Image, references: dict) -> Image:
    """Beyaz + gri + siyah üç noktalı referans kalibrasyonu (rapor §6.1 B).

    `references`: {"white": (r,g,b), "gray": (r,g,b), "black": (r,g,b)}.

    Kameraların tonlama eğrisi genelde tam doğrusal DEĞİLDİR (sensör/JPEG
    gama eğrisi). `white_black` (A) yalnızca iki uçtan doğrusal bir çizgi
    varsayar; orta tonlarda sapabilir. Burada önce A ile aynı uç-nokta
    normalizasyonu yapılır, sonra gri referansın normalize hali hedef orta
    tona (0.5) oturacak şekilde kanal başına bir GAMA (üs) çözülüp
    uygulanır — üç noktadan geçen bir eğri, iki noktadan geçen düz
    çizgiden orta tonlarda daha doğru olur.

    GÜVENLİK KELEPÇESİ (28 Eylül, bkz. docs/decisions/0004 "22 Eylül"
    bulgusu): gerçek baskıda gri yama bazen beyaza (hatta bazen ondan daha
    parlak) çok yakın ölçülüyor — bu durumda ham formül gamayı patlatıyor
    (gözlemlenen: ~693000), görüntüyü neredeyse tamamen siyaha çöken
    dejenere bir eğriyle "düzeltiyor". Bu, YÖNTEMİN kendi varsayımının
    (gri, beyazdan GÜVENİLİR biçimde daha koyu ölçülür) geçersiz kaldığı
    bir durum — "daha az kötü ama hâlâ yanlış" bir gama tahmin etmeye
    çalışmak yerine, güvenilmez (aşırı uçtaki) kanallarda gama=1 kullanılır,
    yani o kanal için `white_black` (A) ile TAMAMEN AYNI doğrusal davranışa
    düşülür. Böylece en kötü durumda bile B, gerçek baskıda en güvenilir
    bulunan A'dan (bkz. karar dosyası) DAHA KÖTÜ bir sonuç üretemez — bu
    B'nin kendi doğruluğunu artırmaz, sadece taban değerini A'ya sabitler.
    """
    white = np.asarray(references["white"], dtype=np.float64)
    black = np.asarray(references["black"], dtype=np.float64)
    gray = np.asarray(references["gray"], dtype=np.float64)
    span = white - black
    span = np.where(span == 0, 1.0, span)

    normalized_gray = np.clip((gray - black) / span, 1e-6, 1 - 1e-6)
    reliable = (normalized_gray > _MIN_RELIABLE_NORM_GRAY) & (normalized_gray < _MAX_RELIABLE_NORM_GRAY)
    gamma = np.where(reliable, np.log(0.5) / np.log(normalized_gray), 1.0)

    normalized = np.clip((image.astype(np.float64) - black) / span, 0.0, 1.0)
    corrected = np.power(normalized, gamma) * 255.0
    return np.clip(corrected, 0, 255).astype(np.uint8)


def multicolor_patch(image: Image, references: dict) -> Image:
    """Çoklu sabit renk yaması ile 3x4 afin renk düzeltme (rapor §6.1 C).

    `references`: {"captured": [(r,g,b), ...], "true": [(r,g,b), ...]}
    — en az 4 nokta gerekir (ör. beyaz/gri/siyah + birkaç renkli yama).

    A ve B her kanalı BAĞIMSIZ düzeltir; bu yöntem en küçük kareler ile
    kanallar ARASI karışımı da (ör. kırmızının yeşile sızması) modelleyen
    bir 3x4 afin matris (3x3 kazanç/karışım + ofset) çözer — daha fazla
    referans noktası ve baskı maliyeti gerektirir ama daha genel bir
    düzeltmedir.
    """
    captured = np.asarray(references["captured"], dtype=np.float64)
    true = np.asarray(references["true"], dtype=np.float64)
    if captured.shape[0] < 4:
        raise ValueError("multicolor_patch en az 4 referans noktası gerektirir (3x4 afin çözüm için).")

    design = np.hstack([captured, np.ones((captured.shape[0], 1))])
    matrix, *_ = np.linalg.lstsq(design, true, rcond=None)  # (4,3)

    flat = image.reshape(-1, 3).astype(np.float64)
    flat_design = np.hstack([flat, np.ones((flat.shape[0], 1))])
    corrected = (flat_design @ matrix).reshape(image.shape)
    return np.clip(corrected, 0, 255).astype(np.uint8)


def qr_fixed_regions(image: Image, references: dict) -> Image:
    """QR'ın kendi sabit siyah/beyaz modüllerini referans alan kalibrasyon
    (rapor §6.1 D) — ek baskılı referans yaması GEREKTİRMEZ.

    `references`: {"white": (r,g,b), "black": (r,g,b)} — bu renkler QR'ın
    finder pattern'i gibi hep aynı kalan modüllerinden örneklenmiş olmalı
    (bkz. `packages.qr_layout.colors.finder_pattern_reference_pixels`,
    piksel konumlarını verir; örnekleme/ROI adımı bu fonksiyonun DIŞINDA).

    Matematiksel olarak `white_black` (A) ile AYNIDIR — tek fark referans
    renklerin nereden geldiği: ayrı bir baskı yaması yerine QR'ın zaten var
    olan sabit modülleri kullanılır, ek baskı maliyeti yoktur.
    """
    return white_black(image, references)


def algorithmic_white_balance(image: Image, references: dict | None = None) -> Image:
    """Algoritmik white balance / "gray-world" varsayımı (rapor §6.1 E).

    Referans yaması GEREKTİRMEZ (`references` diğer yöntemlerle aynı
    arayüz için var, kullanılmaz): görüntünün kanal ortalamalarının kabaca
    nötr gri olması gerektiği varsayılır. Her kanal, üç kanalın ortak
    ortalamasına eşitlenecek şekilde ayrı ayrı ölçeklenir.

    Sınırlama: çerçeve baskın tek renkliyse (ör. neredeyse tamamı tek bir
    reaktif hücre rengiyse) varsayım bozulur — bu yüzden rapor bunu diğer
    yöntemlerle karşılaştırmalı test etmemizi istiyor (§6.1 Karar metrikleri).
    """
    channel_means = image.astype(np.float64).mean(axis=(0, 1))
    channel_means = np.where(channel_means == 0, 1.0, channel_means)
    gray_mean = channel_means.mean()
    gains = gray_mean / channel_means

    corrected = image.astype(np.float64) * gains
    return np.clip(corrected, 0, 255).astype(np.uint8)


# Kod -> uygulama. Kodlar sensor_profile.calibration_method.code ile eşleşir.
METHODS: dict[str, Callable[..., Image]] = {
    "white_black": white_black,                                            # A
    "white_gray_black": white_gray_black,                                  # B
    "multicolor_patch": multicolor_patch,                                  # C
    "qr_fixed_regions": qr_fixed_regions,                                  # D
    "algorithmic_white_balance": algorithmic_white_balance,                # E
    "learned": _not_implemented("learned"),
}

# Benchmark'ta raporlanacak karar metrikleri (rapor §6 "Karar metrikleri", §11.3)
DECISION_METRICS = [
    "inter_device_delta_e",
    "repeatability_cv",
    "illumination_robustness",
    "class_separation",
    "runtime_ms",
    "print_cost",
]


def get(code: str) -> Callable[..., Image]:
    if code not in METHODS:
        raise KeyError(f"Bilinmeyen kalibrasyon kodu: {code!r}. Seçenekler: {sorted(METHODS)}")
    return METHODS[code]
