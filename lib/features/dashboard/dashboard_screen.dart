import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dashboard_provider.dart';
import '../../core/utils/currency.dart';
import 'package:go_router/go_router.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(dashboardStatsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Overview')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(dashboardStatsProvider),
        child: statsAsync.when(
          data: (stats) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.6,
                children: [
                  _StatCard(
                    label: 'Total Revenue (paid)',
                    value: formatRupees(stats.totalRevenue),
                  ),
                  _StatCard(
                    label: 'Today · ${stats.todayOrders} order(s)',
                    value: formatRupees(stats.todayRevenue),
                  ),
                  _StatCard(
                    label: 'This Month · ${stats.monthOrders} order(s)',
                    value: formatRupees(stats.monthRevenue),
                  ),
                  _StatCard(
                    label: 'Pending Fulfilment',
                    value: '${stats.pendingOrders}',
                  ),
                  _StatCard(
                    label: 'Registered Customers',
                    value: '${stats.totalCustomers}',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.fact_check_outlined),
                  title: const Text('Pending Approvals'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/approvals'),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Top Products',
                style: Theme.of(context).textTheme.titleMedium,
              ),
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
                    title: Text(p.productName),
                    trailing: Text(
                      '${p.totalQty} sold · ${formatRupees(p.totalRevenue)}',
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              Text(
                'Recent Orders',
                style: Theme.of(context).textTheme.titleMedium,
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
                    title: Text('#${o.id} — ${o.customerName}'),
                    subtitle: Text('${o.status} · ${o.paymentStatus}'),
                    trailing: Text(
                      formatRupees(o.total),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Could not load stats: $e')),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label, value;
  const _StatCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
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
      ),
    );
  }
}
