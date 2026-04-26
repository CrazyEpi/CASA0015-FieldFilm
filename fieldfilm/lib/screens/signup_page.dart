import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _emailCtrl = TextEditingController();
  final _pwdCtrl = TextEditingController();
  final _pwdConfirmCtrl = TextEditingController();
  bool _isLoading = false;

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

  Future<void> _register() async {
    // 检查两次密码是否一致
    if (_pwdCtrl.text != _pwdConfirmCtrl.text) {
      _showErrorDialog("Validation Error", "The passwords do not match. Please try again.");
      return;
    }
    
    if (_pwdCtrl.text.length < 6) {
      _showErrorDialog("Validation Error", "Password must be at least 6 characters long.");
      return;
    }

    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _pwdCtrl.text.trim(),
      );
      print("[Auth] Register success");
      // Firebase 注册成功后会自动登录，所以我们直接把注册页面关掉，退回上一层即可
      if (mounted) {
        Navigator.pop(context);
      }
    } on FirebaseAuthException catch (e) {
      String errorMsg = e.message ?? "Registration failed due to an unknown error.";
      if (e.code == 'email-already-in-use') errorMsg = "This email is already registered.";
      _showErrorDialog("Sign Up Failed", errorMsg);
    } catch (e) {
      _showErrorDialog("Error", e.toString());
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _pwdCtrl.dispose();
    _pwdConfirmCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Join FieldFilm")),
      body: SingleChildScrollView( // 防止键盘挡住输入框
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Start your journey.",
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.deepOrange),
            ),
            const SizedBox(height: 8),
            const Text(
              "Record your analog field logs connected to the environment.",
              style: TextStyle(color: Colors.white54),
            ),
            const SizedBox(height: 40),
            TextField(
              controller: _emailCtrl,
              decoration: InputDecoration(
                labelText: "Email Address",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _pwdCtrl,
              obscureText: true,
              decoration: InputDecoration(
                labelText: "Create Password (min 6 chars)",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _pwdConfirmCtrl,
              obscureText: true,
              decoration: InputDecoration(
                labelText: "Confirm Password",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Colors.deepOrange))
                  : ElevatedButton(
                      onPressed: _register,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepOrange,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text("Sign Up & Login", style: TextStyle(color: Colors.white, fontSize: 16)),
                    ),
            )
          ],
        ),
      ),
    );
  }
}