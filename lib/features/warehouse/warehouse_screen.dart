import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'raw_materials_api.dart';
import 'raw_materials_provider.dart';
import '../../core/auth/user_role.dart';
import '../../core/network/api_client_provider.dart';
import '../../core/network/api_exception.dart';

class WarehouseScreen extends ConsumerWidget {
  const WarehouseScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final materialsAsync = ref.watch(rawMaterialsProvider);
    final role = ref.watch(authControllerProvider).role;
    final canManage = role == UserRole.warehouser;

    return Scaffold(
      appBar: AppBar(title: const Text('Raw Materials')),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              onPressed: () => _addMaterial(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Add Material'),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(rawMaterialsProvider),
        child: materialsAsync.when(
          data: (materials) {
            if (materials.isEmpty) {
              return const Center(child: Text('No raw materials yet.'));
            }
            return ListView.separated(
              itemCount: materials.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) =>
                  _MaterialTile(material: materials[i], canManage: canManage),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) =>
              Center(child: Text('Could not load raw materials: $e')),
        ),
      ),
    );
  }

  Future<void> _addMaterial(BuildContext context, WidgetRef ref) async {
    final result = await showDialog<_NewMaterialInput>(
      context: context,
      builder: (_) => const _AddMaterialDialog(),
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
      ref.invalidate(rawMaterialsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${result.name} added')));
      }
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }
}

class _MaterialTile extends ConsumerStatefulWidget {
  final RawMaterial material;
  final bool canManage;
  const _MaterialTile({required this.material, required this.canManage});

  @override
  ConsumerState<_MaterialTile> createState() => _MaterialTileState();
}

class _MaterialTileState extends ConsumerState<_MaterialTile> {
  bool _busy = false;

  Future<void> _openAdjustDialog() async {
    final result = await showDialog<_AdjustInput>(
      context: context,
      builder: (_) => _AdjustDialog(material: widget.material),
    );
    if (result == null) return;

    setState(() => _busy = true);
    try {
      await ref
          .read(rawMaterialsApiProvider)
          .submitAdjustment(
            rawMaterialId: widget.material.id,
            delta: result.delta,
            reason: result.reason,
            note: result.note,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Adjustment submitted — pending approval'),
          ),
        );
      }
    } on ApiException catch (e) {
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
    return ListTile(
      title: Text(m.name),
      subtitle: Text(
        m.isLow
            ? 'Low stock — threshold ${m.lowStockThreshold}'
            : 'Unit: ${m.unit}',
        style: m.isLow
            ? TextStyle(color: Theme.of(context).colorScheme.error)
            : null,
      ),
      trailing: _busy
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${m.qty} ${m.unit}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                if (widget.canManage) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.tune),
                    tooltip: 'Request adjustment',
                    onPressed: _openAdjustDialog,
                  ),
                ],
              ],
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

class _AddMaterialDialog extends StatefulWidget {
  const _AddMaterialDialog();
  @override
  State<_AddMaterialDialog> createState() => _AddMaterialDialogState();
}

class _AddMaterialDialogState extends State<_AddMaterialDialog> {
  final _nameCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController(text: '0');
  final _thresholdCtrl = TextEditingController();
  String _unit = rawMaterialUnits.first;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Raw Material'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _unit,
            decoration: const InputDecoration(labelText: 'Unit'),
            items: rawMaterialUnits
                .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                .toList(),
            onChanged: (u) => setState(() => _unit = u!),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _qtyCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Starting quantity'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _thresholdCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Low stock threshold (optional)',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final name = _nameCtrl.text.trim();
            if (name.isEmpty) return;
            final qty = num.tryParse(_qtyCtrl.text.trim()) ?? 0;
            final threshold = num.tryParse(_thresholdCtrl.text.trim());
            Navigator.pop(
              context,
              _NewMaterialInput(name, _unit, qty, threshold),
            );
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}

class _AdjustInput {
  final num delta;
  final String reason;
  final String? note;
  _AdjustInput(this.delta, this.reason, this.note);
}

class _AdjustDialog extends StatefulWidget {
  final RawMaterial material;
  const _AdjustDialog({required this.material});
  @override
  State<_AdjustDialog> createState() => _AdjustDialogState();
}

class _AdjustDialogState extends State<_AdjustDialog> {
  final _deltaCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  String _reason = rawMaterialAdjustReasons.first;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Adjust — ${widget.material.name}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _deltaCtrl,
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
              signed: true,
            ),
            decoration: InputDecoration(
              labelText: 'Change (+ to add, - to remove)',
              helperText:
                  'Current: ${widget.material.qty} ${widget.material.unit}',
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _reason,
            decoration: const InputDecoration(labelText: 'Reason'),
            items: rawMaterialAdjustReasons
                .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                .toList(),
            onChanged: (r) => setState(() => _reason = r!),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _noteCtrl,
            decoration: const InputDecoration(labelText: 'Note (optional)'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final delta = num.tryParse(_deltaCtrl.text.trim());
            if (delta == null || delta == 0) return;
            Navigator.pop(
              context,
              _AdjustInput(delta, _reason, _noteCtrl.text.trim()),
            );
          },
          child: const Text('Submit'),
        ),
      ],
    );
  }
}
