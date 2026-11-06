import 'package:flutter_test/flutter_test.dart';
import 'package:green_house_app/features/dashboard/domain/dashboard_snapshot.dart';

/// Payload shape produced by `flask_agrisense/app.py` (`/api/dashboard/live`).
Map<String, dynamic> fullPayload() => <String, dynamic>{
  'device_id': 'gh-01',
  'is_online': true,
  'uptime': 86400,
  'last_seen': '2026-11-05T09:00:00Z',
  'sensors': <String, dynamic>{
    'air_suhu': 28.4,
    'air_hum': 71.5,
    'tanah_suhu': 26.1,
    'tanah_lembap': 62.0,
    'ph': 6.1,
    'ec': 1240,
    'n': 152,
    'p': 58,
    'k': 214,
    'soil_ok': true,
  },
  'relays': <bool>[true, false, false, true, false, true],
  'target_relays': <bool>[true, false, true, false, false, true],
  'ai': <String, dynamic>{
    'mode': 'dosing',
    'phase': 'idle',
    'ec_setpoint': 1200,
    'model_version': 'v2',
  },
};

void main() {
  group('DashboardSnapshot.fromJson - happy path', () {
    test('reads every sensor, relay, and AI field from the real payload', () {
      final snapshot = DashboardSnapshot.fromJson(fullPayload());

      expect(snapshot.airTemp, 28.4);
      expect(snapshot.airHum, 71.5);
      expect(snapshot.soilTemp, 26.1);
      expect(snapshot.soilMoisture, 62.0);
      expect(snapshot.ph, 6.1);
      expect(snapshot.ec, 1240);
      expect(snapshot.n, 152);
      expect(snapshot.p, 58);
      expect(snapshot.k, 214);

      expect(snapshot.isOnline, isTrue);
      expect(snapshot.lastSeen, DateTime.utc(2026, 11, 5, 9));
      expect(snapshot.aiMode, 'dosing');
      expect(snapshot.soilOk, isTrue);

      expect(snapshot.targetRelays, <bool>[
        true,
        false,
        true,
        false,
        false,
        true,
      ]);
      expect(snapshot.actualRelays, <bool>[
        true,
        false,
        false,
        true,
        false,
        true,
      ]);
    });

    test('parses a last_seen value with an explicit UTC offset', () {
      final snapshot = DashboardSnapshot.fromJson(<String, dynamic>{
        'last_seen': '2026-11-05T16:00:00+07:00',
      });

      expect(snapshot.lastSeen, DateTime.utc(2026, 11, 5, 9));
    });
  });

  group('DashboardSnapshot.fromJson - empty and malformed input', () {
    test('empty payload yields nulls, six false relays, and auto mode', () {
      final snapshot = DashboardSnapshot.fromJson(<String, dynamic>{});

      expect(snapshot.airTemp, isNull);
      expect(snapshot.airHum, isNull);
      expect(snapshot.soilTemp, isNull);
      expect(snapshot.soilMoisture, isNull);
      expect(snapshot.ph, isNull);
      expect(snapshot.ec, isNull);
      expect(snapshot.n, isNull);
      expect(snapshot.p, isNull);
      expect(snapshot.k, isNull);

      expect(snapshot.isOnline, isFalse);
      expect(snapshot.lastSeen, isNull);
      expect(snapshot.aiMode, 'auto');
      expect(snapshot.soilOk, isTrue);
      expect(snapshot.hasNoReadings, isTrue);

      expect(snapshot.targetRelays, List<bool>.filled(6, false));
      expect(snapshot.actualRelays, List<bool>.filled(6, false));
    });

    test('a short target_relays list is padded to six entries', () {
      final snapshot = DashboardSnapshot.fromJson(<String, dynamic>{
        'target_relays': <bool>[true, false, true],
      });

      expect(snapshot.targetRelays, hasLength(6));
      expect(snapshot.targetRelays, <bool>[
        true,
        false,
        true,
        false,
        false,
        false,
      ]);
    });

    test('a long target_relays list is truncated to six entries', () {
      final snapshot = DashboardSnapshot.fromJson(<String, dynamic>{
        'target_relays': <bool>[
          true,
          true,
          false,
          false,
          true,
          false,
          true,
          true,
        ],
      });

      expect(snapshot.targetRelays, hasLength(6));
      expect(snapshot.targetRelays, <bool>[
        true,
        true,
        false,
        false,
        true,
        false,
      ]);
    });

    test(
      'single-entry target_relays (old RangeError payload) does not throw',
      () {
        expect(
          () => DashboardSnapshot.fromJson(<String, dynamic>{
            'target_relays': <bool>[true],
          }),
          returnsNormally,
        );

        final snapshot = DashboardSnapshot.fromJson(<String, dynamic>{
          'target_relays': <bool>[true],
        });
        expect(snapshot.targetRelays, hasLength(6));
        expect(snapshot.targetRelays.first, isTrue);
        expect(snapshot.targetRelays.skip(1), everyElement(isFalse));
      },
    );

    test('garbage types never throw and collapse to safe defaults', () {
      late final DashboardSnapshot snapshot;
      expect(
        () => snapshot = DashboardSnapshot.fromJson(<String, dynamic>{
          'sensors': 'not-a-map',
          'target_relays': 'not-a-list',
          'relays': 42,
          'ai': 7,
          'is_online': 'true',
          'last_seen': 'not-a-date',
        }),
        returnsNormally,
      );

      expect(snapshot.airTemp, isNull);
      expect(snapshot.ph, isNull);
      expect(snapshot.targetRelays, List<bool>.filled(6, false));
      expect(snapshot.actualRelays, List<bool>.filled(6, false));
      expect(snapshot.aiMode, 'auto');
      expect(snapshot.isOnline, isTrue);
      expect(snapshot.lastSeen, isNull);
    });

    test('non-boolean relay entries fall back to false', () {
      final snapshot = DashboardSnapshot.fromJson(<String, dynamic>{
        'target_relays': <Object?>['yes', null, 1, 0, 'nope', true],
      });

      expect(snapshot.targetRelays, <bool>[
        true,
        false,
        true,
        false,
        false,
        true,
      ]);
    });
  });

  group('DashboardSnapshot.fromJson - numeric coercion', () {
    test('numeric strings are parsed, non-numeric strings become null', () {
      final snapshot = DashboardSnapshot.fromJson(<String, dynamic>{
        'sensors': <String, dynamic>{
          'air_suhu': '28.4',
          'air_hum': ' 71.5 ',
          'tanah_suhu': 'abc',
          'tanah_lembap': '',
          'ph': '6.1',
          'ec': '1240',
          'n': true,
          'p': <String, dynamic>{},
          'k': null,
        },
      });

      expect(snapshot.airTemp, 28.4);
      expect(snapshot.airHum, 71.5);
      expect(snapshot.soilTemp, isNull);
      expect(snapshot.soilMoisture, isNull);
      expect(snapshot.ph, 6.1);
      expect(snapshot.ec, 1240);
      expect(snapshot.n, isNull);
      expect(snapshot.p, isNull);
      expect(snapshot.k, isNull);
    });

    test('non-finite numbers become null instead of NaN/Infinity', () {
      final snapshot = DashboardSnapshot.fromJson(<String, dynamic>{
        'sensors': <String, dynamic>{
          'air_suhu': double.nan,
          'air_hum': double.infinity,
        },
      });

      expect(snapshot.airTemp, isNull);
      expect(snapshot.airHum, isNull);
    });
  });

  group('DashboardSnapshot.fromJson - AI mode', () {
    test('ai.mode wins over the legacy ai_mode key', () {
      final snapshot = DashboardSnapshot.fromJson(<String, dynamic>{
        'ai_mode': 'legacy',
        'ai': <String, dynamic>{'mode': 'Dosing'},
      });

      expect(snapshot.aiMode, 'dosing');
    });

    test('legacy ai_mode is used when ai.mode is absent', () {
      final snapshot = DashboardSnapshot.fromJson(<String, dynamic>{
        'ai_mode': 'Manual',
        'ai': <String, dynamic>{'phase': 'idle'},
      });

      expect(snapshot.aiMode, 'manual');
    });

    test('missing AI block falls back to auto', () {
      final snapshot = DashboardSnapshot.fromJson(<String, dynamic>{
        'ai': <String, dynamic>{'mode': null},
      });

      expect(snapshot.aiMode, 'auto');
    });
  });

  group('DashboardSnapshot - immutability', () {
    test('relay lists cannot be mutated after construction', () {
      final snapshot = DashboardSnapshot.fromJson(fullPayload());

      expect(() => snapshot.targetRelays[0] = false, throwsUnsupportedError);
      expect(() => snapshot.actualRelays.add(true), throwsUnsupportedError);
    });

    test('direct construction normalizes relay lists too', () {
      final snapshot = DashboardSnapshot(
        targetRelays: <bool>[true],
        actualRelays: <bool>[true, true, true, true, true, true, true, true],
      );

      expect(snapshot.targetRelays, hasLength(6));
      expect(snapshot.actualRelays, hasLength(6));
      expect(snapshot.targetRelays.first, isTrue);
    });
  });
}
