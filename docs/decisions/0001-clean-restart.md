# 0001 — Temiz Yeniden Başlangıç

**Durum:** kabul edildi · **Tarih:** 2026-09-10 · **Kaynak:** Devir Raporu §2

## Karar

Eski mobil uygulama / eski kod **yamalanmaz.** Yeni Git deposu ile temiz sistem
kurulur. Eski dokümanlar yalnızca proje bağlamı, karşılaşılan sorunlar ve denenmiş
yöntemler için referanstır.

## Kopyalanmayacaklar (§2 "Ne kopyalanmamalı?")

- Eski uygulamanın klasör yapısı
- Framework seçimi (yeniden değerlendirilir — [0002](0002-framework-spike.md))
- Eski QR layout'u (merkez sensör yaklaşımı **güncel değil** — §5)
- Renk eşikleri (profile'dan gelir, koda gömülmez — §6.3)
- Raporda yazılı ama doğrulanmamış algoritmalar ("doğru çözüm" sayılmaz)

## Kaynak önceliği (§2)

1. Güncel devir raporu kararları
2. Onaylı proje dosyası fonksiyonel hedefleri ve başarı ölçütleri
3. Güncel sensör/veri girdileri
4. Literatür ve deneysel karşılaştırmalar
