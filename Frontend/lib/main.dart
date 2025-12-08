// main.dart — FULLY FIXED FOR WEB + DESKTOP
import 'dart:async';
import 'dart:convert';
// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

// IMPORTANT: Only import dart:io on non-web platforms
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:neuronudge/screens/home_page.dart';
import 'package:path/path.dart' as p;
import 'screens/login_page.dart';
import 'screens/signup_page.dart';
import 'screens/reflection_page.dart';
import 'screens/break_page.dart';
import 'screens/feedback_page.dart';
import 'screens/task_page.dart';
import 'dart:ui_web' as ui;
import 'dart:html' as html;

// Conditionally import dart:io
// ignore: avoid_web_libraries_in_flutter
import 'dart:io' show

  Platform,
  Process,
  Directory,
  File,
  ProcessStartMode,
  HttpClient;

/// BACKEND HANDLER — disabled entirely on Web
class LocalBackend {
  static const int _port = 8000;
  static Process? _proc;

static Uri get baseUrl => Uri.base;

  /// SAFE START: Only runs on Windows/macOS
  static Future<void> start() async {
    if (kIsWeb) return; // ← MUST-HAVE FIX
    if (!Platform.isMacOS && !Platform.isWindows) return;

    if (_proc != null) return;

    final env = Map<String, String>.from(Platform.environment)
      ..['MOIRAI_PORT'] = '$_port';

    final appDir = Directory.current.path;

    final packagedExe = Platform.isMacOS
        ? p.join(appDir, 'assets', 'bin', 'macos', 'backend')
        : p.join(appDir, 'assets', 'bin', 'windows', 'backend.exe');

    Future<Process> _spawnBinary(String exe) async {
      final f = File(exe);
      if (!f.existsSync()) throw Exception('Backend binary not found at $exe');

      if (Platform.isMacOS) {
        await Process.run('chmod', ['+x', exe]);
      }
      return Process.start(exe, [],
          environment: env, mode: ProcessStartMode.detached);
    }

    Future<Process> _spawnDev() async {
      final devEntry = p.join(appDir, '..', 'Backend', 'app', 'app.py');
      if (!File(devEntry).existsSync()) {
        throw Exception(
            'No packaged backend and no Python source found at $devEntry');
      }
      final py = Platform.isWindows ? 'python' : 'python3';
      return Process.start(py, [devEntry],
          environment: env, mode: ProcessStartMode.detached);
    }

    try {
      if (File(packagedExe).existsSync()) {
        _proc = await _spawnBinary(packagedExe);
      } else {
        _proc = await _spawnDev();
      }
    } catch (e) {
      _proc = null;
      rethrow;
    }

    final ok = await _waitForHealth(timeout: const Duration(seconds: 8));
    if (!ok) {
      _proc?.kill();
      _proc = null;
      throw Exception('Backend did not become ready at $baseUrl');
    }
  }

  static Future<bool> _waitForHealth(
      {Duration timeout = const Duration(seconds: 6)}) async {
    if (kIsWeb) return true; // Web never runs backend

    final deadline = DateTime.now().add(timeout);
    final client = HttpClient();

    while (DateTime.now().isBefore(deadline)) {
      try {
        final req = await client.getUrl(baseUrl.replace(path: '/health'));
        final res = await req.close();
        if (res.statusCode == 200) {
          final body = await utf8.decodeStream(res);
          if (body.contains('ok')) return true;
        }
      } catch (_) {}
      await Future.delayed(const Duration(milliseconds: 250));
    }
    return false;
  }

  static Future<void> stop() async {
    if (kIsWeb) return;
    _proc?.kill();
    _proc = null;
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();


  runApp(const NeuroNudgeApp());
}

class NeuroNudgeApp extends StatelessWidget {
  const NeuroNudgeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MoirAI Demo',
      debugShowCheckedModeBanner: false,
      initialRoute: '/login',
      routes: {
        '/login': (_) => LoginPage(),
        '/signup': (_) => SignUpPage(),
        '/reflection': (_) => ReflectionPage(
              userId: 0,
        ),
        '/home': (_) => HomePage(
              userId: 0,
            ),
        '/break': (_) => BreakPage(
              userId: 0,
              breakDuration: const Duration(seconds: 10),
              sessionId: 0,
            ),
        '/feedback': (_) => FeedbackPage(
              userId: 0,
              sessionId: 0,
            ),
        '/task': (_) => TaskPage(
              userId: 0,
              sessionId: 0,
              sessionNumber: 0,
            ),
      },
    );
  }
}
