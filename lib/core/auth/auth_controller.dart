import 'dart:async';
import 'package:flutter/foundation.dart';
import 'app_user.dart';
import 'user_role.dart';
import '../network/api_client.dart';
import '../notifications/push_notification_service.dart';

class AuthController extends ChangeNotifier {
  final ApiClient _client;
  AuthController(this._client) {
    _client.onUnauthorized = () {
      _user = null;
      notifyListeners();
    };
  }

  AppUser? _user;
  AppUser? get user => _user;
  bool get isLoggedIn => _user != null;
  UserRole get role => _user?.role ?? UserRole.unknown;
  bool get emailVerified => _user?.emailVerified ?? false;

  bool _initializing = true;
  bool get initializing => _initializing;

  bool _canReceivePush(UserRole role) =>
      role == UserRole.admin || role == UserRole.manager;

  Future<void> restoreSession() async {
    try {
      _user = await _client.fetchCurrentUser();
      if (_user != null && _canReceivePush(_user!.role)) {
        unawaited(PushNotificationService.instance.init(_client));
      }
    } catch (e, st) {
      debugPrint('restoreSession failed: $e\n$st');
    } finally {
      _initializing = false;
      notifyListeners();
    }
  }

  Future<void> login(String email, String password) async {
    _user = await _client.login(email, password);
    if (_canReceivePush(_user!.role)) {
      unawaited(PushNotificationService.instance.init(_client));
    }
    notifyListeners();
  }

  Future<void> signup({
    required String name,
    required String email,
    required String password,
    required String phone,
  }) async {
    _user = await _client.signup(
      name: name,
      email: email,
      password: password,
      phone: phone,
    );
    notifyListeners();
  }

  Future<bool> sendVerifyOtp() => _client.sendVerifyOtp();

  Future<void> verifyEmail(String otp) async {
    await _client.verifyEmail(otp);
    // verify-email.js only returns {ok:true} — refetch to pick up the
    // updated emailVerified flag on _user.
    await restoreSession();
  }

  Future<void> logout() async {
    await PushNotificationService.instance.unregister();
    await _client.logout();
    _user = null;
    notifyListeners();
  }
}
