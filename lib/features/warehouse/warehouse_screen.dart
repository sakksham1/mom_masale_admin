// lib/features/warehouse/warehouse_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'raw_materials_api.dart';
import 'raw_materials_provider.dart';
import '../../core/auth/user_role.dart';
import '../../core/network/api_client_provider.dart';
import '../../core/network/api_exception.dart';
import '../../core/constants/layout_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/haptics.dart';
import '../../shared/widgets/tap_scale.dart';
import '../../shared/widgets/success_pulse.dart';
import '../../shared/widgets/staggered_fade_in.dart';

class WarehouseTab extends ConsumerStatefulWidget {
  const WarehouseTab({super.key});

  @override
  ConsumerState<WarehouseTab> createState() => _WarehouseTabState();
}

class _WarehouseTabState extends ConsumerState<WarehouseTab> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final materialsAsync = ref.watch(rawMaterialsProvider);
    final role = ref.watch(authControllerProvider).role;
    // Packaging can now manage raw materials the same as warehouser — they're
    // often the ones physically pulling stock and best placed to log usage.
    final canManage = role == UserRole.warehouser || role == UserRole.packaging;

    return Stack(
      children: [
        Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: 'Search raw materials…',
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
              child: RefreshIndicator(
                onRefresh: () async => ref.invalidate(rawMaterialsProvider),
                child: materialsAsync.when(
                  data: (materials) {
                    if (materials.isEmpty) {
                      return ListView(
                        children: const [
                          Padding(
                            padding: EdgeInsets.symmetric(vertical: 48),
                            child: Center(child: Text('No raw materials yet.')),
                          ),
                        ],
                      );
                    }

                    final filtered = _query.isEmpty
                        ? materials
                        : materials
                              .where(
                                (m) => m.name.toLowerCase().contains(
                                  _query.toLowerCase(),
                                ),
                              )
                              .toList();

                    if (filtered.isEmpty) {
                      return ListView(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 48),
                            child: Center(
                              child: Text('No materials match "$_query".'),
                            ),
                          ),
                        ],
                      );
                    }

                    final lowCount = materials.where((m) => m.isLow).length;

                    return ListView.builder(
                      padding: EdgeInsets.fromLTRB(
                        16,
                        4,
                        16,
                        LayoutConstants.navBarClearance + (canManage ? 72 : 0),
                      ),
                      itemCount: filtered.length + 1,
                      itemBuilder: (context, i) {
                        if (i == 0) {
                          return _SummaryStrip(
                            total: materials.length,
                            low: lowCount,
                          );
                        }
                        final m = filtered[i - 1];
                        return StaggeredFadeIn(
                          key: ValueKey('mat_fade_${m.id}'),
                          index: i - 1,
                          child: _MaterialCard(
                            key: ValueKey('mat_${m.id}'),
                            material: m,
                            canManage: canManage,
                            onAdjustSubmitted: () =>
                                ref.invalidate(rawMaterialsProvider),
                          ),
                        );
                      },
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) =>
                      Center(child: Text('Could not load raw materials: $e')),
                ),
              ),
            ),
          ],
        ),
        if (canManage)
          Positioned(
            right: 16,
            bottom: LayoutConstants.navBarClearance,
            child: FloatingActionButton.extended(
              onPressed: () => _openAddSheet(context),
              icon: const Icon(Icons.add),
              label: const Text('Add Material'),
            ),
          ),
      ],
    );
  }

  Future<void> _openAddSheet(BuildContext context) async {
    final result = await showModalBottomSheet<_NewMaterialInput>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AddMaterialSheet(),
    );
    if (result == null) return;
    try {
      await ref
          .read(rawMaterialsApiProvider)
          .createRawMaterial(
            name: result.name,
            unit: result.unit,
            qty: result.qty,
            lowStockThreshold: result.lowStockThreshold,
          );
      Haptics.success();
      ref.invalidate(rawMaterialsProvider);
      if (context.mounted) {
        await SuccessPulse.show(context, '${result.name} added');
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
}

class _SummaryStrip extends StatelessWidget {
  final int total, low;
  const _SummaryStrip({required this.total, required this.low});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: _chip(
              context,
              '$total materials',
              Icons.inventory_2_outlined,
              AppColors.cumin,
            ),
          ),
          if (low > 0) ...[
            const SizedBox(width: 8),
            Expanded(
              child: _chip(
                context,
                '$low low stock',
                Icons.warning_amber_rounded,
                const Color(0xFFC62828),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _chip(BuildContext context, String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _MaterialCard extends ConsumerStatefulWidget {
  final RawMaterial material;
  final bool canManage;
  final VoidCallback onAdjustSubmitted;
  const _MaterialCard({
    super.key,
    required this.material,
    required this.canManage,
    required this.onAdjustSubmitted,
  });

  @override
  ConsumerState<_MaterialCard> createState() => _MaterialCardState();
}

class _MaterialCardState extends ConsumerState<_MaterialCard> {
  bool _busy = false;

  Future<void> _openCustomSheet() async {
    final result = await showModalBottomSheet<_AdjustInput>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AdjustMaterialSheet(material: widget.material),
    );
    if (result == null) return;

    setState(() => _busy = true);
    try {
      await ref
          .read(rawMaterialsApiProvider)
          .submitAdjustment(
            rawMaterialId: widget.material.id,
            amount: result.amount,
            unit: result.unit,
            reason: result.reason,
            note: result.note,
          );
      Haptics.success();
      widget.onAdjustSubmitted();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Adjustment submitted — pending approval'),
          ),
        );
      }
    } on ApiException catch (e) {
      Haptics.warning();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.material;
    final scheme = Theme.of(context).colorScheme;
    final accent = m.isLow ? const Color(0xFFC62828) : AppColors.cumin;

    return TapScale(
      onTap: widget.canManage ? _openCustomSheet : null,
      scaleDown: 0.985,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: (m.isLow ? accent : scheme.outlineVariant).withValues(
              alpha: m.isLow ? 0.4 : 0.5,
            ),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(
                m.isLow
                    ? Icons.warning_amber_rounded
                    : Icons.inventory_2_outlined,
                color: accent,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    m.name,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    m.isLow
                        ? 'Low stock · threshold ${formatQty(m.unit, m.lowStockThreshold ?? 0)}'
                        : 'Tap to log usage or restock',
                    style: TextStyle(
                      fontSize: 12,
                      color: m.isLow ? accent : scheme.onSurfaceVariant,
                      fontWeight: m.isLow ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
            if (_busy)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else ...[
              Text(
                formatQty(m.unit, m.qty),
                style: const TextStyle(
                  fontFamily: 'IBMPlexMono',
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              if (widget.canManage) ...[
                const SizedBox(width: 4),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  tooltip: 'Adjust stock',
                  onPressed: _openCustomSheet,
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

/// Shared rounded bottom-sheet shell so Add/Adjust flows read as one
/// consistent, modern surface instead of a stock AlertDialog.
class _SheetShell extends StatelessWidget {
  final String title;
  final Widget child;
  const _SheetShell({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: scheme.outlineVariant,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 18),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _NewMaterialInput {
  final String name, unit;
  final num qty;
  final num? lowStockThreshold;
  _NewMaterialInput(this.name, this.unit, this.qty, this.lowStockThreshold);
}

class _AddMaterialSheet extends StatefulWidget {
  const _AddMaterialSheet();
  @override
  State<_AddMaterialSheet> createState() => _AddMaterialSheetState();
}

class _AddMaterialSheetState extends State<_AddMaterialSheet> {
  final _nameCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController(text: '0');
  final _thresholdCtrl = TextEditingController();
  String _unit = rawMaterialUnits.first;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _qtyCtrl.dispose();
    _thresholdCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    final qty = num.tryParse(_qtyCtrl.text.trim()) ?? 0;
    final threshold = num.tryParse(_thresholdCtrl.text.trim());
    Navigator.pop(context, _NewMaterialInput(name, _unit, qty, threshold));
  }

  @override
  Widget build(BuildContext context) {
    return _SheetShell(
      title: 'Add Raw Material',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _nameCtrl,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          const SizedBox(height: 14),
          Text('Base unit', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 4),
          Text(
            'Adjustments can still be logged in grams/ml later.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: rawMaterialUnits
                .map(
                  (u) => ChoiceChip(
                    label: Text(u),
                    selected: _unit == u,
                    onSelected: (_) => setState(() => _unit = u),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _qtyCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Starting quantity ($_unit)',
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _thresholdCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Low stock threshold ($_unit, optional)',
            ),
          ),
          const SizedBox(height: 22),
          FilledButton(onPressed: _submit, child: const Text('Add Material')),
        ],
      ),
    );
  }
}

class _AdjustInput {
  final num amount; // signed, expressed in `unit`
  final String unit;
  final String reason;
  final String? note;
  _AdjustInput(this.amount, this.unit, this.reason, this.note);
}

/// Small locked/disabled-looking icon slot that takes the place of a
/// stepper button when that direction isn't valid for the selected reason.
class _LockedDirectionIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  const _LockedDirectionIcon({
    required this.icon,
    required this.color,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          shape: BoxShape.circle,
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Icon(icon, color: color.withValues(alpha: 0.45), size: 18),
      ),
    );
  }
}

class _AdjustMaterialSheet extends StatefulWidget {
  final RawMaterial material;
  const _AdjustMaterialSheet({required this.material});

  @override
  State<_AdjustMaterialSheet> createState() => _AdjustMaterialSheetState();
}

class _AdjustMaterialSheetState extends State<_AdjustMaterialSheet> {
  late String _unit;
  num _amount = 0; // signed, expressed in _unit
  final _amountCtrl = TextEditingController(text: '0');
  final _noteCtrl = TextEditingController();
  String _reason = rawMaterialAdjustReasons.first;

  @override
  void initState() {
    super.initState();
    // Default to the everyday sub-unit (g/ml) when the material has one —
    // that's the common case ("used 350g"), not fractions of a kilo.
    _unit = inputUnitsFor(widget.material.unit).first;
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  bool get _isRestock => _reason == 'restock';
  bool get _isConsumption => _reason == 'consumption';

  // Grams/ml step by 10s — stepping by 1g at a time is tedious; kg/l/units
  // still step by 1.
  num get _step => (_unit == 'g' || _unit == 'ml') ? 10 : 1;

  num _signedFor(String reason, num magnitude) {
    if (reason == 'restock') return magnitude.abs();
    if (reason == 'consumption') return -magnitude.abs();
    return magnitude;
  }

  void _bump(num by) {
    setState(() {
      _amount += by;
      if (_isRestock && _amount < 0) _amount = 0;
      if (_isConsumption && _amount > 0) _amount = 0;
      _amountCtrl.text = _trim(_amount);
    });
    Haptics.tap();
  }

  void _onReasonSelected(String reason) {
    setState(() {
      _reason = reason;
      _amount = _signedFor(reason, _amount.abs());
      _amountCtrl.text = _trim(_amount);
    });
  }

  void _onUnitSelected(String unit) {
    if (unit == _unit) return;
    setState(() {
      // Re-express what's already typed in the new unit rather than
      // resetting to 0 — switching kg<->g mid-entry shouldn't lose input.
      final baseAmount = convertToBase(widget.material.unit, _amount, _unit);
      _unit = unit;
      _amount = unit == widget.material.unit ? baseAmount : baseAmount * 1000;
      _amountCtrl.text = _trim(_amount);
    });
  }

  void _onFieldChanged(String v) {
    final parsed = num.tryParse(v) ?? 0;
    setState(() => _amount = _signedFor(_reason, parsed.abs()));
  }

  String _trim(num n) =>
      n == n.roundToDouble() ? n.toInt().toString() : n.toString();

  String get _helperText {
    if (_isRestock) return 'Restocking only adds to stock.';
    if (_isConsumption) return 'Consumption only removes from stock.';
    return 'Corrections can increase or decrease stock.';
  }

  @override
  Widget build(BuildContext context) {
    final units = inputUnitsFor(widget.material.unit);
    num projected = widget.material.qty;
    try {
      projected += convertToBase(widget.material.unit, _amount, _unit);
    } catch (_) {}

    return _SheetShell(
      title: 'Adjust — ${widget.material.name}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Current: ${formatQty(widget.material.unit, widget.material.qty)}  →  '
            'New: ${formatQty(widget.material.unit, projected)}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 14),
          if (units.length > 1) ...[
            Text('Unit', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: units
                  .map(
                    (u) => ChoiceChip(
                      label: Text(u),
                      selected: _unit == u,
                      onSelected: (_) => _onUnitSelected(u),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 14),
          ],
          Row(
            children: [
              _isRestock
                  ? const _LockedDirectionIcon(
                      icon: Icons.remove_circle_outline,
                      color: Color(0xFFC62828),
                      tooltip: 'Not available for restock',
                    )
                  : IconButton.filledTonal(
                      onPressed: () => _bump(-_step),
                      icon: const Icon(Icons.remove),
                    ),
              Expanded(
                child: TextField(
                  controller: _amountCtrl,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.numberWithOptions(
                    decimal: true,
                    signed: _reason == 'correction',
                  ),
                  onChanged: _onFieldChanged,
                  decoration: InputDecoration(labelText: 'Change ($_unit)'),
                ),
              ),
              _isConsumption
                  ? const _LockedDirectionIcon(
                      icon: Icons.add_circle_outline,
                      color: Color(0xFF2E7D32),
                      tooltip: 'Not available for consumption',
                    )
                  : IconButton.filledTonal(
                      onPressed: () => _bump(_step),
                      icon: const Icon(Icons.add),
                    ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _helperText,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          Text('Reason', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: rawMaterialAdjustReasons
                .map(
                  (r) => ChoiceChip(
                    label: Text(r),
                    selected: _reason == r,
                    onSelected: (_) => _onReasonSelected(r),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _noteCtrl,
            decoration: const InputDecoration(labelText: 'Note (optional)'),
          ),
          const SizedBox(height: 22),
          FilledButton(
            onPressed: _amount == 0
                ? null
                : () => Navigator.pop(
                    context,
                    _AdjustInput(
                      _amount,
                      _unit,
                      _reason,
                      _noteCtrl.text.trim(),
                    ),
                  ),
            child: const Text('Submit for Approval'),
          ),
        ],
      ),
    );
  }
}
