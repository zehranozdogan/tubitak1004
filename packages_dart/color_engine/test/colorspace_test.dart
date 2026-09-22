// colorspace.dart testleri — REFERANS DEĞERLER Python'ın gerçek
// packages/color_engine/colorspace.py (yani scikit-image'ın rgb2lab/
// deltaE_ciede2000) çalıştırılarak üretildi, TAHMİN EDİLMEDİ:
//
//   .venv/Scripts/python.exe -c "..." (bkz. sohbet geçmişi, 22 Eylül)
//
// Tolerans 1e-3 — iki farklı dil/kütüphanenin kayan nokta yuvarlamalarını
// hesaba katmak için (skimage float64 kullanıyor, burada da double
// kullanılıyor — aynı hassasiyet, fark yalnızca işlem sırası/derleyici
// kaynaklı en düşük anlamlı basamaklarda beklenir).

import 'package:color_engine/color_engine.dart';
import 'package:test/test.dart';

void main() {
  group('rgbToLab (referans: gerçek Python rgb_to_lab çıktısı)', () {
    void check(String name, Rgb rgb, double L, double a, double b) {
      test(name, () {
        final lab = rgbToLab(rgb);
        expect(lab.L, closeTo(L, 1e-3));
        expect(lab.a, closeTo(a, 1e-3));
        expect(lab.b, closeTo(b, 1e-3));
      });
    }

    check('black', const Rgb(0, 0, 0), 0.0, 0.0, 0.0);
    check('white', const Rgb(255, 255, 255), 100.0, -0.0024549378621063767, 0.004653421154054982);
    check('gray128', const Rgb(128, 128, 128), 53.585013452169036, -0.0014726455531133276, 0.0027914514965976522);
    check('red', const Rgb(255, 0, 0), 53.2405879437449, 80.0923082256922, 67.2027510444287);
    check('green', const Rgb(0, 255, 0), 87.73509948831895, -86.18302974439501, 83.1797031753845);
    check('blue', const Rgb(0, 0, 255), 32.29567256501352, 79.18559091176553, -107.85730020669489);

    // packages/qr_layout/colors.py::STATE_COLORS'daki gerçek Putresin
    // renkleri — bu portun asıl kullanılacağı gerçek değerler.
    check('fresh_light', const Rgb(214, 205, 196), 82.88412474974946, 1.5579307813247123, 5.5880825827570035);
    check('fresh_dark', const Rgb(193, 176, 160), 72.84389933403213, 3.437135763629917, 10.407216732228797);
    check('transition_light', const Rgb(150, 128, 112), 55.16802787723003, 5.815676563255323, 11.81279820823855);
    check('transition_dark', const Rgb(110, 92, 84), 40.58909294546274, 5.918955364423384, 7.327849945761988);
    check('spoiled_light', const Rgb(78, 66, 66), 29.183320314952738, 5.138341779628464, 1.9069469492217106);
    check('spoiled_dark', const Rgb(54, 50, 58), 21.472220362445746, 3.638589585904989, -4.397426184843023);
  });

  group('deltaE (referans: gerçek Python delta_e/CIEDE2000 çıktısı)', () {
    // rgbToLab zaten ayrı doğrulandığı için burada doğrudan Lab
    // kullanılıyor (Python tarafındaki labs[...] sözlüğünün birebir aynısı).
    const black = Lab(0.0, 0.0, 0.0);
    const white = Lab(100.0, -0.0024549378621063767, 0.004653421154054982);
    const freshLight = Lab(82.88412474974946, 1.5579307813247123, 5.5880825827570035);
    const freshDark = Lab(72.84389933403213, 3.437135763629917, 10.407216732228797);
    const transitionLight = Lab(55.16802787723003, 5.815676563255323, 11.81279820823855);
    const transitionDark = Lab(40.58909294546274, 5.918955364423384, 7.327849945761988);
    const spoiledLight = Lab(29.183320314952738, 5.138341779628464, 1.9069469492217106);
    const spoiledDark = Lab(21.472220362445746, 3.638589585904989, -4.397426184843023);
    const red = Lab(53.2405879437449, 80.0923082256922, 67.2027510444287);
    const green = Lab(87.73509948831895, -86.18302974439501, 83.1797031753845);
    const gray128 = Lab(53.585013452169036, -0.0014726455531133276, 0.0027914514965976522);

    void check(String name, Lab a, Lab b, double expected) {
      test(name, () {
        expect(deltaE(a, b), closeTo(expected, 1e-3));
      });
    }

    check('black vs white', black, white, 100.00000017602524);
    check('fresh_light vs fresh_dark', freshLight, freshDark, 8.156056234104648);
    check('fresh_dark vs spoiled_dark', freshDark, spoiledDark, 51.78801571080572);
    check('transition_light vs transition_dark', transitionLight, transitionDark, 14.787957917081542);
    check('red vs green', red, green, 86.608459469392);
    check('fresh_dark vs fresh_dark (özdeş)', freshDark, freshDark, 0.0);
    check('spoiled_light vs spoiled_dark', spoiledLight, spoiledDark, 8.061793216309614);
    check('gray128 vs gray128 (özdeş)', gray128, gray128, 0.0);
  });
}
