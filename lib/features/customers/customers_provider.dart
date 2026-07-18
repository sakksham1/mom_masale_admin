import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_client.dart';
import 'customers_api.dart';
import '../orders/orders_provider.dart' show apiClientProvider;

final customersApiProvider = Provider((ref) => CustomersApi(ref.watch(apiClientProvider)));

final customersProvider = FutureProvider<List<Customer>>((ref) {
  return ref.watch(customersApiProvider).fetchCustomers();
});