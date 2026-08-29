import 'package:flutter/foundation.dart';

/// Manages Firebase Auth state (anonymous auth for MVP).
///
/// In production, this would integrate with Firebase Auth
/// for user identification and job ownership.
class AuthProvider extends ChangeNotifier {
  String? _userId;
  bool _isAuthenticated = false;
  bool _isLoading = false;

  String? get userId => _userId;
  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;

  /// Sign in anonymously for MVP.
  /// In production, replace with Firebase Auth anonymous sign-in.
  Future<void> signInAnonymously() async {
    _isLoading = true;
    notifyListeners();

    try {
      // MVP: Use a generated user ID
      // In production: final credential = await FirebaseAuth.instance.signInAnonymously();
      await Future.delayed(const Duration(milliseconds: 300));
      _userId = 'user_${DateTime.now().millisecondsSinceEpoch}';
      _isAuthenticated = true;
    } catch (e) {
      _isAuthenticated = false;
      _userId = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    _userId = null;
    _isAuthenticated = false;
    notifyListeners();
  }
}
