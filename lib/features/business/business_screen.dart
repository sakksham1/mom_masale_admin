// lib/features/business/business_screen.dart
import 'package:flutter/material.dart';
import '../orders/orders_list_screen.dart';
import '../customers/customers_list_screen.dart';
import '../db_explorer/db_explorer_screen.dart' show DbExplorerView;

/// Combines Orders, Customers, and the read-only DB Explorer under one
/// "Business" nav entry.
class BusinessScreen extends StatefulWidget {
  const BusinessScreen({super.key});

  @override
  State<BusinessScreen> createState() => _BusinessScreenState();
}

class _BusinessScreenState extends State<BusinessScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _controller = TabController(length: 3, vsync: this);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Business'),
        bottom: TabBar(
          controller: _controller,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(text: 'Orders'),
            Tab(text: 'Customers'),
            Tab(text: 'DB Explorer'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _controller,
        children: const [OrdersTab(), CustomersTab(), DbExplorerView()],
      ),
    );
  }
}
