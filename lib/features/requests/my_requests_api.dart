import '../../core/network/api_client.dart';

class MyPackagingRequest {
  final int id, qty;
  final String productSlug, productName, size, reportDate, status, createdAt;
  final String? reviewedAt;
  MyPackagingRequest({
    required this.id,
    required this.productSlug,
    required this.productName,
    required this.size,
    required this.qty,
    required this.reportDate,
    required this.status,
    required this.createdAt,
    this.reviewedAt,
  });
  factory MyPackagingRequest.fromJson(Map<String, dynamic> j) =>
      MyPackagingRequest(
        id: j['id'],
        productSlug: j['product_slug'],
        productName: j['product_name'],
        size: j['size'],
        qty: j['qty'],
        reportDate: j['report_date'],
        status: j['status'],
        createdAt: j['created_at'] ?? '',
        reviewedAt: j['reviewed_at'],
      );
}

class MyRawMaterialRequest {
  final int id;
  final String materialName, reason, status, createdAt;
  final String? note, reviewedAt, inputUnit;
  final num delta;
  final num? inputAmount;
  MyRawMaterialRequest({
    required this.id,
    required this.materialName,
    required this.delta,
    required this.reason,
    this.note,
    required this.status,
    required this.createdAt,
    this.reviewedAt,
    this.inputAmount,
    this.inputUnit,
  });
  factory MyRawMaterialRequest.fromJson(Map<String, dynamic> j) =>
      MyRawMaterialRequest(
        id: j['id'],
        materialName: j['material_name'],
        delta: j['delta'],
        reason: j['reason'],
        note: j['note'],
        status: j['status'],
        createdAt: j['created_at'] ?? '',
        reviewedAt: j['reviewed_at'],
        inputAmount: j['input_amount'],
        inputUnit: j['input_unit'],
      );
}

class MyProductStockRequest {
  final int id, changeQty;
  final String productSlug, productName, size, reason, status, createdAt;
  final String? note, reviewedAt;
  MyProductStockRequest({
    required this.id,
    required this.productSlug,
    required this.productName,
    required this.size,
    required this.changeQty,
    required this.reason,
    this.note,
    required this.status,
    required this.createdAt,
    this.reviewedAt,
  });
  factory MyProductStockRequest.fromJson(Map<String, dynamic> j) =>
      MyProductStockRequest(
        id: j['id'],
        productSlug: j['product_slug'],
        productName: j['product_name'],
        size: j['size'],
        changeQty: j['change_qty'],
        reason: j['reason'],
        note: j['note'],
        status: j['status'],
        createdAt: j['created_at'] ?? '',
        reviewedAt: j['reviewed_at'],
      );
}

class MyRequests {
  final List<MyPackagingRequest> packaging;
  final List<MyRawMaterialRequest> rawMaterial;
  final List<MyProductStockRequest> productStock;
  MyRequests({
    required this.packaging,
    required this.rawMaterial,
    required this.productStock,
  });

  factory MyRequests.fromJson(Map<String, dynamic> j) => MyRequests(
    packaging: (j['packaging'] as List? ?? [])
        .map((p) => MyPackagingRequest.fromJson(p))
        .toList(),
    rawMaterial: (j['rawMaterial'] as List? ?? [])
        .map((r) => MyRawMaterialRequest.fromJson(r))
        .toList(),
    productStock: (j['productStock'] as List? ?? [])
        .map((s) => MyProductStockRequest.fromJson(s))
        .toList(),
  );
}

class MyRequestsApi {
  final ApiClient client;
  MyRequestsApi(this.client);

  Future<MyRequests> fetchMine() async {
    final res = await client.get('/api/requests/mine');
    return MyRequests.fromJson(res.data);
  }

  /// type: 'packaging' | 'raw_material' | 'product_stock'
  Future<void> cancel({required String type, required int id}) {
    return client.post('/api/requests/cancel', {'type': type, 'id': id});
  }
}
