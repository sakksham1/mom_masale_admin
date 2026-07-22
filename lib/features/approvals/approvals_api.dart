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

/// A pending catalog edit — `updates` is the same whitelisted shape the
/// admin PATCH endpoint accepts (name, category, image, prices, the four
/// flags, seo). Built from the generic `payload` column, decoded here so
/// the UI never has to know about the old name/price-only special case.
/// Purely site content — never touches stock.
class PendingProductCore {
  final int id;
  final String? productSlug;
  final String requestedByName, createdAt;
  final Map<String, dynamic> updates;

  PendingProductCore({
    required this.id,
    this.productSlug,
    required this.updates,
    required this.requestedByName,
    required this.createdAt,
  });

  factory PendingProductCore.fromJson(Map<String, dynamic> j) {
    final rawPayload = j['payload'];
    final updates = rawPayload is String
        ? (jsonDecode(rawPayload) as Map<String, dynamic>)
        : (rawPayload as Map<String, dynamic>? ?? {});
    return PendingProductCore(
      id: j['id'],
      productSlug: j['product_slug'],
      updates: updates,
      requestedByName: j['requested_by_name'],
      createdAt: j['created_at'] ?? '',
    );
  }

  String get summary => describeCatalogUpdates(updates);
}

/// Turns a raw updates map into a short, readable diff line for the
/// approvals list — e.g. `Name → "Garam Masala" · 250g → ₹180 · Featured: on`.
String describeCatalogUpdates(Map<String, dynamic> updates) {
  final parts = <String>[];
  if (updates['name'] != null) parts.add('Name → "${updates['name']}"');
  if (updates['category'] != null) parts.add('Category → ${updates['category']}');
  if (updates['image'] != null) parts.add('Image updated');
  final prices = updates['prices'];
  if (prices is Map) {
    prices.forEach((size, price) => parts.add('$size → ₹$price'));
  }
  if (updates['comingSoon'] != null) {
    parts.add('Coming soon: ${updates['comingSoon'] == true ? 'on' : 'off'}');
  }
  if (updates['featured'] != null) {
    parts.add('Featured: ${updates['featured'] == true ? 'on' : 'off'}');
  }
  if (updates['bestseller'] != null) {
    parts.add('Bestseller: ${updates['bestseller'] == true ? 'on' : 'off'}');
  }
  if (updates['newArrival'] != null) {
    parts.add('New arrival: ${updates['newArrival'] == true ? 'on' : 'off'}');
  }
  if (updates['seo'] != null) parts.add('SEO/description updated');
  return parts.isEmpty ? 'Catalog update' : parts.join(' · ');
}

/// Finished-product stock adjustments filed by a warehouser, awaiting
/// manager/admin decision. Unrelated to catalog editing — kept exactly as
/// it already was.
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
  ///
  /// The backend enforces that only an admin can decide 'product_core' —
  /// a manager calling this for that type gets a 403.
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
