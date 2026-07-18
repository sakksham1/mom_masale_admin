import '../../core/api_client.dart';

class TopProduct {
  final String productName, productSlug;
  final int totalQty, totalRevenue;
  TopProduct({required this.productName, required this.productSlug, required this.totalQty, required this.totalRevenue});
  factory TopProduct.fromJson(Map<String, dynamic> j) => TopProduct(
    productName: j['product_name'], productSlug: j['product_slug'],
    totalQty: j['total_qty'], totalRevenue: j['total_revenue'],
  );
}

class RecentOrder {
  final int id;
  final String customerName, status, paymentStatus, createdAt;
  final int total;
  RecentOrder({required this.id, required this.customerName, required this.status,
    required this.paymentStatus, required this.createdAt, required this.total});
  factory RecentOrder.fromJson(Map<String, dynamic> j) => RecentOrder(
    id: j['id'], customerName: j['customer_name'], status: j['status'],
    paymentStatus: j['payment_status'], createdAt: j['created_at'], total: j['total'],
  );
}

class DashboardStats {
  final int totalRevenue, paidOrders, todayRevenue, todayOrders,
      monthRevenue, monthOrders, pendingOrders, totalCustomers;
  final List<TopProduct> topProducts;
  final List<RecentOrder> recentOrders;

  DashboardStats({
    required this.totalRevenue, required this.paidOrders,
    required this.todayRevenue, required this.todayOrders,
    required this.monthRevenue, required this.monthOrders,
    required this.pendingOrders, required this.totalCustomers,
    required this.topProducts, required this.recentOrders,
  });

  factory DashboardStats.fromJson(Map<String, dynamic> j) => DashboardStats(
    totalRevenue: j['totalRevenue'] ?? 0,
    paidOrders: j['paidOrders'] ?? 0,
    todayRevenue: j['todayRevenue'] ?? 0,
    todayOrders: j['todayOrders'] ?? 0,
    monthRevenue: j['monthRevenue'] ?? 0,
    monthOrders: j['monthOrders'] ?? 0,
    pendingOrders: j['pendingOrders'] ?? 0,
    totalCustomers: j['totalCustomers'] ?? 0,
    topProducts: (j['topProducts'] as List? ?? []).map((p) => TopProduct.fromJson(p)).toList(),
    recentOrders: (j['recentOrders'] as List? ?? []).map((o) => RecentOrder.fromJson(o)).toList(),
  );
}

class DashboardApi {
  final ApiClient client;
  DashboardApi(this.client);

  Future<DashboardStats> fetchStats() async {
    final res = await client.get('/api/admin/stats');
    return DashboardStats.fromJson(res.data);
  }
}