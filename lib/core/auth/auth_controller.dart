import 'package:flutter/foundation.dart';
import 'app_user.dart';
import 'user_role.dart';
import '../network/api_client.dart';

/// Extends ChangeNotifier so go_router's refreshListenable can react to
/// login/logout without any manual navigation calls scattered in screens.
class AuthController extends ChangeNotifier {
  final ApiClient _client;
  AuthController(this._client) {
    _client.onUnauthorized = () {
      // Any 401 from anywhere in the app clears the session and the
      // router's redirect logic bounces the user to /login automatically.
      _user = null;
      notifyListeners();
    };
  }

  AppUser? _user;
  AppUser? get user => _user;
  bool get isLoggedIn => _user != null;
  UserRole get role => _user?.role ?? UserRole.unknown;

  bool _initializing = true;
  bool get initializing => _initializing;

  /// Call once at app startup to restore an existing cookie session.
  Future<void> restoreSession() async {
    try {
      _user = await _client.fetchCurrentUser();
    } catch (e, st) {
      debugPrint('restoreSession failed: $e\n$st');
    } finally {
      _initializing = false;
      notifyListeners();
    }
  }

  Future<void> login(String email, String password) async {
    _user = await _client.login(email, password);
    notifyListeners();
  }

  Future<void> logout() async {
    await _client.logout();
    _user = null;
    notifyListeners();
  }
}
