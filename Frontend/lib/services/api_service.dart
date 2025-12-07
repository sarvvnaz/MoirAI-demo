import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb; // 🔹 added
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// ⬅️ keep using LocalBackend for non-web (local dev / native)
import '../main.dart' show LocalBackend;

class ApiService {
  static const _timeout = Duration(seconds: 12);
  static int _localNudgeIndex = 0; // (kept from your code)

  // 🔹 NEW: choose base URL depending on platform
  static Uri get _base {
    if (kIsWeb) {
      // On web: use same origin as the loaded page
      final uri = Uri.base;
      return Uri(
        scheme: uri.scheme,
        host: uri.host,
        port: uri.hasPort ? uri.port : null,
      );
    } else {
      // On desktop/mobile/local dev: use your LocalBackend (127.0.0.1:8765 etc.)
      return LocalBackend.baseUrl;
    }
  }

  // 🔹 UPDATED: build URLs off _base instead of hardcoded 127.0.0.1
  static Uri _u(String path) => _base.replace(path: path);

  // ───────────────────────────────
  // Auth
  // ───────────────────────────────
  static Future<http.Response> signup(Map<String, String> data) {
    return http
        .post(
          _u('/api/auth/signup'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(data),
        )
        .timeout(_timeout);
  }

  static Future<http.Response> login(Map<String, String> credentials) {
    // Your backend expects form-encoded login
    return http
        .post(
          _u('/api/auth/login'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(credentials),
        )
        .timeout(_timeout);
  }

  // ───────────────────────────────
  // EFT
  // ───────────────────────────────
  static Future<http.Response> submitEFT(
      Map<String, dynamic> eftData, String token) {
    return http
        .post(
          _u('/api/eft/submit'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode(eftData),
        )
        .timeout(_timeout);
  }

  // ───────────────────────────────
  // Token helper
  // ───────────────────────────────
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  // ───────────────────────────────
  // Events
  // ───────────────────────────────
  static Future<void> logEvent(
      int userId, String eventType, Map<String, dynamic> details) async {
    final token = await getToken();
    if (token == null) {
      debugPrint('⚠️ No token found — user not logged in?');
      return;
    }

    final res = await http
        .post(
          _u('/api/events/log'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'event_type': eventType,
            'details': details,
          }),
        )
        .timeout(_timeout);

    if (res.statusCode == 200 || res.statusCode == 201) {
      debugPrint('✅ Logged event: $eventType');
    } else {
      debugPrint('⚠️ Failed to log event ($eventType): ${res.statusCode}');
    }
  }

  // ───────────────────────────────
  // Nudges
  // ───────────────────────────────
  static Future<Map<String, dynamic>?> getNextNudge(
      int userId, int currentNudgeId) async {
    final token = await getToken();
    if (token == null) {
      debugPrint('⚠️ No token found — user not logged in?');
      return null;
    }

    try {
      final res = await http
          .get(
            _u('/api/nudges/$userId/$currentNudgeId'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
          )
          .timeout(_timeout);

      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      } else {
        debugPrint('⚠️ Failed to fetch nudge: ${res.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('⚠️ Error fetching nudge: $e');
      return null;
    }
  }

  // ──────────────────────────────
  // Start Session
  // ──────────────────────────────
  static Future<Map<String, dynamic>?> startSession() async {
    final token = await getToken();
    if (token == null) {
      debugPrint('⚠️ No token found — user not logged in');
      return null;
    }

    final res = await http
        .post(
          _u('/api/events/session/start'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        )
        .timeout(_timeout);

    debugPrint("📌 startSession response: ${res.statusCode} - ${res.body}");

    if (res.statusCode == 200 || res.statusCode == 201) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    } else {
      return null;
    }
  }

  // ──────────────────────────────
  // End Session
  // ──────────────────────────────
  static Future<void> endSession() async {
    final token = await getToken();
    if (token == null) return;

    final res = await http.post(
      _u('/api/events/end_session'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (res.statusCode == 200) {
      debugPrint('🟢 Session ended successfully');
    } else {
      debugPrint('⚠️ Failed to end session: ${res.statusCode}');
    }
  }
}
