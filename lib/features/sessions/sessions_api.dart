import '../../core/network/api_client.dart';

class UserSession {
  final int id;
  final String? platform, userAgent, ipAddress;
  final String createdAt, lastSeenAt, expiresAt;
  final bool isCurrent;

  UserSession({
    required this.id,
    this.platform,
    this.userAgent,
    this.ipAddress,
    required this.createdAt,
    required this.lastSeenAt,
    required this.expiresAt,
    required this.isCurrent,
  });

  factory UserSession.fromJson(Map<String, dynamic> j) => UserSession(
    id: j['id'],
    platform: j['platform'],
    userAgent: j['userAgent'],
    ipAddress: j['ipAddress'],
    createdAt: j['createdAt'] ?? '',
    lastSeenAt: j['lastSeenAt'] ?? '',
    expiresAt: j['expiresAt'] ?? '',
    isCurrent: j['isCurrent'] == true,
  );
}

class SessionsApi {
  final ApiClient client;
  SessionsApi(this.client);

  Future<List<UserSession>> fetchSessions() async {
    final res = await client.get('/api/auth/sessions');
    return (res.data['sessions'] as List)
        .map((s) => UserSession.fromJson(s))
        .toList();
  }

  Future<void> revoke(int sessionId) {
    return client.deleteWithBody('/api/auth/sessions', {
      'sessionId': sessionId,
    });
  }
}
