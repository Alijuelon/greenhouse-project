import 'package:flutter/foundation.dart';

/// Immutable, tolerant view over the `/api/dashboard/live` payload.
///
/// Every reading is nullable on purpose: a missing, `null`, or malformed value
/// must surface as "no data" in the UI instead of a fabricated `0.0`.
///
/// The mapper never throws. Unknown shapes (a non-map `sensors`, a string
/// where a list belongs, a scalar `ai` block) collapse to safe defaults so a
/// broken device payload can still be rendered.
@immutable
class DashboardSnapshot {
  DashboardSnapshot({
    this.airTemp,
    this.airHum,
    this.soilTemp,
    this.soilMoisture,
    this.ph,
    this.ec,
    this.n,
    this.p,
    this.k,
    this.isOnline = false,
    this.lastSeen,
    this.aiMode = 'auto',
    this.soilOk = true,
    List<bool>? targetRelays,
    List<bool>? actualRelays,
  }) : targetRelays = _normalizeRelays(targetRelays),
       actualRelays = _normalizeRelays(actualRelays);

  /// Builds a snapshot from the raw Flask payload:
  /// `{device_id, is_online, last_seen, sensors{...}, relays, target_relays, ai{...}}`.
  factory DashboardSnapshot.fromJson(Map<String, dynamic> json) {
    final sensors = _asMap(json['sensors']);
    return DashboardSnapshot(
      airTemp: _toDouble(sensors['air_suhu']),
      airHum: _toDouble(sensors['air_hum']),
      soilTemp: _toDouble(sensors['tanah_suhu']),
      soilMoisture: _toDouble(sensors['tanah_lembap']),
      ph: _toDouble(sensors['ph']),
      ec: _toDouble(sensors['ec']),
      n: _toDouble(sensors['n']),
      p: _toDouble(sensors['p']),
      k: _toDouble(sensors['k']),
      isOnline: _toBool(json['is_online']) ?? false,
      lastSeen: _toDateTime(json['last_seen']),
      aiMode: _resolveAiMode(json),
      // A missing `soil_ok` is "no information", not a fault report.
      soilOk: _toBool(sensors['soil_ok']) ?? true,
      targetRelays: _toRelayList(json['target_relays']),
      actualRelays: _toRelayList(json['relays']),
    );
  }

  /// Number of relays exposed by the ESP32.
  static const int relayCount = 6;

  final double? airTemp;
  final double? airHum;
  final double? soilTemp;
  final double? soilMoisture;
  final double? ph;
  final double? ec;
  final double? n;
  final double? p;
  final double? k;

  final bool isOnline;
  final DateTime? lastSeen;

  /// Normalized (trimmed, lowercased) AI mode, e.g. `auto`, `dosing`.
  final String aiMode;

  final bool soilOk;

  /// Requested relay states, always exactly [relayCount] entries.
  final List<bool> targetRelays;

  /// Reported relay states, always exactly [relayCount] entries.
  final List<bool> actualRelays;

  /// `true` when the payload carried no sensor readings at all.
  bool get hasNoReadings =>
      airTemp == null &&
      airHum == null &&
      soilTemp == null &&
      soilMoisture == null &&
      ph == null &&
      ec == null &&
      n == null &&
      p == null &&
      k == null;

  static Map<String, dynamic> _asMap(Object? value) {
    if (value is Map) {
      final result = <String, dynamic>{};
      value.forEach((key, item) => result[key.toString()] = item);
      return result;
    }
    return const <String, dynamic>{};
  }

  static double? _toDouble(Object? value) {
    if (value is num) {
      final parsed = value.toDouble();
      return parsed.isFinite ? parsed : null;
    }
    if (value is String) {
      final parsed = double.tryParse(value.trim());
      return parsed != null && parsed.isFinite ? parsed : null;
    }
    return null;
  }

  static bool? _toBool(Object? value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      switch (value.trim().toLowerCase()) {
        case 'true':
        case '1':
        case 'on':
        case 'yes':
          return true;
        case 'false':
        case '0':
        case 'off':
        case 'no':
          return false;
      }
    }
    return null;
  }

  static DateTime? _toDateTime(Object? value) {
    if (value is DateTime) return value;
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return null;
      return DateTime.tryParse(trimmed) ??
          DateTime.tryParse(trimmed.replaceFirst(RegExp(r'[Zz]$'), ''));
    }
    return null;
  }

  static String _resolveAiMode(Map<String, dynamic> json) {
    final ai = _asMap(json['ai']);
    final raw = ai['mode'] ?? json['ai_mode'] ?? 'auto';
    final String mode;
    if (raw is String) {
      mode = raw.trim().toLowerCase();
    } else if (raw is num || raw is bool) {
      mode = raw.toString().toLowerCase();
    } else {
      mode = '';
    }
    return mode.isEmpty || mode == 'null' ? 'auto' : mode;
  }

  static List<bool> _toRelayList(Object? value) {
    if (value is! List) return _normalizeRelays(null);
    final flags = <bool>[];
    for (final item in value) {
      flags.add(_toBool(item) ?? false);
      if (flags.length == relayCount) break;
    }
    return _normalizeRelays(flags);
  }

  static List<bool> _normalizeRelays(List<bool>? values) {
    final result = <bool>[];
    if (values != null) {
      for (final value in values) {
        result.add(value);
        if (result.length == relayCount) break;
      }
    }
    while (result.length < relayCount) {
      result.add(false);
    }
    return List<bool>.unmodifiable(result);
  }
}
