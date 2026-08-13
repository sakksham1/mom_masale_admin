import '../../core/network/api_client.dart';

class WheelMode {
  final int id;
  final String key;
  final int sortOrder;
  final String centerLabel;
  final String? centerLabelHover;
  final String centerGlyph;
  final String? hubHref;
  final bool isActive;
  final String? createdAt, updatedAt;

  WheelMode({
    required this.id,
    required this.key,
    required this.sortOrder,
    required this.centerLabel,
    this.centerLabelHover,
    required this.centerGlyph,
    this.hubHref,
    required this.isActive,
    this.createdAt,
    this.updatedAt,
  });

  factory WheelMode.fromJson(Map<String, dynamic> j) => WheelMode(
    id: j['id'],
    key: j['key'] ?? '',
    sortOrder: j['sortOrder'] ?? 0,
    centerLabel: j['centerLabel'] ?? '',
    centerLabelHover: j['centerLabelHover'],
    centerGlyph: j['centerGlyph'] ?? '✦',
    hubHref: j['hubHref'],
    isActive: j['isActive'] == true,
    createdAt: j['createdAt'],
    updatedAt: j['updatedAt'],
  );

  /// centerLabel encodes a line break with '|' (backend convention, e.g. "MOM|MASALE").
  String get displayLabel => centerLabel.replaceAll('|', ' ');
}

class WheelItem {
  final int id;
  final int modeId;
  final String label;
  final String href;
  final String? color;
  final int sortOrder;

  WheelItem({
    required this.id,
    required this.modeId,
    required this.label,
    required this.href,
    this.color,
    required this.sortOrder,
  });

  factory WheelItem.fromJson(Map<String, dynamic> j) => WheelItem(
    id: j['id'],
    modeId: j['modeId'],
    label: j['label'] ?? '',
    href: j['href'] ?? '',
    color: j['color'],
    sortOrder: j['sortOrder'] ?? 0,
  );
}

class WheelApi {
  final ApiClient client;
  WheelApi(this.client);

  Future<List<WheelMode>> fetchModes() async {
    final res = await client.get('/api/admin/wheel/modes');
    return (res.data['modes'] as List)
        .map((m) => WheelMode.fromJson(m))
        .toList();
  }

  /// admin + manager — direct write, applies immediately, no approval step
  /// (the backend has no wheel entry in the approvals handler set).
  Future<WheelMode> createMode(Map<String, dynamic> body) async {
    final res = await client.post('/api/admin/wheel/modes', body);
    return WheelMode.fromJson(res.data['mode']);
  }

  Future<WheelMode> updateMode(int id, Map<String, dynamic> updates) async {
    final res = await client.patch('/api/admin/wheel/modes', {
      'id': id,
      'updates': updates,
    });
    return WheelMode.fromJson(res.data['mode']);
  }

  /// Cascades and deletes the mode's wedges too (server-side).
  Future<void> deleteMode(int id) {
    return client.delete('/api/admin/wheel/modes?id=$id');
  }

  Future<List<WheelItem>> fetchItems(int modeId) async {
    final res = await client.get(
      '/api/admin/wheel/items',
      query: {'modeId': '$modeId'},
    );
    return (res.data['items'] as List)
        .map((i) => WheelItem.fromJson(i))
        .toList();
  }

  Future<WheelItem> createItem(Map<String, dynamic> body) async {
    final res = await client.post('/api/admin/wheel/items', body);
    return WheelItem.fromJson(res.data['item']);
  }

  Future<WheelItem> updateItem(int id, Map<String, dynamic> updates) async {
    final res = await client.patch('/api/admin/wheel/items', {
      'id': id,
      'updates': updates,
    });
    return WheelItem.fromJson(res.data['item']);
  }

  Future<void> deleteItem(int id) {
    return client.delete('/api/admin/wheel/items?id=$id');
  }
}
