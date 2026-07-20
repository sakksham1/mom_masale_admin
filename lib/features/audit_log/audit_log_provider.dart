import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'audit_log_api.dart';
import '../../core/network/api_client_provider.dart' show apiClientProvider;

final auditLogApiProvider = Provider(
  (ref) => AuditLogApi(ref.watch(apiClientProvider)),
);

final auditLogFirstPageProvider = FutureProvider<AuditLogPage>((ref) {
  return ref.watch(auditLogApiProvider).fetchLogs(limit: 6);
});
