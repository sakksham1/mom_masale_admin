import '../../core/network/api_client.dart';

class AuditLogEntry {
  final int id;
  final String? userName, action, resource, createdAt;
  final String?
  resourceId; // mixed-type in D1: slugs, "productId:size", or plain ints — always treat as text
  final Map<String, dynamic>? diff;

  AuditLogEntry({
    required this.id,
    this.userName,
    this.action,
    this.resource,
    this.resourceId,
    this.diff,
    this.createdAt,
  });

  factory AuditLogEntry.fromJson(Map<String, dynamic> j) => AuditLogEntry(
    id: j['id'],
    userName: j['user_name'],
    action: j['action'],
    resource: j['resource'],
    // resource_id can arrive as a JSON number OR a string depending on what
    // was logged (e.g. a numeric userId vs. a product slug) — normalize
    // everything to String here so the UI never has to care.
    resourceId: j['resource_id']?.toString(),
    diff: j['diff'] as Map<String, dynamic>?,
    createdAt: j['created_at'],
  );

  String get summary {
    final who = userName ?? 'Someone';
    final what = resource ?? 'item';
    final id = resourceId != null && resourceId!.isNotEmpty
        ? ' #$resourceId'
        : '';
    return '$who ${action ?? 'updated'} $what$id';
  }
}

class AuditLogPage {
  final List<AuditLogEntry> logs;
  final bool hasMore;
  AuditLogPage({required this.logs, required this.hasMore});
}

class AuditLogApi {
  final ApiClient client;
  AuditLogApi(this.client);

  Future<AuditLogPage> fetchLogs({int limit = 20, int? beforeId}) async {
    final res = await client.get(
      '/api/admin/audit-log',
      query: {'limit': '$limit', if (beforeId != null) 'beforeId': '$beforeId'},
    );
    return AuditLogPage(
      logs: (res.data['logs'] as List)
          .map((l) => AuditLogEntry.fromJson(l))
          .toList(),
      hasMore: res.data['hasMore'] ?? false,
    );
  }
}
