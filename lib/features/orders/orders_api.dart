import '../../core/network/api_client.dart';

class Order {
  final int id;
  final String customerName, phone, status, paymentStatus, createdAt;
  final int total;
  final List<OrderItem> items;

  Order({
    required this.id,
    required this.customerName,
    required this.phone,
    required this.status,
    required this.paymentStatus,
    required this.createdAt,
    required this.total,
    required this.items,
  });

  factory Order.fromJson(Map<String, dynamic> j) => Order(
    id: j['id'],
    customerName: j['customer_name'],
    phone: j['phone'],
    status: j['status'],
    paymentStatus: j['payment_status'],
    createdAt: j['created_at'],
    total: j['total'],
    items: (j['items'] as List).map((i) => OrderItem.fromJson(i)).toList(),
  );
}

class OrderItem {
  final String productName, size;
  final int qty, unitPrice;
  OrderItem({
    required this.productName,
    required this.size,
    required this.qty,
    required this.unitPrice,
  });
  factory OrderItem.fromJson(Map<String, dynamic> j) => OrderItem(
    productName: j['product_name'],
    size: j['size'],
    qty: j['qty'],
    unitPrice: j['unit_price'],
  );
}

class OrdersApi {
  final ApiClient client;
  OrdersApi(this.client);

  Future<List<Order>> fetchOrders({
    String? status,
    String? paymentStatus,
  }) async {
    final params = <String, String>{};
    if (status != null) params['status'] = status;
    if (paymentStatus != null) params['payment_status'] = paymentStatus;
    final query = Uri(queryParameters: params).query;
    final res = await client.get(
      '/api/admin/orders${query.isNotEmpty ? '?$query' : ''}',
    );
    return (res.data['orders'] as List).map((o) => Order.fromJson(o)).toList();
  }

  Future<void> updateOrder(
    int orderId, {
    String? status,
    String? paymentStatus,
  }) {
    return client.patch('/api/admin/orders', {
      'orderId': orderId,
      'status': ?status,
      'payment_status': ?paymentStatus,
    });
  }
}
