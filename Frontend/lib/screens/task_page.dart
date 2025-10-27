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

  // ───────────────────────────────
  // ⚡️ Handle idle detected
  // ───────────────────────────────
  void _handleIdle() async {
    debugPrint("🕒 Idle detected! Fetching Persian nudge...");
    try {
      final nudge = await ApiService.getNextNudge(widget.userId);
      if (!mounted) return;
      setState(() {
        _nudgeText = nudge ?? "به یاد داشته باش هدف تو ارزش ادامه دادن را دارد 💪";
        _showNudge = true;
      });

      await ApiService.logEvent(
        widget.userId,
        "nudge_shown",
        {"nudge_text": _nudgeText},
      );
    } catch (e) {
      debugPrint("⚠️ Error fetching nudge: $e");
    }
  }

  // ───────────────────────────────
  // 🧠 Focus returned handler
  // ───────────────────────────────
  void _handleFocusReturn() {
    // User became active again, but we keep showing the nudge
    debugPrint("🔙 Focus resumed, but keeping nudge until user dismisses it manually");
  }


  // ───────────────────────────────
  // 🧱 Build UI
  // ───────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr, // Persian layout
      child: IdleDetector(
        userId: widget.userId,
        onIdle: _handleIdle,
        onFocusReturn: _handleFocusReturn,
        idleThreshold: const Duration(seconds: 5),
        child: Scaffold(
          backgroundColor: const Color(0xFFF5F0FF),
          appBar: AppBar(
            backgroundColor: Colors.deepPurple,
            title: const Text("تمرین مطالعه", style: TextStyle(fontFamily: 'Vazir')),
          ),
          body: Stack(
            children: [
              _buildContentArea(),
              if (_showNudge) _buildNudgeOverlay(),
            ],
          ),
        ),
      ),
    );
  }

  // ───────────────────────────────
  // 📖 Static PDF display (scrollable)
  // ───────────────────────────────

Widget _buildContentArea() {
  return FutureBuilder<String>(
    future: _loadReadingText(),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Center(child: CircularProgressIndicator(color: Colors.deepPurple));
      } else if (snapshot.hasError) {
        return Center(
          child: Text(
            "خطا در بارگذاری متن 😔",
            style: const TextStyle(fontSize: 18, fontFamily: 'Vazir'),
          ),
        );
      } else {
        final text = snapshot.data ?? "متنی برای نمایش وجود ندارد.";
        return Container(
          color: const Color(0xFFF5F0FF), // soft purple background
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 700), // limit width on large screens
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Text(
                  text,
                  textAlign: TextAlign.justify,
                  style: const TextStyle(
                    fontSize: 18,
                    height: 1.9,
                    fontFamily: 'Vazir',
                    color: Colors.black87,
                  ),
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
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 8, spreadRadius: 2),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "🌱",
                  style: TextStyle(
                    fontSize: 20,
                    color: Colors.deepPurple,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Vazir',
                  ),
                ),
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
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    "ادامه مطالعه",
                    style: TextStyle(fontFamily: 'Vazir', color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
