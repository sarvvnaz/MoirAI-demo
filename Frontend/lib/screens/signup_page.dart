import 'package:flutter/material.dart';
import '../services/api_service.dart';

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
        SnackBar(content: Text("ثبت‌نام با موفقیت انجام شد ✅")),
      );
      Navigator.pushReplacementNamed(context, '/reflection');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("خطا در ثبت‌نام ❌")),
      );
    }
  }

  @override
Widget build(BuildContext context) {
  return Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      backgroundColor: const Color(0xFFF5F0FF),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: LayoutBuilder(
            builder: (context, constraints) {
              double screenWidth = constraints.maxWidth;

              double formWidth;
              if (screenWidth < 600) {
                // Mobile
                formWidth = screenWidth * 0.9;
              } else if (screenWidth < 1100) {
                // Tablet
                formWidth = screenWidth * 0.6;
              } else {
                // Desktop
                formWidth = screenWidth * 0.3;
              }

              return Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: formWidth,
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 40),

                        const Text(
                          "ایجاد حساب کاربری",
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 40),

                        _buildField(
                          "ایمیل",
                          emailController,
                          "لطفا آدرس ایمیل خود را وارد کنید",
                        ),

                        _buildField(
                          "نام",
                          nameController,
                          "به فارسی، مثلا سارا",
                        ),

                        const SizedBox(height: 30),

                        ElevatedButton(
                          onPressed: _loading ? null : _signup,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple,
                            padding: const EdgeInsets.symmetric(
                              vertical: 14,
                              horizontal: 60,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _loading
                              ? const CircularProgressIndicator(
                                  color: Colors.white,
                                )
                              : const Text(
                                  "ثبت‌نام",
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.white,
                                  ),
                                ),
                        ),

                        const SizedBox(height: 20),

                        TextButton(
                          onPressed: () => Navigator.pushReplacementNamed(
                            context,
                            '/login',
                          ),
                          child: const Text("قبلاً ثبت‌نام کرده‌اید؟ ورود"),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    ),
  );
}

  Widget _buildField(String label, TextEditingController controller, String hint,
      {bool obscureText = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        validator: (val) => val == null || val.isEmpty ? "پرکردن الزامی است" : null,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          filled: true,
          fillColor: Colors.deepPurple.shade50,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}
