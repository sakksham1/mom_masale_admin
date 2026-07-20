// lib/features/orders/orders_list_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'orders_provider.dart';
import '../../core/constants/layout_constants.dart';

class OrdersTab extends ConsumerWidget {
  const OrdersTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(ordersProvider(null));
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(ordersProvider(null)),
      child: ordersAsync.when(
        data: (orders) {
          if (orders.isEmpty) {
            return const Center(child: Text('No orders yet.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.only(
              bottom: LayoutConstants.navBarClearance,
            ),
            itemCount: orders.length,
            itemBuilder: (context, i) {
              final o = orders[i];
              return ListTile(
                title: Text('#${o.id} — ${o.customerName}'),
                subtitle: Text('${o.status} · ${o.paymentStatus}'),
                trailing: Text('₹${o.total}'),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load orders: $e')),
      ),
    );
  }
}
