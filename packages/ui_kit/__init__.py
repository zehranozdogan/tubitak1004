"""ui_kit — Flet prototip arayüzleri için ortak tasarım sistemi.

apps/producer ve apps/consumer (Flet prototipi) bunu kullanır. Gerçek tüketici
uygulaması Flutter/native olacağından bu paket yalnızca prototip/masaüstü içindir
(bkz. docs/decisions/0002-framework-spike.md).
"""

from packages.ui_kit import theme
from packages.ui_kit.components import (
    app_header,
    icon_badge,
    kv,
    nav_tile,
    primary_button,
    screen,
    section_card,
    stat_card,
    text_field,
)

__all__ = [
    "theme",
    "app_header",
    "icon_badge",
    "kv",
    "nav_tile",
    "primary_button",
    "screen",
    "section_card",
    "stat_card",
    "text_field",
]
