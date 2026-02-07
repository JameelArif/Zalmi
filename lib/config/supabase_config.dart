import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase configuration and debugging utilities
class SupabaseConfig {
  static const String _url = 'https://dezwlrpyvweynxipnsyp.supabase.co';
  static const String _anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRlendscnB5dndleW54aXBuc3lwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njk2MjUyNjIsImV4cCI6MjA4NTIwMTI2Mn0.5Bkkqp_7ytgSWzKdlOi26fP4YB5P7xliV5L88drxL4Y';

  /// Initialize Supabase with proper configuration for all platforms
  static Future<void> initialize() async {
    try {
      final platform = _getPlatformName();
      debugPrint('🚀 Initializing Supabase on $platform...');

      await Supabase.initialize(url: _url, anonKey: _anonKey);

      debugPrint('✅ Supabase initialized successfully');
      _debugSupabaseStatus();
    } catch (e) {
      debugPrint('❌ Supabase initialization failed: $e');
      rethrow;
    }
  }

  /// Get the current platform name for logging
  static String _getPlatformName() {
    if (kIsWeb) return 'Web';
    if (Platform.isAndroid) return 'Android';
    if (Platform.isIOS) return 'iOS';
    if (Platform.isWindows) return 'Windows';
    if (Platform.isMacOS) return 'macOS';
    if (Platform.isLinux) return 'Linux';
    return 'Unknown';
  }

  /// Debug information about current Supabase connection
  static void _debugSupabaseStatus() {
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;

      debugPrint('📊 Supabase Status:');
      debugPrint('   Platform: ${_getPlatformName()}');
      debugPrint('   URL: $_url');
      debugPrint('   User authenticated: ${user != null}');
      if (user != null) {
        debugPrint('   User ID: ${user.id}');
        debugPrint('   User email: ${user.email}');
      }
    } catch (e) {
      debugPrint('⚠️ Error getting Supabase status: $e');
    }
  }

  /// Test Supabase connection by attempting a simple query
  static Future<bool> testConnection() async {
    try {
      debugPrint('🔍 Testing Supabase connection...');
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;

      if (user == null) {
        debugPrint('❌ No authenticated user');
        return false;
      }

      // Try to fetch admin record
      final response = await client
          .from('admin')
          .select('id')
          .eq('auth_id', user.id)
          .maybeSingle();

      if (response != null) {
        debugPrint('✅ Connection successful. Admin ID: ${response['id']}');
        return true;
      } else {
        debugPrint('⚠️ No admin record found for user');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Connection test failed: $e');
      return false;
    }
  }
}
