import '../../core/network/api_client.dart';
import '../../core/auth/user_role.dart';

class Customer {
  final int id;
  final String name, email;
  final String? phone;
  final UserRole role;
  final String createdAt;
  final int orderCount, lifetimeSpend;
  final String? signupPlatform; // NEW

  Customer({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    required this.role,
    required this.createdAt,
    required this.orderCount,
    required this.lifetimeSpend,
    this.signupPlatform,
  });

  bool get isAdmin => role == UserRole.admin;

  /// True for a role=customer account that signed up from the admin app —
  /// i.e. a prospective staff member still waiting on a role.
  bool get isPendingAppSignup =>
      role == UserRole.customer &&
      signupPlatform != null &&
      signupPlatform != 'web' &&
      signupPlatform != 'unknown';

  factory Customer.fromJson(Map<String, dynamic> j) => Customer(
    id: j['id'],
    name: j['name'],
    email: j['email'],
    phone: j['phone'],
    role: UserRole.fromString(j['role'] as String?),
    createdAt: j['created_at'],
    orderCount: j['order_count'] ?? 0,
    lifetimeSpend: j['lifetime_spend'] ?? 0,
    signupPlatform: j['signup_platform'],
  );
}

class CustomersApi {
  final ApiClient client;
  CustomersApi(this.client);

  Future<List<Customer>> fetchCustomers() async {
    final res = await client.get('/api/admin/customers');
    return (res.data['customers'] as List)
        .map((c) => Customer.fromJson(c))
        .toList();
  }

  Future<void> updateRole(int userId, String role) {
    return client.patch('/api/admin/roles', {'userId': userId, 'role': role});
  }
}
