import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:green_house_app/core/services/api_service.dart';

// ─── Model: LiveData ────────────────────────────────────────────────────────

class LiveData {
  final String deviceId;
  final bool isOnline;
  final int uptime;
  final DateTime lastSeen;
  final Map<String, dynamic> sensors;
  final List<bool> relays;
  final List<bool> targetRelays;
  final Map<String, dynamic> ai;

  LiveData({
    required this.deviceId,
    required this.isOnline,
    required this.uptime,
    required this.lastSeen,
    required this.sensors,
    required this.relays,
    required this.targetRelays,
    required this.ai,
  });

  factory LiveData.fromJson(Map<String, dynamic> json) {
    return LiveData(
      deviceId: json['device_id'] ?? '',
      isOnline: json['is_online'] ?? false,
      uptime: json['uptime'] ?? 0,
      lastSeen: DateTime.tryParse(json['last_seen'] ?? '') ?? DateTime.now(),
      sensors: Map<String, dynamic>.from(json['sensors'] ?? {}),
      relays: List<bool>.from(json['relays'] ?? []),
      targetRelays: List<bool>.from(json['target_relays'] ?? []),
      ai: Map<String, dynamic>.from(json['ai'] ?? {}),
    );
  }
}

// ─── Model: DoseLog ─────────────────────────────────────────────────────────

class DoseLogModel {
  final int id;
  final DateTime timestamp;
  final String src;
  final int phase;
  final List<double> x;
  final Map<String, double> ml;
  final List<double>? aiMl;
  final int rating;

  DoseLogModel({
    required this.id,
    required this.timestamp,
    required this.src,
    required this.phase,
    required this.x,
    required this.ml,
    this.aiMl,
    required this.rating,
  });

  factory DoseLogModel.fromJson(Map<String, dynamic> json) {
    return DoseLogModel(
      id: json['id'] ?? 0,
      timestamp: DateTime.tryParse(json['timestamp'] ?? '') ?? DateTime.now(),
      src: json['src'] ?? '',
      phase: json['phase'] ?? 0,
      x: (json['x'] as List?)?.map((e) => (e as num).toDouble()).toList() ?? [],
      ml: (json['ml'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, (v as num).toDouble()),
          ) ??
          {},
      aiMl: (json['ai_ml'] as List?)?.map((e) => (e as num).toDouble()).toList(),
      rating: json['rating'] ?? 0,
    );
  }

  bool get hasAiPrediction => aiMl != null && aiMl!.isNotEmpty;

  String get srcLabel {
    switch (src) {
      case 'ai':
        return 'AI Auto';
      case 'expert':
        return 'Expert';
      case 'expert_shadow':
        return 'Expert + Shadow AI';
      default:
        return src;
    }
  }
}

// ─── Model: AIModeData ──────────────────────────────────────────────────────

class AIModeData {
  final String mode;
  final int phase;
  final double ecSetpoint;

  AIModeData({
    required this.mode,
    required this.phase,
    required this.ecSetpoint,
  });

  factory AIModeData.fromJson(Map<String, dynamic> json) {
    return AIModeData(
      mode: json['ai_mode'] ?? json['mode'] ?? 'off',
      phase: json['phase'] ?? 1,
      ecSetpoint: (json['ec_setpoint'] as num?)?.toDouble() ?? 0.0,
    );
  }

  String get modeLabel {
    switch (mode) {
      case 'auto':
        return 'AI Otomatis';
      case 'shadow':
        return 'Shadow (Bayangan)';
      case 'off':
        return 'Nonaktif';
      default:
        return mode;
    }
  }
}

// ─── Service ────────────────────────────────────────────────────────────────

class AIRecommendationService {
  String get baseUrl => ApiService.baseUrl;
  final String deviceId;
  Map<String, String> get headers => ApiService.headers;

  AIRecommendationService({this.deviceId = 'esp32_greenhouse_01'});

  /// Data sensor + info device terkini (GET /api/dashboard/live).
  Future<LiveData> getLive() async {
    final response = await http.get(
      Uri.parse('$baseUrl/dashboard/live?device_id=$deviceId'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      return LiveData.fromJson(json.decode(response.body));
    }
    throw Exception('Gagal memuat data live (${response.statusCode})');
  }

  /// Rekomendasi dosis terbaru — 1 baris dose_log.
  Future<DoseLogModel?> getLatestDose() async {
    final logs = await getDoseHistory(limit: 1);
    return logs.isNotEmpty ? logs.first : null;
  }

  /// N baris dose_log terbaru untuk riwayat screen & PDF.
  Future<List<DoseLogModel>> getDoseHistory({
    int limit = 50,
    String? src,           // 'ai' | 'expert' | 'expert_shadow' | null = semua
    String sort = 'desc',  // 'desc' | 'asc'
    String? dateFrom,      // ISO8601
    String? dateTo,        // ISO8601
  }) async {
    var url = '$baseUrl/ai/dose?device_id=$deviceId&limit=$limit&sort=$sort';
    if (src != null) url += '&src=$src';
    if (dateFrom != null) url += '&date_from=$dateFrom';
    if (dateTo != null) url += '&date_to=$dateTo';

    final response = await http.get(Uri.parse(url), headers: headers);
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((j) => DoseLogModel.fromJson(j)).toList();
    }
    throw Exception('Gagal memuat riwayat dosis (${response.statusCode})');
  }

  /// Hapus riwayat dosis (DELETE /api/ai/dose).
  /// [src] — hapus hanya src tertentu, null = semua
  /// [before] — hapus sebelum tanggal ini (ISO8601)
  Future<int> clearDoseHistory({String? src, String? before}) async {
    var url = '$baseUrl/ai/dose?device_id=$deviceId';
    if (src != null) url += '&src=$src';
    if (before != null) url += '&before=$before';
    final response = await http.delete(Uri.parse(url), headers: headers);
    if (response.statusCode == 200) {
      final body = json.decode(response.body);
      return (body['deleted'] as num?)?.toInt() ?? 0;
    }
    throw Exception('Gagal menghapus riwayat dosis (${response.statusCode})');
  }

  /// Mode AI saat ini (GET /api/ai/mode).
  Future<AIModeData> getAIMode() async {
    final response = await http.get(
      Uri.parse('$baseUrl/ai/mode?device_id=$deviceId'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      return AIModeData.fromJson(json.decode(response.body));
    }
    throw Exception('Gagal memuat mode AI (${response.statusCode})');
  }

  /// Set mode AI (PUT /api/ai/mode).
  Future<AIModeData> setAIMode(String mode) async {
    final response = await http.put(
      Uri.parse('$baseUrl/ai/mode?device_id=$deviceId'),
      headers: headers,
      body: json.encode({'ai_mode': mode}),
    );
    if (response.statusCode == 200) {
      return AIModeData.fromJson(json.decode(response.body));
    }
    throw Exception('Gagal mengatur mode AI (${response.statusCode})');
  }

  /// Ambil rekomendasi AI terbaru (tanpa eksekusi).
  Future<Map<String, dynamic>> getLatestAiDose() async {
    final response = await http.get(
      Uri.parse('$baseUrl/ai/latest-dose?device_id=$deviceId'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(json.decode(response.body));
    }
    throw Exception('Gagal memuat rekomendasi AI (${response.statusCode})');
  }

  /// Eksekusi manual satu head dosing (POST /api/ai/relay/run).
  /// [head] = "A" | "B" | "PH_UP" | "PH_DOWN"
  /// [durationSec] = durasi ON relay dalam detik
  Future<Map<String, dynamic>> runDosingHead({
    required String head,
    int durationSec = 10,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/ai/relay/run'),
      headers: headers,
      body: json.encode({
        'device_id':    deviceId,
        'head':         head,
        'duration_sec': durationSec,
      }),
    );
    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(json.decode(response.body));
    }
    throw Exception('Gagal eksekusi dosing $head (${response.statusCode})');
  }
}
