import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'analytics_api.dart';
import 'analytics_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/layout_constants.dart';
import '../../core/utils/haptics.dart';
import '../../shared/widgets/tap_scale.dart';

// ── Shared formatting helpers ──────────────────────────────────────────────

const _monthAbbr = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// Backend timestamps are UTC (`YYYY-MM-DD HH:MM:SS` or `YYYY-MM-DD`) with no
/// offset marker — force UTC on parse, then convert to the device's local time.
DateTime? _parseUtc(String raw) {
  if (raw.isEmpty) return null;
  var iso = raw.contains('T') ? raw : raw.replaceFirst(' ', 'T');
  if (!iso.endsWith('Z') && !iso.contains('+')) iso += 'Z';
  return DateTime.tryParse(iso)?.toLocal();
}

String _formatDate(String raw) {
  final dt = _parseUtc(raw);
  if (dt == null) return raw.isEmpty ? '—' : raw;
  return '${_monthAbbr[dt.month - 1]} ${dt.day}';
}

String _formatDateTime(String raw) {
  final dt = _parseUtc(raw);
  if (dt == null) return raw.isEmpty ? '—' : raw;
  final hour24 = dt.hour;
  final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
  final ampm = hour24 < 12 ? 'AM' : 'PM';
  final minute = dt.minute.toString().padLeft(2, '0');
  return '${_monthAbbr[dt.month - 1]} ${dt.day}, $hour12:$minute $ampm';
}

String _formatCount(int n) =>
    n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');

// ── Screen shell ────────────────────────────────────────────────────────────

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(
    length: 6,
    vsync: this,
  );
  int _days = 30;

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _goToTab(int index) {
    Haptics.tap();
    _tabController.animateTo(index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Checkout Funnel'),
            Tab(text: 'Searches'),
            Tab(text: 'Filters'),
            Tab(text: 'Coming Soon'),
            Tab(text: 'Recipes'),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: _DaysSelector(
              selected: _days,
              onChanged: (d) => setState(() => _days = d),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _OverviewTab(days: _days, onNavigate: _goToTab),
                _FunnelTab(days: _days),
                _SearchTermsTab(days: _days),
                _FiltersTab(days: _days),
                _ComingSoonTab(days: _days),
                _RecipesTab(days: _days),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DaysSelector extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onChanged;
  const _DaysSelector({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const options = [7, 30, 90];
    return Row(
      children: [
        Icon(
          Icons.date_range_outlined,
          size: 18,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        ...options.map((d) {
          final isSelected = d == selected;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text('${d}d'),
              selected: isSelected,
              onSelected: (_) => onChanged(d),
              selectedColor: AppColors.maroon,
              labelStyle: TextStyle(
                color: isSelected ? AppColors.parchment : null,
                fontWeight: FontWeight.w600,
              ),
            ),
          );
        }),
      ],
    );
  }
}

// ── Shared empty / error states ────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 40,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final Object error;
  const _ErrorState({required this.error});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Text(
        'Could not load analytics: $error',
        textAlign: TextAlign.center,
      ),
    ),
  );
}

// ── Overview tab ────────────────────────────────────────────────────────────

class _EventTypeMeta {
  final String key;
  final String label;
  final IconData icon;
  final Color color;
  final int tabIndex;
  const _EventTypeMeta(
    this.key,
    this.label,
    this.icon,
    this.color,
    this.tabIndex,
  );
}

const _eventTypeMetas = <_EventTypeMeta>[
  _EventTypeMeta(
    'search_zero_result',
    'Zero-Result Searches',
    Icons.search_off,
    Color(0xFFC62828),
    2,
  ),
  _EventTypeMeta(
    'filter_applied',
    'Filters Applied',
    Icons.filter_alt_outlined,
    AppColors.turmeric,
    3,
  ),
  _EventTypeMeta(
    'coming_soon_click',
    'Coming Soon Clicks',
    Icons.rocket_launch_outlined,
    AppColors.paprika,
    4,
  ),
  _EventTypeMeta(
    'checkout_step',
    'Checkout Activity',
    Icons.shopping_cart_checkout,
    Color(0xFF2E7D32),
    1,
  ),
  _EventTypeMeta(
    'recipe_ingredient_click',
    'Recipe → Shop Clicks',
    Icons.restaurant_menu_outlined,
    AppColors.maroon,
    5,
  ),
];

class _OverviewTab extends ConsumerWidget {
  final int days;
  final ValueChanged<int> onNavigate;
  const _OverviewTab({required this.days, required this.onNavigate});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overviewAsync = ref.watch(analyticsOverviewProvider(days));
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(analyticsOverviewProvider),
      child: overviewAsync.when(
        data: (overview) {
          final hasAnyData = overview.totals.values.any((t) => t.count > 0);
          return ListView(
            padding: const EdgeInsets.fromLTRB(
              16,
              8,
              16,
              LayoutConstants.navBarClearance,
            ),
            children: [
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.35,
                children: _eventTypeMetas.map((meta) {
                  final total =
                      overview.totals[meta.key] ??
                      EventTypeTotal(count: 0, uniqueVisitors: 0);
                  return _EventStatCard(
                    meta: meta,
                    total: total,
                    onTap: () => onNavigate(meta.tabIndex),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Icon(
                    Icons.show_chart,
                    size: 18,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Daily Activity',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (!hasAnyData)
                const _EmptyState(
                  icon: Icons.insights_outlined,
                  message: 'No analytics events recorded yet for this period.',
                )
              else
                _DailyTrendChart(daily: overview.daily),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorState(error: e),
      ),
    );
  }
}

class _EventStatCard extends StatelessWidget {
  final _EventTypeMeta meta;
  final EventTypeTotal total;
  final VoidCallback onTap;
  const _EventStatCard({
    required this.meta,
    required this.total,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TapScale(
      scaleDown: 0.97,
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              meta.color.withValues(alpha: 0.16),
              meta.color.withValues(alpha: 0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: meta.color.withValues(alpha: 0.25)),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: meta.color.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(meta.icon, color: meta.color, size: 17),
                ),
                const Spacer(),
                Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: meta.color.withValues(alpha: 0.6),
                ),
              ],
            ),
            const Spacer(),
            Text(
              _formatCount(total.count),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: meta.color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              meta.label,
              style: Theme.of(context).textTheme.bodySmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              '${_formatCount(total.uniqueVisitors)} unique visitor${total.uniqueVisitors == 1 ? '' : 's'}',
              style: TextStyle(
                fontSize: 10,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DailyTrendChart extends StatelessWidget {
  final List<DailyEventCount> daily;
  const _DailyTrendChart({required this.daily});

  Map<String, int> _aggregate() {
    final map = <String, int>{};
    for (final d in daily) {
      map[d.day] = (map[d.day] ?? 0) + d.count;
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final agg = _aggregate();
    final days = agg.keys.toList()..sort();
    final values = days.map((d) => agg[d]!).toList();
    final scheme = Theme.of(context).colorScheme;

    if (values.isEmpty || values.every((v) => v == 0)) {
      return const _EmptyState(
        icon: Icons.show_chart,
        message: 'No daily activity to chart yet.',
      );
    }

    final maxValue = values.reduce((a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total events / day',
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
              Text(
                'Peak: ${_formatCount(maxValue)}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.maroon,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 140,
            child: CustomPaint(
              painter: _TrendPainter(values: values, color: AppColors.maroon),
              size: Size.infinite,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDate(days.first),
                style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
              ),
              if (days.length > 2)
                Text(
                  _formatDate(days[days.length ~/ 2]),
                  style: TextStyle(
                    fontSize: 11,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              Text(
                _formatDate(days.last),
                style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TrendPainter extends CustomPainter {
  final List<int> values;
  final Color color;
  _TrendPainter({required this.values, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final maxValue = values.reduce((a, b) => a > b ? a : b).toDouble();
    final safeMax = maxValue == 0 ? 1.0 : maxValue;
    final stepX = values.length > 1 ? size.width / (values.length - 1) : 0.0;

    final points = <Offset>[];
    for (var i = 0; i < values.length; i++) {
      final x = values.length > 1 ? stepX * i : size.width / 2;
      final y = size.height - (values[i] / safeMax) * size.height;
      points.add(Offset(x, y));
    }

    final fillPath = Path()..moveTo(points.first.dx, size.height);
    for (final p in points) {
      fillPath.lineTo(p.dx, p.dy);
    }
    fillPath.lineTo(points.last.dx, size.height);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withValues(alpha: 0.28), color.withValues(alpha: 0.02)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(fillPath, fillPaint);

    final linePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) {
      linePath.lineTo(p.dx, p.dy);
    }
    final linePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(linePath, linePaint);

    final peakIndex = values.indexOf(values.reduce((a, b) => a > b ? a : b));
    final peakPoint = points[peakIndex];
    canvas.drawCircle(peakPoint, 4, Paint()..color = color);
    canvas.drawCircle(
      peakPoint,
      4,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(covariant _TrendPainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.color != color;
}

// ── Checkout funnel tab ─────────────────────────────────────────────────────

String _funnelStepLabel(String step) {
  switch (step) {
    case 'cart_opened':
      return 'Cart Opened';
    case 'checkout_started':
      return 'Checkout Started';
    case 'pincode_checked':
      return 'Pincode Checked';
    case 'payment_opened':
      return 'Payment Opened';
    case 'order_placed':
      return 'Order Placed';
    case 'payment_completed':
      return 'Payment Completed';
    default:
      return step;
  }
}

IconData _funnelStepIcon(String step) {
  switch (step) {
    case 'cart_opened':
      return Icons.shopping_cart_outlined;
    case 'checkout_started':
      return Icons.receipt_long_outlined;
    case 'pincode_checked':
      return Icons.location_on_outlined;
    case 'payment_opened':
      return Icons.payment_outlined;
    case 'order_placed':
      return Icons.assignment_turned_in_outlined;
    case 'payment_completed':
      return Icons.verified_outlined;
    default:
      return Icons.circle_outlined;
  }
}

class _FunnelTab extends ConsumerWidget {
  final int days;
  const _FunnelTab({required this.days});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final funnelAsync = ref.watch(checkoutFunnelProvider(days));
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(checkoutFunnelProvider),
      child: funnelAsync.when(
        data: (steps) {
          final totalSessions = steps.fold<int>(
            0,
            (sum, s) => sum + s.sessions,
          );
          if (totalSessions == 0) {
            return ListView(
              children: const [
                _EmptyState(
                  icon: Icons.filter_alt_off_outlined,
                  message: 'No checkout activity recorded for this period yet.',
                ),
              ],
            );
          }
          final maxSessions = steps
              .map((s) => s.sessions)
              .fold<int>(0, (a, b) => a > b ? a : b);

          FunnelStepRow? worst;
          for (final s in steps) {
            if (s.dropOffPercent == null) continue;
            if (worst == null || s.dropOffPercent! > worst.dropOffPercent!) {
              worst = s;
            }
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              16,
              12,
              16,
              LayoutConstants.navBarClearance,
            ),
            children: [
              if (worst != null && worst.dropOffPercent! > 0)
                _InsightBanner(
                  icon: Icons.warning_amber_rounded,
                  color: const Color(0xFFC62828),
                  text:
                      'Biggest drop-off: ${worst.dropOffPercent!.toStringAsFixed(1)}% of sessions '
                      'leave before reaching "${_funnelStepLabel(worst.step)}".',
                ),
              const SizedBox(height: 16),
              for (var i = 0; i < steps.length; i++) ...[
                _FunnelStepBar(
                  step: steps[i],
                  fraction: maxSessions == 0
                      ? 0.0
                      : steps[i].sessions / maxSessions,
                ),
                if (i < steps.length - 1)
                  _DropOffConnector(
                    dropOffPercent: steps[i + 1].dropOffPercent,
                  ),
              ],
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorState(error: e),
      ),
    );
  }
}

class _InsightBanner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  const _InsightBanner({
    required this.icon,
    required this.color,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FunnelStepBar extends StatelessWidget {
  final FunnelStepRow step;
  final double fraction;
  const _FunnelStepBar({required this.step, required this.fraction});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final clamped = fraction.clamp(0.04, 1.0).toDouble();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.maroon.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _funnelStepIcon(step.step),
              size: 17,
              color: AppColors.maroon,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _funnelStepLabel(step.step),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Text(
                      '${_formatCount(step.sessions)} sessions',
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    height: 10,
                    width: double.infinity,
                    child: Stack(
                      children: [
                        Container(color: scheme.surfaceContainerHighest),
                        FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: clamped,
                          child: Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [AppColors.turmeric, AppColors.maroon],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DropOffConnector extends StatelessWidget {
  final double? dropOffPercent;
  const _DropOffConnector({required this.dropOffPercent});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pct = dropOffPercent == null
        ? null
        : (dropOffPercent! < 0 ? 0.0 : dropOffPercent!);
    Color color;
    if (pct == null) {
      color = scheme.onSurfaceVariant;
    } else if (pct < 15) {
      color = const Color(0xFF2E7D32);
    } else if (pct < 40) {
      color = AppColors.paprika;
    } else {
      color = const Color(0xFFC62828);
    }
    return Padding(
      padding: const EdgeInsets.only(left: 17),
      child: Row(
        children: [
          Container(width: 1.5, height: 22, color: scheme.outlineVariant),
          const SizedBox(width: 15),
          Icon(Icons.arrow_downward, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            pct == null ? '' : '${pct.toStringAsFixed(1)}% drop-off',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Scope selector shared by Searches / Filters tabs ────────────────────────

class _ScopeSelector extends StatelessWidget {
  final String? selected;
  final ValueChanged<String?> onChanged;
  const _ScopeSelector({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    Widget chip(String label, String? value) => Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected == value,
        onSelected: (_) => onChanged(value),
      ),
    );
    return Row(
      children: [
        chip('All', null),
        chip('Products', 'products'),
        chip('Recipes', 'recipes'),
      ],
    );
  }
}

class _RankedRow extends StatelessWidget {
  final int rank;
  final String title;
  final String subtitle;
  final int count;
  final int uniqueVisitors;
  const _RankedRow({
    required this.rank,
    required this.title,
    required this.subtitle,
    required this.count,
    required this.uniqueVisitors,
  });

  Color? _medalColor() {
    switch (rank) {
      case 1:
        return const Color(0xFFD9A441);
      case 2:
        return const Color(0xFFB0B7C0);
      case 3:
        return const Color(0xFFC98A5A);
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final medal = _medalColor();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: (medal ?? AppColors.maroon).withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Text(
              '$rank',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: medal ?? AppColors.maroon,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$count',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                '$uniqueVisitors visitors',
                style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Search terms tab ────────────────────────────────────────────────────────

class _SearchTermsTab extends ConsumerStatefulWidget {
  final int days;
  const _SearchTermsTab({required this.days});

  @override
  ConsumerState<_SearchTermsTab> createState() => _SearchTermsTabState();
}

class _SearchTermsTabState extends ConsumerState<_SearchTermsTab> {
  String? _scope;

  @override
  Widget build(BuildContext context) {
    final range = (days: widget.days, scope: _scope);
    final termsAsync = ref.watch(searchTermsProvider(range));
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: _ScopeSelector(
            selected: _scope,
            onChanged: (s) => setState(() => _scope = s),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async => ref.invalidate(searchTermsProvider),
            child: termsAsync.when(
              data: (terms) {
                if (terms.isEmpty) {
                  return ListView(
                    children: const [
                      _EmptyState(
                        icon: Icons.search_off,
                        message:
                            'No zero-result searches in this period — nice!',
                      ),
                    ],
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    16,
                    8,
                    16,
                    LayoutConstants.navBarClearance,
                  ),
                  itemCount: terms.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) => _RankedRow(
                    rank: i + 1,
                    title: terms[i].query,
                    subtitle:
                        '${terms[i].scope} · last seen ${_formatDateTime(terms[i].lastSeen)}',
                    count: terms[i].count,
                    uniqueVisitors: terms[i].uniqueVisitors,
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _ErrorState(error: e),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Filters tab ──────────────────────────────────────────────────────────────

class _FiltersTab extends ConsumerStatefulWidget {
  final int days;
  const _FiltersTab({required this.days});

  @override
  ConsumerState<_FiltersTab> createState() => _FiltersTabState();
}

class _FiltersTabState extends ConsumerState<_FiltersTab> {
  String? _scope;

  @override
  Widget build(BuildContext context) {
    final range = (days: widget.days, scope: _scope);
    final combosAsync = ref.watch(filtersAnalyticsProvider(range));
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: _ScopeSelector(
            selected: _scope,
            onChanged: (s) => setState(() => _scope = s),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async => ref.invalidate(filtersAnalyticsProvider),
            child: combosAsync.when(
              data: (combos) {
                if (combos.isEmpty) {
                  return ListView(
                    children: const [
                      _EmptyState(
                        icon: Icons.filter_alt_off_outlined,
                        message:
                            'No filter combinations recorded for this period.',
                      ),
                    ],
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    16,
                    8,
                    16,
                    LayoutConstants.navBarClearance,
                  ),
                  itemCount: combos.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) =>
                      _FilterComboCard(rank: i + 1, combo: combos[i]),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _ErrorState(error: e),
            ),
          ),
        ),
      ],
    );
  }
}

class _FilterComboCard extends StatelessWidget {
  final int rank;
  final FilterCombo combo;
  const _FilterComboCard({required this.rank, required this.combo});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            margin: const EdgeInsets.only(top: 2),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.turmeric.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Text(
              '$rank',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final c in combo.categories)
                  Chip(
                    label: Text(c, style: const TextStyle(fontSize: 11)),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    backgroundColor: AppColors.maroon.withValues(alpha: 0.1),
                  ),
                for (final s in combo.sizes)
                  Chip(
                    label: Text(s, style: const TextStyle(fontSize: 11)),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    backgroundColor: AppColors.turmeric.withValues(alpha: 0.18),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${combo.count}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                '${combo.uniqueVisitors} visitors',
                style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Coming soon tab ──────────────────────────────────────────────────────────

class _ComingSoonTab extends ConsumerWidget {
  final int days;
  const _ComingSoonTab({required this.days});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(comingSoonAnalyticsProvider(days));
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(comingSoonAnalyticsProvider),
      child: asyncData.when(
        data: (rows) {
          if (rows.isEmpty) {
            return ListView(
              children: const [
                _EmptyState(
                  icon: Icons.rocket_launch_outlined,
                  message: 'No "Coming Soon" clicks recorded for this period.',
                ),
              ],
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              16,
              12,
              16,
              LayoutConstants.navBarClearance,
            ),
            itemCount: rows.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) => _RankedRow(
              rank: i + 1,
              title: rows[i].displayName,
              subtitle: 'last seen ${_formatDateTime(rows[i].lastSeen)}',
              count: rows[i].clicks,
              uniqueVisitors: rows[i].uniqueVisitors,
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorState(error: e),
      ),
    );
  }
}

// ── Recipe conversion tab ────────────────────────────────────────────────────

class _RecipesTab extends ConsumerWidget {
  final int days;
  const _RecipesTab({required this.days});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(recipeConversionProvider(days));
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(recipeConversionProvider),
      child: asyncData.when(
        data: (result) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(
              16,
              12,
              16,
              LayoutConstants.navBarClearance,
            ),
            children: [
              if (result.note.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    result.note,
                    style: TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              if (result.pairs.isEmpty)
                const _EmptyState(
                  icon: Icons.restaurant_menu_outlined,
                  message:
                      'No recipe → product clicks recorded for this period.',
                )
              else
                for (var i = 0; i < result.pairs.length; i++) ...[
                  _RecipePairRowTile(rank: i + 1, pair: result.pairs[i]),
                  const SizedBox(height: 8),
                ],
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorState(error: e),
      ),
    );
  }
}

class _RecipePairRowTile extends StatelessWidget {
  final int rank;
  final RecipePairRow pair;
  const _RecipePairRowTile({required this.rank, required this.pair});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.maroon.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Text(
              '$rank',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    pair.recipeSlug,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(
                    Icons.arrow_forward,
                    size: 13,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                Flexible(
                  child: Text(
                    pair.productSlug,
                    style: TextStyle(color: scheme.onSurfaceVariant),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${pair.clicks}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                '${pair.uniqueVisitors} visitors',
                style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
