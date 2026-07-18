import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'orders_api.dart';
import '../../core/network/api_client_provider.dart';


final ordersApiProvider = Provider((ref) => OrdersApi(ref.watch(apiClientProvider)));

final ordersProvider = FutureProvider.family<List<Order>, String?>((ref, statusFilter) {
  return ref.watch(ordersApiProvider).fetchOrders(status: statusFilter);
});