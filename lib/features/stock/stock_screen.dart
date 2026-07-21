// lib/features/stock/stock_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/auth/user_role.dart';
import '../../core/network/api_client_provider.dart';
import '../products/products_list_screen.dart';
import '../warehouse/warehouse_screen.dart';

/// Inventory screen — two tabs: Products (finished goods) and Raw Materials.
/// Visible (view-only) to packaging, manager, and admin — who approve
/// pending changes via the Approvals tab. Editable only by warehouser, who
/// submits changes on either tab for manager/admin approval.
class StockScreen extends ConsumerStatefulWidget {
  const StockScreen({super.key});

  @override
  ConsumerState<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends ConsumerState<StockScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _controller = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(authControllerProvider).role;
    final canManage = role == UserRole.warehouser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory'),
        bottom: TabBar(
          controller: _controller,
          tabs: const [
            Tab(text: 'Products'),
            Tab(text: 'Raw Materials'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _controller,
        children: [
          ProductsTab(canManage: canManage),
          const WarehouseTab(),
        ],
      ),
    );
  }
}
