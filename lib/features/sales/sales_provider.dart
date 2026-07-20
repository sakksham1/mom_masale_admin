import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'sales_api.dart';
import '../../core/network/api_client_provider.dart' show apiClientProvider;

final salesApiProvider = Provider(
  (ref) => SalesApi(ref.watch(apiClientProvider)),
);

final salesStatsProvider = FutureProvider<SalesStats>((ref) {
  return ref.watch(salesApiProvider).fetchStats();
});

final mySalesReportsProvider = FutureProvider<List<SalesReport>>((ref) {
  return ref.watch(salesApiProvider).fetchMyReports();
});
