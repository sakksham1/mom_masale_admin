import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_client.dart';
import 'orders_api.dart';

final apiClientProvider = Provider<ApiClient>((ref) {
  throw UnimplementedError('apiClientProvider must be overridden in main.dart');
});

final ordersApiProvider = Provider((ref) => OrdersApi(ref.watch(apiClientProvider)));

final ordersProvider = FutureProvider.family<List<Order>, String?>((ref, statusFilter) {
  return ref.watch(ordersApiProvider).fetchOrders(status: statusFilter);
});