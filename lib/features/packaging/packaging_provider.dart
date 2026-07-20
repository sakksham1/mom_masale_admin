import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'packaging_api.dart';
import '../../core/network/api_client_provider.dart' show apiClientProvider;

final packagingApiProvider = Provider(
  (ref) => PackagingApi(ref.watch(apiClientProvider)),
);

final staffProductsProvider = FutureProvider<List<StaffProduct>>((ref) {
  return ref.watch(packagingApiProvider).fetchStaffProducts();
});

final myPackagingReportsProvider = FutureProvider<List<PackagingReport>>((ref) {
  return ref.watch(packagingApiProvider).fetchMyReports();
});
