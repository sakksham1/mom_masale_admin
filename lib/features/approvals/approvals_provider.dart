import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'approvals_api.dart';
import '../../core/network/api_client_provider.dart' show apiClientProvider;

final approvalsApiProvider = Provider(
  (ref) => ApprovalsApi(ref.watch(apiClientProvider)),
);

final approvalsQueueProvider = FutureProvider<ApprovalsQueue>((ref) {
  return ref.watch(approvalsApiProvider).fetchQueue();
});
