import 'package:flutter/material.dart';
import '../services/api_service.dart';

/// FeedbackPage collects the participant's post-session feedback on their
/// episodic future thinking (EFT) rehearsal and study experience. It
/// prompts the user to rate several aspects on a 1–7 Likert scale,
/// indicate whether the imagined episode came to mind, and provide
/// optional qualitative feedback. The results are submitted to the
/// backend via the ApiService.
class FeedbackPage extends StatefulWidget {
  final int userId;
  final int sessionNumber;

  const FeedbackPage({Key? key, required this.userId, required this.sessionNumber})
      : super(key: key);

  @override
  State<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage> {
  int? _vividness;
  int? _accessibility;
  int? _futureSelfConnection;
  int? _taskFocus;
  int? _effort;
  bool? _episodeRecall;

  final TextEditingController _recallDetailController = TextEditingController();
  final TextEditingController _helpCommentController = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _recallDetailController.dispose();
    _helpCommentController.dispose();
    super.dispose();
  }

  Future<void> _submitFeedback() async {
    // Basic validation: ensure required ratings are selected
    if (_vividness == null ||
        _accessibility == null ||
        _futureSelfConnection == null ||
        _taskFocus == null ||
        _effort == null ||
        _episodeRecall == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لطفاً همهٔ سوالات را پاسخ دهید.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() => _sending = true);
    try {
      final data = <String, dynamic>{
        'session_number': widget.sessionNumber,
        'vividness': _vividness,
        'accessibility': _accessibility,
        'future_self_connection': _futureSelfConnection,
        'task_focus': _taskFocus,
        'effort': _effort,
        'episode_recall': _episodeRecall,
        'recall_detail': _episodeRecall == true
            ? (_recallDetailController.text.trim().isEmpty
                ? null
                : _recallDetailController.text.trim())
            : null,
        'help_comment': _helpCommentController.text.trim().isEmpty
            ? null
            : _helpCommentController.text.trim(),
      };
      final res = await ApiService.submitStudyFeedback(data);
      if (res.statusCode == 200 || res.statusCode == 201) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('بازخورد شما ثبت شد. سپاسگزاریم!'),
            duration: Duration(seconds: 3),
          ),
        );
        // After submission, do nothing further. Participants can close the page.
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطا در ارسال بازخورد: ${res.statusCode}'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطا: $e')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  /// Builds a row of selectable numbers for a Likert scale from 1 to 7.
  Widget _buildLikertRow(String label, int? groupValue, ValueChanged<int?> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            label,
            style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600),
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.right,
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(7, (i) {
            final value = i + 1;
            final selected = groupValue == value;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: ChoiceChip(
                  label: Text(value.toString()),
                  selected: selected,
                  onSelected: (_) => onChanged(value),
                  selectedColor: Colors.deepPurple,
                  backgroundColor: Colors.grey.shade200,
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F0FF),
        appBar: AppBar(
          title: const Text('بازخورد پایانی'),
          backgroundColor: Colors.deepPurple,
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
                    // Vividness
                    _buildLikertRow(
                        'وضوح تصویر آینده شما چقدر بود؟ (۱ = اصلاً واضح نبود، ۷ = بسیار واضح)',
                        _vividness, (v) => setState(() => _vividness = v)),
                    // Accessibility
                    _buildLikertRow(
                        'به‌نظر شما یادآوری این تصویر در طول جلسه چقدر آسان بود؟ (۱ = بسیار سخت، ۷ = بسیار آسان)',
                        _accessibility,
                        (v) => setState(() => _accessibility = v)),
                    // Future-self connection
                    _buildLikertRow(
                        'چقدر احساس ارتباط با خود آینده‌تان داشتید؟ (۱ = هیچ، ۷ = بسیار زیاد)',
                        _futureSelfConnection,
                        (v) => setState(() => _futureSelfConnection = v)),
                    // Task focus
                    _buildLikertRow(
                        'تمرکز شما روی کار چقدر بود؟ (۱ = بسیار کم، ۷ = بسیار زیاد)',
                        _taskFocus,
                        (v) => setState(() => _taskFocus = v)),
                    // Effort
                    _buildLikertRow(
                        'میزان تلاش برای مطالعه چقدر بود؟ (۱ = بسیار کم، ۷ = بسیار زیاد)',
                        _effort,
                        (v) => setState(() => _effort = v)),

                    // Episode recall yes/no
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        'آیا صحنهٔ آینده‌ای که ساختید در طول مطالعه به ذهن‌تان آمد؟',
                        style: const TextStyle(
                            fontSize: 15.5, fontWeight: FontWeight.w600),
                        textDirection: TextDirection.rtl,
                        textAlign: TextAlign.right,
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: RadioListTile<bool>(
                            value: true,
                            groupValue: _episodeRecall,
                            onChanged: (v) => setState(() => _episodeRecall = v),
                            title: const Text('بله'),
                            activeColor: Colors.deepPurple,
                          ),
                        ),
                        Expanded(
                          child: RadioListTile<bool>(
                            value: false,
                            groupValue: _episodeRecall,
                            onChanged: (v) => setState(() => _episodeRecall = v),
                            title: const Text('خیر'),
                            activeColor: Colors.deepPurple,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // If recalled, ask for detail
                    if (_episodeRecall == true) ...[
                      TextField(
                        controller: _recallDetailController,
                        minLines: 2,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'اگر بله، چه زمانی یا چگونه به ذهن‌تان آمد؟',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    // Open comment
                    TextField(
                      controller: _helpCommentController,
                      minLines: 3,
                      maxLines: 6,
                      decoration: const InputDecoration(
                        labelText: 'چه چیزی در طول مطالعه کمک کرد یا نکرد؟ (اختیاری)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _sending ? null : _submitFeedback,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 32, vertical: 12),
                        ),
                        child: _sending
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : const Text('ارسال بازخورد'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'با سپاس از مشارکت شما 💜',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13),
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