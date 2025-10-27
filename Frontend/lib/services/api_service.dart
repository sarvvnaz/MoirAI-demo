import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String baseUrl = "http://127.0.0.1:8000"; // for iOS simulator
  // if using Android emulator use: "http://10.0.2.2:8000"

  static Future<http.Response> signup(Map<String, String> data) async {
    final url = Uri.parse('$baseUrl/auth/signup');
    final headers = {'Content-Type': 'application/json'};
    final body = jsonEncode(data);

    final response = await http.post(url, headers: headers, body: body);
    return response;
  }

  static Future<http.Response> login(Map<String, String> credentials) async {
    final url = Uri.parse('$baseUrl/auth/login');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: credentials, // not jsonEncode!
    );
    return response;
  }


  static Future<http.Response> submitEFT(
      Map<String, dynamic> eftData, String token) async {
    final url = Uri.parse('$baseUrl/eft/submit');
    return await http.post(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode(eftData),
    );
  }

  
  // ────────────────────────────────
  // ✅ Central token fetcher
  // ────────────────────────────────
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  static Future<void> logEvent(int userId, String eventType, Map<String, dynamic> details) async {
    final token = await getToken();
    if (token == null) {
      print("⚠️ No token found — user not logged in?");
      return;
    }

    final url = Uri.parse("$baseUrl/events/log");

    final response = await http.post(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode({
        "event_type": eventType,
        "details": details,
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      print("✅ Logged event: $eventType");
    } else {
      print("⚠️ Failed to log event ($eventType): ${response.statusCode}");
    }
  }


  // 💬 Fetch next sequential Persian nudge
  static Future<String?> getNextNudge(int userId) async {
    final token = await getToken();
    if (token == null) {
      print("⚠️ No token found — user not logged in?");
      return null;
    }

    final url = Uri.parse("$baseUrl/nudges/next/$userId");
    final response = await http.get(
      url,
      headers: {
        "Authorization": "Bearer $token",
      },
    );

    if (response.statusCode == 200) {
      try {
        final data = jsonDecode(response.body);
        final nudge = data['nudge'] ?? data['text'] ?? data['message'];
        print("💬 Nudge received: $nudge");
        return nudge;
      } catch (e) {
        print("⚠️ Error decoding nudge JSON: $e");
      }
    } else {
      print("⚠️ Failed to fetch nudge: ${response.statusCode}");
    }
    return null;
  }
}