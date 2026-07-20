import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'raw_materials_api.dart';
import '../../core/network/api_client_provider.dart' show apiClientProvider;

final rawMaterialsApiProvider = Provider(
  (ref) => RawMaterialsApi(ref.watch(apiClientProvider)),
);

final rawMaterialsProvider = FutureProvider<List<RawMaterial>>((ref) {
  return ref.watch(rawMaterialsApiProvider).fetchRawMaterials();
});
