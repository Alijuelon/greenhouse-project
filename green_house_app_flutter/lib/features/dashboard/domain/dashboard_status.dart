import 'dashboard_snapshot.dart';

/// Aggregate health of the greenhouse, derived from a [DashboardSnapshot].
enum GreenhouseStatus { optimal, attention, offline }

/// Ideal operating envelope. Values exactly on a bound are considered inside.
const double airTempMin = 24;
const double airTempMax = 30;
const double airHumMin = 60;
const double airHumMax = 80;
const double phMin = 5.5;
const double phMax = 6.5;
const double ecMin = 300;
const double soilMoistureMin = 40;

/// A reading older than this is treated as stale, matching the server's own
/// `is_online` threshold (`last_seen < 15s` in the Flask backend).
const Duration defaultStaleAfter = Duration(seconds: 15);

/// Pure resolution of the dashboard status. Never throws, never mutates.
///
/// Offline wins over attention: data that is missing, flagged offline, or older
/// than [staleAfter] cannot be trusted enough to judge.
GreenhouseStatus resolveStatus(
  DashboardSnapshot snapshot, {
  required DateTime now,
  Duration staleAfter = defaultStaleAfter,
}) {
  if (!snapshot.isOnline) return GreenhouseStatus.offline;

  final lastSeen = snapshot.lastSeen;
  if (lastSeen == null) return GreenhouseStatus.offline;
  if (now.difference(lastSeen) > staleAfter) return GreenhouseStatus.offline;

  return attentionReasons(snapshot).isEmpty
      ? GreenhouseStatus.optimal
      : GreenhouseStatus.attention;
}

/// Human-readable reasons the greenhouse needs attention, in priority order.
///
/// A `null` reading never produces a reason: unknown is not the same as wrong.
List<String> attentionReasons(DashboardSnapshot snapshot) {
  final reasons = <String>[];

  final airTemp = snapshot.airTemp;
  if (airTemp != null && (airTemp < airTempMin || airTemp > airTempMax)) {
    reasons.add(
      'Suhu udara ${_format(airTemp)} °C di luar '
      '${_format(airTempMin)}–${_format(airTempMax)} °C',
    );
  }

  final airHum = snapshot.airHum;
  if (airHum != null && (airHum < airHumMin || airHum > airHumMax)) {
    reasons.add(
      'Kelembapan udara ${_format(airHum)} % di luar '
      '${_format(airHumMin)}–${_format(airHumMax)} %',
    );
  }

  final ph = snapshot.ph;
  if (ph != null && (ph < phMin || ph > phMax)) {
    reasons.add(
      'pH ${_format(ph)} di luar ${_format(phMin)}–${_format(phMax)}',
    );
  }

  final ec = snapshot.ec;
  if (ec != null && ec < ecMin) {
    reasons.add('EC ${_format(ec)} µS/cm di bawah ${_format(ecMin)}');
  }

  final soilMoisture = snapshot.soilMoisture;
  if (soilMoisture != null && soilMoisture < soilMoistureMin) {
    reasons.add(
      'Kelembapan tanah ${_format(soilMoisture)} % di bawah '
      '${_format(soilMoistureMin)} %',
    );
  }

  if (!snapshot.soilOk) {
    reasons.add('Sensor tanah melaporkan masalah');
  }

  return List<String>.unmodifiable(reasons);
}

String _format(double value) {
  final text = value.toStringAsFixed(1);
  return text.endsWith('.0') ? text.substring(0, text.length - 2) : text;
}
