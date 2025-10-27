import 'package:flutter/material.dart';
import 'screens/signup_page.dart';
import 'screens/login_page.dart';
import 'screens/reflection_page.dart';

void main() {
  runApp(const NeuroNudgeApp());
}

class NeuroNudgeApp extends StatelessWidget {
  const NeuroNudgeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NeuroNudge Demo',
      debugShowCheckedModeBanner: false,
      initialRoute: '/login',
      routes: {
        '/login': (context) => LoginPage(),
        '/signup': (context) => SignUpPage(),
        '/reflection': (context) => ReflectionPage(),
      },
    );
  }
}
