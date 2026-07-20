// lib/features/stock/stock_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/auth/user_role.dart';
import '../../core/network/api_client_provider.dart';
import '../products/products_list_screen.dart';
import '../warehouse/warehouse_screen.dart';

/// Combines Inventory (finished-product stock) and Warehouse (raw-material
/// stock) under one "Stock" nav entry. Which sub-tabs show up depends on
/// the signed-in role — admins see both, everyone else with stock access
/// (manager, warehouser, packaging) just sees Warehouse, so the tab bar is
/// skipped entirely for them.
class StockScreen extends ConsumerStatefulWidget {
  const StockScreen({super.key});

  @override
  ConsumerState<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends ConsumerState<StockScreen>
    with SingleTickerProviderStateMixin {
  TabController? _controller;
  List<_StockSection> _sections = const [];

  void _syncSections(UserRole role) {
    final sections = <_StockSection>[
      if (role == UserRole.admin)
        const _StockSection('Inventory', InventoryTab()),
      const _StockSection('Warehouse', WarehouseTab()),
    ];
    if (_sections.length != sections.length) {
      _controller?.dispose();
      _controller = TabController(length: sections.length, vsync: this);
    }
    _sections = sections;
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(authControllerProvider).role;
    _syncSections(role);

    if (_sections.length == 1) {
      return Scaffold(
        appBar: AppBar(title: const Text('Stock')),
        body: _sections.first.body,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock'),
        bottom: TabBar(
          controller: _controller,
          tabs: _sections.map((s) => Tab(text: s.label)).toList(),
        ),
      ),
      body: TabBarView(
        controller: _controller,
        children: _sections.map((s) => s.body).toList(),
      ),
    );
  }
}

class _StockSection {
  final String label;
  final Widget body;
  const _StockSection(this.label, this.body);
}
