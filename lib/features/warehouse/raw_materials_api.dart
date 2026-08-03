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

/// Base unit -> its everyday sub-unit, for entering adjustments at a more
/// natural scale ("used 350g") instead of fractions of the base unit.
const rawMaterialSubUnits = {'kg': 'g', 'l': 'ml'};

/// Valid input units for a material's base unit, sub-unit first — that's
/// the common case ("350 g" beats "0.35 kg").
List<String> inputUnitsFor(String baseUnit) {
  final sub = rawMaterialSubUnits[baseUnit];
  return sub == null ? [baseUnit] : [sub, baseUnit];
}

/// Converts an amount expressed in [inputUnit] into the material's base unit.
num convertToBase(String baseUnit, num amount, String inputUnit) {
  if (inputUnit == baseUnit) return amount;
  final sub = rawMaterialSubUnits[baseUnit];
  if (sub == inputUnit) return amount / 1000;
  throw ArgumentError('$inputUnit is not a valid unit for $baseUnit');
}

String _trimNum(num n) =>
    n == n.roundToDouble() ? n.toInt().toString() : n.toStringAsFixed(2);

/// Pretty-prints a base-unit quantity using the smaller unit when it reads
/// more naturally (0.35 kg -> "350 g", 2.4 kg -> "2.4 kg").
String formatQty(String baseUnit, num baseAmount) {
  final sub = rawMaterialSubUnits[baseUnit];
  if (sub == null) return '${_trimNum(baseAmount)} $baseUnit';
  final abs = baseAmount.abs();
  if (abs > 0 && abs < 1) return '${(baseAmount * 1000).round()} $sub';
  return '${_trimNum(baseAmount)} $baseUnit';
}

class RawMaterialsApi {
  final ApiClient client;
  RawMaterialsApi(this.client);

  Future<List<RawMaterial>> fetchRawMaterials() async {
    final res = await client.get('/api/warehouse/raw-materials');
    return (res.data['rawMaterials'] as List)
        .map((r) => RawMaterial.fromJson(r))
        .toList();
  }

  /// warehouser only
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
      'lowStockThreshold': ?lowStockThreshold,
    });
  }

  /// warehouser only. Doesn't change qty immediately — files a
  /// pending raw_material_transactions row that a manager/admin approves.
  /// [amount] is signed, expressed in [unit] (which may be the material's
  /// base unit or its everyday sub-unit, e.g. 'g' for a 'kg' material).
  Future<void> submitAdjustment({
    required int rawMaterialId,
    required num amount,
    required String unit,
    required String reason,
    String? note,
  }) {
    return client.post('/api/warehouse/raw-materials/adjust', {
      'rawMaterialId': rawMaterialId,
      'amount': amount,
      'unit': unit,
      'reason': reason,
      if (note != null && note.isNotEmpty) 'note': note,
    });
  }
}
