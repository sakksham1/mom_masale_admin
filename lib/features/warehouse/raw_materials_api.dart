import '../../core/network/api_client.dart';

class RawMaterial {
  final int id;
  final String name;
  final String unit;
  final num qty;
  final num? lowStockThreshold;
  final String updatedAt;

  RawMaterial({
    required this.id,
    required this.name,
    required this.unit,
    required this.qty,
    this.lowStockThreshold,
    required this.updatedAt,
  });

  bool get isLow => lowStockThreshold != null && qty <= lowStockThreshold!;

  factory RawMaterial.fromJson(Map<String, dynamic> j) => RawMaterial(
    id: j['id'],
    name: j['name'],
    unit: j['unit'],
    qty: j['qty'] ?? 0,
    lowStockThreshold: j['low_stock_threshold'],
    updatedAt: j['updated_at'] ?? '',
  );
}

const rawMaterialUnits = ['kg', 'l', 'units'];
const rawMaterialAdjustReasons = ['restock', 'consumption', 'correction'];

class RawMaterialsApi {
  final ApiClient client;
  RawMaterialsApi(this.client);

  Future<List<RawMaterial>> fetchRawMaterials() async {
    final res = await client.get('/api/warehouse/raw-materials');
    return (res.data['rawMaterials'] as List)
        .map((r) => RawMaterial.fromJson(r))
        .toList();
  }

  /// warehouser-only on the backend.
  Future<void> createRawMaterial({
    required String name,
    required String unit,
    num qty = 0,
    num? lowStockThreshold,
  }) {
    return client.post('/api/warehouse/raw-materials', {
      'name': name,
      'unit': unit,
      'qty': qty,
      if (lowStockThreshold != null) 'lowStockThreshold': lowStockThreshold,
    });
  }

  /// warehouser-only on the backend. Doesn't change qty immediately — it
  /// files a pending raw_material_transactions row that a manager/admin
  /// approves via /api/manager/approvals/decide.
  Future<void> submitAdjustment({
    required int rawMaterialId,
    required num delta,
    required String reason,
    String? note,
  }) {
    return client.post('/api/warehouse/raw-materials/adjust', {
      'rawMaterialId': rawMaterialId,
      'delta': delta,
      'reason': reason,
      if (note != null && note.isNotEmpty) 'note': note,
    });
  }
}
