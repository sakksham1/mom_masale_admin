// lib/features/site_core/site_core_api.dart
import '../../core/network/api_client.dart';

class SiteSettings {
  final Map<String, dynamic> business;
  final Map<String, dynamic> commerce;
  SiteSettings({required this.business, required this.commerce});

  factory SiteSettings.fromJson(Map<String, dynamic> j) => SiteSettings(
    business: Map<String, dynamic>.from(j['business'] ?? {}),
    commerce: Map<String, dynamic>.from(j['commerce'] ?? {}),
  );
}

class SiteCoreApi {
  final ApiClient client;
  SiteCoreApi(this.client);

  Future<SiteSettings> fetchSettings() async {
    final res = await client.get('/api/admin/settings');
    return SiteSettings.fromJson(Map<String, dynamic>.from(res.data));
  }

  /// Backend does a shallow merge per top-level key (see settings.js), so
  /// always send the full business/commerce objects you want to end up
  /// with — a partial nested object (e.g. commerce without shippingZones)
  /// would wipe the missing nested keys.
  Future<void> updateSettings({
    Map<String, dynamic>? business,
    Map<String, dynamic>? commerce,
  }) {
    return client.patch('/api/admin/settings', {
      if (business != null) 'business': business,
      if (commerce != null) 'commerce': commerce,
    });
  }
}
