import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'my_requests_api.dart';
import '../../core/network/api_client_provider.dart' show apiClientProvider;

final myRequestsApiProvider = Provider(
  (ref) => MyRequestsApi(ref.watch(apiClientProvider)),
);

final myRequestsProvider = FutureProvider<MyRequests>((ref) {
  return ref.watch(myRequestsApiProvider).fetchMine();
});
