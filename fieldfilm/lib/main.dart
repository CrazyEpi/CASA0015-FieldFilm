import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'screens/login_page.dart';
import 'screens/home_page.dart';

// --- Initialization ---
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load environment variables
  try {
    await dotenv.load(fileName: ".env");
    print("[Env] .env loaded successfully");
  } catch (e) {
    print("[Env] Failed to load .env file: $e");
  }
  
  // Initialize Firebase
  try {
    await Firebase.initializeApp();
    print("[Firebase] Initialization successful");
  } catch (e) {
    print("[Firebase] Initialization failed: $e");
  }
  
  runApp(const FieldFilmApp());
}

// --- Root Widget ---
class FieldFilmApp extends StatelessWidget {
  const FieldFilmApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FieldFilm',
      theme: ThemeData.dark().copyWith(
        primaryColor: Colors.deepOrange,
        scaffoldBackgroundColor: const Color(0xFF0A0A0A),
      ),
      // --- Authentication Routing ---
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return const FieldFilmHomePage();
          }
          return const LoginPage();
        },
      ),
    );
  }
}