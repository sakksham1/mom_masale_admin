import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dashboard_provider.dart';
import '../../core/utils/currency.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/layout_constants.dart';
import '../../shared/widgets/status_badge.dart';
import '../audit_log/audit_log_section.dart';
import '../notifications/notification_bell.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(dashboardStatsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Overview'),
        actions: const [NotificationBell(), SizedBox(width: 8)],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(dashboardStatsProvider),
        child: statsAsync.when(
          data: (stats) => ListView(
            padding: const EdgeInsets.fromLTRB(
              16,
              16,
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
                childAspectRatio: 1.4,
                children: [
                  _StatCard(
                    label: 'Total Revenue (paid)',
                    value: formatRupees(stats.totalRevenue),
                    numericValue: stats.totalRevenue,
                    icon: Icons.account_balance_wallet,
                    color: const Color(0xFF2E7D32),
                  ),
                  _StatCard(
                    label: 'Today · ${stats.todayOrders} order(s)',
                    value: formatRupees(stats.todayRevenue),
                    numericValue: stats.todayRevenue,
                    icon: Icons.today,
                    color: AppColors.turmeric,
                  ),
                  _StatCard(
                    label: 'This Month · ${stats.monthOrders} order(s)',
                    value: formatRupees(stats.monthRevenue),
                    numericValue: stats.monthRevenue,
                    icon: Icons.calendar_month,
                    color: AppColors.paprika,
                  ),
                  _StatCard(
                    label: 'Pending Fulfilment',
                    value: '${stats.pendingOrders}',
                    numericValue: stats.pendingOrders,
                    icon: Icons.local_shipping,
                    color: const Color(0xFFC98A1F),
                  ),
                  _StatCard(
                    label: 'Registered Customers',
                    value: '${stats.totalCustomers}',
                    numericValue: stats.totalCustomers,
                    icon: Icons.groups,
                    color: AppColors.maroon,
                  ),
                ],
              ),

              const Divider(height: 40),

              const _SectionHeader('Top Products', Icons.star_outline),
              const SizedBox(height: 8),
              if (stats.topProducts.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('No paid orders yet.'),
                )
              else
                ...stats.topProducts.map(
                  (p) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.local_fire_department_outlined,
                      size: 20,
                    ),
                    title: Text(p.productName),
                    trailing: Text(
                      '${p.totalQty} sold · ${formatRupees(p.totalRevenue)}',
                    ),
                  ),
                ),

              const Divider(height: 40),

              const _SectionHeader(
                'Recent Orders',
                Icons.receipt_long_outlined,
              ),
              const SizedBox(height: 8),
              if (stats.recentOrders.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('No orders yet.'),
                )
              else
                ...stats.recentOrders.map(
                  (o) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: OrderStatusBadge(
                      status: o.status,
                      paymentStatus: o.paymentStatus,
                    ),
                    title: Text('#${o.id} — ${o.customerName}'),
                    subtitle: Text('${o.status} · ${o.paymentStatus}'),
                    trailing: Text(
                      formatRupees(o.total),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),

              const Divider(height: 40),

              const _SectionHeader('Recent Activity', Icons.history),
              const SizedBox(height: 8),
              const AuditLogSection(),
            ],
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Could not load stats: $e')),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  const _SectionHeader(this.title, this.icon);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  final num? numericValue; // pass raw number for count-up animation

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.numericValue,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.16),
            color.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const Spacer(),
          numericValue != null
              ? TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: numericValue!.toDouble()),
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeOutCubic,
                  builder: (context, val, _) => Text(
                    value.contains('₹')
                        ? '₹${val.round().toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',')}'
                        : val.round().toString(),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                )
              : Text(
                  value,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
