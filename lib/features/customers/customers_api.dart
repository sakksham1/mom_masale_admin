import '../../core/api_client.dart';

class Customer {
  final int id;
  final String name, email;
  final String? phone;
  final bool isAdmin;
  final String createdAt;
  final int orderCount, lifetimeSpend;

  Customer({
    required this.id, required this.name, required this.email, this.phone,
    required this.isAdmin, required this.createdAt,
    required this.orderCount, required this.lifetimeSpend,
  });

  factory Customer.fromJson(Map<String, dynamic> j) => Customer(
    id: j['id'],
    name: j['name'],
    email: j['email'],
    phone: j['phone'],
    isAdmin: j['is_admin'] == 1 || j['is_admin'] == true,
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