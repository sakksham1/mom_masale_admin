// lib/features/business/business_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../orders/orders_list_screen.dart';
import '../customers/customers_list_screen.dart';
import '../db_explorer/db_explorer_screen.dart' show DbExplorerView;
import '../../core/auth/user_role.dart';
import '../../core/network/api_client_provider.dart';

/// Combines Orders, Customers (and, for admin, the read-only DB Explorer;
/// for manager, a Staff view instead) under one "Business" nav entry.
/// Admin gets edit access on Orders/Customers; manager is view-only on
/// everything here — enforced both by hiding controls and by the backend
/// (orders PATCH / roles PATCH stay admin-only regardless of this UI).
class BusinessScreen extends ConsumerStatefulWidget {
  const BusinessScreen({super.key});

  @override
  ConsumerState<BusinessScreen> createState() => _BusinessScreenState();
}

class _BusinessScreenState extends ConsumerState<BusinessScreen>
    with SingleTickerProviderStateMixin {
  TabController? _controller;

  TabController _controllerFor(int length) {
    if (_controller == null || _controller!.length != length) {
      _controller?.dispose();
      _controller = TabController(length: length, vsync: this);
    }
    return _controller!;
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  static const _staffRoles = {
    UserRole.manager,
    UserRole.warehouser,
    UserRole.packaging,
    UserRole.salesperson,
    UserRole.admin,
  };

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(authControllerProvider).role;
    final isAdmin = role == UserRole.admin;

    final tabs = isAdmin
        ? const [
            Tab(text: 'Orders'),
            Tab(text: 'Customers'),
            Tab(text: 'DB Explorer'),
          ]
        : const [
            Tab(text: 'Orders'),
            Tab(text: 'Customers'),
            Tab(text: 'Staff'),
          ];

    final controller = _controllerFor(tabs.length);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Business'),
        bottom: TabBar(
          controller: controller,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: tabs,
        ),
      ),
      body: TabBarView(
        controller: controller,
        children: isAdmin
            ? const [OrdersTab(), CustomersTab(), DbExplorerView()]
            : const [
                OrdersTab(editable: false),
                CustomersTab(
                  editable: false,
                  roleFilter: {UserRole.customer},
                  emptyMessage: 'No registered customers yet.',
                ),
                CustomersTab(
                  editable: false,
                  roleFilter: _staffRoles,
                  emptyMessage: 'No staff members yet.',
                ),
              ],
      ),
    );
  }
}
