import 'package:flutter/material.dart';
import 'package:neuronudge/services/api_service.dart';
import 'home_page.dart';

class FeedbackPage extends StatefulWidget {
  final int userId;
  final int sessionId; // still accepted, even if backend uses last session

  const FeedbackPage({
    Key? key,
    required this.userId,
    required this.sessionId,
  }) : super(key: key);

  @override
  State<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage>
    with WidgetsBindingObserver {
  final TextEditingController _feedbackController = TextEditingController();
  bool _sending = false;

  /// 1–5 overall effectiveness rating (how much it helped with distractions)
  int? _effectivenessRating;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _feedbackController.dispose();
    super.dispose();
  }

  Future<void> _sendFeedback() async {
    if (_effectivenessRating == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'لطفاً یک عدد از ۱ تا ۵ برای میزان اثرگذاری انتخاب کن 🌱',
            textDirection: TextDirection.rtl,
          ),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.all(16),
        ),
      );
      return;
    }

    setState(() => _sending = true);
    try {
      await ApiService.logEvent(
        widget.userId,
        'session_feedback',
        {
          'rating': _effectivenessRating,
          'comment': _feedbackController.text.trim(),
          // اگر خواستی بعداً sessionId هم لاگ کنی:
          // 'session_id': widget.sessionId,
        },
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'بازخوردت ثبت شد، خیلی ممنون 🙏',
            textDirection: TextDirection.rtl,
          ),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.all(16),
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _startNewSessionDirectly() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => HomePage(userId: widget.userId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Global RTL + Persian-friendly look
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F0FF),
        appBar: AppBar(
          elevation: 0,
          centerTitle: true,
          backgroundColor: Colors.deepPurple,
          title: const Text(
            'بازخورد شما',
            style: TextStyle(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header / thank you card
                    Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 18,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFFF5ECFF),
                            Color(0xFFFFFFFF),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [
                          BoxShadow(
                            blurRadius: 14,
                            offset: Offset(0, 8),
                            color: Color(0x1A000000),
                          ),
                        ],
                      ),
                      child: Row(
                        children: const [
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: Color(0xFFE5D4FF),
                            child: Icon(
                              Icons.self_improvement_outlined,
                              size: 26,
                              color: Colors.deepPurple,
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'مرسی که توی این تحقیق کمکمون کردی \n'
                              'لطفاً خیلی کوتاه برامون بنویس این پیام‌ها چقدر کمک کردن حواست کمتر پرت بشه.',
                              style: TextStyle(fontSize: 15.5, height: 1.5),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Overall effectiveness rating (1–5)
                    _LabeledField(
                      label:
                          'به‌طور کلی این مداخله چقدر به کم‌شدن حواس‌پرتی‌های تو کمک کرد؟',
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: const [
                            BoxShadow(
                              blurRadius: 10,
                              offset: Offset(0, 6),
                              color: Color(0x14000000),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            _RatingTile(
                              value: 1,
                              groupValue: _effectivenessRating,
                              label: '۱ – اصلاً کمک نکرد',
                              description:
                                  'تقریباً هیچ تغییری در تعداد یا شدت حواس‌پرتی‌هام حس نکردم.',
                              onChanged: (v) =>
                                  setState(() => _effectivenessRating = v),
                            ),
                            const Divider(height: 1),
                            _RatingTile(
                              value: 2,
                              groupValue: _effectivenessRating,
                              label: '۲ – کمی کمک کرد',
                              description:
                                  'بعضی وقت‌ها کمی کمتر حواس‌پرت شدم، ولی هنوز زیاد پرت می‌شدم.',
                              onChanged: (v) =>
                                  setState(() => _effectivenessRating = v),
                            ),
                            const Divider(height: 1),
                            _RatingTile(
                              value: 3,
                              groupValue: _effectivenessRating,
                              label: '۳ – متوسط',
                              description:
                                  'در کل کمی کمک کرد؛ بخشی از حواس‌پرتی‌هام کمتر شد.',
                              onChanged: (v) =>
                                  setState(() => _effectivenessRating = v),
                            ),
                            const Divider(height: 1),
                            _RatingTile(
                              value: 4,
                              groupValue: _effectivenessRating,
                              label: '۴ – خوب',
                              description:
                                  'در بیشتر مواقع کمک کرد حواسم رو برگردونم و تمرکز کنم.',
                              onChanged: (v) =>
                                  setState(() => _effectivenessRating = v),
                            ),
                            const Divider(height: 1),
                            _RatingTile(
                              value: 5,
                              groupValue: _effectivenessRating,
                              label: '۵ – عالی',
                              description:
                                  'به‌صورت واضح و قابل‌توجهی حواس‌پرتی‌هام کمتر شد و تمرکزم بالا رفت.',
                              onChanged: (v) =>
                                  setState(() => _effectivenessRating = v),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 22),

                    // Text feedback input
                    _LabeledField(
                      label: 'اگر دوست داری کمی بیشتر توضیح بدی…',
                      child: TextField(
                        controller: _feedbackController,
                        textDirection: TextDirection.rtl,
                        textAlign: TextAlign.right,
                        maxLines: 6,
                        minLines: 4,
                        keyboardType: TextInputType.multiline,
                        decoration: InputDecoration(
                          hintText:
                              'اینجا بنویس… (مثلاً چه چیزی مفید بود، چه چیزی نبود، یا چه پیشنهادی داری)',
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: Color(0xFFE3D8FF),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: Colors.deepPurple,
                              width: 1.4,
                            ),
                          ),
                          prefixIcon: const Icon(Icons.edit_outlined),
                        ),
                        style: const TextStyle(
                          fontSize: 15.5,
                          height: 1.5,
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Action buttons
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: _sending
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.send_outlined),
                            label: Text(
                              _sending ? 'در حال ارسال…' : 'ارسال بازخورد',
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.deepPurple,
                              foregroundColor: Colors.white,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 0,
                            ),
                            onPressed: _sending ? null : _sendFeedback,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.restart_alt),
                            label: const Text('شروع دوباره (اختیاری)'),
                            style: OutlinedButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              side: const BorderSide(color: Colors.deepPurple),
                              foregroundColor: Colors.deepPurple,
                            ),
                            onPressed: _startNewSessionDirectly,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),
                    const Text(
                      'اگر دوست نداری ادامه بدی، می‌تونی این صفحه رو ببندی؛ همین‌قدر همکاری‌ات هم برای ما خیلی ارزشمنده 💜',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF6A6A6A),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Small helper to show a label above a field with consistent spacing.
class _LabeledField extends StatelessWidget {
  final String label;
  final Widget child;

  const _LabeledField({
    Key? key,
    required this.label,
    required this.child,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start, // still RTL, but label looks nicer
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8, right: 4),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13.5,
              color: Color(0xFF5B5B5B),
              fontWeight: FontWeight.w600,
            ),
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.right,
          ),
        ),
        child,
      ],
    );
  }
}

class _RatingTile extends StatelessWidget {
  final int value;
  final int? groupValue;
  final String label;
  final String description;
  final ValueChanged<int> onChanged;

  const _RatingTile({
    Key? key,
    required this.value,
    required this.groupValue,
    required this.label,
    required this.description,
    required this.onChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return RadioListTile<int>(
      value: value,
      groupValue: groupValue,
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
      activeColor: Colors.deepPurple,
      title: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        description,
        style: const TextStyle(fontSize: 13.5, height: 1.4),
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    );
  }
}
