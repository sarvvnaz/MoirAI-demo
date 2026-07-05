import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'eft_chat_page.dart';
import 'eft_reflection_page.dart';

/// BaselineProfilePage collects the participant's demographic and study
/// baseline information and introduces the research. After completion,
/// the data is sent to the backend and the user proceeds to the EFT
/// chat construction page.
class BaselineProfilePage extends StatefulWidget {
  final int userId;
  const BaselineProfilePage({Key? key, required this.userId}) : super(key: key);

  @override
  _BaselineProfilePageState createState() => _BaselineProfilePageState();
}

class _BaselineProfilePageState extends State<BaselineProfilePage> {
  // Controllers for form fields
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _studyFieldController = TextEditingController();
  final TextEditingController _studyFrequencyController = TextEditingController();
  final TextEditingController _importanceController = TextEditingController();

  String? _educationLevel;
  String? _englishGoal;
  String? _englishLevel;

  bool _submitting = false;

  @override
  void dispose() {
    _ageController.dispose();
    _studyFieldController.dispose();
    _studyFrequencyController.dispose();
    _importanceController.dispose();
    super.dispose();
  }

  Future<void> _submitProfile() async {
    setState(() => _submitting = true);
    try {
      final data = <String, dynamic>{
        'age': int.tryParse(_ageController.text),
        'education_level': _educationLevel,
        'study_field': _studyFieldController.text.trim().isEmpty
            ? null
            : _studyFieldController.text.trim(),
        'english_goal': _englishGoal,
        'english_level': _englishLevel,
        'study_frequency': _studyFrequencyController.text.trim().isEmpty
            ? null
            : _studyFrequencyController.text.trim(),
        'english_importance': _importanceController.text.trim().isEmpty
            ? null
            : _importanceController.text.trim(),
      };
      await ApiService.submitProfile(data);
      if (!mounted) return;
      // Navigate to EFT chat page on success
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ReflectionPage(userId: widget.userId),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطا در ذخیره‌سازی اطلاعات: $e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFFDF6E3),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 700),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Research introduction
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: const [
                          Text(
                            'خوش آمدید 🌸',
                            style: TextStyle(
                                fontSize: 22, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'از اینکه در این پژوهش تمرین تصویرسازی آینده همراه ما هستید سپاسگزاریم. هدف ما بررسی تاثیر ساخت و مرور یک تصویر آیندهٔ شخصی بر تمرکز و انگیزهٔ مطالعه زبان انگلیسی است.',
                            style: TextStyle(fontSize: 16),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'این مطالعه شامل سه مرحله است: ۱) تکمیل اطلاعات اولیه، ۲) ساخت یک اپیزود آیندهٔ روشن به کمک راهنما، و ۳) انجام یک یا دو جلسه مطالعه‌ی ۲۰ دقیقه‌ای. مدت زمان کل پژوهش حدود ۳۰ دقیقه است.',
                            style: TextStyle(fontSize: 16),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'لطفاً موارد زیر را تکمیل کنید. اطلاعات شما به صورت محرمانه و تنها برای اهداف علمی استفاده خواهد شد.',
                            style: TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Form fields
                    TextField(
                      controller: _ageController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'سن',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _educationLevel,
                      decoration: const InputDecoration(
                        labelText: 'مقطع تحصیلی',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'دیپلم', child: Text('دیپلم')),
                        DropdownMenuItem(value: 'کارشناسی', child: Text('کارشناسی')),
                        DropdownMenuItem(value: 'کارشناسی ارشد', child: Text('کارشناسی ارشد')),
                        DropdownMenuItem(value: 'دکترا', child: Text('دکترا')),
                        DropdownMenuItem(value: 'سایر', child: Text('سایر')),
                      ],
                      onChanged: (val) => setState(() => _educationLevel = val),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _studyFieldController,
                      decoration: const InputDecoration(
                        labelText: 'رشته یا زمینهٔ تحصیلی/کاری',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _englishGoal,
                      decoration: const InputDecoration(
                        labelText: 'هدف یادگیری زبان',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'IELTS', child: Text('آیلتس')),
                        DropdownMenuItem(value: 'TOEFL', child: Text('تافل')),
                        DropdownMenuItem(value: 'General English', child: Text('یادگیری عمومی')),
                        DropdownMenuItem(value: 'Other', child: Text('سایر')),
                      ],
                      onChanged: (val) => setState(() => _englishGoal = val),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _englishLevel,
                      decoration: const InputDecoration(
                        labelText: 'سطح کنونی زبان انگلیسی',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'A1', child: Text('A1')),
                        DropdownMenuItem(value: 'A2', child: Text('A2')),
                        DropdownMenuItem(value: 'B1', child: Text('B1')),
                        DropdownMenuItem(value: 'B2', child: Text('B2')),
                        DropdownMenuItem(value: 'C1', child: Text('C1')),
                        DropdownMenuItem(value: 'C2', child: Text('C2')),
                        DropdownMenuItem(value: 'Beginner', child: Text('مبتدی')),
                        DropdownMenuItem(value: 'Intermediate', child: Text('متوسط')),
                        DropdownMenuItem(value: 'Advanced', child: Text('پیشرفته')),
                      ],
                      onChanged: (val) => setState(() => _englishLevel = val),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _studyFrequencyController,
                      decoration: const InputDecoration(
                        labelText: 'دفعات/مدت مطالعه در هفته (مثلاً ۳ روز در هفته، ۳۰ دقیقه در هر جلسه)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _importanceController,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'چرا یادگیری زبان برای شما مهم است؟ (اختیاری)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _submitting ? null : _submitProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.pink.shade300,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 32, vertical: 12),
                        ),
                        child: _submitting
                            ? const CircularProgressIndicator()
                            : const Text('ادامه'),
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