import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'products_api.dart';
import '../../core/network/api_client_provider.dart' show apiClientProvider;

final productsApiProvider = Provider((ref) => ProductsApi(ref.watch(apiClientProvider)));

final productsProvider = FutureProvider<List<Product>>((ref) {
  return ref.watch(productsApiProvider).fetchProducts();
});
