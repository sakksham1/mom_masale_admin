import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'db_explorer_api.dart';
import '../../core/network/api_client_provider.dart' show apiClientProvider;

final dbExplorerApiProvider = Provider(
  (ref) => DbExplorerApi(ref.watch(apiClientProvider)),
);

final dbTablesProvider = FutureProvider<List<DbTable>>((ref) {
  return ref.watch(dbExplorerApiProvider).fetchTables();
});
