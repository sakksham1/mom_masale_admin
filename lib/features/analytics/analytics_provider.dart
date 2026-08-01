import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'analytics_api.dart';
import '../../core/network/api_client_provider.dart' show apiClientProvider;

final analyticsApiProvider = Provider(
  (ref) => AnalyticsApi(ref.watch(apiClientProvider)),
);

final analyticsOverviewProvider = FutureProvider.family<AnalyticsOverview, int>((ref, days) {
  return ref.watch(analyticsApiProvider).fetchOverview(days: days);
});

/// (days, scope) — scope is null for "all". Records give FutureProvider.family
/// free structural equality, same pattern as OrdersFilter in orders_provider.dart.
typedef ScopedRange = ({int days, String? scope});

final searchTermsProvider = FutureProvider.family<List<SearchTermRow>, ScopedRange>((ref, range) {
  return ref.watch(analyticsApiProvider).fetchSearchTerms(days: range.days, scope: range.scope);
});

final filtersAnalyticsProvider = FutureProvider.family<List<FilterCombo>, ScopedRange>((ref, range) {
  return ref.watch(analyticsApiProvider).fetchFilters(days: range.days, scope: range.scope);
});

final comingSoonAnalyticsProvider = FutureProvider.family<List<ComingSoonRow>, int>((ref, days) {
  return ref.watch(analyticsApiProvider).fetchComingSoon(days: days);
});

final checkoutFunnelProvider = FutureProvider.family<List<FunnelStepRow>, int>((ref, days) {
  return ref.watch(analyticsApiProvider).fetchCheckoutFunnel(days: days);
});

final recipeConversionProvider = FutureProvider.family<RecipeConversionResult, int>((ref, days) {
  return ref.watch(analyticsApiProvider).fetchRecipeConversion(days: days);
});
