import 'dart:async';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../services/api_service.dart';
import '../services/idle_detector.dart';

class TaskPage extends StatefulWidget {
  final int userId;

  const TaskPage({Key? key, required this.userId}) : super(key: key);

  @override
  _TaskPageState createState() => _TaskPageState();
}

class _TaskPageState extends State<TaskPage> {
  final PdfViewerController _pdfController = PdfViewerController();
  bool _showNudge = false;
  String? _nudgeText;

  // 🕒 Timer state
  static const int sessionSeconds = 600; // 10 minutes
  int _remaining = sessionSeconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startSessionTimer();
  }

  // ───────────────────────────────
  // 🕒 Session Timer Logic
  // ───────────────────────────────
  void _startSessionTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_remaining <= 0) {
        t.cancel();
        _onSessionEnd();
      } else {
        setState(() => _remaining--);
      }
    });
  }

  Future<void> _onSessionEnd() async {
    await ApiService.logEvent(widget.userId, "session_end", {"duration": sessionSeconds});
    if (!mounted) return;
    _showFeedbackPopup();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // ───────────────────────────────
  // ⚡️ Idle detection → show nudge
  // ───────────────────────────────
  void _handleIdle() async {
    debugPrint("🕒 Idle detected! Fetching Persian nudge...");
    try {
      final nudge = await ApiService.getNextNudge(widget.userId);
      if (!mounted) return;
      setState(() {
        _nudgeText = nudge ?? "،میخوای ادامه بدی؟یک لحظه چشماتو ببند و حسی که بعد از رسیدن به هدفت داری رو تصور کن";
        _showNudge = true;
      });
      await ApiService.logEvent(widget.userId, "nudge_shown", {"nudge_text": _nudgeText});
    } catch (e) {
      debugPrint("⚠️ Error fetching nudge: $e");
    }
  }

  void _handleFocusReturn() {
    debugPrint("🔙 Focus resumed, keeping nudge until dismissed manually");
  }

  // ───────────────────────────────
  // 💬 Feedback popup after timer
  // ───────────────────────────────
  void _showFeedbackPopup() {
    int rating = 3;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          title: const Text(
            "پایان تمرین 🎯",
            style: TextStyle(fontFamily: 'Vazir'),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "آیا پیام‌ ها بهت کمک کردند دوباره تمرکز کنی؟",
                style: TextStyle(fontFamily: 'Vazir', fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Slider(
                min: 1,
                max: 5,
                divisions: 4,
                label: "$rating",
                value: rating.toDouble(),
                onChanged: (v) => setState(() => rating = v.toInt()),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await ApiService.logEvent(
                  widget.userId,
                  "session_feedback",
                  {"rating": rating},
                );
                if (mounted) Navigator.pop(ctx);
              },
              child: const Text("ثبت بازخورد", style: TextStyle(fontFamily: 'Vazir')),
            ),
          ],
        );
      },
    );
  }

  // ───────────────────────────────
  // 🧱 Build UI
  // ───────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: IdleDetector(
        userId: widget.userId,
        onIdle: _handleIdle,
        onFocusReturn: _handleFocusReturn,
        idleThreshold: const Duration(seconds: 20),
        child: Scaffold(
          backgroundColor: const Color(0xFFF5F0FF),
          appBar: AppBar(
            backgroundColor: Colors.deepPurple,
            title: const Text("تمرین مطالعه", style: TextStyle(fontFamily: 'Vazir')),
            actions: [
              // 🕒 Wrap timer in a ValueListenableBuilder-like pattern
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
                  child: Text(
                    _formatTime(_remaining),
                    key: ValueKey(_remaining),
                    style: const TextStyle(fontFamily: 'Vazir', fontSize: 18),
                  ),
                ),
              ),
            ],
          ),
          body: Stack(
            children: [
              // ⚡ Build content outside timer rebuilds
              _contentCached ??= _buildContentArea(),
              if (_showNudge) _buildNudgeOverlay(),
            ],
          ),
        ),
      ),
    );
  }

  // Helper to format MM:SS
  String _formatTime(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return "$m:$s";
  }

// Cache for static content so it doesn't rebuild every tick
Widget? _contentCached;

  // ───────────────────────────────
  // 📖 Content display
  // ───────────────────────────────
  Widget _buildContentArea() {
    return FutureBuilder<String>(
      future: _loadReadingText(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.deepPurple));
        } else if (snapshot.hasError) {
          return const Center(child: Text("خطا در بارگذاری متن 😔", style: TextStyle(fontFamily: 'Vazir')));
        } else {
          final text = snapshot.data ?? "متنی برای نمایش وجود ندارد.";
          return Container(
            color: const Color(0xFFF5F0FF),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 700),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 12, offset: Offset(0, 6))],
                ),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Text(
                    text,
                    textAlign: TextAlign.justify,
                    style: const TextStyle(fontSize: 18, height: 1.9, fontFamily: 'Vazir', color: Colors.black87),
                  ),
                ),
              ),
            ),
          );
        }
      },
    );
  }

  Future<String> _loadReadingText() async {
    try {
      return await DefaultAssetBundle.of(context).loadString('assets/docs/lesson1.txt');
    } catch (e) {
      debugPrint("⚠️ Error loading text: $e");
      return "خطا در بارگذاری فایل متن.";
    }
  }

  // ───────────────────────────────
  // 💬 Persian nudge overlay
  // ───────────────────────────────
  Widget _buildNudgeOverlay() {
    return AnimatedOpacity(
      opacity: _showNudge ? 1 : 0,
      duration: const Duration(milliseconds: 400),
      child: GestureDetector(
        onTap: () => setState(() => _showNudge = false),
        child: Container(
          color: Colors.black54,
          alignment: Alignment.center,
          child: Container(
            margin: const EdgeInsets.all(32),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8, spreadRadius: 2)],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("🌱", style: TextStyle(fontSize: 24, color: Colors.deepPurple, fontFamily: 'Vazir')),
                const SizedBox(height: 16),
                Text(
                  _nudgeText ?? "",
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18, fontFamily: 'Vazir'),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => setState(() => _showNudge = false),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text("ادامه مطالعه", style: TextStyle(fontFamily: 'Vazir', color: Colors.white)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
