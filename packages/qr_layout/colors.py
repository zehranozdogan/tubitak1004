"""Tazelik durumuna göre reaktif modül renkleri (rapor §5, §7, §8).

Kavram: reaktif modül renklense bile QR'ın kendi açık/koyu (0/1) sınıfını
bozmamalı ki decoder hâlâ okuyabilsin (rapor §5.2 adım 3: "Her reaktif
rengin gri-seviye/binary davranışını incele... orijinal siyah/beyaz
sınıfını değiştirmeyen pozisyonlara yerleştir"). Bu yüzden her durum için
İKİ ton tanımlanır: bit=1 (koyu modül) → 'dark', bit=0 (açık modül) → 'light'.

DEĞERLER TASLAK: gerçek pigment renkleri Putresin deney verilerine göre
kalibre edilecek (rapor §4, §6). Şimdilik görsel ayrım + demo içindir;
gerçek decodability testi tests/synthetic altında ayrıca doğrulanmalı.
"""

RGB = tuple[int, int, int]

STATE_LABELS = {
    "fresh": "Taze",
    "transition": "Geçiş",
    "spoiled": "Bozuk",
}

STATE_COLORS: dict[str, dict[str, RGB]] = {
    "fresh": {"dark": (0, 140, 40), "light": (140, 255, 160)},
    "transition": {"dark": (185, 90, 0), "light": (255, 185, 90)},
    "spoiled": {"dark": (210, 0, 0), "light": (255, 140, 140)},
}

# Henüz bir duruma atanmamış / yalnızca yerleşimi göstermek için nötr gri.
NEUTRAL: dict[str, RGB] = {"dark": (97, 97, 97), "light": (224, 224, 224)}


def module_color(bit: int, is_sensor: bool, state: str | None) -> RGB:
    """Tek bir modülün rengini döndürür.

    bit: modülün orijinal QR biti (1=koyu, 0=açık)
    is_sensor: bu modül reaktif sensör hücresi mi (layout['sensor_modules'])
    state: "fresh" | "transition" | "spoiled" | None (None -> nötr gri)
    """
    if not is_sensor:
        return (0, 0, 0) if bit else (255, 255, 255)
    tones = STATE_COLORS.get(state, NEUTRAL) if state else NEUTRAL
    return tones["dark"] if bit else tones["light"]
