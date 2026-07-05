// lib/screens/home_page.dart
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'task_page.dart';

class HomePage extends StatefulWidget {
  final int userId;

  const HomePage({
    Key? key,
    required this.userId,
  }) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _noteController = TextEditingController();
  bool _starting = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _onStartPressed() async {
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
    
    return Directionality(
       
      textDirection: TextDirection.rtl, // ✅ Persian-friendly
      child: Scaffold(
        
        backgroundColor: const Color(0xFFF5F0FF), // pastel purple-ish
        body: Stack(
          children: [
            Opacity(
                opacity: 0.5,
                child: SizedBox.expand(child: Image.asset(
                  'assets/images/purple_background.png',
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
            ),)),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [

                        // Card with text box
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x14000000),
                                blurRadius: 14,
                                offset: Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text(
                                """سلام و ممنونیم که در این تحقیق همراه ما هستید 🤍
    این تست از دو جلسه‌ی ۲۵ دقیقه‌ای تشکیل شده که بین آن‌ها یک استراحت ۵ دقیقه‌ای قرار دارد.

    در هر جلسه، مطالب مفیدی برای تقویت مهارت‌های آزمون زبان نمایش داده می‌شود. تنها کافیست مثل حالت عادی خودتان این مطالب را بخوانید.
    اگر در طول کار حواس‌تان پرت شود یا به صفحه‌ای دیگر بروید، یک پیام کوتاه روی صفحه ظاهر می‌شود. فقط کافیست چند ثانیه به این پیام فکر کنید و خودتان را در موقعیتی که توصیف می‌کند تصور کنید.

    هدف ما این است که ببینیم این پیام‌ها چقدر به بازگشت تمرکز کمک می‌کنند.

    با زدن دکمه «شروع»، وارد اولین جلسه می‌شوید.
    بعد از پایان جلسه دوم، لطفاً بازخورد خود را دقیق ثبت کنید.
    ممنون از همکاری ارزشمند شما""",
                                // fontFamily: 'Vazir',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF4A2F8F),
                                ),
                              ),
                              const SizedBox(height: 8),
                              
                            ],
                          ),
                        ),

                        const SizedBox(height: 28),

                        // Start button
                        SizedBox(
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _starting ? null : _onStartPressed,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF6C4EDB),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 0,
                            ),
                            child: _starting
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'شروع جلسه تمرکز',
                                    // style: TextStyle(fontFamily: 'Vazir'),
                                    style: TextStyle(
                                      fontSize: 16.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),

                        const SizedBox(height: 8),

                        const Text(
                          'وقتی دکمه را بزنی، یک جلسهٔ جدید برایت ثبت می‌شود و وارد تمرین اول می‌شوی.',
                          textAlign: TextAlign.center,
                          // style: TextStyle(fontFamily: 'Vazir'),
                          style: TextStyle(
                            fontSize: 12.5,
                            height: 1.7,
                            color: Color(0xFF7A7A88),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
              ],
      ),
    ),
    );
  }
}
