import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final _supabase = Supabase.instance.client;

  /// Check if user is logged in
  Future<bool> isUserLoggedIn() async {
    try {
      final session = _supabase.auth.currentSession;
      return session != null;
    } catch (e) {
      print('Error checking user login: $e');
      return false;
    }
  }

  /// Get current user
  User? getCurrentUser() {
    return _supabase.auth.currentUser;
  }

  /// Check if user exists in admin table
  Future<bool> isAdminExists(String authId) async {
    try {
      final response = await _supabase
          .from('admin')
          .select('id')
          .eq('auth_id', authId)
          .maybeSingle();

      return response != null;
    } catch (e) {
      print('Error checking admin: $e');
      return false;
    }
  }

  /// Login with email and password (with admin check)
  Future<AuthResponse> login(String email, String password) async {
    try {
      // Step 1: Authenticate user
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      // Step 2: Check if user exists in admin table
      final userId = response.user?.id;
      if (userId == null) {
        throw Exception('User authentication failed');
      }

      final adminExists = await isAdminExists(userId);
      if (!adminExists) {
        // User authenticated but not admin - logout
        await _supabase.auth.signOut();
        throw Exception('You are not registered as an admin. Contact administrator.');
      }

      return response;
    } on AuthException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception('$e');
    }
  }

  /// Logout
  Future<void> logout() async {
    try {
      await _supabase.auth.signOut();
    } catch (e) {
      throw Exception('Logout failed: $e');
    }
  }

  /// Get auth state stream
  Stream<AuthState> authStateChanges() {
    return _supabase.auth.onAuthStateChange;
  }

  /// Get current session
  Session? getSession() {
    return _supabase.auth.currentSession;
  }
}