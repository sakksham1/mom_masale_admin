import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'publish_queue_api.dart';
import '../../core/network/api_client_provider.dart' show apiClientProvider;

final publishQueueApiProvider = Provider(
  (ref) => PublishQueueApi(ref.watch(apiClientProvider)),
);

final publishQueueProvider = FutureProvider<SyncQueueState>((ref) {
  return ref.watch(publishQueueApiProvider).fetchQueue();
});
