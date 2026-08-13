import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'wheel_api.dart';
import '../../core/network/api_client_provider.dart' show apiClientProvider;

final wheelApiProvider = Provider(
  (ref) => WheelApi(ref.watch(apiClientProvider)),
);

final wheelModesProvider = FutureProvider<List<WheelMode>>((ref) {
  return ref.watch(wheelApiProvider).fetchModes();
});

/// Per-mode wedge list — also used by the mode-list cards to show a live
/// wedge count without a separate bulk endpoint.
final wheelItemsProvider = FutureProvider.family<List<WheelItem>, int>((
  ref,
  modeId,
) {
  return ref.watch(wheelApiProvider).fetchItems(modeId);
});
