import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'catalog_api.dart';
import '../../core/network/api_client_provider.dart' show apiClientProvider;

final catalogApiProvider = Provider((ref) => CatalogApi(ref.watch(apiClientProvider)));

final catalogProvider = FutureProvider<List<CatalogProduct>>((ref) {
  return ref.watch(catalogApiProvider).fetchProducts();
});
