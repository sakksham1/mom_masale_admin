// lib/features/business/business_screen.dart
import 'package:flutter/material.dart';
import '../orders/orders_list_screen.dart';
import '../customers/customers_list_screen.dart';

/// Combines Orders and Customers under one "Business" nav entry.
class BusinessScreen extends StatefulWidget {
  const BusinessScreen({super.key});

  @override
  State<BusinessScreen> createState() => _BusinessScreenState();
}

class _BusinessScreenState extends State<BusinessScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _controller = TabController(length: 2, vsync: this);

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
          tabs: const [
            Tab(text: 'Orders'),
            Tab(text: 'Customers'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _controller,
        children: const [OrdersTab(), CustomersTab()],
      ),
    );
  }
}
