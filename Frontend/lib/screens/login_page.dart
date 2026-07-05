import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:moirai/screens/signup_page.dart';
import 'package:moirai/screens/baseline_profile_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
// import 'home_page.dart'; // no longer used in the new flow
// ignore: deprecated_member_use
import 'dart:html' as html;
import 'package:flutter/foundation.dart' show kIsWeb;

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController emailController = TextEditingController();

  bool _loading = false;
Future<void> _login() async {
  // 1) Validate form
  if (!_formKey.currentState!.validate()) {
    print("❌ Form not valid, not sending request");
    return;
  }

  setState(() => _loading = true);

  final email = emailController.text.trim();

  // 2) Log what you'll send (without secrets)
  print("📨 Sending login request with email: $email");

  final credentials = {
    "email": email,
  };

  try {
    final response = await ApiService.login(credentials);

    print("🔍 Response status: ${response.statusCode}");
    print("🔍 Response body: ${response.body}");

    setState(() => _loading = false);

    if (response.statusCode == 200) {
      dynamic body;
      try {
        body = jsonDecode(response.body);
      } catch (e) {
        print("❌ JSON decode error: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("❌ مشکل در خواندن پاسخ سرور")),
        );
        return;
      }

      if (body['access_token'] != null && body['user'] != null) {
        final token = body['access_token'] as String;
        final int userId = body['user']['id'] as int;

        print("✅ Login success. userId=$userId");

        if (kIsWeb) {
          html.window.localStorage['access_token'] = token;
        } else {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('access_token', token);
          await prefs.setInt('user_id', userId);
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("ورود با موفقیت انجام شد ✅")),
        );

        // After successful login, direct the user to fill baseline demographic information.
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => BaselineProfilePage(userId: userId),
          ),
        );
      } else {
        print("❌ Missing access_token or user in response.");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("❌ پاسخ نامعتبر از سرور")),
        );
      }
    } else {
      print("❌ Login failed with status: ${response.statusCode}");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "❌ ورود ناموفق (${response.statusCode})",
            textDirection: TextDirection.rtl,
          ),
        ),
      );
    }
  } catch (e, st) {
    setState(() => _loading = false);
    print("💥 Exception during login: $e");
    print(st);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("❌ مشکل در اتصال به سرور")),
    );
  }
}

   @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;
    final bool isMobile = width < 900; // threshold for smaller screens

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 195, 177, 225),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Stack(
          children: [
            // // --- Background image (desktop only) ---
            // if (!isMobile)
            //   Positioned.fill(
            //     child: Image.asset(
            //       'assets/images/green_bg.png',
            //       fit: BoxFit.cover,
            //     ),
            //   ),
            // if(isMobile)
            //   Positioned.fill(
            //     child: Image.asset(
            //       'assets/images/green_bg.png',
            //       fit: BoxFit.cover,
            //   )),
            // --- Right side form content ---
            Align(
              alignment: Alignment.center,
              child: Container(
                decoration: 
                 BoxDecoration(
                        // ignore: deprecated_member_use
                        color: Colors.white.withOpacity(0.3),
                        boxShadow: [
                          BoxShadow(
                            // ignore: deprecated_member_use
                            color: const Color.fromARGB(255, 255, 255, 255).withOpacity(0.3),
                            blurRadius: 10,
                            spreadRadius: 5,
                          ),
                        ],
                        borderRadius: BorderRadius.circular(32),
                      ),
                width: isMobile
                    ? MediaQuery.of(context).size.width * 0.7
                    : MediaQuery.of(context).size.width * 0.8, 
                margin: isMobile
                    ? const EdgeInsets.symmetric(horizontal: 24, vertical: 48)
                    : EdgeInsets.zero,
                padding:
                const EdgeInsets.only( right: 80, left: 50, top: 32, bottom: 32),
                //const EdgeInsets.symmetric(horizontal: 50, vertical: 32),
                child: SingleChildScrollView(
                  child:Form(
                    key: _formKey,
                  child: isMobile
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                      if (isMobile)
                      Padding(

                        padding: const EdgeInsets.only(bottom: 20),
                        //child: Lottie.asset(
                       // 'assets/animations/business_girl_with_laptop.json',
                        //height: 300,
                       // alignment: Alignment.center,
                       // ),
                      ),
                    
                      const Text(
                        'به مویرای خوش آمدین',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2E2E2E),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'مویرای اینجاست تا بهتون کمک کنه که به طور شخصی سازی شده به سمت اهدافتون پیش برید',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF555555),
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: 32),

                      // --- Username field ---
                      _buildField(label: 'ایمیل', hint: "لطفا ایمیل خود را وارد کنید", controller: emailController),
                      
                      const SizedBox(height: 16),


                      // --- Login button ---
                      ElevatedButton(
                        onPressed: _loading ? null : _login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7E5EFF),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding:
                              const EdgeInsets.symmetric(vertical: 16),
                          minimumSize: const Size(double.infinity, 50),
                        ),
                        child: const Text(
                          'ورود',
                          style: TextStyle(
                              fontSize: 16, color: Colors.white),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // --- Sign-up link ---
                      const SizedBox(height: 20),
                      TextButton(
                        onPressed: () => Navigator.pushNamed(context, '/signup'),
                        child: const Text("حساب ندارید؟ ثبت‌نام کنید"),
                      ),
                      ]
                    )
                        : Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        const Text(
                                          'به مویرای خوش آمدین',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 26,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF2E2E2E),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        const Text(
                                          'مویرای اینجاست تا بهتون کمک کنه که به طور شخصی سازی شده به سمت اهدافتون پیش برید',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Color(0xFF555555),
                                            height: 1.6,
                                          ),
                                        ),
                                        const SizedBox(height: 32),
                                        _buildField(label: 'ایمیل', hint: "لطفا ایمیل خود را وارد کنید", controller: emailController),
                                        const SizedBox(height: 16),
                                        ElevatedButton(
                                          onPressed: _loading ? null : _login,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF7E5EFF),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            padding: const EdgeInsets.symmetric(vertical: 16),
                                            minimumSize: const Size(double.infinity, 50),
                                          ),
                                          child: const Text(
                                            'ورود',
                                            style: TextStyle(fontSize: 16, color: Colors.white),
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        const SizedBox(height: 20),
                                        TextButton(
                                          onPressed: () => Navigator.pushNamed(context, '/signup'),
                                          child: const Text("حساب ندارید؟ ثبت‌نام کنید"),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              //Expanded(child:   Lottie.asset(
                              //  'assets/animations/business_girl_with_laptop.json',
                              //  height: 400,
                              //  alignment: Alignment.center,
                              //),),
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



  // @override
  // Widget build(BuildContext context) {
  //   return Directionality(
  //     textDirection: TextDirection.rtl,
  //     child: Scaffold(
  //       backgroundColor: const Color(0xFFF4EEFF),
  //       body: SafeArea(
  //         child: LayoutBuilder(
  //           builder: (context, constraints) {
  //           double screenWidth = constraints.maxWidth;

  //           double formWidth;

  //           if (screenWidth < 600) {
  //             // Mobile
  //             formWidth = screenWidth * 0.9;
  //           } else if (screenWidth < 1100) {
  //             // Tablet
  //             formWidth = screenWidth * 0.6;
  //           } else {
  //             // Desktop / large screens
  //             formWidth = screenWidth * 0.3;
  //           }

  //           return Center(
  //             child: ConstrainedBox(
  //               constraints: BoxConstraints(
  //                 maxWidth: formWidth,
  //               ),
  //               child: Form(
  //                 key: _formKey,
  //                 child: Column(
  //                   mainAxisSize: MainAxisSize.min, 
  //                   crossAxisAlignment: CrossAxisAlignment.center,
  //                   children: [
  //                     const Icon(Icons.lock_outline, size: 70, color: Colors.deepPurple),
  //                     const SizedBox(height: 20),
  //                     const Text(
  //                       "ورود به حساب کاربری",
  //                       style: TextStyle(
  //                         fontSize: 24,
  //                         fontWeight: FontWeight.bold,
  //                         color: Colors.deepPurple,
  //                       ),
  //                     ),
  //                     const SizedBox(height: 40),

  //                     _buildField(
  //                       label: "ایمیل",
  //                       hint: "",
  //                       controller: emailController,
  //                     ),

  //                     const SizedBox(height: 30),
  //                     ElevatedButton(
  //                       onPressed: _loading ? null : _login,
  //                       style: ElevatedButton.styleFrom(
  //                         backgroundColor: Colors.deepPurple,
  //                         padding: const EdgeInsets.symmetric(
  //                           vertical: 14, horizontal: 80),
  //                         shape: RoundedRectangleBorder(
  //                             borderRadius: BorderRadius.circular(12)),
  //                       ),
  //                       child: _loading
  //                           ? const CircularProgressIndicator(color: Colors.white)
  //                           : const Text(
  //                               "ورود",
  //                               style: TextStyle(fontSize: 18, color: Colors.white),
  //                             ),
  //                     ),

  //                     const SizedBox(height: 20),
  //                     TextButton(
  //                       onPressed: () => Navigator.pushNamed(context, '/signup'),
  //                       child: const Text("حساب ندارید؟ ثبت‌نام کنید"),
  //                     ),
  //                   ],
  //                 ),
  //               ),
  //             ),
  //           );
  //         },
  //       ),

  //         ),
  //     ),
  //   );
  // }

  Widget _buildField({
    required String label,
    required String hint,
    required TextEditingController controller,
    bool obscureText = false,
    Widget? suffix,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      validator: (val) =>
          val == null || val.isEmpty ? "پر کردن الزامی است" : null,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.deepPurple.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
