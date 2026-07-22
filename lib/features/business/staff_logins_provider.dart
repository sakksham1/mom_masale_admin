import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'staff_logins_api.dart';
import '../../core/network/api_client_provider.dart' show apiClientProvider;

final staffLoginsApiProvider = Provider(
  (ref) => StaffLoginsApi(ref.watch(apiClientProvider)),
);

final staffLoginsProvider = FutureProvider<List<StaffLogin>>((ref) {
  return ref.watch(staffLoginsApiProvider).fetchRecent();
});
