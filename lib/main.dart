import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io' show Platform;

import 'config/supabase_config.dart';
import 'Homeshell.dart';
import 'Prevoius code/Login/authservice.dart';
import 'Prevoius code/Login/loginscreen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Initialize Supabase with proper configuration
    await SupabaseConfig.initialize();
  } catch (e) {
    debugPrint('❌ Failed to initialize Supabase: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final AuthService _authService;
  bool _isCheckingAuth = true;
  bool _isUserLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _authService = AuthService();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    try {
      final isLoggedIn = await _authService.isUserLoggedIn();
      setState(() {
        _isUserLoggedIn = isLoggedIn;
        _isCheckingAuth = false;
      });
    } catch (e) {
      print('Error checking auth status: $e');
      setState(() {
        _isCheckingAuth = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Zalmi Reseller - Admin',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false,
      home: _isCheckingAuth
          ? const SplashScreen()
          : (_isUserLoggedIn ? const HomeShell() : const LoginPage()),
    );
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.shopping_bag, size: 64, color: Colors.blue),
            const SizedBox(height: 24),
            const Text(
              'Zalmi Reseller',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Admin Portal',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 32),
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade400),
            ),
          ],
        ),
      ),
    );
  }
}
