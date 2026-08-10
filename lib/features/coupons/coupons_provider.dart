import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'coupons_api.dart';
import '../../core/network/api_client_provider.dart' show apiClientProvider;

final couponsApiProvider = Provider(
  (ref) => CouponsApi(ref.watch(apiClientProvider)),
);

final couponsProvider = FutureProvider<List<Coupon>>((ref) {
  return ref.watch(couponsApiProvider).fetchCoupons();
});
