import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'task_page.dart';

class EFTChatPage extends StatefulWidget {
  final int userId;
  const EFTChatPage({Key? key, required this.userId}) : super(key: key);

  @override
  _EFTChatPageState createState() => _EFTChatPageState();
}

class _EFTChatPageState extends State<EFTChatPage> {
  final List<Map<String, String>> _messages = [];
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  int _step = 0;
  bool _needsUser = true;
  bool _canStart = false;
  bool _loading = false;
  String? _summary;
  bool _startingSession = false;

  @override
  void initState() {
    super.initState();
    // Ask backend for first question
    _sendToServer(message: '', reset: true);
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _addMessage(String sender, String text) {
    setState(() => _messages.add({'sender': sender, 'text': text}));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 60,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _sendToServer({required String message, bool reset = false}) async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final body = {
        'uid': widget.userId.toString(),
        'message': message,
        'client_version': 'v1',
        'reset': reset,
      };
      final res = await ApiService.eftChat(body);
      if (res == null) {
        _addMessage('bot', 'مشکلی در ارتباط با سرور رخ داد.');
        return;
      }
      final bot = (res['bot'] as String?) ?? '';
      setState(() {
        _step = (res['step'] as int?) ?? 0;
        _needsUser = (res['needs_user'] as bool?) ?? true;
        _canStart = (res['can_start_session'] as bool?) ?? false;
        _summary = res['episode_summary'] as String?;
      });
      if (bot.trim().isNotEmpty) {
        _addMessage('bot', bot);
      }
    } catch (e) {
      _addMessage('bot', 'خطایی رخ داد: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleSend() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || !_needsUser) return;
    _inputController.clear();
    _addMessage('user', text);
    await _sendToServer(message: text);
  }

  Future<void> _startSession() async {
    setState(() => _startingSession = true);
    try {
      final sessionInfo = await ApiService.startSession();
      if (!mounted) return;
      if (sessionInfo == null ||
          sessionInfo['session_id'] == null ||
          sessionInfo['session_number'] == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('مشکلی در شروع جلسه پیش آمد. دوباره تلاش کنید.'),
          ),
        );
        return;
      }
      final int sessionId = (sessionInfo['session_id'] as num).toInt();
      final int sessionNumber = (sessionInfo['session_number'] as num).toInt();

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
      if (mounted) setState(() => _startingSession = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFFDF6E3),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final msg = _messages[index];
                    final isBot = msg['sender'] == 'bot';
                    return Container(
                      alignment: isBot ? Alignment.centerRight : Alignment.centerLeft,
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isBot ? Colors.pink.shade100 : Colors.green.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Text(
                          msg['text'] ?? '',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    );
                  },
                ),
              ),

              if (_needsUser)
                Container(
                  padding: const EdgeInsets.all(8),
                  color: Colors.white,
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _inputController,
                          onSubmitted: (_) => _handleSend(),
                          decoration: const InputDecoration(
                            hintText: 'پاسخ خود را تایپ کنید...',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.send),
                        onPressed: _handleSend,
                      ),
                    ],
                  ),
                )
              else if (!_canStart && _summary != null)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(
                        onPressed: () => _sendToServer(message: 'تایید'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.pink.shade300,
                        ),
                        child: const Text('تأیید'),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton(
                        onPressed: () => _sendToServer(message: 'ویرایش'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey.shade400,
                        ),
                        child: const Text('ویرایش'),
                      ),
                    ],
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: ElevatedButton(
                    onPressed: _canStart && !_startingSession ? _startSession : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.pink.shade300,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    ),
                    child: _startingSession
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(),
                          )
                        : const Text('شروع جلسه'),
                  ),
                ),

              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: CircularProgressIndicator(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
