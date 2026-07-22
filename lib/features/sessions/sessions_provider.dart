import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'sessions_api.dart';
import '../../core/network/api_client_provider.dart' show apiClientProvider;

final sessionsApiProvider = Provider(
  (ref) => SessionsApi(ref.watch(apiClientProvider)),
);

final userSessionsProvider = FutureProvider<List<UserSession>>((ref) {
  return ref.watch(sessionsApiProvider).fetchSessions();
});
