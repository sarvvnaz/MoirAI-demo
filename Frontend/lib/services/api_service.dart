import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb; // 🔹 added
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
// ignore: deprecated_member_use
import 'dart:html' as html;
import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

// ⬅️ keep using LocalBackend for non-web (local dev / native)
import '../main.dart' show LocalBackend;

@JS('chrome.runtime.sendMessage')
external void chromeRuntimeSendMessage(
  String extensionId,
  JSObject message,
  JSFunction callback,
);

@JS('chrome.runtime.lastError')
external JSObject? get chromeRuntimeLastError;
class ApiService {
  static Uri _u(String path) => Uri.parse('http://127.0.0.1:8000$path');
  static const _timeout = Duration(seconds: 60);
  static const String extensionId = 'cdfchhleliecjmcpdgnjdphfkpkkmckg';

  //choose base URL depending on platform
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

  //build URLs off _base instead of hardcoded 127.0.0.1
  //static Uri _u(String path) => _base.replace(path: path);

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
  // Baseline profile
  // ───────────────────────────────
  /// Saves the participant's baseline/demographic profile to the backend.
  static Future<http.Response> submitProfile(
      Map<String, dynamic> profileData) async {
    final token = await getToken();
    if (token == null) {
      throw Exception('No access token');
    }

    return http
        .post(
          _u('/api/participant/profile'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode(profileData),
        )
        .timeout(_timeout);
  }

  // ───────────────────────────────
  // EFT Episode submission
  // ───────────────────────────────
  /// Persists a structured EFT episode on the backend.
  static Future<http.Response> submitEpisode(
      Map<String, dynamic> episode) async {
    final token = await getToken();
    if (token == null) {
      throw Exception('No access token');
    }
    final body = {'episode': episode};
    return http
        .post(
          _u('/api/eft/episode'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode(body),
        )
        .timeout(_timeout);
  }

  
  // ───────────────────────────────
  // EFT Chat
  // ───────────────────────────────
  static Future<Map<String, dynamic>?> eftChat(
      Map<String, dynamic> payload) async {
    final token = await getToken();
    if (token == null) {
      return null;
    }
    final res = await http
        .post(
          _u('/api/eft/chat'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode(payload),
        )
        .timeout(_timeout);
    if (res.statusCode == 200) {
      try {
        return jsonDecode(res.body) as Map<String, dynamic>;
      } catch (_) {
        return null;
      }
    }
    return null;
  }

// ───────────────────────────────
// Extension setup
// ───────────────────────────────
static Future<http.Response> ensureExtensionReminder() async {
  final token = await getToken();

  if (token == null) {
    throw Exception('No access token');
  }

  return http
      .post(
        _u('/api/extension/ensure-reminder'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'image_url':
              'https://upload.wikimedia.org/wikipedia/commons/thumb/a/a7/React-icon.svg/512px-React-icon.svg.png',
          'cue': 'تصویر تستی برای افزونه ذخیره شد.',
        }),
      )
      .timeout(_timeout);
}
static Future<bool> connectExtension() async {
  if (!kIsWeb) {
    debugPrint('⚠️ Extension connection only works on web.');
    return false;
  }

  final token = await getToken();

  if (token == null) {
    debugPrint('⚠️ No access token found for extension connection.');
    return false;
  }

  final completer = Completer<bool>();

  try {
    final message = JSObject();

    message.setProperty('action'.toJS, 'CONNECT_EFT_USER'.toJS);
    message.setProperty('accessToken'.toJS, token.toJS);

    chromeRuntimeSendMessage(
      extensionId,
      message,
      ((JSAny? response) {
        final lastError = chromeRuntimeLastError;

        if (lastError != null) {
          final errorMessage =
              lastError.getProperty<JSString?>('message'.toJS)?.toDart ??
                  'Unknown extension error';

          debugPrint('⚠️ Extension connection error: $errorMessage');

          if (!completer.isCompleted) {
            completer.complete(false);
          }
          return;
        }

        bool success = false;

        if (response != null) {
          final responseObject = response as JSObject;
          success =
              responseObject.getProperty<JSBoolean?>('success'.toJS)?.toDart ==
                  true;
        }

        debugPrint('🔌 Extension connected? $success');

        if (!completer.isCompleted) {
          completer.complete(success);
        }
      }).toJS,
    );

    return await completer.future.timeout(
      const Duration(seconds: 3),
      onTimeout: () {
        debugPrint('⚠️ Extension connection timed out.');
        return false;
      },
    );
  } catch (e) {
    debugPrint('⚠️ Failed to connect extension: $e');
    return false;
  }
}

// ───────────────────────────────
  // Study session feedback
  // ───────────────────────────────
  /// Sends post-session feedback to the backend.
  static Future<http.Response> submitStudyFeedback(
      Map<String, dynamic> feedbackData) async {
    final token = await getToken();
    if (token == null) {
      throw Exception('No access token');
    }
    return http
        .post(
          _u('/api/study/feedback'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode(feedbackData),
        )
        .timeout(_timeout);
  }

  // ───────────────────────────────
  // Token helper
  // ───────────────────────────────
  static Future<String?> getToken() async {
      if (kIsWeb) {
    // Flutter Web → use browser localStorage
    return html.window.localStorage['access_token'];
  }
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

  // Nudge support removed. The app no longer fetches or displays nudges.

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

