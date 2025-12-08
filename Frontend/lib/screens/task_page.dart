import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:neuronudge/screens/break_page.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../services/api_service.dart';
import '../services/idle_detector.dart';
import 'feedback_page.dart';

class TaskPage extends StatefulWidget {
  final int userId;
  final int sessionId;
  final int sessionNumber;

  const TaskPage({
    Key? key,
    required this.userId,
    required this.sessionId,
    required this.sessionNumber,
  }) : super(key: key);

  @override
  State<TaskPage> createState() => _TaskPageState();
}

class _TaskPageState extends State<TaskPage> {
  final PdfViewerController _pdfController = PdfViewerController();

  bool _showNudge = false;
  String? _nudgeText;

  // Timer
  static const int sessionSeconds = 60;
  int _remaining = sessionSeconds;
  Timer? _timer;

  // Nudge
  int _nudgeId = 1;

  // @override
  // void initState() {
  //   super.initState();
  //   _startSessionTimer();
  // }

  void _startSessionTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_remaining <= 0) {
        t.cancel();
        _onSessionEnd();
      } else {
        if (mounted) setState(() => _remaining--);
      }
    });
  }

  Future<void> _onSessionEnd() async {
    await ApiService.endSession();
    print("current session id is ${widget.sessionId}");

    if (widget.sessionId.isEven) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => FeedbackPage(
            userId: widget.userId,
            sessionId: widget.sessionId,
          ),
        ),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => BreakPage(
            userId: widget.userId,
            breakDuration: const Duration(minutes: 5),
            sessionId: widget.sessionId,
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // ──────────────────────────────
  // Idle handling
  // ──────────────────────────────

  Future<void> _handleIdle() async {
    debugPrint("🕒 Idle detected → Fetching nudge $_nudgeId");

    final res = await ApiService.getNextNudge(widget.userId, _nudgeId);

    if (!mounted) return;

    setState(() {
      _nudgeText = res?["message"] ??
          "به حس خوبی که بعد از برداشتن این قدم و رسیدن به هدفت داری فکر کن";
      _showNudge = true;
      _nudgeId = res?["next_nudge_number"] ?? _nudgeId;
      print(  "Next nudge id: $res?['next_nudge_number']");
    });

    await ApiService.logEvent(widget.userId, "nudge_shown", {
      "nudge_text": _nudgeText,
    });
  }

  void _handleFocusReturn() {
    debugPrint("🔙 Focus returned");
  }

  // ──────────────────────────────
  // Build UI
  // ──────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: IdleDetector(
        userId: widget.userId,
        idleThreshold: const Duration(seconds: 20),
        onIdle: _handleIdle,
        onFocusReturn: _handleFocusReturn,
        child: Scaffold(
          backgroundColor: const Color(0xFFF5F0FF),
          appBar: AppBar(
            backgroundColor: Colors.deepPurple,
            elevation: 4,
            title: const Text(
              "۲ تمرین مطالعه",
              style: TextStyle(
                fontFamily: 'Vazir',
                fontSize: 22,
                fontWeight: FontWeight.w600,
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (child, anim) =>
                      FadeTransition(opacity: anim, child: child),
                  child: Text(
                    _formatTime(_remaining),
                    key: ValueKey(_remaining),
                    style: const TextStyle(
                      fontSize: 20,
                      fontFamily: 'Vazir',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
          body: Stack(
            children: [
              _buildContent(),
              if (_showNudge) _nudgeOverlay(),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(int sec) {
    final m = (sec ~/ 60).toString().padLeft(2, '0');
    final s = (sec % 60).toString().padLeft(2, '0');
    return "$m:$s";
  }

  // ──────────────────────────────
  // Content: PDF in a nice box
  // ──────────────────────────────

  Widget _buildContent() {
    final pdfPath = widget.sessionNumber == 1
        ? 'assets/docs/lesson1.pdf'
        : 'assets/docs/lesson1.pdf';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 900,  // small-ish box, not full screen
            maxHeight: 600,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(
                  blurRadius: 18,
                  spreadRadius: 1,
                  offset: Offset(0, 8),
                  color: Color(0x22000000),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Directionality(
                textDirection: TextDirection.ltr, // PDF layout
                child: SfPdfViewer.asset(
                  pdfPath,
                  controller: _pdfController,
                  canShowScrollHead: true,
                  canShowScrollStatus: true,
                  onDocumentLoaded: (_) => _startSessionTimer(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ──────────────────────────────
  // Nudge popup
  // ──────────────────────────────

Widget _nudgeOverlay() {
  return GestureDetector(
    onTap: () => setState(() => _showNudge = false),
    child: Container(
      color: Colors.black54,
      alignment: Alignment.center,
      child: FractionallySizedBox(
        widthFactor: 0.6,   // 60% of screen width → responsive
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 380,   // never wider than this
            maxHeight: 300,  // keep it like a dialog
          ),
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _nudgeText ?? "",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontFamily: 'Vazir',
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => setState(() => _showNudge = false),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    minimumSize: const Size(120, 42),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    "ادامه",
                    style: TextStyle(
                      fontFamily: 'Vazir',
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

}
