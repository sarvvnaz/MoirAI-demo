import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'task_page.dart';
// import 'api_service.dart';

/// نسخه فارسی از صفحهٔ بازتاب برای مطالعهٔ تفکر آینده‌نگر اپیزودیک (EFT).
/// این صفحه کاربران را به صورت قدم‌به‌قدم راهنمایی می‌کند و در هر مرحله
/// هدف را تکرار می‌کند تا کاربران حواس‌پرت یا نیازمند راهنمایی بیشتر
/// بتوانند به راحتی وظیفهٔ خود را انجام دهند. علاوه بر معرفی EFT و ارائهٔ
/// مثال‌های کوتاه، اطلاعات دموگرافیک جمع‌آوری می‌شود، سپس کاربران با
/// راهنماهای جزئی برای تصویرسازی روبه‌رو می‌شوند، یک تایمر دو دقیقه‌ای
/// برای تجسم اجرا می‌شود، و در نهایت پاسخ‌ها در بخش‌های مجزا جمع‌آوری
/// می‌شوند. در پایان، مقیاس‌های اندازه‌گیری و رضایت‌نامهٔ پژوهشی ارائه
/// می‌گردد و کاربر می‌تواند ارسال نهایی انجام دهد.
class ReflectionPage extends StatefulWidget {
final int userId;
const ReflectionPage({Key? key, required this.userId}) : super(key: key);
  @override
  _ReflectionPageState createState() => _ReflectionPageState();
}

class _ReflectionPageState extends State<ReflectionPage> {
  // Total steps: 0=توضیح و اطلاعات، 1=راهنمای تجسم، 2=تایمر، 3=پرسش‌های جزئی،
  // 4=مقیاس‌های ارزیابی، 5=رضایت و ارسال نهایی.
  final _formKey = GlobalKey<FormState>();
  final int _totalSteps = 6;
  int _currentStep = 0;

  // Timer state for the imagination period (step 2).
  Timer? _timer;
  int _remainingSeconds = 1;
  bool _timerStarted = false;
  bool _timerCompleted = false;

  bool _loading = false;
  String? _nudgeText;

  bool _aiReady = false;          // enable Step-5 button when true
  bool _submitInFlight = false;   // avoid double taps
  String? _submitError;           // any error message
  bool _submitSucceeded = false;


   bool _starting = false;

  // Controllers for narrative fields.
  final TextEditingController _timeFrameController = TextEditingController();
  final TextEditingController _placeController = TextEditingController();
  final TextEditingController _activitiesController = TextEditingController();
  final TextEditingController _peopleController = TextEditingController();
  final TextEditingController _feelingsController = TextEditingController();

  // Demographic data controllers.
  final TextEditingController _ageController = TextEditingController();
  String? _selectedGender;
  String? _selectedDegree;
  String? _selectedExamGoal;
  final TextEditingController _studyHoursController = TextEditingController();

  // Measurement scales (1 to 6).
  double _ratingVividness = 3;
  double _ratingSpecificity = 3;
  double _ratingDifficulty = 3;
  double _ratingGoalImportance = 3;

  @override
  void dispose() {
    _timer?.cancel();
    _timeFrameController.dispose();
    _placeController.dispose();
    _activitiesController.dispose();
    _peopleController.dispose();
    _feelingsController.dispose();
    _ageController.dispose();
    _studyHoursController.dispose();
    super.dispose();
  }

  // Timer logic for the imagination period.
  void _startTimer() {
    setState(() {
      _timerStarted = true;
      _remainingSeconds = 1;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() => _remainingSeconds--);
      } else {
        timer.cancel();
        setState(() {
          _timerCompleted = true;
        });
      }
    });
  }

  void _nextStep() {
    if (_currentStep < _totalSteps - 1) {
      setState(() => _currentStep++);
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  // Build progress indicator.
  Widget _buildProgressBar() {
    final double progress = (_currentStep + 1) / _totalSteps;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'مرحله ${_currentStep + 1} از $_totalSteps',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: progress,
          minHeight: 4,
          backgroundColor: Colors.grey.shade300,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.pink.shade200),
        ),
      ],
    );
  }

  // Build content for each step.
  Widget _buildStepContent() {
    switch (_currentStep) {
      // Step 0: Introduction, examples, demographics, consent.
      case 0:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
            'خوش آمدید 🌸',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),

          SizedBox(height: 12),

          const Text(
            'از این‌که در این پژوهش با ما همراه هستید، بسیار سپاسگزاریم.',
            style: TextStyle(fontSize: 16),
          ),

          SizedBox(height: 8),

          const Text(
            'هدف این مطالعه بررسی تأثیر «تصویرسازی آینده‌نگر اپیزودیک» (EFT) بر تمرکز و انگیزهٔ یادگیری زبان انگلیسی است.',
            style: TextStyle(fontSize: 16),
          ),

          SizedBox(height: 8),

          const Text(
            'در این مسیر، شما آینده‌ای را تصور می‌کنید که در آن به هدف زبان خود — مانند موفقیت در آزمون آیلتس یا تافل، یا بهبود مهارت‌های عمومی زبان — رسیده‌اید. این تصویر ذهنی، به کمک هوش مصنوعی، به شما کمک خواهد کرد تا هنگام مطالعه، تمرکز خود را حفظ کرده و در مسیر یادگیری انگیزه داشته باشید.',
            style: TextStyle(fontSize: 16),
          ),

          SizedBox(height: 12),

          const Text(
            'این پژوهش ۳۰ دقیقه زمان نیاز دارد و شامل مراحل زیر است:',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),

          SizedBox(height: 6),

          const Text('۱. ثبت اطلاعات اولیه (سن، جنسیت، هدف یادگیری و...)'),
          const Text('۲. آشنایی با نحوهٔ تصویرسازی آینده‌نگر و ارائهٔ راهنما'),
          const Text('۳. دو دقیقه تصویرسازی ذهنی در سکوت'),
          const Text('۴. نوشتن توصیف صحنهٔ تصورشده در چند بخش ساده'),
          const Text('۵. پاسخ به دو پرسش دربارهٔ وضوح تصویر و اهمیت هدف'),
          const Text('۶. آغاز یک جلسهٔ ۲۵ دقیقه‌ای مطالعه بر اساس هدف شما'),

          SizedBox(height: 12),

          const Text(
            'این مراحل به‌صورت ساده و گام‌به‌گام طراحی شده‌اند تا بدون هیچ‌گونه فشار یا پیچیدگی قابل انجام باشند.',
            style: TextStyle(fontSize: 16, color: Colors.black87),
          ),

          SizedBox(height: 8),

          const Text(
            'در ادامه، لطفاً چند مورد ساده را تکمیل بفرمایید تا وارد مرحلهٔ اول شویم.',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),

            const SizedBox(height: 8),
            TextField(
              controller: _ageController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'سن', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _selectedGender,
              decoration: const InputDecoration(labelText: 'جنسیت', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'زن', child: Text('زن')),
                DropdownMenuItem(value: 'مرد', child: Text('مرد')),
                DropdownMenuItem(value: 'ترجیح می‌دهم نگوییم', child: Text('ترجیح می‌دهم نگوییم')),
              ],
              onChanged: (value) => setState(() => _selectedGender = value),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _selectedDegree,
              decoration: const InputDecoration(labelText: ' تحصیلات', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'کارشناسی', child: Text('کارشناسی')),
                DropdownMenuItem(value: 'کارشناسی ارشد', child: Text('کارشناسی ارشد')),
                DropdownMenuItem(value: 'سایر', child: Text('سایر')),
              ],
              onChanged: (initialValue) => setState(() => _selectedDegree = initialValue),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _selectedExamGoal,
              decoration: const InputDecoration(labelText: 'هدف یادگیری زبان', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'آیلتس', child: Text('آیلتس')),
                DropdownMenuItem(value: 'تافل', child: Text('تافل')),
                DropdownMenuItem(value: 'بهبود مهارت عمومی زبان', child: Text('بهبود مهارت عمومی زبان')),
              ],
              onChanged: (initialValue) => setState(() => _selectedExamGoal = initialValue),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _studyHoursController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'ساعات حدودی مطالعه زبان در هفته', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            const Text(
              'با رفتن به مرحله بعد، شما تأیید می‌کنید که با مشارکت خود در این پژوهش موافق هستید و اطلاعات شما به‌صورت محرمانه و فقط برای اهداف علمی استفاده خواهد شد.',
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
          ],
        );
      // Step 1: Guidance on how to imagine.
      // Updated content for the "راهنمای تجسم آیندهٔ خود" step in Flutter

// Updated Step 1: Guidance on how to imagine.
      case 1:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'راهنمای تجسم آیندهٔ شما',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'برای شروع تصویرسازی ذهنی، ابتدا چند مثال کوتاه از حوزه‌های مختلف را مشاهده می‌کنید. این مثال‌ها فقط برای الهام گرفتن هستند و پاسخ شما می‌تواند بسیار مفصل‌تر، شخصی‌تر و متفاوت باشد.',
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: Color(0xFFE3F2FD),
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.symmetric(vertical: 6),
              child: const Text(
                '🔹 سناریو: موفقیت ورزشی\n«در ماراتن شرکت کرده‌ام و آن را تمام کرده‌ام. دوستانم و خانواده‌ام با لبخند تشویقم می‌کنند. احساس قدرت، اعتمادبه‌نفس و توانمندی دارم.»',
                style: TextStyle(fontSize: 16),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: Color(0xFFE3F2FD),
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.symmetric(vertical: 6),
              child: const Text(
                '🔹 سناریو: فعالیت هنری\n«در اولین نمایشگاه نقاشی‌ام در برلین کنار تابلوهایم ایستاده‌ام. بازدیدکنندگان دربارهٔ آثارم سؤال می‌کنند. ترکیبی از هیجان، رضایت و افتخار را تجربه می‌کنم.»',
                style: TextStyle(fontSize: 16),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: Color(0xFFE3F2FD),
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.symmetric(vertical: 6),
              child: const Text(
                '🔹 سناریو: هدف یادگیری زبان (برای شما)\n«در جلسهٔ مصاحبهٔ کاری‌ام در یک شرکت بین‌المللی، با اعتمادبه‌نفس به انگلیسی صحبت می‌کنم. مصاحبه‌گر لبخند می‌زند و من حس می‌کنم به هدفم رسیده‌ام.»',
                style: TextStyle(fontSize: 16),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              ' هر چه جزئیات بیشتری در ذهن خود مجسم کنید—مثل زمان، مکان، فعالیت‌ها، افراد و احساسات—تجربهٔ ذهنی شما زنده‌تر و اثرگذارتر خواهد بود.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            const Text(
              'وقتی آماده بودید، روی دکمهٔ «مرحله بعد» بزنید تا وارد مرحلهٔ تجسم شوید. .',
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
          ],
        );
         // Step 2: Two-minute timer for imagination.
      case 2:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'تجسم آیندهٔ شما',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold ),
            ),
            RichText(
              text: TextSpan(
                text: 'اکنون نوبت شماست که هدف زبان انگلیسی خود را در ذهن داشته باشید: .\n',
                style: TextStyle(fontSize: 16),
                children: [
                  TextSpan(
                    text: ' آینده‌ای بلندمدت را تصور کنید که در آن به هدف زبان انگلیسی‌تان رسیده‌اید و از مهارت زبان خود با اطمینان استفاده می‌کنید. ',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),

                ],
              ),
            ),
            const Text(
           ' توجه کنید که منظور هدف‌های کوتاه‌مدت مانند قبولی در یک آزمون خاص نیست، بلکه تصویری از آینده‌ای است که در آن به طور کلی در زبان انگلیسی موفق شده‌اید. \nاما اگر برایتان مبهم است، آینده ی کوتاه مدت مثلا پس از قبولی در آزمون یا گرفتن پذیرش را تصور کنید.هدف این است که تا حد توان یک تصویر کلی و زنده بسازید',
            style: TextStyle(color: Colors.pink, fontSize: 14),
            ),
            const SizedBox(height: 8),
            const Text( 
              ' لطفاً روی شروع تجسم کلیک کنید و به مدت دو دقیقه به پنج جنبهٔ زیر فکر کنید و آن‌ها را در ذهن خود تجسم کنید. ',
              style: TextStyle(color: Color.fromARGB(255, 49, 113, 51), fontSize: 18)
            ),
            const SizedBox(height: 8),
            _buildPromptBullet('زمان: تقریباً چه زمانی این اتفاق می‌افتد؟ برای مثال: دو سال بعد، یا پس از فارغ‌التحصیلی..'),
            _buildPromptBullet('مکان: در کجا هستید؟ کلاس، شهر، کشور یا یک محل کاری خاص؟.'),
            _buildPromptBullet('فعالیت‌ها: چه کار می‌کنید؟ مثلاً درس خواندن در دانشگاه مورد نظرتان، تدریس، سفر، شرکت در یک کنفرانس یا صحبت کردن انگلیسی....'),
            _buildPromptBullet('افراد: چه کسانی در کنار شما هستند؟ دوستان، خانواده یا همکاران. آنها چگونه واکنش مثبت نشان می‌دهند؟ .'),
            _buildPromptBullet('احساسات: مهم‌ترین بخش! احساس مثبتی را که خودتان تجربه می‌کنید توصیف کنید؛ مثل شادی، غرور، آرامش یا هیجان. تمرکز بر احساسات به تصویر شما عمق می‌دهد.'),
            const SizedBox(height: 12),

            const SizedBox(height: 12),
 
            const Text(

              ' هدف شما در این مرحله فقط تصور کردن لحظه ای از آینده پس از رسیدن به هدف زبان انگلیسی مطلوبتان است؛ در مرحله بعد این تصور را می نویسید.',
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 12),
                       const Text(
              'اگر آماده‌اید، بر روی «شروع تجسم» کلیک کنید تا تایمر دو دقیقه‌ای شروع شود. در این مدت، چشمان خود را ببندید و به تصویرسازی ادامه دهید.',
                ),
            const SizedBox(height: 8),
            if (!_timerStarted)
              Center(
                child: ElevatedButton(
                  onPressed: _startTimer,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.pink.shade300,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  ),
                  child: const Text('شروع تجسم'),
                ),
              )
            else if (!_timerCompleted)
              Column(
                children: [
                  Text(
                    'زمان باقی‌مانده: ${_remainingSeconds ~/ 60}:${(_remainingSeconds % 60).toString().padLeft(2, '0')}',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text('چشمان خود را بسته نگه دارید و به تجسم ادامه دهید...'),
                ],
              )
            else
              Column(
                children: [
                  const Text(
                    'زمان به پایان رسید.',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _nextStep,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.pink.shade300,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    ),
                    child: const Text('ادامه به مرحله نوشتن'),
                  ),
                ],
              ),
          ],
        );
      // Step 3: Collect detailed narrative in separate fields.
      case 3:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'نوشتن جزئیات صحنهٔ تصورشده',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'اکنون زمان آن است که آنچه را تصور کرده‌اید بنویسید. برای کمک به شما، این پاسخ را به پنج بخش تقسیم کرده‌ایم. .',
            ),

            const SizedBox(height: 8),
            TextField(
              controller: _timeFrameController,
              decoration: const InputDecoration(
                labelText: 'زمان (حدودا چه زمانی؟)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _placeController,
              decoration: const InputDecoration(
                labelText: 'مکان (در کجا هستید؟)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _activitiesController,
              decoration: const InputDecoration(
                labelText: 'فعالیت‌ها (چه کارهایی انجام می‌دهید؟)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _peopleController,
              decoration: const InputDecoration(
                labelText: 'افراد (حضور یا احساسات چه کسانی برایتان پررنگ است؟آنها چگونه به موفقیت شما واکنش نشان می‌دهند؟)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _feelingsController,
              decoration: const InputDecoration(
                labelText: 'احساسات (چه احساس مثبتی دارید؟)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'به خاطر داشته باشید که هیچ پاسخ درست یا غلطی وجود ندارد و هر چه جزئیات بیشتری بنویسید، تصویر ذهنی شما واضح‌تر می‌شود و هوش مصنوعی نتیجه بهتری را نمایش می دهد..',
              style: TextStyle(color: Color.fromARGB(255, 233, 65, 121)),
            ),

          ],
        );
      // Step 4: Measurement scales for vividness and goal importance.
      case 4:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'پایان و ارسال نهایی',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'از اینکه تا اینجای این پژوهش همراه ما بودید، صمیمانه سپاسگزاریم 🌸\n.',
            ),
            const SizedBox(height: 12),
            const Text(
              'اکنون فقط دو سوال کوتاه باقی مانده‌اند تا بتوانیم کیفیت تجسم و اهمیت هدف شما را ارزیابی کنیم.',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _buildRatingRowFa('صحنه‌ای که تصور کردم زنده و واضح بود.', (val) => setState(() => _ratingVividness = val), _ratingVividness),
            _buildRatingRowFa('جزئیات صحنه‌ای که تصور کردم مشخص و دقیق بود.', (val) => setState(() => _ratingSpecificity = val), _ratingSpecificity),
            _buildRatingRowFa('تصور آینده برایم سخت بود', (val) => setState(() => _ratingDifficulty = val), _ratingDifficulty),
            _buildRatingRowFa('رسیدن به هدف زبان برایم اهمیت زیادی دارد.', (val) => setState(() => _ratingGoalImportance = val), _ratingGoalImportance),
            const SizedBox(height: 12),
            // const Text(
            //   'با زدن دکمهٔ «ارسال نهایی» در پایین به مرحله پایانی می روید د.',
            //   style: TextStyle(fontSize: 14, color: Colors.grey),
            // ),
          ],
        );
        // Step 6: Waiting for AI and next study instructions
        // case 5 in _buildStepContent():
    case 5:
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('همه‌چیز آماده است!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Text(
            _aiReady ? 'می‌توانید مطالعه را آغاز کنید.' : 'هوش مصنوعی در حال آماده‌سازی محتوای مناسب با هدف شماست...',
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 12),
            _buildPromptBullet('در مرحلهٔ بعد، یک مطلب مرتبط با هدف زبان شما نمایش داده می‌شود.'),
            _buildPromptBullet('شما فقط باید مثل همیشه مطالعه کنید. اگر حواستان پرت شود، پیام‌هایی برای کمک به تمرکز نمایش داده می‌شوند.'),
            _buildPromptBullet('لازم نیست کل متن را بخوانید؛ تا جایی که مایل هستید ادامه دهید.'),
            _buildPromptBullet('پیشنهاد می‌کنیم پیش از شروع چند دقیقه صبر کنید تا از حالت تجسم خارج شوید.'),
            _buildPromptBullet('در پایان، دربارهٔ تأثیر پیام‌ها نظر شما پرسیده می‌شود و کار به پایان می‌رسد.'),
          const SizedBox(height: 20),
          Center(
            child: ElevatedButton(
                    onPressed: (_submitSucceeded && _aiReady)
                      ? (_starting ? null : _onStartPressed)
                      : null,

                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.pink.shade300,
                        padding:
                            const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                      ),
                      child: Text(
                        
                        _aiReady ? 'شروع مطالعه' : 'در حال آماده‌سازی...',
                      ),
                      ),
          ),
          if (_submitInFlight) const SizedBox(height: 16),
          if (_submitInFlight) const Center(child: CircularProgressIndicator()),
          if (_submitError != null) ...[
            const SizedBox(height: 16),
            Text(_submitError!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: _submit, // allow retry on failure
                child: const Text('تلاش مجدد'),
              ),
            ),
          ],
        ],
      );
          default:
            return const SizedBox.shrink(); // Fallback (should not occur). 
        }
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
  // Helper to build example bullets.
  Widget _buildExampleBullet(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('• ', style: TextStyle(fontSize: 16, height: 1.4)),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 16, height: 1.4))),
      ],
    );
  }

  // Helper to build prompt bullets (with check icon).
  Widget _buildPromptBullet(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check, size: 20, color: Colors.pink),
          const SizedBox(width: 6),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 16))),
        ],
      ),
    );
  }

  // Helper to build a Farsi rating row with a slider from 1 to 6.
  Widget _buildRatingRowFa(String question, ValueChanged<double> onChanged, double currentValue) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(question, style: const TextStyle(fontWeight: FontWeight.w600)),
        Slider(
          value: currentValue,
          min: 1,
          max: 6,
          divisions: 5,
          label: currentValue.toStringAsFixed(0),
          onChanged: onChanged,
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: const [
            Text('۱'),
            Text('۶'),
          ],
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  // Submit data to the API when final step is reached.
  Future<bool> _submitEFT(token) async {

    final data = {
      'timeFrame': _timeFrameController.text,
      'place': _placeController.text,
      'activities': _activitiesController.text,
      'people': _peopleController.text,
      'feelings': _feelingsController.text,
    };
    
    try {
      final response = await ApiService.submitEFT(data, token);
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        setState(() => _nudgeText = body['nudge']);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_nudgeText ?? "پاسخ‌ها با موفقیت ارسال شد ✅")),
        );
        return true;

      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("خطا در ارسال پاسخ‌های EFT ❌")),
        );
        return false;

      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("اتصال به سرور برقرار نشد ❌")),
      );
      return false;

    } finally {
      setState(() => _loading = false);
    }
  }
  Future<void> _saveEftFeedback() async {
    final data = {
      'ratingVividness': _ratingVividness,
      'ratingSpecificity': _ratingSpecificity,
      'ratingDifficulty': _ratingDifficulty,
      'ratingGoalImportance': _ratingGoalImportance,
    };
    await ApiService.logEvent(widget.userId, 'eft_feedback', data);
    if(!mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("خطا در ذخیره بازخورد EFT ❌")),
      );
    }
    
    // final prefs = await SharedPreferences.getInstance();
    // final feedbackData = {
    //   'ratingVividness': _ratingVividness,
    //   'ratingSpecificity': _ratingSpecificity,
    //   'ratingDifficulty': _ratingDifficulty,
    //   'ratingGoalImportance': _ratingGoalImportance,
    // };
    // await prefs.setString('eft_feedback_${widget.userId}', jsonEncode(feedbackData));
  }
  Future<void> _saveUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final userInfo = {
      'age': _ageController.text,
      'gender': _selectedGender,
      'degree': _selectedDegree,
      'examGoal': _selectedExamGoal,
      'studyHoursPerWeek': _studyHoursController.text,
    };
    await ApiService.logEvent(widget.userId, 'user_info', userInfo);
    if(!mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("خطا در ذخیره اطلاعات کاربر ❌")),
      );
    }
    // await prefs.setString('user_info_${widget.userId}', jsonEncode(userInfo));
  }

    void _dbg(String msg, {Object? err, StackTrace? st}) {
      debugPrint('[EFT] $msg');
      if (err != null) debugPrint('[EFT][ERR] $err');
      if (st != null) debugPrint('[EFT][ST] $st');
    }

    bool _validateBeforeSubmit() {
      final missing = <String>[];

      // Step 3 text fields validation
      if (_timeFrameController.text.trim().isEmpty) missing.add('زمان');
      if (_placeController.text.trim().isEmpty) missing.add('مکان');
      if (_activitiesController.text.trim().isEmpty) missing.add('فعالیت‌ها');
      if (_peopleController.text.trim().isEmpty) missing.add('افراد');
      if (_feelingsController.text.trim().isEmpty) missing.add('احساسات');

      // Step 4 ratings (adjust as needed)
      if (_ratingVividness == null) missing.add('زنده و واضح بودن تصویر');
      if (_ratingSpecificity == null) missing.add('جزئیات تصویر');
      if (_ratingDifficulty == null) missing.add('سختی تجسم');
      if (_ratingGoalImportance == null) missing.add('اهمیت هدف');

      if (missing.isNotEmpty) {
        final msg = 'لطفاً این موارد را تکمیل کنید:\n• ${missing.join('\n• ')}';
        setState(() => _submitError = msg);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
        _dbg('Validation failed: $missing');
        return false;
    }

    return true;
  }

  Future<void> _submit() async {
  _dbg('Submit pressed. step=$_currentStep inFlight=$_submitInFlight');

  if (_submitInFlight) {
    _dbg('Submit ignored: already in flight');
    return;
  }

  // Validate BEFORE flipping inFlight
  if (!_validateBeforeSubmit()) return;

  setState(() {
    _currentStep = 5; // Move to step 5 immediately
    _submitInFlight = true;
    _submitSucceeded = false;
    _submitError = null;
    _loading = true;
    _nudgeText = null;
  });

  try {
    final token = await ApiService.getToken();
    _dbg('Token loaded? ${token != null}');

    if (token == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("ابتدا وارد حساب شوید ❌")),
      );
      setState(() => _loading = false);
      return;
    }

    _dbg('Saving user info / feedback...');
    await _saveUserInfo();
    await _saveEftFeedback();

    if (!mounted) return;

    _dbg('Submitting EFT...');
    final ok = await _submitEFT(token);

    if (!mounted) return;

    if (!ok) {
      _dbg('Submit failed (ok=false), staying on step 4');
      setState(() {
        _submitError = 'ارسال ناموفق بود. لطفاً دوباره تلاش کنید.';
        _loading = false;
      });
      return;
    }


    _dbg('Submit succeeded. Moving to step 5 and starting AI wait.');
    setState(() {
      _submitSucceeded = true;
      _currentStep = 5;
      _aiReady = false;
    });

    // If you really do AI processing, call it here. Otherwise keep delay.
    await Future.delayed(const Duration(seconds: 3));

    if (!mounted) return;
    setState(() => _aiReady = true);
    _dbg('AI ready set to true');
  } catch (e, st) {
    _dbg('Submit crashed', err: e, st: st);
    if (!mounted) return;
    setState(() => _submitError = 'خطا در ارسال نهایی. لطفاً دوباره تلاش کنید.');
  } finally {
    if (!mounted) return;
    setState(() => _submitInFlight = false);
    _dbg('Submit finished. inFlight reset to false');
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
            child: Container(
              constraints: const BoxConstraints(maxWidth: 700),
              margin: const EdgeInsets.all(16.0),
              padding: const EdgeInsets.all(24.0),
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
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildProgressBar(),
                  const SizedBox(height: 16),
                  Expanded(
                    child: SingleChildScrollView(
                      child: _buildStepContent(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (_currentStep > 0)
                        TextButton(
                          onPressed: _previousStep,
                          child: const Text('بازگشت'),
                        ),
                      if (_currentStep < 4)
                        ElevatedButton(
                          onPressed: () {
                            // Special case: ensure timer is completed before proceeding from step 2.
                            if (_currentStep == 2) {
                              if (!_timerStarted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('لطفاً ابتدا تایمر را شروع کنید'),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                                return;
                              }
                              if (!_timerCompleted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('لطفاً صبر کنید تا تایمر به پایان برسد'),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                                return;
                              }
                            }
                            _nextStep();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.pink.shade300,
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                          ),
                          child: const Text('مرحله بعد'),
                        ),
                      if (_currentStep == 4)
                        ElevatedButton(
                          onPressed: _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.pink.shade300,
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                          ),
                          child: const Text('ارسال نهایی'),
                        ),
                    ],
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