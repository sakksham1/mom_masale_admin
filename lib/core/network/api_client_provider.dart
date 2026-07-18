import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api_client.dart';
import '../auth/auth_controller.dart';

final apiClientProvider = Provider<ApiClient>((ref) {
  throw UnimplementedError('apiClientProvider must be overridden in main.dart');
});

final authControllerProvider = ChangeNotifierProvider<AuthController>((ref) {
  return AuthController(ref.watch(apiClientProvider));
});