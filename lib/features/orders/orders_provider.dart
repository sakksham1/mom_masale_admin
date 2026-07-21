import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'orders_api.dart';
import '../../core/network/api_client_provider.dart';

final ordersApiProvider = Provider(
  (ref) => OrdersApi(ref.watch(apiClientProvider)),
);

/// (status, paymentStatus) — either can be null ("no filter" on that
/// dimension). A record gives FutureProvider.family free structural
/// equality, so each distinct filter combo is cached/invalidated on its own.
typedef OrdersFilter = ({String? status, String? paymentStatus});

final ordersProvider = FutureProvider.family<List<Order>, String?>((
  ref,
  statusFilter,
) {
  return ref.watch(ordersApiProvider).fetchOrders(status: statusFilter);
});
