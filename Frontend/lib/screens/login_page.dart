import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:neuronudge/screens/signup_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'task_page.dart'; // navigation after login

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool _loading = false;
  bool _obscure = true;
  Future<void> _login() async {
  if (!_formKey.currentState!.validate()) return;

  setState(() => _loading = true);

  final credentials = {
    "username": usernameController.text.trim(),
    "password": passwordController.text.trim(),
  };

  final response = await ApiService.login(credentials);
  setState(() => _loading = false);

  // ✅ Debug print to see what backend actually returns
  print("🔍 Response code: ${response.statusCode}");
  print("🔍 Response body: ${response.body}");

  if (response.statusCode == 200) {
    final body = jsonDecode(response.body);

    if (body['access_token'] != null && body['user'] != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('access_token', body['access_token']);
      await prefs.setInt('user_id', body['user']['id']);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("ورود با موفقیت انجام شد ✅")),
      );

      Navigator.pushReplacement(
        context,
        
        MaterialPageRoute(builder: (_) => TaskPage(
            userId: body['user']['id'],
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ پاسخ نامعتبر از سرور")),
      );
    }
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("❌ نام کاربری یا رمز عبور اشتباه است")),
    );
  }
}

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4EEFF),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Icon(Icons.lock_outline,
                        size: 70, color: Colors.deepPurple),
                    const SizedBox(height: 20),
                    const Text(
                      "ورود به حساب کاربری",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple,
                      ),
                    ),
                    const SizedBox(height: 40),
                    _buildField(
                      label: "نام کاربری",
                      hint: "",
                      controller: usernameController,
                    ),
                    const SizedBox(height: 16),
                    _buildField(
                      label: "رمز عبور",
                      hint: "حداقل ۶ کاراکتر",
                      controller: passwordController,
                      obscureText: _obscure,
                      suffix: IconButton(
                        icon: Icon(
                          _obscure
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                        onPressed: () =>
                            setState(() => _obscure = !_obscure),
                      ),
                    ),
                    const SizedBox(height: 30),
                    ElevatedButton(
                      onPressed: _loading ? null : _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        padding: const EdgeInsets.symmetric(
                            vertical: 14, horizontal: 80),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _loading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              "ورود",
                              style:
                                  TextStyle(fontSize: 18, color: Colors.white),
                            ),
                    ),
                    const SizedBox(height: 20),
                    TextButton(
                      onPressed: () => Navigator.pushNamed(context, '/signup'),
                      child: const Text("حساب ندارید؟ ثبت‌نام کنید"),
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
