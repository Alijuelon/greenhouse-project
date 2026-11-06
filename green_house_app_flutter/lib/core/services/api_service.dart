import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class ApiService {
  /// Server produksi (cPanel/hosting) — bisa diubah saat runtime lewat
  /// Settings → Ubah Server Base URL.
  static String baseUrl = 'https://api-greenhouse.andanafarm.web.id/api';

  /// Fallback LAN untuk pengembangan tanpa internet (komentar bila dipakai):
  /// static String baseUrl = 'http://192.168.0.151:5000/api';

  /// API key produksi (harus sama dengan `app_settings.api_key` di server).
  /// Bisa dilihat di Settings → API Key, dan dirotasi dari sana bila perlu.
  static const String apiKey = 'live_sec_agri_46d0bb18';

  static void setBaseUrl(String url) {
    String trimmed = url.trim();
    if (trimmed.endsWith('/api')) {
      baseUrl = trimmed;
    } else if (trimmed.endsWith('/')) {
      baseUrl = '${trimmed}api';
    } else {
      baseUrl = '$trimmed/api';
    }
  }

  static Map<String, String> get headers => {
        'Content-Type': 'application/json',
        'x-api-key': apiKey,
      };

  static Future<String?> uploadAvatar(File imageFile) async {
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/upload_avatar'));
    request.headers['x-api-key'] = apiKey;
    
    request.files.add(await http.MultipartFile.fromPath('avatar', imageFile.path));
    
    final response = await request.send();
    if (response.statusCode == 200) {
      final resString = await response.stream.bytesToString();
      final data = json.decode(resString);
      return data['url'];
    }
    return null;
  }

  // ================= DASHBOARD =================
  static Future<Map<String, dynamic>> getDashboardLive(
      {String deviceId = 'esp32_greenhouse_01'}) async {
    final response = await http.get(
      Uri.parse('$baseUrl/dashboard/live?device_id=$deviceId'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(json.decode(response.body));
    } else {
      throw Exception('Failed to load dashboard data');
    }
  }

  static Future<bool> toggleRelay(int relayIndex, bool targetState,
      {String deviceId = 'esp32_greenhouse_01'}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/relay/toggle'),
      headers: headers,
      body: json.encode({
        'device_id': deviceId,
        'relay_index': relayIndex,
        'target_state': targetState,
      }),
    );
    return response.statusCode == 200;
  }

  static Future<bool> setRelayTimer(int relayIndex, int duration,
      {String deviceId = 'esp32_greenhouse_01'}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/relay/timer'),
      headers: headers,
      body: json.encode({
        'device_id': deviceId,
        'relay_index': relayIndex,
        'duration': duration,
      }),
    );
    return response.statusCode == 200;
  }

  // ================= AUTOMATION =================
  static Future<List<dynamic>> getAutomationRules() async {
    final response = await http.get(
      Uri.parse('$baseUrl/automation/rules'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      return List<dynamic>.from(json.decode(response.body));
    } else {
      throw Exception('Failed to load rules');
    }
  }

  static Future<bool> toggleRuleActive(int ruleId, bool isActive) async {
    final response = await http.put(
      Uri.parse('$baseUrl/automation/rules/$ruleId'),
      headers: headers,
      body: json.encode({'is_active': isActive}),
    );
    return response.statusCode == 200;
  }

  static Future<bool> addAutomationRule(Map<String, dynamic> ruleData) async {
    final response = await http.post(
      Uri.parse('$baseUrl/automation/rules'),
      headers: headers,
      body: json.encode(ruleData),
    );
    return response.statusCode == 201;
  }

  // ================= MANUAL COMMAND =================
  static Future<bool> sendManualCommand({
    required String deviceId,
    required String pump,
    required double ml,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/manual/command'),
      headers: headers,
      body: json.encode({
        'device_id': deviceId,
        'pump': pump,
        'ml': ml,
      }),
    );
    return response.statusCode == 201;
  }

  static Future<bool> updateAutomationRule(int ruleId, Map<String, dynamic> ruleData) async {
    final response = await http.put(
      Uri.parse('$baseUrl/automation/rules/$ruleId'),
      headers: headers,
      body: json.encode(ruleData),
    );
    return response.statusCode == 200;
  }

  static Future<bool> deleteAutomationRule(int ruleId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/automation/rules/$ruleId'),
      headers: headers,
    );
    return response.statusCode == 200;
  }

  // ================= ANALYTICS =================
  static Future<Map<String, dynamic>> getAnalyticsChart(
      String metric, int hours,
      {String deviceId = 'esp32_greenhouse_01',
      String? startDate,
      String? endDate}) async {
    String url = '$baseUrl/analytics/chart?device_id=$deviceId&metric=$metric&hours=$hours';
    if (startDate != null && endDate != null) {
      url += '&start_date=$startDate&end_date=$endDate';
    }
    final response = await http.get(
      Uri.parse(url),
      headers: headers,
    );
    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(json.decode(response.body));
    } else {
      throw Exception('Failed to load chart data');
    }
  }

  static String getExportUrl({String deviceId = 'esp32_greenhouse_01', String? startDate, String? endDate}) {
    String url = '$baseUrl/analytics/export?device_id=$deviceId';
    if (startDate != null && endDate != null) {
      url += '&start_date=$startDate&end_date=$endDate';
    }
    return url;
  }
  static Future<List<dynamic>> getActivityLogs({int limit = 10}) async {
    final response = await http.get(
      Uri.parse('$baseUrl/analytics/logs?limit=$limit'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      return List<dynamic>.from(json.decode(response.body));
    } else {
      throw Exception('Failed to load activity logs');
    }
  }

  // ================= SETTINGS =================
  static bool isHapticFeedbackEnabled = false;
  static Map<String, dynamic>? cachedSettings;
  static Future<Map<String, dynamic>>? _inFlightSettings;

  static Future<Map<String, dynamic>> getSettings() {
    return _inFlightSettings ??= _fetchSettingsInternal().whenComplete(() {
      _inFlightSettings = null;
    });
  }

  static Future<Map<String, dynamic>> _fetchSettingsInternal() async {
    final response = await http.get(
      Uri.parse('$baseUrl/settings'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      final data = Map<String, dynamic>.from(json.decode(response.body));
      isHapticFeedbackEnabled = data['notif_haptic_feedback'] ?? false;
      cachedSettings = data;
      return data;
    } else {
      throw Exception('HTTP ${response.statusCode}');
    }
  }

  static Future<Map<String, dynamic>> updateSettings(Map<String, dynamic> data) async {
    final response = await http.put(
      Uri.parse('$baseUrl/settings'),
      headers: headers,
      body: json.encode(data),
    );
    if (response.statusCode == 200) {
      final resData = Map<String, dynamic>.from(json.decode(response.body));
      if (resData.containsKey('notif_haptic_feedback')) {
        isHapticFeedbackEnabled = resData['notif_haptic_feedback'];
      }
      cachedSettings = resData;
      return resData;
    } else {
      throw Exception('Failed to update settings');
    }
  }

  // ================= AI PERFORMANCE =================
  static Future<Map<String, dynamic>> getAIPerformance({
    String deviceId = 'esp32_greenhouse_01',
    int hours = 24,
  }) async {
    final response = await http.get(
      Uri.parse('$baseUrl/ai/performance?device_id=$deviceId&hours=$hours'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(json.decode(response.body));
    } else if (response.statusCode == 404) {
      return {'error': 'no_data', 'n_samples': 0};
    } else {
      throw Exception('Failed to load AI performance');
    }
  }

  static Future<List<dynamic>> getAIPerformanceHistory({
    String deviceId = 'esp32_greenhouse_01',
    int limit = 20,
  }) async {
    final response = await http.get(
      Uri.parse('$baseUrl/ai/performance/history?device_id=$deviceId&limit=$limit'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      return List<dynamic>.from(json.decode(response.body));
    } else {
      throw Exception('Failed to load AI performance history');
    }
  }

  static Future<Map<String, dynamic>> computeAIPerformance({
    String deviceId = 'esp32_greenhouse_01',
    int hours = 24,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/ai/performance/compute'),
      headers: headers,
      body: json.encode({
        'device_id': deviceId,
        'hours': hours,
      }),
    );
    if (response.statusCode == 201) {
      return Map<String, dynamic>.from(json.decode(response.body));
    } else if (response.statusCode == 404) {
      return {'error': 'no_data', 'n_samples': 0};
    } else {
      throw Exception('Failed to compute AI performance');
    }
  }
}
