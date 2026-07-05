import 'dart:async';
import 'package:flutter/material.dart';
import 'package:moirai/screens/break_page.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../services/api_service.dart';
import '../services/idle_detector.dart';
import 'feedback_page.dart';
import '../widgets/custom_app_bar.dart';
// We keep importing dart:html for PDF progress tracking only. js_util and
// notifications are no longer used since nudges and notifications were
// removed from the study prototype.
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:html' as html;

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

  int _pageCount = 0;
  int _currentPage = 1;

  // Timer
  static const int sessionSeconds = 1200;
  int _remaining = sessionSeconds;
  Timer? _timer;
  Color _timerColor = const Color.fromARGB(255, 255, 255, 255);

  @override
  void initState() {
    super.initState();
    // No need to request notification permissions; nudges and notifications are disabled.
  }

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

  void _pauseTimer() {
    _timer?.cancel();
  }

  void _resumeTimer() {
    _startSessionTimer();
  }

  Future<void> _onSessionEnd() async {
    await ApiService.endSession();
    // Decide whether to break or finish based on the session number. If this is
    // the first session (sessionNumber == 1), take a break and then start
    // another session. Otherwise (sessionNumber >= 2), proceed to the
    // feedback page to conclude the study.
    if (widget.sessionNumber >= 2) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => FeedbackPage(
            userId: widget.userId,
            sessionNumber: widget.sessionNumber,
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

  // Idle callbacks removed — nudges are disabled in this version. IdleDetector
  // will continue to log idle and focus events automatically via ApiService.

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
        child: Scaffold(
          backgroundColor: const Color(0xFFF5F0FF),
          appBar: CustomAppBar(
            title: "تمرین مطالعه ",
            timerText: _formatTime(_remaining),
            timerColor: _timerColor,
            isDimmed: false,
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
                    style: TextStyle(
                      color: _timerColor,
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
              Positioned(
                bottom: 12,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  child: AnimatedOpacity(
                    opacity: 0.85,
                    duration: const Duration(milliseconds: 300),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          '$_currentPage / $_pageCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              _buildContent(),
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

    final _pdfPath = widget.sessionNumber == 1
        ? 'assets/docs/lesson1.pdf'
        : 'assets/docs/lesson1.pdf';
    String _progressKey() {
      // final pdfPath = widget.sessionNumber == 1
      //     ? 'lesson1.pdf'
      //     : 'lesson2.pdf';
      return 'moirai:pdf_progress:user=${widget.userId}:pdf=$_pdfPath';
    }

    void _saveLastPage(int page) {
      html.window.localStorage[_progressKey()] = page.toString();

    }

    int? _loadLastPage() {
      final v = html.window.localStorage[_progressKey()];

      return v == null ? null : int.tryParse(v);
    }
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
                    _pdfPath,
                    controller: _pdfController,
                    canShowScrollHead: true,
                    canShowScrollStatus: true,

                    onDocumentLoaded: (details) {
                      if (!mounted) return;

                      setState(() {
                        _pageCount = details.document.pages.count;
                      });

                      // start timer once (only if not already started)
                      if (_timer == null) {
                        _startSessionTimer();
                      }

                      // resume page
                      final savedPage = _loadLastPage();
                      if (savedPage != null && savedPage >= 1 && savedPage <= _pageCount) {
                        _pdfController.jumpToPage(savedPage);

                        // optional: update UI immediately
                        setState(() => _currentPage = savedPage);
                      }
                    },

                    onPageChanged: (details) {
                      if (!mounted) return;

                      setState(() => _currentPage = details.newPageNumber);

                      // persist progress
                      _saveLastPage(details.newPageNumber);
                    },
                  ),

                                  
                ),
              ),
            ),
          ),
        ),
      );
    
  }

  // Nudge overlay removed — nudges are disabled in this version.

}
