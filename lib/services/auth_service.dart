import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import 'database_service.dart';

/// Authentication service for Google Sign-In
/// Manages user authentication state and profile data
class AuthService extends ChangeNotifier {
  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);

  final DatabaseService _dbService = DatabaseService();

  AppUser? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  AppUser? get currentUser => _currentUser;
  bool get isSignedIn => _currentUser != null;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Initialize service and restore session
  Future<void> initialize() async {
    debugPrint('🔐 Initializing AuthService...');
    _isLoading = true;
    notifyListeners();

    try {
      // Try to restore user from local storage
      await _loadUserFromLocal();

      // Try silent sign-in if user was previously signed in
      if (_currentUser == null) {
        await _silentSignIn();
      }
    } catch (e) {
      debugPrint('❌ Error initializing auth: $e');
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Sign in with Google
  Future<bool> signInWithGoogle() async {
    debugPrint('🔐 Starting Google Sign-In...');
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Trigger Google Sign-In flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        // User cancelled the sign-in
        debugPrint('⚠️ User cancelled Google Sign-In');
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Create user from Google account
      _currentUser = AppUser(
        id: googleUser.id,
        email: googleUser.email,
        displayName: googleUser.displayName ?? 'User',
        photoUrl: googleUser.photoUrl,
        loginDate: DateTime.now(),
      );

      // Save to database and local storage
      await _saveUser(_currentUser!);

      debugPrint('✅ Google Sign-In successful: ${_currentUser!.email}');
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (error) {
      debugPrint('❌ Google Sign-In error: $error');
      _errorMessage = 'Failed to sign in with Google. Please try again.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    debugPrint('🔐 Signing out...');
    _isLoading = true;
    notifyListeners();

    try {
      // Sign out from Google
      await _googleSignIn.signOut();

      // Clear user data
      if (_currentUser != null) {
        await _dbService.deleteUser(_currentUser!.id);
        await _clearLocalStorage();
      }

      _currentUser = null;
      _errorMessage = null;

      debugPrint('✅ Sign out successful');
    } catch (error) {
      debugPrint('❌ Sign out error: $error');
      _errorMessage = 'Failed to sign out. Please try again.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Silent sign-in (restore session without UI)
  Future<void> _silentSignIn() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn
          .signInSilently();

      if (googleUser != null) {
        _currentUser = AppUser(
          id: googleUser.id,
          email: googleUser.email,
          displayName: googleUser.displayName ?? 'User',
          photoUrl: googleUser.photoUrl,
          loginDate: DateTime.now(),
        );

        await _saveUser(_currentUser!);
        debugPrint('✅ Silent sign-in successful: ${_currentUser!.email}');
      }
    } catch (e) {
      debugPrint('⚠️ Silent sign-in failed: $e');
    }
  }

  /// Save user to database and local storage
  Future<void> _saveUser(AppUser user) async {
    try {
      // Save to SQLite database
      await _dbService.saveUser(user);

      // Save to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('current_user', jsonEncode(user.toJson()));

      debugPrint('💾 User saved to local storage');
    } catch (e) {
      debugPrint('❌ Error saving user: $e');
    }
  }

  /// Load user from local storage
  Future<void> _loadUserFromLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString('current_user');

      if (userJson != null) {
        final userMap = jsonDecode(userJson) as Map<String, dynamic>;
        _currentUser = AppUser.fromJson(userMap);
        debugPrint('✅ User loaded from local storage: ${_currentUser!.email}');
      }
    } catch (e) {
      debugPrint('⚠️ Error loading user from local storage: $e');
    }
  }

  /// Clear local storage
  Future<void> _clearLocalStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('current_user');
      debugPrint('🗑️ Local storage cleared');
    } catch (e) {
      debugPrint('❌ Error clearing local storage: $e');
    }
  }

  /// Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
