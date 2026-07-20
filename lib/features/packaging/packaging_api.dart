import '../../core/network/api_client.dart';

class StaffProductSize {
  final String size;
  final int price;
  final int stockQty;
  StaffProductSize({
    required this.size,
    required this.price,
    required this.stockQty,
  });
  factory StaffProductSize.fromJson(Map<String, dynamic> j) => StaffProductSize(
    size: j['size'],
    price: j['price'],
    stockQty: j['stockQty'] ?? 0,
  );
}

class StaffProduct {
  final int id;
  final String slug, name, image;
  final List<StaffProductSize> sizes;
  StaffProduct({
    required this.id,
    required this.slug,
    required this.name,
    required this.image,
    required this.sizes,
  });
  factory StaffProduct.fromJson(Map<String, dynamic> j) => StaffProduct(
    id: j['id'],
    slug: j['slug'],
    name: j['name'],
    image: j['image'] ?? '',
    sizes: (j['sizes'] as List? ?? [])
        .map((s) => StaffProductSize.fromJson(s))
        .toList(),
  );
}

class PackagingReport {
  final int id;
  final String productName, size, status, reportDate;
  final int qty;
  PackagingReport({
    required this.id,
    required this.productName,
    required this.size,
    required this.status,
    required this.reportDate,
    required this.qty,
  });
  factory PackagingReport.fromJson(Map<String, dynamic> j) => PackagingReport(
    id: j['id'],
    productName: j['product_name'],
    size: j['size'],
    status: j['status'],
    reportDate: j['report_date'],
    qty: j['qty'],
  );
}

class PackagingApi {
  final ApiClient client;
  PackagingApi(this.client);

  Future<List<StaffProduct>> fetchStaffProducts() async {
    final res = await client.get('/api/staff/products');
    return (res.data['products'] as List)
        .map((p) => StaffProduct.fromJson(p))
        .toList();
  }

  Future<void> submitReport({
    required int productId,
    required String size,
    required int qty,
  }) {
    return client.post('/api/packaging/reports', {
      'productId': productId,
      'size': size,
      'qty': qty,
    });
  }

  Future<List<PackagingReport>> fetchMyReports() async {
    final res = await client.get(
      '/api/packaging/reports',
      query: {'mine': '1'},
    );
    return (res.data['reports'] as List)
        .map((r) => PackagingReport.fromJson(r))
        .toList();
  }
}
