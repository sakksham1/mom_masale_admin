import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:dio/dio.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:path_provider/path_provider.dart';
import '../config/env.dart';
import 'api_exception.dart';
import '../auth/app_user.dart';

class ApiClient {
  late final Dio dio;
  late final CookieJar cookieJar;

  /// Called whenever a request comes back 401. Wire this to your auth
  /// controller so the router can redirect to /login automatically,
  /// instead of every screen having to notice on its own.
  void Function()? onUnauthorized;

  Future<void> init() async {
    if (kIsWeb) {
      cookieJar = CookieJar();
    } else {
      final dir = await getApplicationDocumentsDirectory();
      cookieJar = PersistCookieJar(
        storage: FileStorage('${dir.path}/.cookies/'),
      );
    }
    dio = Dio(
      BaseOptions(
        baseUrl: Env.apiBaseUrl,
        headers: {'Content-Type': 'application/json'},
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        extra: {'withCredentials': true},
      ),
    );
    dio.interceptors.add(CookieManager(cookieJar));
  }

  ApiException _mapError(DioException e) {
    final status = e.response?.statusCode;
    switch (e.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return const NetworkException();
      default:
        break;
    }
    switch (status) {
      case 401:
        onUnauthorized?.call();
        return const UnauthorizedException();
      case 403:
        return const ForbiddenException();
      case 404:
        return const NotFoundException();
      case 422:
        final data = e.response?.data;
        if (data is Map && data['errors'] is Map) {
          final errors = (data['errors'] as Map).map(
            (k, v) => MapEntry(k.toString(), List<String>.from(v)),
          );
          return ValidationException(errors);
        }
        return const ValidationException({});
      case 500:
      case 502:
      case 503:
        return const ServerException();
      default:
        return const UnknownApiException();
    }
  }

  Future<T> _run<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<Response> get(String path, {Map<String, dynamic>? query}) =>
      _run(() => dio.get(path, queryParameters: query));

  Future<Response> post(String path, Map<String, dynamic> body) =>
      _run(() => dio.post(path, data: body));

  Future<Response> patch(String path, Map<String, dynamic> body) =>
      _run(() => dio.patch(path, data: body));

  Future<Response> delete(String path) => _run(() => dio.delete(path));

  Future<bool> isLoggedInAdmin() async {
    try {
      final res = await dio.get('/api/admin/stats');
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // --- Auth ---

  /// Returns the logged-in user (with role) on success, throws ApiException
  /// (typically UnauthorizedException) on failure.
  Future<AppUser> login(String email, String password) async {
    try {
      final res = await post('/api/auth/login', {
        'email': email,
        'password': password,
      });
      return AppUser.fromJson(res.data['user']);
    } on UnauthorizedException {
      throw const UnauthorizedException('Invalid email or password.');
    }
  }

  /// Checks for an existing session on app launch (cookie already present)
  /// and returns the current user if valid, or null if not logged in.
  ///
  /// ASSUMPTION: hits GET /api/auth/me returning the same user shape as
  /// login (id, name, email, phone, role). Flag if this endpoint doesn't
  /// exist yet — see note below.
  Future<AppUser?> fetchCurrentUser() async {
    try {
      final res = await get('/api/auth/me');
      return AppUser.fromJson(res.data['user']);
    } catch (_) {
      return null;
    }
  }

  Future<void> logout() async {
    try {
      await post('/api/auth/logout', {});
    } on ApiException {
      // ignore — clearing local state below is what actually matters
    }
    cookieJar.deleteAll();
  }
}
