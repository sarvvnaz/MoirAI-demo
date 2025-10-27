import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'task_page.dart';

class ReflectionPage extends StatefulWidget {
  @override
  _ReflectionPageState createState() => _ReflectionPageState();
}

class _ReflectionPageState extends State<ReflectionPage> {
  final _formKey = GlobalKey<FormState>();

  final whyController = TextEditingController();
  final whenController = TextEditingController();
  final obstaclesController = TextEditingController();
  final visionController = TextEditingController();
  final ifGiveUpController = TextEditingController();
  final notesController = TextEditingController();

  bool _loading = false;
  String? _nudgeText;

  Future<void> _submitEFT() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _nudgeText = null;
    });

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');

    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("ابتدا وارد حساب شوید ❌")),
      );
      setState(() => _loading = false);
      return;
    }

    final eftData = {
      "q1_why_goal_matters": whyController.text,
      "q2_when_reach_goal": whenController.text,
      "q3_possible_obstacles": obstaclesController.text,
      "q4_future_visualization": visionController.text,
      "q5_if_give_up": ifGiveUpController.text,
      "q6_notes": notesController.text,
    };

    try {
      final response = await ApiService.submitEFT(eftData, token);
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        setState(() => _nudgeText = body['nudge']);
        _showNudgeDialog(_nudgeText ?? "پاسخ‌ها ذخیره شد ✅");
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("خطا در ارسال پاسخ‌ها ❌")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("اتصال به سرور برقرار نشد ❌")),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  void _showNudgeDialog(String text) {
    showDialog(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: Colors.white,
          title: const Text(
            "✨ نکته انگیزشی برای شما ✨",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            textAlign: TextAlign.center,
          ),
          content: Text(
            text,
            style: const TextStyle(fontSize: 16, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("ادامه بده"),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context)  {
    return Directionality(
      textDirection: TextDirection.rtl, // ✅ Persian RTL layout
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F0FF),
        appBar: AppBar(
          title: const Text("تفکر آینده‌محور"),
          backgroundColor: Colors.deepPurple,
          centerTitle: true,
          elevation: 0,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    "🎯 هدف اصلی: رسیدن به تسلط زبانی برای آزمون IELTS",
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "لطفاً برای هر سؤال، پاسخ خود را با جزئیات بنویسید — به‌ویژه بخش‌های که مربوط به احساساتتان است، تا هوش مصنوعی بتواند انگیزه و بازخورد دقیق‌تری ایجاد کند. هر بخش می تواند چند جواب داشته باشد💬",
                    style: TextStyle(fontSize: 15, height: 1.6),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),

                  _buildQuestionBlock(
                    "چرا این هدف برایت مهم است؟",
                    whyController,
                    "مثلاً: چون با نمره‌ی بالا در IELTS می‌توانم در دانشگاه مورد علاقه‌ام تحصیل کنم و به رؤیای مهاجرت نزدیک شوم.",
                  ),
                  _buildQuestionBlock(
                    "چه زمانی می خواهی به هدفت برسی؟",
                    whenController,
                    "مثلاً: شش ماه بعد، حدود یک سال بعد.",
                  ),
                  _buildQuestionBlock(
                    "چه موانعی ممکن است سر راهت قرار بگیرد؟",
                    obstaclesController,
                    "مثلاً: احساس خستگی، کمبود زمان، یا مقایسه خود با دیگران.",
                  ),
                  _buildQuestionBlock(
                    "اگر موفق شوی، آینده‌ات را چطور می‌بینی؟",
                    visionController,
                    "مثلاً: خودم را می‌بینم که در آمریکا زندگی می‌کنم و با آرامش و اعتماد به‌نفس صحبت می‌کنم. ایمیل پذیرش دانشگاه را دریافت کردم و خانواده ام به من افتخار میکنند. ",
                  ),
                  _buildQuestionBlock(
                    "اگر به این هدف نرسی عواقب آن چیست و چه احساسی در آن لحظه خواهی داشت؟ ",
                    ifGiveUpController,
                    "مثلاً: احساس ناامیدی میکنم، زیان مالی خواهم دید و از برنامه ام عقب می افتم.",
                  ),
                  _buildQuestionBlock(
                    "یادداشت یا توضیح اضافه‌ای داری؟",
                    notesController,
                    "هر چیز دیگری که به ذهنت می‌رسد یا می‌خواهی اضافه کنی.",
                  ),

                  const SizedBox(height: 25),
                  ElevatedButton(
                    onPressed: _loading ? null : _submitEFT,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      padding: const EdgeInsets.symmetric(
                          vertical: 14, horizontal: 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _loading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            "ارسال پاسخ‌ها",
                            style:
                                TextStyle(fontSize: 18, color: Colors.white),
                          ),
                  ),
                  TextButton(
                    onPressed: () async{

                      final prefs = await SharedPreferences.getInstance();
                      final userId = prefs.getInt('user_id');

                      if (userId != null) {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (_) => TaskPage(userId: userId)),
                        );
                      }



                    },
                    child: const Text(
                      "⏭ رفتن به صفحه تمرین (برای تست)",
                      style: TextStyle(color: Colors.deepPurple),
                    ),
                  ),

                  if (_nudgeText != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(
                        "✅ پاسخ‌ها ذخیره شد!",
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Colors.green, fontWeight: FontWeight.w600),
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

  Widget _buildQuestionBlock(
      String question, TextEditingController controller, String example) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question,
            style: const TextStyle(
                fontWeight: FontWeight.w600, fontSize: 16, height: 1.5),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            minLines: 2,
            maxLines: null,
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return "لطفاً پاسخ بده";
              }
              if (val.trim().split(" ").length < 3) {
                return "پاسخ باید حداقل ۳ واژه باشد";
              }
              return null;
            },
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.right,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.deepPurple.shade50,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            example,
            style: TextStyle(
              fontSize: 13,
              color: Colors.black.withOpacity(0.55),
              height: 1.5,
            ),
          ),
          
        ],
        
      ),
    );
  }
}
