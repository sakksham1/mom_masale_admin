import '../../core/network/api_client.dart';

/// Color keys the backend actually forwards to the storefront (see
/// active-theme.js ALLOWED_COLOR_KEYS) — anything else is silently dropped
/// server-side, so the editor only ever exposes these.
const themeColorKeys = [
  'maroon',
  'maroonDark',
  'gold',
  'goldLight',
  'cream',
  'creamDark',
  'brown',
];

const themeColorLabels = {
  'maroon': 'Maroon',
  'maroonDark': 'Maroon (dark)',
  'gold': 'Gold',
  'goldLight': 'Gold (light)',
  'cream': 'Cream',
  'creamDark': 'Cream (dark)',
  'brown': 'Brown',
};

class SiteTheme {
  final int id;
  final String key, name;
  final bool isActive;
  final Map<String, String> colors;
  final String? featuredSectionTitle, promoBannerText;
  final String? heroTitle, heroCtaLabel, heroCtaUrl, heroImage;
  final bool bannerEnabled;
  final String? bannerTitle,
      bannerBody,
      bannerImage,
      bannerCtaLabel,
      bannerCtaUrl;
  final int? discountPercent;
  final String? couponCode;
  final String? startsAt, endsAt;
  final String createdAt, updatedAt;

  SiteTheme({
    required this.id,
    required this.key,
    required this.name,
    required this.isActive,
    required this.colors,
    this.featuredSectionTitle,
    this.promoBannerText,
    this.heroTitle,
    this.heroCtaLabel,
    this.heroCtaUrl,
    this.heroImage,
    required this.bannerEnabled,
    this.bannerTitle,
    this.bannerBody,
    this.bannerImage,
    this.bannerCtaLabel,
    this.bannerCtaUrl,
    this.discountPercent,
    this.couponCode,
    this.startsAt,
    this.endsAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SiteTheme.fromJson(Map<String, dynamic> j) => SiteTheme(
    id: j['id'],
    key: j['key'] ?? '',
    name: j['name'] ?? '',
    isActive: j['isActive'] == true,
    colors: (j['colors'] as Map? ?? {}).map(
      (k, v) => MapEntry(k.toString(), v.toString()),
    ),
    featuredSectionTitle: j['featuredSectionTitle'],
    promoBannerText: j['promoBannerText'],
    heroTitle: j['heroTitle'],
    heroCtaLabel: j['heroCtaLabel'],
    heroCtaUrl: j['heroCtaUrl'],
    heroImage: j['heroImage'],
    bannerEnabled: j['bannerEnabled'] == true,
    bannerTitle: j['bannerTitle'],
    bannerBody: j['bannerBody'],
    bannerImage: j['bannerImage'],
    bannerCtaLabel: j['bannerCtaLabel'],
    bannerCtaUrl: j['bannerCtaUrl'],
    discountPercent: j['discountPercent'],
    couponCode: j['couponCode'],
    startsAt: j['startsAt'],
    endsAt: j['endsAt'],
    createdAt: j['createdAt'] ?? '',
    updatedAt: j['updatedAt'] ?? '',
  );
}

class ThemesApi {
  final ApiClient client;
  ThemesApi(this.client);

  Future<List<SiteTheme>> fetchThemes() async {
    final res = await client.get('/api/admin/themes');
    return (res.data['themes'] as List)
        .map((t) => SiteTheme.fromJson(t))
        .toList();
  }

  Future<SiteTheme> create(Map<String, dynamic> body) async {
    final res = await client.post('/api/admin/themes', body);
    return SiteTheme.fromJson(res.data['theme']);
  }

  Future<SiteTheme> update(int id, Map<String, dynamic> updates) async {
    final res = await client.patch('/api/admin/themes', {
      'id': id,
      'updates': updates,
    });
    return SiteTheme.fromJson(res.data['theme']);
  }

  Future<void> delete(int id) {
    return client.delete('/api/admin/themes?id=$id');
  }

  /// Activates this theme (deactivating whichever theme was active before)
  /// and syncs linked coupons — see themes/activate.js.
  Future<void> activate(int id) {
    return client.post('/api/admin/themes/activate', {'id': id});
  }

  Future<void> deactivate() {
    return client.post('/api/admin/themes/deactivate', {});
  }
}
