import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'packaging_api.dart';
import 'packaging_provider.dart';
import '../../core/utils/haptics.dart';
import '../../shared/widgets/tap_scale.dart';
import '../../shared/widgets/success_pulse.dart';
import '../../shared/widgets/staggered_fade_in.dart';
import '../../shared/widgets/product_avatar.dart';

class PackagingBulkReportScreen extends ConsumerStatefulWidget {
  const PackagingBulkReportScreen({super.key});

  @override
  ConsumerState<PackagingBulkReportScreen> createState() =>
      _PackagingBulkReportScreenState();
}

class _PackagingBulkReportScreenState
    extends ConsumerState<PackagingBulkReportScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';
  bool _submitting = false;
  int _doneCount = 0;

  // key = "productId:size" -> qty
  final Map<String, int> _quantities = {};

  int get _selectedCount => _quantities.length;

  void _setQty(String key, int value) {
    setState(() {
      if (value <= 0) {
        _quantities.remove(key);
      } else {
        _quantities[key] = value;
      }
    });
  }

  Future<void> _submitAll(List<StaffProduct> products) async {
    if (_quantities.isEmpty) return;

    Haptics.warning();
    setState(() {
      _submitting = true;
      _doneCount = 0;
    });

    final lines = _quantities.entries.toList();
    final errors = <String>[];

    for (final entry in lines) {
      final separatorIndex = entry.key.indexOf(':');
      final productId = int.parse(entry.key.substring(0, separatorIndex));
      final size = entry.key.substring(separatorIndex + 1);

      try {
        await ref
            .read(packagingApiProvider)
            .submitReport(productId: productId, size: size, qty: entry.value);
        if (mounted) {
          setState(() => _doneCount++);
        }
      } catch (_) {
        final product = products.firstWhere(
          (p) => p.id == productId,
          orElse: () => products.first,
        );
        errors.add('${product.name} ($size)');
      }
    }

    ref.invalidate(myPackagingReportsProvider);
    if (!mounted) return;

    setState(() => _submitting = false);

    if (errors.isEmpty) {
      Haptics.success();
      await SuccessPulse.show(
        context,
        '${lines.length} report${lines.length == 1 ? '' : 's'} submitted — pending approval',
      );
      if (mounted) {
        setState(() => _quantities.clear());
      }
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${lines.length - errors.length}/${lines.length} submitted. Failed: ${errors.join(', ')}',
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(staffProductsProvider);
    final products = productsAsync.valueOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('Bulk Report Packaging')),
      body: productsAsync.when(
        data: (products) => _buildBody(products),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load products: $e')),
      ),
      // Pinned to the Scaffold's dedicated bottom slot instead of being the
      // last item in a scrolling Column — it now always gets guaranteed
      // screen space regardless of list length or how many items are
      // selected, which was the root cause of the button being unreachable.
      bottomNavigationBar: products == null ? null : _buildSubmitBar(products),
    );
  }

  Widget _buildBody(List<StaffProduct> products) {
    final filtered = _query.isEmpty
        ? products
        : products
              .where((p) => p.name.toLowerCase().contains(_query.toLowerCase()))
              .toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              hintText: 'Search products…',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() {
                        _searchCtrl.clear();
                        _query = '';
                      }),
                    ),
            ),
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? const Center(child: Text('No matching products.'))
              : ListView.builder(
                  padding: const EdgeInsets.only(top: 8, bottom: 8),
                  itemCount: filtered.length,
                  itemBuilder: (context, i) => StaggeredFadeIn(
                    key: ValueKey('fade_${filtered[i].id}'),
                    index: i,
                    child: _BulkProductCard(
                      key: ValueKey('card_${filtered[i].id}'),
                      product: filtered[i],
                      quantities: _quantities,
                      onChanged: _setQty,
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildSubmitBar(List<StaffProduct> products) {
    return SafeArea(
      top: false,
      child: AnimatedSize(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        alignment: Alignment.bottomCenter,
        child: _selectedCount == 0
            ? const SizedBox(width: double.infinity, height: 0)
            : Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHigh,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 12,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '$_selectedCount item${_selectedCount == 1 ? '' : 's'} selected',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: _submitting
                          ? null
                          : () => _submitAll(products),
                      icon: _submitting
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                value: _selectedCount == 0
                                    ? null
                                    : _doneCount / _selectedCount,
                              ),
                            )
                          : const Icon(Icons.send),
                      label: Text(_submitting ? 'Submitting…' : 'Submit All'),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _BulkProductCard extends StatelessWidget {
  final StaffProduct product;
  final Map<String, int> quantities;
  final void Function(String key, int value) onChanged;

  const _BulkProductCard({
    super.key,
    required this.product,
    required this.quantities,
    required this.onChanged,
  });

  int _selectedInProduct() => product.sizes
      .where((s) => quantities.containsKey('${product.id}:${s.size}'))
      .length;

  @override
  Widget build(BuildContext context) {
    final selected = _selectedInProduct();
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ExpansionTile(
        initiallyExpanded: selected > 0,
        leading: ProductAvatar(image: product.image),
        title: Text(product.name),
        subtitle: selected > 0
            ? Text('$selected size${selected == 1 ? '' : 's'} added')
            : null,
        trailing: selected > 0
            ? CircleAvatar(
                radius: 12,
                backgroundColor: const Color(0xFF2E7D32),
                child: Text(
                  '$selected',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            : null,
        children: product.sizes.map((size) {
          final key = '${product.id}:${size.size}';
          final qty = quantities[key] ?? 0;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Expanded(child: Text('${size.size} · stock ${size.stockQty}')),
                _QtyStepper(qty: qty, onChanged: (v) => onChanged(key, v)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _QtyStepper extends StatelessWidget {
  final int qty;
  final ValueChanged<int> onChanged;

  const _QtyStepper({required this.qty, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final active = qty > 0;
    final primary = Theme.of(context).colorScheme.primary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        TapScale(
          onTap: qty > 0
              ? () {
                  Haptics.tap();
                  onChanged(qty - 1);
                }
              : null,
          child: Icon(
            Icons.remove_circle_outline,
            color: qty > 0 ? primary : Colors.grey.shade400,
          ),
        ),
        SizedBox(
          width: 32,
          child: Text(
            '$qty',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: active ? primary : null,
            ),
          ),
        ),
        TapScale(
          onTap: () {
            Haptics.tap();
            onChanged(qty + 1);
          },
          child: Icon(Icons.add_circle_outline, color: primary),
        ),
      ],
    );
  }
}
