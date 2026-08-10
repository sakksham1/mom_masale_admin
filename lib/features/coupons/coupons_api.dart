import '../../core/network/api_client.dart';

const couponTypes = ['percent', 'flat'];

class Coupon {
  final int id;
  final String code;
  final String? description;
  final String type; // percent | flat
  final num value;
  final int? maxDiscountAmount;
  final int minSubtotal;
  final int? usageLimit;
  final int usedCount;
  final int perUserLimit;
  final bool isActive;
  final int? themeId;
  final String? startsAt, endsAt;
  final String createdAt, updatedAt;

  Coupon({
    required this.id,
    required this.code,
    this.description,
    required this.type,
    required this.value,
    this.maxDiscountAmount,
    required this.minSubtotal,
    this.usageLimit,
    required this.usedCount,
    required this.perUserLimit,
    required this.isActive,
    this.themeId,
    this.startsAt,
    this.endsAt,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isExhausted =>
      usageLimit != null && usedCount >= usageLimit!;

  factory Coupon.fromJson(Map<String, dynamic> j) => Coupon(
    id: j['id'],
    code: j['code'] ?? '',
    description: j['description'],
    type: j['type'] ?? 'percent',
    value: j['value'] ?? 0,
    maxDiscountAmount: j['maxDiscountAmount'],
    minSubtotal: j['minSubtotal'] ?? 0,
    usageLimit: j['usageLimit'],
    usedCount: j['usedCount'] ?? 0,
    perUserLimit: j['perUserLimit'] ?? 1,
    isActive: j['isActive'] == true,
    themeId: j['themeId'],
    startsAt: j['startsAt'],
    endsAt: j['endsAt'],
    createdAt: j['createdAt'] ?? '',
    updatedAt: j['updatedAt'] ?? '',
  );
}

class CouponsApi {
  final ApiClient client;
  CouponsApi(this.client);

  Future<List<Coupon>> fetchCoupons() async {
    final res = await client.get('/api/admin/coupons');
    return (res.data['coupons'] as List)
        .map((c) => Coupon.fromJson(c))
        .toList();
  }

  /// admin-only on the backend — applies immediately.
  Future<Coupon> createDirect(Map<String, dynamic> body) async {
    final res = await client.post('/api/admin/coupons', body);
    return Coupon.fromJson(res.data['coupon']);
  }

  Future<Coupon> updateDirect(int id, Map<String, dynamic> updates) async {
    final res = await client.patch('/api/admin/coupons', {
      'id': id,
      'updates': updates,
    });
    return Coupon.fromJson(res.data['coupon']);
  }

  Future<void> deleteDirect(int id) {
    return client.delete('/api/admin/coupons?id=$id');
  }

  /// Manager (or admin) — files a pending change; nothing goes live until
  /// an admin approves it via the Approvals screen. Mirrors
  /// CatalogApi.requestUpdate for products.
  Future<void> requestCreate(Map<String, dynamic> payload) {
    return client.post('/api/coupon-core/request', {
      'action': 'create',
      'payload': payload,
    });
  }

  Future<void> requestUpdate(int couponId, Map<String, dynamic> payload) {
    return client.post('/api/coupon-core/request', {
      'action': 'update',
      'couponId': couponId,
      'payload': payload,
    });
  }
}
