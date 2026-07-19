import '../../core/network/api_client.dart';
import '../../core/auth/user_role.dart';

class Customer {
  final int id;
  final String name, email;
  final String? phone;
  final UserRole role;
  final String createdAt;
  final int orderCount, lifetimeSpend;

  Customer({
    required this.id, required this.name, required this.email, this.phone,
    required this.role, required this.createdAt,
    required this.orderCount, required this.lifetimeSpend,
  });

  /// Kept so existing UI code (the "Admin" chip in customers_list_screen.dart)
  /// doesn't need to change — now derived from role instead of the retired
  /// is_admin column.
  bool get isAdmin => role == UserRole.admin;

  factory Customer.fromJson(Map<String, dynamic> j) => Customer(
    id: j['id'],
    name: j['name'],
    email: j['email'],
    phone: j['phone'],
    role: UserRole.fromString(j['role'] as String?),
    createdAt: j['created_at'],
    orderCount: j['order_count'] ?? 0,
    lifetimeSpend: j['lifetime_spend'] ?? 0,
  );
}

class CustomersApi {
  final ApiClient client;
  CustomersApi(this.client);

  Future<List<Customer>> fetchCustomers() async {
    final res = await client.get('/api/admin/customers');
    return (res.data['customers'] as List).map((c) => Customer.fromJson(c)).toList();
  }
}
