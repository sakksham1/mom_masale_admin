import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'approvals_provider.dart';
import '../../core/auth/user_role.dart';
import '../../core/network/api_client_provider.dart';
import '../../core/network/api_exception.dart';
import '../../core/constants/layout_constants.dart';
import '../../core/utils/haptics.dart';
import '../../shared/widgets/success_pulse.dart';
import '../../shared/widgets/swipe_confirm_sheet.dart';

class ApprovalsScreen extends ConsumerStatefulWidget {
  const ApprovalsScreen({super.key});

  @override
  ConsumerState<ApprovalsScreen> createState() => _ApprovalsScreenState();
}

class _ApprovalsScreenState extends ConsumerState<ApprovalsScreen> {
  bool _selectMode = false;
  final Set<String> _selected = {};
  bool _submitting = false;

  String _key(String type, int id) => '$type:$id';

  void _toggle(String type, int id) {
    final k = _key(type, id);
    setState(() {
      if (_selected.contains(k)) {
        _selected.remove(k);
      } else {
        _selected.add(k);
      }
    });
    Haptics.tap();
  }

  void _toggleSectionAll(List<String> keys) {
    if (keys.isEmpty) return;
    final allSelected = keys.every(_selected.contains);
    setState(() {
      if (allSelected) {
        _selected.removeAll(keys);
      } else {
        _selected.addAll(keys);
      }
    });
    Haptics.tap();
  }

  void _exitSelectMode() {
    setState(() {
      _selectMode = false;
      _selected.clear();
    });
  }

  Future<void> _decide(
    BuildContext context,
    WidgetRef ref,
    String type,
    int id,
    String decision,
  ) async {
    final confirmed = await SwipeConfirmSheet.show(
      context,
      icon: decision == 'approved'
          ? Icons.check_circle_outline
          : Icons.cancel_outlined,
      color: decision == 'approved'
          ? const Color(0xFF2E7D32)
          : Theme.of(context).colorScheme.error,
      message: Text(
        decision == 'approved'
            ? 'Approve this request? The change will take effect.'
            : 'Reject this request? It will be removed from the queue.',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      swipeLabel: decision == 'approved'
          ? 'Slide to approve'
          : 'Slide to reject',
    );
    if (!confirmed || !context.mounted) return;

    try {
      await ref
          .read(approvalsApiProvider)
          .decide(type: type, id: id, decision: decision);
      ref.invalidate(approvalsQueueProvider);
      Haptics.success();
      if (context.mounted) {
        await SuccessPulse.show(
          context,
          decision == 'approved' ? 'Approved' : 'Rejected',
        );
      }
    } on ApiException catch (e) {
      Haptics.warning();
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _confirmAndDecideBatch(String decision) async {
    if (_selected.isEmpty) return;
    final confirmed = await SwipeConfirmSheet.show(
      context,
      icon: decision == 'approved'
          ? Icons.check_circle_outline
          : Icons.cancel_outlined,
      color: decision == 'approved'
          ? const Color(0xFF2E7D32)
          : Theme.of(context).colorScheme.error,
      message: Text.rich(
        TextSpan(
          style: Theme.of(context).textTheme.bodyMedium,
          children: [
            TextSpan(text: decision == 'approved' ? 'Approve ' : 'Reject '),
            TextSpan(
              text:
                  '${_selected.length} request${_selected.length == 1 ? '' : 's'}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const TextSpan(text: '?'),
          ],
        ),
      ),
      swipeLabel: decision == 'approved'
          ? 'Slide to approve all'
          : 'Slide to reject all',
    );
    if (!confirmed) return;
    await _decideBatch(decision);
  }

  Future<void> _decideBatch(String decision) async {
    if (_selected.isEmpty) return;
    setState(() => _submitting = true);

    final items = _selected.map((k) {
      final idx = k.indexOf(':');
      return (
        type: k.substring(0, idx),
        id: int.parse(k.substring(idx + 1)),
        decision: decision,
      );
    }).toList();

    try {
      final result = await ref.read(approvalsApiProvider).decideBatch(items);
      ref.invalidate(approvalsQueueProvider);

      if (result.failed == 0) {
        Haptics.success();
        if (mounted) {
          await SuccessPulse.show(
            context,
            '${result.succeeded} request${result.succeeded == 1 ? '' : 's'} '
            '${decision == 'approved' ? 'approved' : 'rejected'}',
          );
        }
      } else {
        Haptics.warning();
        if (mounted) {
          final lines = result.results
              .where((r) => !r.ok)
              .map((r) => '#${r.id} (${r.type}): ${r.error ?? 'failed'}')
              .join('\n');
          await showDialog<void>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: Text(
                '${result.succeeded} succeeded, ${result.failed} failed',
              ),
              content: SingleChildScrollView(child: Text(lines)),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      }
      _exitSelectMode();
    } on ApiException catch (e) {
      Haptics.warning();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final queueAsync = ref.watch(approvalsQueueProvider);
    final role = ref.watch(authControllerProvider).role;
    final canApproveCatalog = role == UserRole.admin;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Approvals'),
        actions: [
          TextButton(
            onPressed: () {
              if (_selectMode) {
                _exitSelectMode();
              } else {
                setState(() => _selectMode = true);
              }
            },
            child: Text(_selectMode ? 'Done' : 'Select'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(approvalsQueueProvider),
        child: queueAsync.when(
          data: (queue) {
            if (queue.isEmpty) {
              return ListView(
                padding: const EdgeInsets.fromLTRB(
                  16,
                  16,
                  16,
                  LayoutConstants.navBarClearance,
                ),
                children: const [
                  Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child: Text('Nothing pending. All caught up.'),
                    ),
                  ),
                ],
              );
            }

            final productCoreKeys = canApproveCatalog
                ? queue.productCore
                      .map((c) => _key('product_core', c.id))
                      .toList()
                : <String>[];
            final rawMaterialKeys = queue.rawMaterial
                .map((r) => _key('raw_material', r.id))
                .toList();
            final productStockKeys = queue.productStock
                .map((s) => _key('product_stock', s.id))
                .toList();
            final packagingKeys = queue.packaging
                .map((p) => _key('packaging', p.id))
                .toList();

            return ListView(
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                LayoutConstants.navBarClearance +
                    (_selected.isNotEmpty ? 76 : 0),
              ),
              children: [
                if (queue.productCore.isNotEmpty) ...[
                  _SectionHeader(
                    'Product Catalog Changes',
                    selectMode: _selectMode && canApproveCatalog,
                    allSelected:
                        productCoreKeys.isNotEmpty &&
                        productCoreKeys.every(_selected.contains),
                    onSelectAll: () => _toggleSectionAll(productCoreKeys),
                  ),
                  ...queue.productCore.map(
                    (c) => _DecisionTile(
                      title: c.productSlug ?? 'product',
                      subtitle: '${c.summary} · by ${c.requestedByName}',
                      canDecide: canApproveCatalog,
                      lockedReason: 'Awaiting admin approval',
                      selectMode: _selectMode,
                      selectable: canApproveCatalog,
                      selected: _selected.contains(_key('product_core', c.id)),
                      onToggle: () => _toggle('product_core', c.id),
                      onDecide: (decision) =>
                          _decide(context, ref, 'product_core', c.id, decision),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (queue.rawMaterial.isNotEmpty) ...[
                  _SectionHeader(
                    'Raw Material Adjustments',
                    selectMode: _selectMode,
                    allSelected:
                        rawMaterialKeys.isNotEmpty &&
                        rawMaterialKeys.every(_selected.contains),
                    onSelectAll: () => _toggleSectionAll(rawMaterialKeys),
                  ),
                  ...queue.rawMaterial.map(
                    (r) => _DecisionTile(
                      title: r.inputAmount != null && r.inputUnit != null
                          ? '${r.materialName}  ${r.inputAmount! > 0 ? '+' : ''}${r.inputAmount} ${r.inputUnit}'
                          : '${r.materialName}  ${r.delta > 0 ? '+' : ''}${r.delta}',
                      subtitle:
                          'Reason: ${r.reason}'
                          '${r.note != null && r.note!.isNotEmpty ? ' · ${r.note}' : ''}'
                          ' · by ${r.requestedByName}',
                      selectMode: _selectMode,
                      selected: _selected.contains(_key('raw_material', r.id)),
                      onToggle: () => _toggle('raw_material', r.id),
                      onDecide: (decision) =>
                          _decide(context, ref, 'raw_material', r.id, decision),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (queue.productStock.isNotEmpty) ...[
                  _SectionHeader(
                    'Product Stock Adjustments',
                    selectMode: _selectMode,
                    allSelected:
                        productStockKeys.isNotEmpty &&
                        productStockKeys.every(_selected.contains),
                    onSelectAll: () => _toggleSectionAll(productStockKeys),
                  ),
                  ...queue.productStock.map(
                    (s) => _DecisionTile(
                      title:
                          '${s.productName} (${s.size})  ${s.changeQty > 0 ? '+' : ''}${s.changeQty}',
                      subtitle:
                          'Reason: ${s.reason}'
                          '${s.note != null && s.note!.isNotEmpty ? ' · ${s.note}' : ''}'
                          ' · by ${s.requestedByName}',
                      selectMode: _selectMode,
                      selected: _selected.contains(_key('product_stock', s.id)),
                      onToggle: () => _toggle('product_stock', s.id),
                      onDecide: (decision) => _decide(
                        context,
                        ref,
                        'product_stock',
                        s.id,
                        decision,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (queue.packaging.isNotEmpty) ...[
                  _SectionHeader(
                    'Packaging Reports',
                    selectMode: _selectMode,
                    allSelected:
                        packagingKeys.isNotEmpty &&
                        packagingKeys.every(_selected.contains),
                    onSelectAll: () => _toggleSectionAll(packagingKeys),
                  ),
                  ...queue.packaging.map(
                    (p) => _DecisionTile(
                      title: '${p.productSlug} (${p.size}) × ${p.qty}',
                      subtitle:
                          'Reported by ${p.requestedByName} on ${p.reportDate}',
                      selectMode: _selectMode,
                      selected: _selected.contains(_key('packaging', p.id)),
                      onToggle: () => _toggle('packaging', p.id),
                      onDecide: (decision) =>
                          _decide(context, ref, 'packaging', p.id, decision),
                    ),
                  ),
                ],
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Could not load approvals: $e')),
        ),
      ),
      // Pinned Scaffold slot, not the last item in a scrolling Column — same
      // fix documented for packaging_bulk_report_screen.dart's submit bar.
      bottomNavigationBar: _selected.isEmpty
          ? null
          : SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHigh,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 16,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${_selected.length} selected',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    if (_submitting)
                      const Padding(
                        padding: EdgeInsets.only(right: 8),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    else ...[
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Theme.of(
                              context,
                            ).colorScheme.error,
                            side: BorderSide(
                              color: Theme.of(
                                context,
                              ).colorScheme.error.withValues(alpha: 0.5),
                            ),
                          ),
                          onPressed: () => _confirmAndDecideBatch('rejected'),
                          icon: const Icon(Icons.close, size: 18),
                          label: Text('Reject (${_selected.length})'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF2E7D32),
                          ),
                          onPressed: () => _confirmAndDecideBatch('approved'),
                          icon: const Icon(Icons.check, size: 18),
                          label: Text('Approve (${_selected.length})'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final bool selectMode;
  final bool allSelected;
  final VoidCallback? onSelectAll;
  const _SectionHeader(
    this.title, {
    this.selectMode = false,
    this.allSelected = false,
    this.onSelectAll,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
          if (selectMode && onSelectAll != null)
            TextButton(
              onPressed: onSelectAll,
              child: Text(allSelected ? 'Deselect all' : 'Select all'),
            ),
        ],
      ),
    );
  }
}

class _DecisionTile extends StatefulWidget {
  final String title, subtitle;
  final Future<void> Function(String decision) onDecide;
  final bool canDecide;
  final String? lockedReason;
  final bool selectMode;
  final bool selectable;
  final bool selected;
  final VoidCallback? onToggle;

  const _DecisionTile({
    required this.title,
    required this.subtitle,
    required this.onDecide,
    this.canDecide = true,
    this.lockedReason,
    this.selectMode = false,
    this.selectable = true,
    this.selected = false,
    this.onToggle,
  });

  @override
  State<_DecisionTile> createState() => _DecisionTileState();
}

class _DecisionTileState extends State<_DecisionTile> {
  bool _busy = false;

  Future<void> _tap(String decision) async {
    setState(() => _busy = true);
    await widget.onDecide(decision);
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final canSelect =
        widget.selectMode && widget.canDecide && widget.selectable;

    Widget trailing;
    if (widget.selectMode) {
      trailing = canSelect
          ? Checkbox(
              value: widget.selected,
              onChanged: (_) => widget.onToggle?.call(),
            )
          : Chip(
              label: Text(
                widget.canDecide
                    ? 'Not selectable'
                    : (widget.lockedReason ?? 'Locked'),
                style: const TextStyle(fontSize: 11),
              ),
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            );
    } else if (!widget.canDecide) {
      trailing = Chip(
        label: Text(
          widget.lockedReason ?? 'Pending',
          style: const TextStyle(fontSize: 11),
        ),
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      );
    } else if (_busy) {
      trailing = const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    } else {
      trailing = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(Icons.check_circle, color: Colors.green.shade600),
            tooltip: 'Approve',
            onPressed: () => _tap('approved'),
          ),
          IconButton(
            icon: Icon(
              Icons.cancel,
              color: Theme.of(context).colorScheme.error,
            ),
            tooltip: 'Reject',
            onPressed: () => _tap('rejected'),
          ),
        ],
      );
    }

    return Card(
      child: ListTile(
        onTap: canSelect ? widget.onToggle : null,
        title: Text(widget.title),
        subtitle: Text(widget.subtitle),
        trailing: trailing,
      ),
    );
  }
}
