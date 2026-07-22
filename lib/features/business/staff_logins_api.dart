import '../../core/network/api_client.dart';

class StaffLogin {
  final int id;
  final String userName, userRole, createdAt;
  final String? platform, userAgent, ipAddress;

  StaffLogin({
    required this.id,
    required this.userName,
    required this.userRole,
    this.platform,
    this.userAgent,
    this.ipAddress,
    required this.createdAt,
  });

  factory StaffLogin.fromJson(Map<String, dynamic> j) => StaffLogin(
    id: j['id'],
    userName: j['user_name'] ?? 'Unknown',
    userRole: j['user_role'] ?? '',
    platform: j['platform'],
    userAgent: j['user_agent'],
    ipAddress: j['ip_address'],
    createdAt: j['created_at'] ?? '',
  );
}

class StaffLoginsApi {
  final ApiClient client;
  StaffLoginsApi(this.client);

  Future<List<StaffLogin>> fetchRecent({int limit = 50}) async {
    final res = await client.get(
      '/api/manager/staff-logins',
      query: {'limit': '$limit'},
    );
    return (res.data['logins'] as List)
        .map((l) => StaffLogin.fromJson(l))
        .toList();
  }
}
