import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'signup_page.dart'; // 引入我们接下来要建的注册页

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailCtrl = TextEditingController();
  final _pwdCtrl = TextEditingController();
  bool _isLoading = false;

  // --- 专业的通用报错弹窗 ---
  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Colors.grey[900],
        title: Text(title, style: const TextStyle(color: Colors.redAccent)),
        content: Text(message, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("Got it", style: TextStyle(color: Colors.deepOrange)),
          ),
        ],
      ),
    );
  }

  // --- 登录逻辑 ---
  Future<void> _login() async {
    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _pwdCtrl.text.trim(),
      );
      print("[Auth] Login success");
      // 登录成功后会自动被 main.dart 里的 StreamBuilder 捕捉并切换到主页
    } on FirebaseAuthException catch (e) {
      // 捕捉 Firebase 专属错误，提取更干净的错误信息
      print("[Auth] Login failed: ${e.code}");
      String errorMsg = "Please check your email and password.";
      if (e.code == 'invalid-email') errorMsg = "The email format is incorrect.";
      if (e.code == 'user-not-found' || e.code == 'invalid-credential') errorMsg = "Incorrect email or password.";
      
      _showErrorDialog("Login Failed", errorMsg);
    } catch (e) {
      _showErrorDialog("Error", e.toString());
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _pwdCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("FieldFilm Portal")),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.camera_outlined, size: 80, color: Colors.deepOrange),
            const SizedBox(height: 40),
            TextField(
              controller: _emailCtrl,
              decoration: InputDecoration(
                labelText: "Email",
                // 圆角矩形输入框
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)), 
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _pwdCtrl,
              obscureText: true,
              decoration: InputDecoration(
                labelText: "Password",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
            const SizedBox(height: 30),
            _isLoading 
              ? const CircularProgressIndicator(color: Colors.deepOrange)
              : Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    OutlinedButton(
                      // 跳转到专属注册页
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const SignupPage()),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text("Create Account", style: TextStyle(color: Colors.white)),
                    ),
                    ElevatedButton(
                      onPressed: _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepOrange,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text("Login", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ],
                )
          ],
        ),
      ),
    );
  }
}