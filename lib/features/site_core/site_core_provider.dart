// lib/features/site_core/site_core_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'site_core_api.dart';
import '../../core/network/api_client_provider.dart' show apiClientProvider;

final siteCoreApiProvider = Provider(
  (ref) => SiteCoreApi(ref.watch(apiClientProvider)),
);

final siteSettingsProvider = FutureProvider<SiteSettings>((ref) {
  return ref.watch(siteCoreApiProvider).fetchSettings();
});
