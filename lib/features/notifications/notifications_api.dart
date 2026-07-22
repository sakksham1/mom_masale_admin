import '../../core/network/api_client.dart';

class AppNotification {
  final int id;
  final String type, title, createdAt;
  final String? body, referenceType, readAt;
  final int? referenceId;

  AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.createdAt,
    this.body,
    this.referenceType,
    this.referenceId,
    this.readAt,
  });

  bool get isUnread => readAt == null;

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
    id: j['id'],
    type: j['type'],
    title: j['title'],
    createdAt: j['created_at'],
    body: j['body'],
    referenceType: j['reference_type'],
    referenceId: j['reference_id'],
    readAt: j['read_at'],
  );
}

class NotificationsFetchResult {
  final List<AppNotification> notifications;
  final int unreadCount;
  NotificationsFetchResult({
    required this.notifications,
    required this.unreadCount,
  });
}

class NotificationsApi {
  final ApiClient client;
  NotificationsApi(this.client);

  Future<NotificationsFetchResult> fetch({int limit = 20}) async {
    final res = await client.get(
      '/api/admin/notifications',
      query: {'limit': '$limit'},
    );
    return NotificationsFetchResult(
      notifications: (res.data['notifications'] as List)
          .map((n) => AppNotification.fromJson(n))
          .toList(),
      unreadCount: res.data['unreadCount'] as int? ?? 0,
    );
  }

  Future<void> markRead({int? id}) {
    return client.post('/api/admin/notifications', {'id': ?id});
  }
}
