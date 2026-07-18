import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dashboard_api.dart';
import '../orders/orders_provider.dart' show apiClientProvider;

final dashboardApiProvider = Provider((ref) => DashboardApi(ref.watch(apiClientProvider)));

final dashboardStatsProvider = FutureProvider<DashboardStats>((ref) {
  return ref.watch(dashboardApiProvider).fetchStats();
});