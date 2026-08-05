import '../../core/network/api_client.dart';

class SyncQueueItem {
  final int id;
  final String
  sourceType; // product_core | review | product_create | product_delete
  final int? sourceId;
  final String? productSlug;
  final String summary;
  final String createdAt;
  final String? createdByName;

  SyncQueueItem({
    required this.id,
    required this.sourceType,
    this.sourceId,
    this.productSlug,
    required this.summary,
    required this.createdAt,
    this.createdByName,
  });

  factory SyncQueueItem.fromJson(Map<String, dynamic> j) => SyncQueueItem(
    id: j['id'],
    sourceType: j['source_type'] ?? '',
    sourceId: j['source_id'],
    productSlug: j['product_slug'],
    summary: j['summary'] ?? '',
    createdAt: j['created_at'] ?? '',
    createdByName: j['created_by_name'],
  );
}

class LastSyncBatch {
  final int id;
  final int itemCount;
  final String status; // running | success | failed
  final String? errorMessage;
  final String? startedAt, completedAt, triggeredByName;

  LastSyncBatch({
    required this.id,
    required this.itemCount,
    required this.status,
    this.errorMessage,
    this.startedAt,
    this.completedAt,
    this.triggeredByName,
  });

  bool get failed => status == 'failed';
  bool get running => status == 'running';

  factory LastSyncBatch.fromJson(Map<String, dynamic> j) => LastSyncBatch(
    id: j['id'],
    itemCount: j['item_count'] ?? 0,
    status: j['status'] ?? '',
    errorMessage: j['error_message'],
    startedAt: j['started_at'],
    completedAt: j['completed_at'],
    triggeredByName: j['triggered_by_name'],
  );
}

class SyncQueueState {
  final List<SyncQueueItem> pending;
  final int pendingCount;
  final LastSyncBatch? lastBatch;

  SyncQueueState({
    required this.pending,
    required this.pendingCount,
    this.lastBatch,
  });

  factory SyncQueueState.fromJson(Map<String, dynamic> j) => SyncQueueState(
    pending: (j['pending'] as List? ?? [])
        .map((p) => SyncQueueItem.fromJson(p))
        .toList(),
    pendingCount: j['pendingCount'] ?? 0,
    lastBatch: j['lastBatch'] != null
        ? LastSyncBatch.fromJson(j['lastBatch'])
        : null,
  );
}

class PublishResult {
  final bool published;
  final String? message;
  final int? batchId;
  final int? itemCount;
  PublishResult({
    required this.published,
    this.message,
    this.batchId,
    this.itemCount,
  });

  factory PublishResult.fromJson(Map<String, dynamic> j) => PublishResult(
    published: j['published'] == true,
    message: j['message'],
    batchId: j['batchId'],
    itemCount: j['itemCount'],
  );
}

class PublishQueueApi {
  final ApiClient client;
  PublishQueueApi(this.client);

  Future<SyncQueueState> fetchQueue() async {
    final res = await client.get('/api/admin/sync-queue');
    return SyncQueueState.fromJson(res.data);
  }

  /// Throws ConflictException (409) if a publish is already running, or
  /// ServerException (502/500) with the backend's error message if the
  /// GitHub sync itself failed. Either way, nothing is lost — the queue
  /// items stay pending and this is safe to retry.
  Future<PublishResult> runPublish() async {
    final res = await client.post('/api/admin/sync-queue/run', {});
    return PublishResult.fromJson(res.data);
  }

  /// ASSUMPTION: the backend exposes POST /api/admin/sync-queue/discard,
  /// clearing every currently-pending item without publishing anything
  /// (nothing goes live, and the discarded items are gone — not archived).
  /// Flag if this endpoint doesn't exist yet so the backend agent can add it.
  Future<void> discardQueue() async {
    await client.post('/api/admin/sync-queue/discard', {});
  }
}
