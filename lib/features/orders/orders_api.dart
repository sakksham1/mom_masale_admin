import '../../core/network/api_client.dart';

class Order {
  final int id;
  final int? userId;
  final String customerName, phone, status, paymentStatus, createdAt, updatedAt;
  final String? email,
      address,
      city,
      pincode,
      razorpayOrderId,
      razorpayPaymentId;
  final int subtotal, shippingFee, total;
  final List<OrderItem> items;

  Order({
    required this.id,
    this.userId,
    required this.customerName,
    required this.phone,
    this.email,
    this.address,
    this.city,
    this.pincode,
    required this.status,
    required this.paymentStatus,
    required this.createdAt,
    required this.updatedAt,
    required this.subtotal,
    required this.shippingFee,
    required this.total,
    this.razorpayOrderId,
    this.razorpayPaymentId,
    required this.items,
  });

  /// True when this order has no linked account (checkout without login is
  /// not currently possible per checkout.js, which requires a session, but
  /// user_id can still be legitimately absent for older/edge-case rows).
  bool get isGuest => userId == null;

  factory Order.fromJson(Map<String, dynamic> j) => Order(
    id: j['id'],
    userId: j['user_id'],
    customerName: j['customer_name'],
    phone: j['phone'],
    email: j['email'],
    address: j['address'],
    city: j['city'],
    pincode: j['pincode'],
    status: j['status'],
    paymentStatus: j['payment_status'],
    createdAt: j['created_at'] ?? '',
    updatedAt: j['updated_at'] ?? '',
    subtotal: j['subtotal'] ?? 0,
    shippingFee: j['shipping_fee'] ?? 0,
    total: j['total'],
    razorpayOrderId: j['razorpay_order_id'],
    razorpayPaymentId: j['razorpay_payment_id'],
    items: (j['items'] as List).map((i) => OrderItem.fromJson(i)).toList(),
  );
}

class OrderItem {
  final String productSlug, productName, size;
  final int qty, unitPrice;
  OrderItem({
    required this.productSlug,
    required this.productName,
    required this.size,
    required this.qty,
    required this.unitPrice,
  });
  factory OrderItem.fromJson(Map<String, dynamic> j) => OrderItem(
    productSlug: j['product_slug'] ?? '',
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
