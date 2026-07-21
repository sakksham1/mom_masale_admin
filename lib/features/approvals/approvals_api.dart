import 'dart:convert';
import '../../core/network/api_client.dart';

class PendingRawMaterial {
  final int id, rawMaterialId;
  final String materialName, reason, requestedByName, createdAt;
  final num delta;
  final String? note;
  PendingRawMaterial({
    required this.id,
    required this.rawMaterialId,
    required this.materialName,
    required this.delta,
    required this.reason,
    this.note,
    required this.requestedByName,
    required this.createdAt,
  });

  factory PendingRawMaterial.fromJson(Map<String, dynamic> j) =>
      PendingRawMaterial(
        id: j['id'],
        rawMaterialId: j['raw_material_id'],
        materialName: j['material_name'],
        delta: j['delta'],
        reason: j['reason'],
        note: j['note'],
        requestedByName: j['requested_by_name'],
        createdAt: j['created_at'] ?? '',
      );
}

class PendingPackaging {
  final int id, qty;
  final String productSlug, size, reportDate, requestedByName, createdAt;
  PendingPackaging({
    required this.id,
    required this.productSlug,
    required this.size,
    required this.qty,
    required this.reportDate,
    required this.requestedByName,
    required this.createdAt,
  });

  factory PendingPackaging.fromJson(Map<String, dynamic> j) => PendingPackaging(
    id: j['id'],
    productSlug: j['product_slug'],
    size: j['size'],
    qty: j['qty'],
    reportDate: j['report_date'],
    requestedByName: j['requested_by_name'],
    createdAt: j['created_at'] ?? '',
  );
}

class PendingProductCore {
  final int id;
  final String? productSlug;
  final String field, requestedByName, createdAt;
  final Map<String, dynamic> payload;
  PendingProductCore({
    required this.id,
    this.productSlug,
    required this.field,
    required this.payload,
    required this.requestedByName,
    required this.createdAt,
  });

  factory PendingProductCore.fromJson(Map<String, dynamic> j) {
    final rawPayload = j['payload'];
    final payload = rawPayload is String
        ? (jsonDecode(rawPayload) as Map<String, dynamic>)
        : (rawPayload as Map<String, dynamic>? ?? {});
    return PendingProductCore(
      id: j['id'],
      productSlug: j['product_slug'],
      field: j['field'],
      payload: payload,
      requestedByName: j['requested_by_name'],
      createdAt: j['created_at'] ?? '',
    );
  }
}

/// New: finished-product stock adjustments filed by a warehouser, awaiting
/// manager/admin decision. Mirrors PendingRawMaterial.
class PendingProductStock {
  final int id, changeQty;
  final String productSlug,
      productName,
      size,
      reason,
      requestedByName,
      createdAt;
  final String? note;
  PendingProductStock({
    required this.id,
    required this.productSlug,
    required this.productName,
    required this.size,
    required this.changeQty,
    required this.reason,
    this.note,
    required this.requestedByName,
    required this.createdAt,
  });

  factory PendingProductStock.fromJson(Map<String, dynamic> j) =>
      PendingProductStock(
        id: j['id'],
        productSlug: j['product_slug'],
        productName: j['product_name'],
        size: j['size'],
        changeQty: j['change_qty'],
        reason: j['reason'],
        note: j['note'],
        requestedByName: j['requested_by_name'],
        createdAt: j['created_at'] ?? '',
      );
}

class ApprovalsQueue {
  final List<PendingRawMaterial> rawMaterial;
  final List<PendingPackaging> packaging;
  final List<PendingProductCore> productCore;
  final List<PendingProductStock> productStock;
  ApprovalsQueue({
    required this.rawMaterial,
    required this.packaging,
    required this.productCore,
    required this.productStock,
  });

  bool get isEmpty =>
      rawMaterial.isEmpty &&
      packaging.isEmpty &&
      productCore.isEmpty &&
      productStock.isEmpty;

  factory ApprovalsQueue.fromJson(Map<String, dynamic> j) => ApprovalsQueue(
    rawMaterial: (j['rawMaterial'] as List? ?? [])
        .map((r) => PendingRawMaterial.fromJson(r))
        .toList(),
    packaging: (j['packaging'] as List? ?? [])
        .map((r) => PendingPackaging.fromJson(r))
        .toList(),
    productCore: (j['productCore'] as List? ?? [])
        .map((r) => PendingProductCore.fromJson(r))
        .toList(),
    productStock: (j['productStock'] as List? ?? [])
        .map((r) => PendingProductStock.fromJson(r))
        .toList(),
  );
}

class ApprovalsApi {
  final ApiClient client;
  ApprovalsApi(this.client);

  Future<ApprovalsQueue> fetchQueue() async {
    final res = await client.get('/api/manager/approvals');
    return ApprovalsQueue.fromJson(res.data);
  }

  /// type: 'raw_material' | 'packaging' | 'product_core' | 'product_stock'
  /// decision: 'approved' | 'rejected'
  Future<void> decide({
    required String type,
    required int id,
    required String decision,
  }) {
    return client.post('/api/manager/approvals/decide', {
      'type': type,
      'id': id,
      'decision': decision,
    });
  }
}
