"""label_export — etiket paketi üretimi (label_payload + layout_version + PNG/PDF).

Framework'ten bağımsız iş mantığı (rapor §8). `apps/consumer`'ın Yönetici
ekranı bunu kullanır; ileride ayrı bir üretici uygulaması gerekirse aynen
oradan da kullanılabilir.
"""

from packages.label_export.export import build_label_payload, export_label

__all__ = ["build_label_payload", "export_label"]
