import 'dart:async';
import 'package:flutter/material.dart';
import 'package:neuronudge/services/api_service.dart';
import 'task_page.dart'; 

class BreakPage extends StatefulWidget {
  final int userId;
  final Duration breakDuration;
  final int sessionId;

  const BreakPage({
    Key? key,
    required this.userId,
    required this.breakDuration,
    required this.sessionId,
  }) : super(key: key);

  @override
  State<BreakPage> createState() => _BreakPageState();
}

class _BreakPageState extends State<BreakPage> {
  late Duration _remaining;
  Timer? _timer;
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    _remaining = widget.breakDuration;
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_remaining.inSeconds <= 1) {
        t.cancel();
        _goToNextSession();
      } else {
        setState(() {
          _remaining = Duration(seconds: _remaining.inSeconds - 1);
        });
      }
    });
  }
Future<void> _goToNextSession() async {
  if (_starting) return;
  setState(() => _starting = true);

  try {
    final sessionInfo = await ApiService.startSession();
    if (!mounted) return;

    if (sessionInfo == null ||
        sessionInfo['session_id'] == null ||
        sessionInfo['session_number'] == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'مشکلی در شروع جلسه پیش آمد. لطفاً دوباره تلاش کن 🌧️',
            textDirection: TextDirection.rtl,
          ),
        ),
      );
      return;
    }

    // JSON gives num → cast safely to int
    final int sessionId =
        (sessionInfo['session_id'] as num).toInt();
    final int sessionNumber =
        (sessionInfo['session_number'] as num).toInt();

    // Now pass both to TaskPage
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => TaskPage(
          userId: widget.userId,
          sessionId: sessionId,
          sessionNumber: sessionNumber,
        ),
      ),
    );
  } finally {
    if (mounted) setState(() => _starting = false);
  }
  }
  @override
  Widget build(BuildContext context) {
    final minutes = _remaining.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = _remaining.inSeconds.remainder(60).toString().padLeft(2, '0');

    return Scaffold(
      appBar: AppBar(
        title: const Text("Break"),
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "وقت استراحت 🤍",
              style: TextStyle(fontSize: 22),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              "$minutes:$seconds",
              style: const TextStyle(fontSize: 40, fontFeatures: [FontFeature.tabularFigures()]),
            ),
            const SizedBox(height: 24),
            Text(
              "تا ۵ دقیقه به خودت استراحت بده.\n"
              "بعد از تموم شدن، خودکار می‌ریم سر جلسه بعدی.",
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            TextButton(
              onPressed: _goToNextSession,
              child: const Text("رد کردن استراحت و شروع جلسه بعدی"),
            ),
          ],
        ),
      ),
    );
  }
}
