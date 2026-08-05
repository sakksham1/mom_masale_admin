import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'packaging_api.dart';
import 'packaging_provider.dart';
import '../../core/theme/app_colors.dart';
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
  bool _showSelectedOnly = false;
  int _doneCount = 0;

  final Map<String, int> _quantities = {};
  final Map<String, TextEditingController> _controllers = {};

  int get _selectedCount => _quantities.length;
  int get _totalUnits => _quantities.values.fold(0, (a, b) => a + b);

  TextEditingController _controllerFor(String key) {
    return _controllers.putIfAbsent(
      key,
      () => TextEditingController(text: (_quantities[key] ?? 0).toString()),
    );
  }

  void _setQty(String key, int value) {
    final clamped = value < 0 ? 0 : value;
    setState(() {
      if (clamped <= 0) {
        _quantities.remove(key);
      } else {
        _quantities[key] = clamped;
      }
    });
    final ctrl = _controllerFor(key);
    final text = clamped == 0 ? '' : '$clamped';
    if (ctrl.text != text) {
      ctrl.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    }
  }

  void _clearAll() {
    setState(() {
      _quantities.clear();
      for (final c in _controllers.values) {
        c.text = '';
      }
    });
    Haptics.tap();
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
        if (mounted) setState(() => _doneCount++);
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
      if (mounted) _clearAll();
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
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(staffProductsProvider);
    final products = productsAsync.valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bulk Report Packaging'),
        actions: [
          if (_selectedCount > 0)
            TextButton(
              onPressed: _submitting ? null : _clearAll,
              child: const Text('Clear'),
            ),
        ],
      ),
      body: productsAsync.when(
        data: (products) => _buildBody(products),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load products: $e')),
      ),
      bottomNavigationBar: products == null ? null : _buildSubmitBar(products),
    );
  }

  Widget _buildBody(List<StaffProduct> products) {
    var filtered = _query.isEmpty
        ? products
        : products
              .where((p) => p.name.toLowerCase().contains(_query.toLowerCase()))
              .toList();

    if (_showSelectedOnly) {
      filtered = filtered
          .where(
            (p) => p.sizes.any(
              (s) => _quantities.containsKey('${p.id}:${s.size}'),
            ),
          )
          .toList();
    }

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
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(
            children: [
              ChoiceChip(
                label: Text('Selected only ($_selectedCount)'),
                selected: _showSelectedOnly,
                onSelected: (v) => setState(() => _showSelectedOnly = v),
              ),
              const Spacer(),
              Text(
                'Tap the number to type it',
                style: TextStyle(
                  fontSize: 11.5,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Text(
                    _showSelectedOnly
                        ? 'Nothing selected yet.'
                        : 'No matching products.',
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(top: 4, bottom: 8),
                  itemCount: filtered.length,
                  itemBuilder: (context, i) => StaggeredFadeIn(
                    key: ValueKey('fade_${filtered[i].id}'),
                    index: i,
                    child: _BulkProductCard(
                      key: ValueKey('card_${filtered[i].id}'),
                      product: filtered[i],
                      quantities: _quantities,
                      controllerFor: _controllerFor,
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
      child: Container(
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _selectedCount == 0
                        ? 'No items selected'
                        : '$_selectedCount item${_selectedCount == 1 ? '' : 's'} · $_totalUnits unit${_totalUnits == 1 ? '' : 's'}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: _selectedCount == 0
                          ? Theme.of(context).colorScheme.onSurfaceVariant
                          : null,
                    ),
                  ),
                  if (_selectedCount == 0)
                    Text(
                      'Enter quantities below to report packaging',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size(150, 48)),
              onPressed: (_submitting || _selectedCount == 0)
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
    );
  }
}

class _BulkProductCard extends StatelessWidget {
  final StaffProduct product;
  final Map<String, int> quantities;
  final TextEditingController Function(String key) controllerFor;
  final void Function(String key, int value) onChanged;

  const _BulkProductCard({
    super.key,
    required this.product,
    required this.quantities,
    required this.controllerFor,
    required this.onChanged,
  });

  int _selectedInProduct() => product.sizes
      .where((s) => quantities.containsKey('${product.id}:${s.size}'))
      .length;

  @override
  Widget build(BuildContext context) {
    final selected = _selectedInProduct();
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: selected > 0
              ? AppColors.turmeric.withValues(alpha: 0.5)
              : scheme.outlineVariant.withValues(alpha: 0.4),
          width: selected > 0 ? 1.3 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
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
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                Expanded(child: Text('${size.size} · stock ${size.stockQty}')),
                _QtyInput(
                  controller: controllerFor(key),
                  onChanged: (v) => onChanged(key, v),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Editable quantity control: type any number directly (fast for large
/// batches), or use −/+ for small nudges. Long-press + adds 10 at a time.
class _QtyInput extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<int> onChanged;
  const _QtyInput({required this.controller, required this.onChanged});

  int get _current => int.tryParse(controller.text) ?? 0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final primary = Theme.of(context).colorScheme.primary;
    final active = _current > 0;

    return Container(
      decoration: BoxDecoration(
        color: active
            ? primary.withValues(alpha: 0.08)
            : scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: active
              ? primary.withValues(alpha: 0.35)
              : scheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TapScale(
            onTap: _current > 0 ? () => onChanged(_current - 1) : null,
            child: const Padding(
              padding: EdgeInsets.all(8),
              child: Icon(Icons.remove, size: 18),
            ),
          ),
          SizedBox(
            width: 46,
            child: TextField(
              controller: controller,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: active ? primary : null,
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 10),
                hintText: '0',
              ),
              onChanged: (v) => onChanged(int.tryParse(v) ?? 0),
            ),
          ),
          GestureDetector(
            onLongPress: () => onChanged(_current + 10),
            child: TapScale(
              onTap: () => onChanged(_current + 1),
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: Icon(Icons.add, size: 18),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
