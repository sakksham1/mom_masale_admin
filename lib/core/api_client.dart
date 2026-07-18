import 'package:dio/dio.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:path_provider/path_provider.dart';

class ApiClient {
  static const baseUrl = 'https://mommasale.com';
  late final Dio dio;
  late final PersistCookieJar cookieJar;

  Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    cookieJar = PersistCookieJar(storage: FileStorage('${dir.path}/.cookies/'));
    dio = Dio(BaseOptions(baseUrl: baseUrl, headers: {'Content-Type': 'application/json'}));
    dio.interceptors.add(CookieManager(cookieJar));
  }

  Future<Response> get(String path) => dio.get(path);
  Future<Response> post(String path, Map<String, dynamic> body) => dio.post(path, data: body);
  Future<Response> patch(String path, Map<String, dynamic> body) => dio.patch(path, data: body);

  Future<bool> isLoggedInAdmin() async {
    try {
      final res = await dio.get('/api/admin/stats');
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}