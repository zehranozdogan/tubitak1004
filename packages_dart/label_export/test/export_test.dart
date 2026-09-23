// export.dart testleri — packages/label_export/export.py'nin render-öncesi
// kısmının Dart portu (bkz. lib/src/export.dart dosya başlığı).
//
// DOĞRULAMA: gerçek Python (`generate_qr`+`reactive_candidates`+
// `select_reactive_modules`+`build_layout`+`validate`, AYNI payload,
// density='low', seed=seed_from_layout_version(...)) çalıştırılıp
// qr.version/qr.error/layout.matrix_size/seçilen reaktif hücre SAYISI
// (RNG'den ÖNCEKİ, saf geometriden türeyen hedef) karşılaştırıldı — TAM
// eşleşiyor (12, H, 65, 75). HANGİ hücrelerin seçildiği RNG algoritma farkı
// yüzünden Python'la eşleşmiyor — bu qr_layout/reactive.dart'ta ZATEN
// belgelenmiş, kasıtlı bir mimari sapma, burada tekrar test EDİLMEDİ.
import 'package:label_export/label_export.dart';
import 'package:profile_schema/profile_schema.dart' as schema;
import 'package:qr_layout/qr_layout.dart' show seedFromLayoutVersion;
import 'package:test/test.dart';

schema.LabelPayload _referencePayload() => buildLabelPayload(
      productId: 'P-001',
      productType: 'balik', // trim+uppercase normalizasyonunu da test eder
      productionDate: '2026-09-23',
      sensorProfileId: 'SP-STD-1',
      layoutVersion: 'L-2026-09-23-A',
    );

void main() {
  group('buildLabelPayload', () {
    test('trim + product_type büyük harf normalizasyonu, şema doğrulaması geçer', () {
      final payload = _referencePayload();
      expect(payload.productId, 'P-001');
      expect(payload.productType, 'BALIK');
      expect(payload.productionDate, '2026-09-23');
      expect(payload.sensorProfileId, 'SP-STD-1');
      expect(payload.layoutVersion, 'L-2026-09-23-A');
    });

    test('geçersiz production_date -> SchemaValidationException (schema kuralı, tekrar test edilmedi ama tetiklendiği doğrulanıyor)', () {
      expect(
        () => buildLabelPayload(
          productId: 'P-001',
          productType: 'BALIK',
          productionDate: '23-09-2026', // yanlış format
          sensorProfileId: 'SP-STD-1',
          layoutVersion: 'L-1',
        ),
        throwsA(isA<schema.SchemaValidationException>()),
      );
    });
  });

  test('labelPayloadQrText: gerçek Python json.dumps(separators=(",",":")) ile BİREBİR aynı kompakt biçim', () {
    final payload = _referencePayload();
    expect(
      labelPayloadQrText(payload),
      '{"product_id":"P-001","product_type":"BALIK","production_date":"2026-09-23",'
      '"sensor_profile_id":"SP-STD-1","layout_version":"L-2026-09-23-A"}',
    );
  });

  group('generateLabel (uçtan uca, render-öncesi — bkz. dosya başlığı)', () {
    test('gerçek Python ile version/ecc/matrix_size/hücre SAYISI eşleşir', () {
      final payload = _referencePayload();
      final seed = seedFromLayoutVersion(payload.layoutVersion);
      final label = generateLabel(payload, seed: seed);

      expect(label.qr.version, 12);
      expect(label.qr.eccLevel, 'H');
      expect(label.layout.matrixSize, 65);
      expect(label.layout.qrVersion, 12);
      expect(label.layout.eccLevel, 'H');
      expect(label.layout.sensorModules.length, 75); // gerçek Python select_reactive_modules ile AYNI hedef sayı
      expect(label.layout.layoutVersion, payload.layoutVersion);
      expect(label.layoutJson['layout_version'], payload.layoutVersion);
    });

    test('seed=null iken seedFromLayoutVersion ile TÜRETİLEN seed kullanılmış gibi davranır (determinizm)', () {
      final payload = _referencePayload();
      final withExplicitSeed = generateLabel(payload, seed: seedFromLayoutVersion(payload.layoutVersion));
      final withDefaultSeed = generateLabel(payload); // seed=null -> içeride aynı türetme
      expect(withDefaultSeed.layout.sensorModules, withExplicitSeed.layout.sensorModules);
    });

    test('aynı layout_version -> aynı seçim (determinizm, fiziksel şablon tekrarlanabilir, §5.2/7)', () {
      final payload = _referencePayload();
      final first = generateLabel(payload);
      final second = generateLabel(payload);
      expect(first.layout.sensorModules, second.layout.sensorModules);
    });

    test('farklı layout_version -> farklı seçim', () {
      final payload = _referencePayload();
      final otherPayload = buildLabelPayload(
        productId: payload.productId,
        productType: payload.productType,
        productionDate: payload.productionDate,
        sensorProfileId: payload.sensorProfileId,
        layoutVersion: 'L-2026-09-23-B',
      );
      final a = generateLabel(payload);
      final b = generateLabel(otherPayload);
      expect(a.layout.sensorModules, isNot(equals(b.layout.sensorModules)));
    });

    test('varsayılan reference_regions sadece finder white/black (render entegre olana dek — bkz. dosya başlığı)', () {
      final label = generateLabel(_referencePayload());
      expect(label.layout.referenceRegions.keys.toSet(), {'black', 'white'});
      expect(label.layout.referenceRegions['black'], [(3, 3)]);
      expect(label.layout.referenceRegions['white'], [(1, 1)]);
    });

    test('layout şemaya göre GEÇERLİ (LayoutVersionData.fromJson hata fırlatmadı, decoder_check dahil)', () {
      final label = generateLabel(_referencePayload());
      expect(label.layout.decoderCheck, isNotNull);
      expect(label.layout.decoderCheck!.colorStates, ['fresh', 'transition', 'spoiled']);
      expect(label.layout.intentionalErrors, isEmpty);
      expect(label.layout.moduleDensity, 'low');
    });
  });
}
