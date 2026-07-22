import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'packaging_provider.dart';
import '../../core/constants/layout_constants.dart';

class PackagingHistoryScreen extends ConsumerWidget {
  const PackagingHistoryScreen({super.key});

  Color _statusColor(BuildContext context, String status) {
    switch (status) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Theme.of(context).colorScheme.error;
      default:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportsAsync = ref.watch(myPackagingReportsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My Packaging Reports')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(myPackagingReportsProvider),
        child: reportsAsync.when(
          data: (reports) {
            if (reports.isEmpty) {
              return const Center(child: Text('No reports yet.'));
            }
            return ListView.separated(
              padding: const EdgeInsets.only(
                bottom: LayoutConstants.navBarClearance,
              ),
              itemCount: reports.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final r = reports[i];
                return ListTile(
                  title: Text('${r.productName} (${r.size}) × ${r.qty}'),
                  subtitle: Text(r.reportDate),
                  trailing: Chip(
                    label: Text(r.status, style: const TextStyle(fontSize: 11)),
                    backgroundColor: _statusColor(
                      context,
                      r.status,
                    ).withValues(alpha: 0.15),
                    labelStyle: TextStyle(
                      color: _statusColor(context, r.status),
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Could not load history: $e')),
        ),
      ),
    );
  }
}
