/// Fixture payloads for the dashboard, shaped exactly like the real
/// `GET /api/dashboard/live` response (`flask_agrisense/app.py:326-352`).
///
/// Every builder returns a **fresh** map, so a test may mutate the result
/// without leaking state into the next test. Nothing here touches the network
/// or the clock: [kFixedNow] is the single pinned instant shared by every
/// dashboard test, which keeps golden text (relative ages, "stale" labels)
/// reproducible.
library;

/// Pinned "now" for every dashboard fixture and golden.
///
/// `DateTime` has no const constructor, hence `final` instead of `const`.
final DateTime kFixedNow = DateTime(2026, 11, 5, 9, 0);

/// Realistic healthy greenhouse: comfortable climate, pH/EC in range, NPK
/// measured, soil OK, two actuators running.
Map<String, dynamic> healthyPayload() {
  return <String, dynamic>{
    'device_id': 'esp32_greenhouse_01',
    'is_online': true,
    'uptime': 428400,
    'last_seen': kFixedNow
        .subtract(const Duration(seconds: 5))
        .toIso8601String(),
    'sensors': <String, dynamic>{
      'air_suhu': 27.6,
      'air_hum': 68.0,
      'tanah_suhu': 25.8,
      'tanah_lembap': 58.0,
      'ph': 6.1,
      'ec': 420.0,
      'n': 148.0,
      'p': 58.0,
      'k': 210.0,
      'soil_ok': true,
    },
    // Exhaust Blower (4) + Pompa Irigasi (5) are running.
    'relays': <bool>[false, false, false, false, true, true],
    'target_relays': <bool>[false, false, false, false, true, true],
    'ai': <String, dynamic>{
      'mode': 'auto',
      'phase': 'vegetatif',
      'ec_setpoint': 420.0,
      'model_version': 'v2.3.1',
    },
  };
}

/// Device went silent: `last_seen` 60 s before [kFixedNow] and the server
/// already reports `is_online: false` (server threshold is 15 s,
/// `app.py:324`). Sensor values are still the last known good ones, which is
/// what "keep the old data and flag it" must render.
Map<String, dynamic> stalePayload() {
  final payload = healthyPayload();
  payload['is_online'] = false;
  payload['last_seen'] = kFixedNow
      .subtract(const Duration(seconds: 60))
      .toIso8601String();
  return payload;
}

/// Probe attached but every channel is `null` and `soil_ok: false` — the
/// "sensor 7-in-1 tidak terdeteksi" state. Values must render as "—", never
/// as a fabricated `0.0`.
Map<String, dynamic> emptySensorsPayload() {
  return <String, dynamic>{
    'device_id': 'esp32_greenhouse_01',
    'is_online': true,
    'uptime': 428400,
    'last_seen': kFixedNow.toIso8601String(),
    'sensors': <String, dynamic>{
      'air_suhu': null,
      'air_hum': null,
      'tanah_suhu': null,
      'tanah_lembap': null,
      'ph': null,
      'ec': null,
      'n': null,
      'p': null,
      'k': null,
      'soil_ok': false,
    },
    'relays': <bool>[false, false, false, false, false, false],
    'target_relays': <bool>[false, false, false, false, false, false],
    'ai': <String, dynamic>{
      'mode': 'auto',
      'phase': 'vegetatif',
      'ec_setpoint': 420.0,
      'model_version': 'v2.3.1',
    },
  };
}

/// Half-broken payload: pH/EC probe offline (`null`), only N has a reading,
/// and the firmware sent a short `target_relays` array (3 entries instead of
/// 6) plus a short `relays` array. The mapper must pad to six without a
/// `RangeError` and must not invent values for the missing channels.
Map<String, dynamic> partialPayload() {
  return <String, dynamic>{
    'device_id': 'esp32_greenhouse_01',
    'is_online': true,
    'uptime': 428400,
    'last_seen': kFixedNow.toIso8601String(),
    'sensors': <String, dynamic>{
      'air_suhu': 29.1,
      'air_hum': 66.0,
      'tanah_suhu': 27.0,
      'tanah_lembap': 48.0,
      'ph': null,
      'ec': null,
      'n': 118.0,
      'p': null,
      'k': null,
      'soil_ok': true,
    },
    'relays': <bool>[true, false, false],
    'target_relays': <bool>[true, false, false],
    'ai': <String, dynamic>{
      'mode': 'manual',
      'phase': 'generatif',
      'ec_setpoint': 380.0,
      'model_version': 'v2.3.1',
    },
  };
}
