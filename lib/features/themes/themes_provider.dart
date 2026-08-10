import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'themes_api.dart';
import '../../core/network/api_client_provider.dart' show apiClientProvider;

final themesApiProvider = Provider(
  (ref) => ThemesApi(ref.watch(apiClientProvider)),
);

final themesProvider = FutureProvider<List<SiteTheme>>((ref) {
  return ref.watch(themesApiProvider).fetchThemes();
});
