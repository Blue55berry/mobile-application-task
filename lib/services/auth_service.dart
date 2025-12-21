import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import 'database_service.dart';

/// Authentication service for Google Sign-In
/// Manages user authentication state and profile data
class AuthService extends ChangeNotifier {
  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);

  // Use getters with safety checks to avoid early/missing initialization issues
  Future<void> _ensureFirebaseInitialized() async {
    if (Firebase.apps.isEmpty) {
      debugPrint(
        '🔄 Firebase not initialized. Attempting auto-initialization...',
      );
      try {
        await Firebase.initializeApp();
        debugPrint('✅ Firebase auto-initialized successfully');
      } catch (e) {
        debugPrint('❌ Firebase auto-initialization failed: $e');
        rethrow;
      }
    }
  }

  FirebaseAuth get _auth {
    if (Firebase.apps.isEmpty) {
      throw FirebaseException(
        plugin: 'firebase_auth',
        code: 'no-app',
        message: 'Firebase App has not been initialized.',
      );
    }
    return FirebaseAuth.instance;
  }

  FirebaseFirestore get _firestore {
    if (Firebase.apps.isEmpty) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'no-app',
        message: 'Firebase App has not been initialized.',
      );
    }
    return FirebaseFirestore.instance;
  }

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
      // 1. Ensure Firebase is ready
      await _ensureFirebaseInitialized();

      // 2. Try to restore user from local storage (Cached session)
      await _loadUserFromLocal();

      // 3. Sync with Firebase
      if (_currentUser != null && _auth.currentUser == null) {
        debugPrint(
          '🔄 Local session found but Firebase session missing. Syncing...',
        );
        await _silentSignIn();
      } else if (_currentUser == null) {
        await _silentSignIn();
      }

      if (_auth.currentUser != null && _currentUser != null) {
        await _syncUserWithFirestore(_currentUser!);
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
      // Ensure Firebase is ready
      await _ensureFirebaseInitialized();

      // Trigger Google Sign-In flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        // User cancelled the sign-in
        debugPrint('⚠️ User cancelled Google Sign-In');
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Obtain auth details from the request
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Create a new credential
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Once signed in, return the UserCredential
      final UserCredential userCredential = await _auth.signInWithCredential(
        credential,
      );
      final User? firebaseUser = userCredential.user;

      if (firebaseUser == null) {
        throw Exception('Firebase login failed');
      }

      // Create user from Firebase account data
      _currentUser = AppUser(
        id: firebaseUser.uid,
        email: firebaseUser.email ?? googleUser.email,
        displayName:
            firebaseUser.displayName ?? googleUser.displayName ?? 'User',
        photoUrl: firebaseUser.photoURL ?? googleUser.photoUrl,
        loginDate: DateTime.now(),
      );

      // Save to Firebase (Firestore), local database, and local storage
      await _syncUserWithFirestore(_currentUser!);
      await _saveUser(_currentUser!);

      debugPrint(
        '✅ Google/Firebase Sign-In successful: ${_currentUser!.email}',
      );
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (error) {
      debugPrint('❌ Google Sign-In error details: $error');

      if (error is FirebaseAuthException) {
        if (error.code == 'operation-not-allowed') {
          _errorMessage =
              'Google Sign-In is not enabled in Firebase Console. Please enable it in Authentication > Sign-in method.';
        } else {
          _errorMessage = 'Firebase Auth Error: ${error.message}';
        }
      } else {
        _errorMessage = 'Failed to sign in with Google. Please try again.';
      }

      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Sign in as Guest (Register Later)
  Future<bool> signInAsGuest() async {
    debugPrint('👤 Signing in as Guest...');
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _currentUser = AppUser(
        id: 'guest_${DateTime.now().millisecondsSinceEpoch}',
        email: 'guest@sbs.local',
        displayName: 'Guest User',
        photoUrl: null,
        loginDate: DateTime.now(),
      );

      await _saveUser(_currentUser!);

      debugPrint('✅ Guest Sign-In successful');
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('❌ Guest Sign-In error: $e');
      _errorMessage = 'Failed to enter as guest.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() async {
    debugPrint('🔐 Signing out...');
    _isLoading = true;
    notifyListeners();

    try {
      // 1. Sign out from Google (non-blocking)
      try {
        // Disconnect forces the account picker to appear on next login
        await _googleSignIn.disconnect();
        await _googleSignIn.signOut();
        debugPrint('✅ Google disconnect and sign-out complete');
      } catch (e) {
        debugPrint('⚠️ Google disconnect error (falling back to sign-out): $e');
        // Fallback to simple sign-out if disconnect fails
        await _googleSignIn.signOut();
      }

      // 2. Sign out from Firebase (non-blocking)
      try {
        // Only attempt if Firebase is initialized
        if (Firebase.apps.isNotEmpty) {
          await _auth.signOut();
          debugPrint('✅ Firebase sign-out complete');
        } else {
          debugPrint('ℹ️ Skipping Firebase sign-out: No Firebase apps found.');
        }
      } catch (e) {
        debugPrint('⚠️ Firebase sign-out error: $e');
      }

      // 3. ALWAYS clear local data regardless of remote sign-out success
      if (_currentUser != null) {
        await _dbService.deleteUser(_currentUser!.id);
        await _clearLocalStorage();
      }

      _currentUser = null;
      _errorMessage = null;

      debugPrint('✅ local sign-out successful');
    } catch (error) {
      debugPrint('❌ Sign out error: $error');
      // Still set user to null to let them escape the screen
      _currentUser = null;
      _errorMessage = 'Signed out locally, but some remote services failed.';
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
        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;
        final OAuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        final UserCredential userCredential = await _auth.signInWithCredential(
          credential,
        );
        final User? firebaseUser = userCredential.user;

        if (firebaseUser != null) {
          _currentUser = AppUser(
            id: firebaseUser.uid,
            email: firebaseUser.email ?? googleUser.email,
            displayName:
                firebaseUser.displayName ?? googleUser.displayName ?? 'User',
            photoUrl: firebaseUser.photoURL ?? googleUser.photoUrl,
            loginDate: DateTime.now(),
          );

          await _syncUserWithFirestore(_currentUser!);
          await _saveUser(_currentUser!);
          debugPrint(
            '✅ Silent Firebase sign-in successful: ${_currentUser!.email}',
          );
        }
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

  /// Sync user data with Firebase Firestore
  Future<void> _syncUserWithFirestore(AppUser user) async {
    // Skip sync for guest users
    if (user.id.startsWith('guest_')) {
      debugPrint('ℹ️ Skipping Firestore sync for guest user.');
      return;
    }

    try {
      // Store user record in Firestore console
      await _firestore
          .collection('users')
          .doc(user.id)
          .set(user.toMap(), SetOptions(merge: true));
      debugPrint('☁️ User profile synced with Firestore Console');
    } catch (e) {
      debugPrint('❌ Firestore sync error: $e');
      final errorStr = e.toString();
      if (errorStr.contains('Cloud Firestore API has not been used')) {
        _errorMessage =
            'Firestore API is not enabled. Please enable it in the Google Cloud/Firebase Console.';
        notifyListeners();
      } else if (errorStr.contains('permission-denied') ||
          errorStr.contains('Missing or insufficient permissions')) {
        _errorMessage =
            'Firestore Security Rules are blocking the sync. Please set Rules to "allow read, write: if request.auth != null;" in the Firebase Console.';
        notifyListeners();
      }
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
