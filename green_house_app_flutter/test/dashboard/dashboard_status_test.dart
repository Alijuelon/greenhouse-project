import 'package:flutter_test/flutter_test.dart';
import 'package:green_house_app/features/dashboard/domain/dashboard_snapshot.dart';
import 'package:green_house_app/features/dashboard/domain/dashboard_status.dart';

/// Fixed clock so the tests never depend on wall time.
final DateTime now = DateTime.utc(2026, 11, 5, 9);

DashboardSnapshot healthy({
  double? airTemp = 27.0,
  double? airHum = 70.0,
  double? ph = 6.0,
  double? ec = 1200.0,
  double? soilMoisture = 62.0,
  bool isOnline = true,
  DateTime? lastSeen,
  bool soilOk = true,
}) {
  return DashboardSnapshot(
    airTemp: airTemp,
    airHum: airHum,
    ph: ph,
    ec: ec,
    soilMoisture: soilMoisture,
    isOnline: isOnline,
    lastSeen: lastSeen ?? now,
    soilOk: soilOk,
  );
}

void main() {
  group('resolveStatus - offline', () {
    test('lastSeen 20 seconds ago is offline (default 15s threshold)', () {
      final snapshot = healthy(
        lastSeen: now.subtract(const Duration(seconds: 20)),
      );

      expect(resolveStatus(snapshot, now: now), GreenhouseStatus.offline);
    });

    test('is_online false is offline even when lastSeen is fresh', () {
      expect(
        resolveStatus(healthy(isOnline: false), now: now),
        GreenhouseStatus.offline,
      );
    });

    test('a missing lastSeen is offline', () {
      final snapshot = DashboardSnapshot(isOnline: true);

      expect(snapshot.lastSeen, isNull);
      expect(resolveStatus(snapshot, now: now), GreenhouseStatus.offline);
    });

    test('exactly 15 seconds old is still online, 1 ms later is offline', () {
      expect(
        resolveStatus(
          healthy(lastSeen: now.subtract(const Duration(seconds: 15))),
          now: now,
        ),
        isNot(GreenhouseStatus.offline),
      );
      expect(
        resolveStatus(
          healthy(
            lastSeen: now.subtract(
              const Duration(seconds: 15, milliseconds: 1),
            ),
          ),
          now: now,
        ),
        GreenhouseStatus.offline,
      );
    });

    test('a custom staleAfter window is honored', () {
      final snapshot = healthy(
        lastSeen: now.subtract(const Duration(seconds: 40)),
      );

      expect(
        resolveStatus(
          snapshot,
          now: now,
          staleAfter: const Duration(minutes: 1),
        ),
        GreenhouseStatus.optimal,
      );
      expect(
        resolveStatus(
          snapshot,
          now: now,
          staleAfter: const Duration(seconds: 30),
        ),
        GreenhouseStatus.offline,
      );
    });
  });

  group('resolveStatus - attention', () {
    test('pH 4.9 needs attention and reports the pH reason', () {
      final snapshot = healthy(ph: 4.9);

      expect(resolveStatus(snapshot, now: now), GreenhouseStatus.attention);
      expect(attentionReasons(snapshot), hasLength(1));
      expect(attentionReasons(snapshot).single, contains('pH 4.9'));
    });

    test('temperature above the 24-30 C band needs attention', () {
      final snapshot = healthy(airTemp: 31.5);

      expect(resolveStatus(snapshot, now: now), GreenhouseStatus.attention);
      expect(attentionReasons(snapshot).single, contains('Suhu udara'));
    });

    test('humidity below the 60-80 % band needs attention', () {
      final snapshot = healthy(airHum: 55);

      expect(resolveStatus(snapshot, now: now), GreenhouseStatus.attention);
      expect(attentionReasons(snapshot).single, contains('Kelembapan udara'));
    });

    test('EC below 300 needs attention', () {
      final snapshot = healthy(ec: 250);

      expect(resolveStatus(snapshot, now: now), GreenhouseStatus.attention);
      expect(attentionReasons(snapshot).single, contains('EC 250'));
    });

    test('soil moisture below 40 % needs attention', () {
      final snapshot = healthy(soilMoisture: 35);

      expect(resolveStatus(snapshot, now: now), GreenhouseStatus.attention);
      expect(attentionReasons(snapshot).single, contains('Kelembapan tanah'));
    });

    test('soil_ok false needs attention even when all readings look fine', () {
      final snapshot = healthy(soilOk: false);

      expect(resolveStatus(snapshot, now: now), GreenhouseStatus.attention);
      expect(attentionReasons(snapshot).single, contains('Sensor tanah'));
    });

    test('multiple faults produce multiple reasons in priority order', () {
      final snapshot = healthy(airTemp: 33, ph: 4.5);

      expect(attentionReasons(snapshot), hasLength(2));
      expect(attentionReasons(snapshot).first, contains('Suhu udara'));
      expect(attentionReasons(snapshot).last, contains('pH 4.5'));
    });
  });

  group('resolveStatus - optimal', () {
    test('every reading inside the envelope is optimal', () {
      final snapshot = healthy();

      expect(attentionReasons(snapshot), isEmpty);
      expect(resolveStatus(snapshot, now: now), GreenhouseStatus.optimal);
    });

    test('values exactly on the bounds are still optimal', () {
      expect(
        resolveStatus(healthy(airTemp: 24), now: now),
        GreenhouseStatus.optimal,
      );
      expect(
        resolveStatus(healthy(airTemp: 30), now: now),
        GreenhouseStatus.optimal,
      );
      expect(
        resolveStatus(healthy(airHum: 60), now: now),
        GreenhouseStatus.optimal,
      );
      expect(
        resolveStatus(healthy(airHum: 80), now: now),
        GreenhouseStatus.optimal,
      );
      expect(
        resolveStatus(healthy(ph: 5.5), now: now),
        GreenhouseStatus.optimal,
      );
      expect(
        resolveStatus(healthy(ph: 6.5), now: now),
        GreenhouseStatus.optimal,
      );
      expect(
        resolveStatus(healthy(ec: 300), now: now),
        GreenhouseStatus.optimal,
      );
      expect(
        resolveStatus(healthy(soilMoisture: 40), now: now),
        GreenhouseStatus.optimal,
      );
    });
  });

  group('resolveStatus - null readings', () {
    test('null readings never produce a reason and never force attention', () {
      final snapshot = DashboardSnapshot(
        isOnline: true,
        lastSeen: now,
        aiMode: 'auto',
      );

      expect(snapshot.hasNoReadings, isTrue);
      expect(attentionReasons(snapshot), isEmpty);
      expect(resolveStatus(snapshot, now: now), GreenhouseStatus.optimal);
    });

    test('an empty JSON payload is offline, not attention', () {
      final snapshot = DashboardSnapshot.fromJson(<String, dynamic>{});

      expect(attentionReasons(snapshot), isEmpty);
      expect(resolveStatus(snapshot, now: now), GreenhouseStatus.offline);
    });

    test(
      'partial payload keeps null metrics silent while flagging known faults',
      () {
        final snapshot = DashboardSnapshot.fromJson(<String, dynamic>{
          'is_online': true,
          'last_seen': '2026-11-05T09:00:00Z',
          'sensors': <String, dynamic>{'ph': 4.9, 'ec': null, 'n': null},
          'target_relays': <bool>[true],
        });

        expect(attentionReasons(snapshot), hasLength(1));
        expect(attentionReasons(snapshot).single, contains('pH 4.9'));
        expect(resolveStatus(snapshot, now: now), GreenhouseStatus.attention);
      },
    );
  });

  group('attentionReasons - immutability', () {
    test('the returned list cannot be mutated', () {
      final reasons = attentionReasons(healthy(ph: 4.9));

      expect(() => reasons.add('fake'), throwsUnsupportedError);
    });
  });
}
