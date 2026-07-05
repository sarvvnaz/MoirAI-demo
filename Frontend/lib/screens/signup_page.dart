import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
// No longer import old EFT reflection page
import 'package:moirai/screens/baseline_profile_page.dart';
import '../services/api_service.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
// ignore: deprecated_member_use
import 'dart:html' as html;
import 'package:flutter/foundation.dart' show kIsWeb;

class SignUpPage extends StatefulWidget {
  @override
  _SignUpPageState createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController emailController = TextEditingController();
  final TextEditingController nameController = TextEditingController();

  bool _loading = false;

  void _signup() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    final data = {
      "email": emailController.text,
  
      "full_name_fa": nameController.text,

    };

    final response = await ApiService.signup(data);

    setState(() => _loading = false);

    if (response.statusCode == 200 || response.statusCode == 201) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text("ثبت‌نام با موفقیت انجام شد، در حال ورود... ✅")),
  );

  // 🔥 AUTO LOGIN USING EMAIL (same as in login_page)
  final loginResponse = await ApiService.login({
    "email": emailController.text.trim(),
  });

  if (loginResponse.statusCode == 200) {
    final body = jsonDecode(loginResponse.body);

    if (body['access_token'] != null && body['user'] != null) {
      final token = body['access_token'] as String;

      if (kIsWeb) {
      // Web → browser localStorage
        html.window.localStorage['access_token'] = token;
      } else {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('access_token', body['access_token']);
        await prefs.setInt('user_id', body['user']['id']);
      }
      // After auto login, navigate to the baseline profile page instead of the old reflection.
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => BaselineProfilePage(userId: body['user']['id']),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ پاسخ نامعتبر از سرور هنگام ورود خودکار")),
      );
    }
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("❌ ورود خودکار پس از ثبت‌نام انجام نشد")),
    );
  }
}

  }

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;
    final bool isMobile = width < 900;

    return Scaffold(
      backgroundColor: const Color(0xFFC1E1C1),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Stack(
          children: [
            // // --- Background image ---
            // if (!isMobile)
            //   Positioned.fill(
            //     child: Image.asset(
            //       'assets/images/purple_background.png',
            //       fit: BoxFit.cover,
            //     ),
            //   ),
            // if (isMobile)
            //   Positioned.fill(
            //     child: Image.asset(
            //       'assets/images/purple_background.png',
            //       fit: BoxFit.cover,
            //     ),
            //   ),
            // --- Form container ---
            Align(
              alignment: Alignment.center,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  boxShadow: [
                    BoxShadow(
                      color: const Color.fromARGB(255, 255, 255, 255).withOpacity(0.3),
                      blurRadius: 10,
                      spreadRadius: 5,
                    ),
                  ],
                  borderRadius: BorderRadius.circular(32),
                ),
                width: isMobile
                    ? MediaQuery.of(context).size.width * 0.85
                    : MediaQuery.of(context).size.width * 0.8,
                margin: isMobile
                    ? const EdgeInsets.symmetric(horizontal: 24, vertical: 48)
                    : EdgeInsets.zero,
                padding: const EdgeInsets.only(right: 80, left: 50, top: 32, bottom: 32),
                child: SingleChildScrollView(
                  child: isMobile
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            if (isMobile)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 20),
                                //child: Lottie.asset(
                                //  'assets/animations/man_on_desk.json',
                                //  height: 300,
                                //  alignment: Alignment.center,
                                //),
                              ),
                            const Text(
                              'ایجاد حساب کاربری ',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2E2E2E),
                              ),
                            ),
                            const SizedBox(height: 4),
                            
                            const SizedBox(height: 32),
                            Form(
                              key: _formKey,
                              child: Column(
                                children: [
                                  _buildField(
                                    label: 'ایمیل',
                                    hint: "لطفا ایمیل خود را وارد کنید",
                                    controller: emailController,
                                  ),
                                  const SizedBox(height: 16),
                                  _buildField(
                                    label: 'نام',
                                    hint: "به فارسی، مثلا سارا",
                                    controller: nameController,
                                  ),
                                  const SizedBox(height: 32),
                                  ElevatedButton(
                                    onPressed: _loading ? null : _signup,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF7E5EFF),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      minimumSize: const Size(double.infinity, 50),
                                    ),
                                    child: _loading
                                        ? const CircularProgressIndicator(color: Colors.white)
                                        : const Text(
                                            'ثبت‌نام',
                                            style: TextStyle(fontSize: 16, color: Colors.white),
                                          ),
                                  ),
                                  const SizedBox(height: 20),
                                  TextButton(
                                    onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
                                    child: const Text("قبلاً ثبت‌نام کرده‌اید؟ ورود"),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        )
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [

                            //Expanded(
                              
                              //child: Lottie.asset(
                              //  'assets/animations/man_on_desk.json',
                              //  height: 400,
                              //  alignment: Alignment.center,
                              //),
                           // ),
                              Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    const Text(
                                      'ایجاد حساب کاربری ',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 26,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF2E2E2E),
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    
                                    Form(
                                      key: _formKey,
                                      child: Column(
                                        children: [
                                          _buildField(
                                            label: 'ایمیل',
                                            hint: "لطفا ایمیل خود را وارد کنید",
                                            controller: emailController,
                                          ),
                                          const SizedBox(height: 16),
                                          _buildField(
                                            label: 'نام',
                                            hint: "به فارسی، مثلا سارا",
                                            controller: nameController,
                                          ),
                                          const SizedBox(height: 32),
                                          ElevatedButton(
                                            onPressed: _loading ? null : _signup,
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(0xFF7E5EFF),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              padding: const EdgeInsets.symmetric(vertical: 16),
                                              minimumSize: const Size(double.infinity, 50),
                                            ),
                                            child: _loading
                                                ? const CircularProgressIndicator(color: Colors.white)
                                                : const Text(
                                                    'ثبت‌نام',
                                                    style: TextStyle(fontSize: 16, color: Colors.white),
                                                  ),
                                          ),
                                          const SizedBox(height: 20),
                                          TextButton(
                                            onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
                                            child: const Text("قبلاً ثبت‌نام کرده‌اید؟ ورود"),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField({
    required String label,
    required String hint,
    required TextEditingController controller,
    bool obscureText = false,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      validator: (val) => val == null || val.isEmpty ? "پر کردن الزامی است" : null,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: const Color.fromARGB(255, 255, 255, 255),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}