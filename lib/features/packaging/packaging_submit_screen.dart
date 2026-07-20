import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'packaging_api.dart';
import 'packaging_provider.dart';
import '../../core/network/api_exception.dart';
import '../../core/constants/layout_constants.dart';
import '../../core/utils/haptics.dart';
import '../../shared/widgets/success_pulse.dart';
import 'package:go_router/go_router.dart';

class PackagingSubmitScreen extends ConsumerStatefulWidget {
  const PackagingSubmitScreen({super.key});
  @override
  ConsumerState<PackagingSubmitScreen> createState() =>
      _PackagingSubmitScreenState();
}

class _PackagingSubmitScreenState extends ConsumerState<PackagingSubmitScreen> {
  StaffProduct? _selectedProduct;
  String? _selectedSize;
  final _qtyCtrl = TextEditingController();
  bool _submitting = false;
  String? _error;
  Future<void> _submit() async {
    final product = _selectedProduct;
    final size = _selectedSize;
    final qty = int.tryParse(_qtyCtrl.text.trim());

    if (product == null || size == null) {
      setState(() => _error = 'Select a product and size');
      return;
    }
    if (qty == null || qty <= 0) {
      setState(() => _error = 'Enter a valid quantity');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref
          .read(packagingApiProvider)
          .submitReport(productId: product.id, size: size, qty: qty);
      Haptics.success();
      if (mounted) {
        await SuccessPulse.show(
          context,
          '${product.name} ($size) × $qty reported',
        );
      }
      if (mounted) {
        setState(() {
          _qtyCtrl.clear();
          _selectedSize = null;
        });
      }
      ref.invalidate(myPackagingReportsProvider);
    } on ApiException catch (e) {
      Haptics.warning();
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(staffProductsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Report Packaging'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => context.push('/packaging/history'),
          ),
        ],
      ),
      body: productsAsync.when(
        data: (products) => SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            20,
            20,
            20,
            LayoutConstants.navBarClearance,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<StaffProduct>(
                initialValue: _selectedProduct,
                decoration: const InputDecoration(labelText: 'Product'),
                items: products
                    .map((p) => DropdownMenuItem(value: p, child: Text(p.name)))
                    .toList(),
                onChanged: (p) => setState(() {
                  _selectedProduct = p;
                  _selectedSize = null;
                }),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _selectedSize,
                decoration: const InputDecoration(labelText: 'Size'),
                items: (_selectedProduct?.sizes ?? [])
                    .map(
                      (s) => DropdownMenuItem(
                        value: s.size,
                        child: Text('${s.size} (current stock: ${s.stockQty})'),
                      ),
                    )
                    .toList(),
                onChanged: _selectedProduct == null
                    ? null
                    : (s) => setState(() => _selectedSize = s),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _qtyCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Quantity packaged today',
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 22),
              FilledButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Submit Report'),
              ),
            ],
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load products: $e')),
      ),
    );
  }
}
