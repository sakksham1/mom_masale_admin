import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'customers_provider.dart';

class CustomersListScreen extends ConsumerWidget {
  const CustomersListScreen({super.key});

  String _rupee(int n) => '₹${n.toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',')}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customersAsync = ref.watch(customersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Customers')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(customersProvider),
        child: customersAsync.when(
          data: (customers) {
            if (customers.isEmpty) {
              return const Center(child: Text('No registered customers yet.'));
            }
            return ListView.separated(
              itemCount: customers.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final c = customers[i];
                return ListTile(
                  leading: CircleAvatar(
                    child: Text(c.name.isNotEmpty ? c.name[0].toUpperCase() : '?'),
                  ),
                  title: Row(
                    children: [
                      Flexible(child: Text(c.name, overflow: TextOverflow.ellipsis)),
                      if (c.isAdmin) ...[
                        const SizedBox(width: 6),
                        Chip(
                          label: const Text('Admin', style: TextStyle(fontSize: 11)),
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ],
                    ],
                  ),
                  subtitle: Text(c.phone != null ? '${c.email} · ${c.phone}' : c.email),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(_rupee(c.lifetimeSpend), style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text('${c.orderCount} order${c.orderCount == 1 ? '' : 's'}',
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Could not load customers: $e')),
        ),
      ),
    );
  }
}