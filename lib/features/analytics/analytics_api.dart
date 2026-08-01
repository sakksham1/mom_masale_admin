import '../../core/network/api_client.dart';

/// { count, uniqueVisitors } — one entry per event type in the overview totals map.
class EventTypeTotal {
  final int count;
  final int uniqueVisitors;
  EventTypeTotal({required this.count, required this.uniqueVisitors});

  factory EventTypeTotal.fromJson(Map<String, dynamic> j) => EventTypeTotal(
    count: j['count'] ?? 0,
    uniqueVisitors: j['uniqueVisitors'] ?? 0,
  );
}

/// One row of the overview's `daily` time series: a single (day, event_type) count.
class DailyEventCount {
  final String day;
  final String eventType;
  final int count;
  DailyEventCount({required this.day, required this.eventType, required this.count});

  factory DailyEventCount.fromJson(Map<String, dynamic> j) => DailyEventCount(
    day: j['day'] ?? '',
    eventType: j['event_type'] ?? '',
    count: j['count'] ?? 0,
  );
}

class AnalyticsOverview {
  final int days;
  final Map<String, EventTypeTotal> totals;
  final List<DailyEventCount> daily;
  AnalyticsOverview({required this.days, required this.totals, required this.daily});

  factory AnalyticsOverview.fromJson(Map<String, dynamic> j) => AnalyticsOverview(
    days: j['days'] ?? 30,
    totals: (j['totals'] as Map<String, dynamic>? ?? {}).map(
      (key, value) => MapEntry(key, EventTypeTotal.fromJson(value as Map<String, dynamic>)),
    ),
    daily: (j['daily'] as List? ?? [])
        .map((d) => DailyEventCount.fromJson(d as Map<String, dynamic>))
        .toList(),
  );
}

class SearchTermRow {
  final String query;
  final String scope;
  final int count;
  final int uniqueVisitors;
  final String lastSeen;
  SearchTermRow({
    required this.query,
    required this.scope,
    required this.count,
    required this.uniqueVisitors,
    required this.lastSeen,
  });

  factory SearchTermRow.fromJson(Map<String, dynamic> j) => SearchTermRow(
    query: j['query'] ?? '',
    scope: j['scope'] ?? '',
    count: j['count'] ?? 0,
    uniqueVisitors: j['uniqueVisitors'] ?? 0,
    lastSeen: j['lastSeen'] ?? '',
  );
}

class FilterCombo {
  final String scope;
  final List<String> categories;
  final List<String> sizes;
  final int count;
  final int uniqueVisitors;
  FilterCombo({
    required this.scope,
    required this.categories,
    required this.sizes,
    required this.count,
    required this.uniqueVisitors,
  });

  factory FilterCombo.fromJson(Map<String, dynamic> j) => FilterCombo(
    scope: j['scope'] ?? '',
    categories: (j['categories'] as List? ?? []).map((e) => e.toString()).toList(),
    sizes: (j['sizes'] as List? ?? []).map((e) => e.toString()).toList(),
    count: j['count'] ?? 0,
    uniqueVisitors: j['uniqueVisitors'] ?? 0,
  );
}

class ComingSoonRow {
  final String productSlug;
  final String? productName;
  final int clicks;
  final int uniqueVisitors;
  final String lastSeen;
  ComingSoonRow({
    required this.productSlug,
    this.productName,
    required this.clicks,
    required this.uniqueVisitors,
    required this.lastSeen,
  });

  String get displayName =>
      (productName != null && productName!.isNotEmpty) ? productName! : productSlug;

  factory ComingSoonRow.fromJson(Map<String, dynamic> j) => ComingSoonRow(
    productSlug: j['productSlug'] ?? '',
    productName: j['productName'],
    clicks: j['clicks'] ?? 0,
    uniqueVisitors: j['uniqueVisitors'] ?? 0,
    lastSeen: j['lastSeen'] ?? '',
  );
}

class FunnelStepRow {
  final String step;
  final int sessions;
  final int events;
  final double? dropOffPercent;
  FunnelStepRow({
    required this.step,
    required this.sessions,
    required this.events,
    this.dropOffPercent,
  });

  factory FunnelStepRow.fromJson(Map<String, dynamic> j) => FunnelStepRow(
    step: j['step'] ?? '',
    sessions: j['sessions'] ?? 0,
    events: j['events'] ?? 0,
    dropOffPercent: (j['dropOffPercent'] as num?)?.toDouble(),
  );
}

class RecipePairRow {
  final String recipeSlug;
  final String productSlug;
  final int clicks;
  final int uniqueVisitors;
  RecipePairRow({
    required this.recipeSlug,
    required this.productSlug,
    required this.clicks,
    required this.uniqueVisitors,
  });

  factory RecipePairRow.fromJson(Map<String, dynamic> j) => RecipePairRow(
    recipeSlug: j['recipeSlug'] ?? '',
    productSlug: j['productSlug'] ?? '',
    clicks: j['clicks'] ?? 0,
    uniqueVisitors: j['uniqueVisitors'] ?? 0,
  );
}

class RecipeConversionResult {
  final List<RecipePairRow> pairs;
  final String note;
  RecipeConversionResult({required this.pairs, required this.note});
}

/// Scope filter shared by the search-terms and filters endpoints.
const analyticsScopes = ['products', 'recipes'];

class AnalyticsApi {
  final ApiClient client;
  AnalyticsApi(this.client);

  Future<AnalyticsOverview> fetchOverview({int days = 30}) async {
    final res = await client.get(
      '/api/admin/analytics/overview',
      query: {'days': '$days'},
    );
    return AnalyticsOverview.fromJson(res.data);
  }

  Future<List<SearchTermRow>> fetchSearchTerms({
    int days = 30,
    String? scope,
    int limit = 50,
  }) async {
    final query = {'days': '$days', 'limit': '$limit'};
    if (scope != null) query['scope'] = scope;
    final res = await client.get('/api/admin/analytics/search-terms', query: query);
    return (res.data['terms'] as List)
        .map((t) => SearchTermRow.fromJson(t as Map<String, dynamic>))
        .toList();
  }

  Future<List<FilterCombo>> fetchFilters({
    int days = 30,
    String? scope,
    int limit = 50,
  }) async {
    final query = {'days': '$days', 'limit': '$limit'};
    if (scope != null) query['scope'] = scope;
    final res = await client.get('/api/admin/analytics/filters', query: query);
    return (res.data['combos'] as List)
        .map((c) => FilterCombo.fromJson(c as Map<String, dynamic>))
        .toList();
  }

  Future<List<ComingSoonRow>> fetchComingSoon({int days = 30}) async {
    final res = await client.get(
      '/api/admin/analytics/coming-soon',
      query: {'days': '$days'},
    );
    return (res.data['products'] as List)
        .map((p) => ComingSoonRow.fromJson(p as Map<String, dynamic>))
        .toList();
  }

  Future<List<FunnelStepRow>> fetchCheckoutFunnel({int days = 30}) async {
    final res = await client.get(
      '/api/admin/analytics/checkout-funnel',
      query: {'days': '$days'},
    );
    return (res.data['funnel'] as List)
        .map((f) => FunnelStepRow.fromJson(f as Map<String, dynamic>))
        .toList();
  }

  Future<RecipeConversionResult> fetchRecipeConversion({
    int days = 30,
    int limit = 50,
  }) async {
    final res = await client.get(
      '/api/admin/analytics/recipe-conversion',
      query: {'days': '$days', 'limit': '$limit'},
    );
    return RecipeConversionResult(
      pairs: (res.data['pairs'] as List)
          .map((p) => RecipePairRow.fromJson(p as Map<String, dynamic>))
          .toList(),
      note: res.data['note'] ?? '',
    );
  }
}
