import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';

class IdleDetector extends StatefulWidget {
  final int userId;
  final Widget child;
  final Duration idleThreshold; // e.g. Duration(seconds: 30)
  final VoidCallback? onIdle; // optional local action
  final VoidCallback? onFocusReturn;

  const IdleDetector({
    Key? key,
    required this.userId,
    required this.child,
    this.idleThreshold = const Duration(seconds: 30),
    this.onIdle,
    this.onFocusReturn,
  }) : super(key: key);

  @override
  _IdleDetectorState createState() => _IdleDetectorState();
}

class _IdleDetectorState extends State<IdleDetector> with WidgetsBindingObserver {
  Timer? _idleTimer;
  bool _isIdle = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _idleTimer?.cancel();
    super.dispose();
  }

  // ───────────────────────────────
  // 🔄 APP LIFECYCLE (focus tracking)
  // ───────────────────────────────
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      print("🔙 App resumed");
      _resetTimer();
      _onFocusReturn();
    } else if (state == AppLifecycleState.paused) {
      print("🚫 App lost focus");
      _onIdle();
    }
  }

  // ───────────────────────────────
  // ⏳ Idle tracking
  // ───────────────────────────────
  void _startTimer() {
    _idleTimer = Timer(widget.idleThreshold, _onIdle);
  }

  void _resetTimer() {
    if (_isIdle) {
      _isIdle = false;
      _onFocusReturn();
    }
    _idleTimer?.cancel();
    _startTimer();
  }

  void _onIdle() {
    if (!_isIdle) {
      _isIdle = true;
      print("💤 No activity for ${widget.idleThreshold.inSeconds} seconds");

      // log to backend
      ApiService.logEvent(
        widget.userId,
        "idle_detected",
        {"duration": widget.idleThreshold.inSeconds},
      );

      // trigger callback
      widget.onIdle?.call();
    }
  }

  void _onFocusReturn() {
    print("🧠 Focus returned");
    ApiService.logEvent(widget.userId, "focus_resumed", {});
    widget.onFocusReturn?.call();
  }

  // ───────────────────────────────
  // 🧭 Pointer listeners
  // ───────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _resetTimer(),
      onPointerMove: (_) => _resetTimer(),
      onPointerHover: (_) => _resetTimer(),
      child: widget.child,
    );
  }
}
