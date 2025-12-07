// lib/widgets/idle_detector.dart
import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';

class IdleDetector extends StatefulWidget {
  final int userId;
  final Widget child;
  final Duration idleThreshold; // e.g. Duration(seconds: 20)
  final VoidCallback? onIdle;   // show your nudge UI
  final VoidCallback? onFocusReturn;

  const IdleDetector({
    Key? key,
    required this.userId,
    required this.child,
    required this.idleThreshold,
    this.onIdle,
    this.onFocusReturn,
  }) : super(key: key);

  @override
  State<IdleDetector> createState() => _IdleDetectorState();
}

class _IdleDetectorState extends State<IdleDetector>
    with WidgetsBindingObserver {
  Timer? _idleTimer;
  bool _isIdle = false;
  late DateTime _lastActivityAt;

  // Defer nudge when app is not visible / not resumed
  bool _deferNudge = false;
  String? _deferReason;
  DateTime? _deferAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lastActivityAt = DateTime.now();
    _startTimer();
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // ───────────────────────────────────────────
  // Lifecycle
  // ───────────────────────────────────────────
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    debugPrint("📱 Lifecycle: $state");
    if (!mounted) return;

    switch (state) {
      case AppLifecycleState.resumed:
        _isIdle = false;
        _markActivity(); // refresh timer
        _onFocusReturn();

        // focus_resumed is a state change (keep it here)
        ApiService.logEvent(
          widget.userId,
          'focus_resumed',
          _baseDetails(),
        );

        // If a nudge was deferred while backgrounded, now we only CALL onIdle.
        // The screen (Task page) will be responsible for logging `nudge_shown`.
        final hadDeferred = _deferNudge;
        final suppressedForMs = _deferAt == null
            ? 0
            : DateTime.now().difference(_deferAt!).inMilliseconds;
        final reason = _deferReason;

        _deferNudge = false;
        _deferAt = null;
        _deferReason = null;

        if (hadDeferred) {
          await Future.delayed(const Duration(milliseconds: 100));
          try {
            widget.onIdle?.call();
            // NOTE: no `nudge_shown` logging here anymore.
            // The Task page will log the actual nudge with its text.
          } catch (e) {
            debugPrint("⚠️ onIdle on resume threw: $e");
          }
        }
        break;

      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        _idleTimer?.cancel();

        _deferNudge = true;
        _deferReason = 'app_background_or_hidden';
        _deferAt = DateTime.now();

        ApiService.logEvent(
          widget.userId,
          'idle_suppressed',
          _baseDetails(extra: {'reason': 'app_background_or_hidden'}),
        );
        ApiService.logEvent(
          widget.userId,
          'focus_lost',
          _baseDetails(),
        );
        break;

      case AppLifecycleState.detached:
        _idleTimer?.cancel();
        break;
    }
  }

  // ───────────────────────────────────────────
  // Idle tracking
  // ───────────────────────────────────────────
  void _startTimer() {
    _idleTimer?.cancel();
    _idleTimer = Timer(widget.idleThreshold, _onIdleTimerFired);
  }

  void _resetTimer() {
    if (_isIdle) {
      _isIdle = false;
      _onFocusReturn();
    }
    _idleTimer?.cancel();
    _startTimer();
  }

  void _markActivity() {
    _lastActivityAt = DateTime.now();
    _resetTimer();
  }

  Future<void> _onIdleTimerFired() async {
    final now = DateTime.now();
    final silentFor = now.difference(_lastActivityAt);

    // Guard against stale timer
    if (silentFor < widget.idleThreshold) {
      _startTimer();
      return;
    }

    if (_isIdle) return;

    final canShow = mounted &&
        (ModalRoute.of(context)?.isCurrent ?? true) &&
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;

    if (!canShow) {
      _deferNudge = true;
      _deferReason = 'not_visible_or_inactive';
      _deferAt = DateTime.now();

      ApiService.logEvent(
        widget.userId,
        'idle_suppressed',
        _baseDetails(extra: {
          'reason': 'not_visible_or_inactive',
          'silent_for_ms': silentFor.inMilliseconds,
          'idle_threshold_ms': widget.idleThreshold.inMilliseconds,
        }),
      );
      return;
    }

    _isIdle = true;

    // Only log idle_detected here
    ApiService.logEvent(
      widget.userId,
      'idle_detected',
      _baseDetails(extra: {
        'silent_for_ms': silentFor.inMilliseconds,
        'idle_threshold_ms': widget.idleThreshold.inMilliseconds,
      }),
    );

    // Now let parent show the nudge and log `nudge_shown`.
    try {
      widget.onIdle?.call();
    } catch (e) {
      debugPrint("⚠️ onIdle threw: $e");
    }
  }

  void _onFocusReturn() {
    try {
      widget.onFocusReturn?.call();
    } catch (e) {
      debugPrint("⚠️ onFocusReturn threw: $e");
    }
  }

  Map<String, dynamic> _baseDetails({Map<String, dynamic>? extra}) {
    return {
      'route': ModalRoute.of(context)?.settings.name,
      'ts': DateTime.now().toIso8601String(),
      ...?extra,
    };
  }

  // ───────────────────────────────────────────
  // Build: capture user activity
  // ───────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _markActivity(),
      onPointerMove: (_) => _markActivity(),
      onPointerUp: (_) => _markActivity(),
      onPointerSignal: (_) => _markActivity(),
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n is UserScrollNotification ||
              n is ScrollUpdateNotification ||
              n is OverscrollNotification) {
            _markActivity();
          }
          return false;
        },
        child: widget.child,
      ),
    );
  }
}
