import '../../core/network/api_client.dart';

class SalesTotals {
  final int reportCount;
  final num totalQty;
  final num totalAmount;
  SalesTotals({
    required this.reportCount,
    required this.totalQty,
    required this.totalAmount,
  });

  factory SalesTotals.fromJson(Map<String, dynamic> j) => SalesTotals(
    reportCount: j['report_count'] ?? 0,
    totalQty: j['total_qty'] ?? 0,
    totalAmount: j['total_amount'] ?? 0,
  );
}

class SalesByProduct {
  final String productName;
  final num totalQty;
  final num totalAmount;
  SalesByProduct({
    required this.productName,
    required this.totalQty,
    required this.totalAmount,
  });

  factory SalesByProduct.fromJson(Map<String, dynamic> j) => SalesByProduct(
    productName: j['product_name'],
    totalQty: j['total_qty'] ?? 0,
    totalAmount: j['total_amount'] ?? 0,
  );
}

class SalesStats {
  final SalesTotals totals;
  final List<SalesByProduct> byProduct;
  SalesStats({required this.totals, required this.byProduct});

  factory SalesStats.fromJson(Map<String, dynamic> j) => SalesStats(
    totals: SalesTotals.fromJson(j['totals'] ?? {}),
    byProduct: (j['byProduct'] as List? ?? [])
        .map((p) => SalesByProduct.fromJson(p))
        .toList(),
  );
}

class SalesReport {
  final int id;
  final String productName, size, reportDate;
  final int qty;
  final num saleAmount;
  final String? customerName;
  SalesReport({
    required this.id,
    required this.productName,
    required this.size,
    required this.reportDate,
    required this.qty,
    required this.saleAmount,
    this.customerName,
  });

  factory SalesReport.fromJson(Map<String, dynamic> j) => SalesReport(
    id: j['id'],
    productName: j['product_name'],
    size: j['size'],
    reportDate: j['report_date'],
    qty: j['qty'],
    saleAmount: j['sale_amount'] ?? 0,
    customerName: j['customer_name'],
  );
}

class SalesApi {
  final ApiClient client;
  SalesApi(this.client);

  Future<SalesStats> fetchStats({String? from, String? to}) async {
    final query = <String, dynamic>{};
    if (from != null) query['from'] = from;
    if (to != null) query['to'] = to;
    final res = await client.get(
      '/api/sales/stats',
      query: query.isEmpty ? null : query,
    );
    return SalesStats.fromJson(res.data);
  }

  /// salesperson-only on the backend.
  Future<void> submitReport({
    required int productId,
    required String size,
    required int qty,
    required num saleAmount,
    String? customerName,
    String? reportDate,
  }) {
    return client.post('/api/sales/reports', {
      'productId': productId,
      'size': size,
      'qty': qty,
      'saleAmount': saleAmount,
      if (customerName != null && customerName.isNotEmpty)
        'customerName': customerName,
      if (reportDate != null) 'reportDate': reportDate,
    });
  }

  Future<List<SalesReport>> fetchMyReports() async {
    final res = await client.get('/api/sales/reports', query: {'mine': '1'});
    return (res.data['reports'] as List)
        .map((r) => SalesReport.fromJson(r))
        .toList();
  }
}
