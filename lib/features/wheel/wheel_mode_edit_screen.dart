// lib/features/wheel/wheel_mode_edit_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'wheel_api.dart';
import 'wheel_provider.dart';
import '../themes/themes_screen.dart' show parseHexColor;
import '../../core/network/api_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/haptics.dart';
import '../../shared/widgets/success_pulse.dart';
import '../../shared/widgets/swipe_confirm_sheet.dart';

/// Create/edit a wheel mode, and (once it exists) manage its wedges inline.
/// admin + manager both write directly here — the backend's wheel endpoints
/// (modes.js / items.js) require only ['admin','manager'], with no approval
/// queue involved, so there's nothing to hold for review.
class WheelModeEditScreen extends ConsumerStatefulWidget {
  final WheelMode? mode; // null = creating a new mode
  const WheelModeEditScreen({super.key, required this.mode});

  @override
  ConsumerState<WheelModeEditScreen> createState() =>
      _WheelModeEditScreenState();
}

class _WheelModeEditScreenState extends ConsumerState<WheelModeEditScreen> {
  late final TextEditingController _keyCtrl,
      _centerLabelCtrl,
      _hoverCtrl,
      _glyphCtrl,
      _hubHrefCtrl,
      _sortOrderCtrl;
  late bool _isActive;
  bool _submitting = false, _deleting = false;
  List<WheelItem> _items = [];
  bool _itemsLoaded = false;

  bool get _isNew => widget.mode == null;

  @override
  void initState() {
    super.initState();
    final m = widget.mode;
    _keyCtrl = TextEditingController(text: m?.key ?? '');
    _centerLabelCtrl = TextEditingController(text: m?.centerLabel ?? '')
      ..addListener(() => setState(() {}));
    _hoverCtrl = TextEditingController(text: m?.centerLabelHover ?? '');
    _glyphCtrl = TextEditingController(text: m?.centerGlyph ?? '✦')
      ..addListener(() => setState(() {}));
    _hubHrefCtrl = TextEditingController(text: m?.hubHref ?? '');
    _sortOrderCtrl = TextEditingController(
      text: m != null ? '${m.sortOrder}' : '',
    );
    _isActive = m?.isActive ?? true;
    if (!_isNew) _loadItems();
  }

  Future<void> _loadItems() async {
    try {
      final items = await ref
          .read(wheelApiProvider)
          .fetchItems(widget.mode!.id);
      items.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      if (mounted) {
        setState(() {
          _items = items;
          _itemsLoaded = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _itemsLoaded = true);
    }
  }

  @override
  void dispose() {
    _keyCtrl.dispose();
    _centerLabelCtrl.dispose();
    _hoverCtrl.dispose();
    _glyphCtrl.dispose();
    _hubHrefCtrl.dispose();
    _sortOrderCtrl.dispose();
    super.dispose();
  }

  Map<String, dynamic> _buildBody() {
    final sortOrder = int.tryParse(_sortOrderCtrl.text.trim());
    return {
      'centerLabel': _centerLabelCtrl.text.trim(),
      if (_keyCtrl.text.trim().isNotEmpty) 'key': _keyCtrl.text.trim(),
      'centerLabelHover': _hoverCtrl.text.trim().isEmpty
          ? null
          : _hoverCtrl.text.trim(),
      'centerGlyph': _glyphCtrl.text.trim().isEmpty
          ? '✦'
          : _glyphCtrl.text.trim(),
      'hubHref': _hubHrefCtrl.text.trim().isEmpty
          ? null
          : _hubHrefCtrl.text.trim(),
      'sortOrder': ?sortOrder,
      'isActive': _isActive,
    };
  }

  Future<void> _submit() async {
    if (_centerLabelCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Center label is required')));
      return;
    }
    final confirmed = await SwipeConfirmSheet.show(
      context,
      icon: _isNew ? Icons.add_circle_outline : Icons.save_outlined,
      color: AppColors.turmeric,
      message: Text.rich(
        TextSpan(
          style: Theme.of(context).textTheme.bodyMedium,
          children: [
            TextSpan(text: _isNew ? 'Create wheel mode ' : 'Save changes to '),
            TextSpan(
              text: _centerLabelCtrl.text.trim().replaceAll('|', ' '),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const TextSpan(
              text: '? This appears on the live homepage wheel immediately.',
            ),
          ],
        ),
      ),
      swipeLabel: _isNew ? 'Slide to create' : 'Slide to save',
    );
    if (!confirmed) return;

    setState(() => _submitting = true);
    try {
      final api = ref.read(wheelApiProvider);
      final saved = _isNew
          ? await api.createMode(_buildBody())
          : await api.updateMode(widget.mode!.id, _buildBody());
      ref.invalidate(wheelModesProvider);
      Haptics.success();
      if (mounted) {
        await SuccessPulse.show(
          context,
          _isNew ? 'Wheel mode created' : 'Wheel mode saved',
        );
      }
      if (!mounted) return;
      if (_isNew) {
        // Drop straight into the new mode's editor so wedges can be added
        // right away instead of a round-trip back through the list.
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => WheelModeEditScreen(mode: saved)),
        );
      } else {
        Navigator.of(context).pop();
      }
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

  Future<void> _delete() async {
    if (_isNew) return;
    final confirmed = await SwipeConfirmSheet.show(
      context,
      icon: Icons.delete_outline,
      color: Theme.of(context).colorScheme.error,
      message: Text(
        'Delete "${widget.mode!.displayLabel}" and all ${_items.length} of its wedges permanently? '
        'This can\'t be undone.',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      swipeLabel: 'Slide to delete',
    );
    if (!confirmed) return;

    setState(() => _deleting = true);
    try {
      await ref.read(wheelApiProvider).deleteMode(widget.mode!.id);
      ref.invalidate(wheelModesProvider);
      Haptics.success();
      if (mounted) {
        await SuccessPulse.show(
          context,
          'Wheel mode deleted',
          icon: Icons.delete_outline,
          accentColor: Theme.of(context).colorScheme.error,
        );
      }
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      Haptics.warning();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  Future<void> _openWedgeSheet({WheelItem? item}) async {
    final result = await showModalBottomSheet<_WedgeInput>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _WedgeEditSheet(item: item),
    );
    if (result == null) return;

    try {
      if (item == null) {
        await ref.read(wheelApiProvider).createItem({
          'modeId': widget.mode!.id,
          'label': result.label,
          'href': result.href,
          if (result.color != null) 'color': result.color,
        });
      } else {
        await ref.read(wheelApiProvider).updateItem(item.id, {
          'label': result.label,
          'href': result.href,
          'color': result.color,
        });
      }
      Haptics.success();
      ref.invalidate(wheelItemsProvider(widget.mode!.id));
      await _loadItems();
      if (mounted) {
        await SuccessPulse.show(
          context,
          item == null ? 'Wedge added' : 'Wedge updated',
        );
      }
    } on ApiException catch (e) {
      Haptics.warning();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _deleteWedge(WheelItem item) async {
    final confirmed = await SwipeConfirmSheet.show(
      context,
      icon: Icons.delete_outline,
      color: Theme.of(context).colorScheme.error,
      message: Text(
        'Remove the "${item.label}" wedge?',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      swipeLabel: 'Slide to remove',
    );
    if (!confirmed) return;
    try {
      await ref.read(wheelApiProvider).deleteItem(item.id);
      Haptics.success();
      ref.invalidate(wheelItemsProvider(widget.mode!.id));
      await _loadItems();
      if (mounted) {
        await SuccessPulse.show(
          context,
          'Wedge removed',
          icon: Icons.delete_outline,
          accentColor: Theme.of(context).colorScheme.error,
        );
      }
    } on ApiException catch (e) {
      Haptics.warning();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      appBar: AppBar(
        title: Text(
          _isNew ? 'New Wheel Mode' : widget.mode!.displayLabel,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (!_isNew)
            IconButton(
              icon: _deleting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.delete_outline),
              onPressed: _deleting ? null : _delete,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          _WheelPreviewCard(
            glyph: _glyphCtrl.text.trim().isEmpty
                ? '✦'
                : _glyphCtrl.text.trim(),
            label: _centerLabelCtrl.text.trim().isEmpty
                ? 'Preview'
                : _centerLabelCtrl.text.trim().replaceAll('|', '\n'),
            items: _items,
          ),
          const SizedBox(height: 16),
          _SectionCard(
            icon: Icons.badge_outlined,
            title: 'Basics',
            children: [
              _Field(
                controller: _centerLabelCtrl,
                label: 'Center label',
                helper: 'Use | for a line break, e.g. MOM|MASALE',
              ),
              const SizedBox(height: 12),
              _Field(controller: _hoverCtrl, label: 'Hover label (optional)'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: _Field(controller: _glyphCtrl, label: 'Glyph'),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: _Field(
                      controller: _keyCtrl,
                      label: 'Key (optional — auto)',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _Field(controller: _hubHrefCtrl, label: 'Hub link (optional)'),
              const SizedBox(height: 12),
              _Field(
                controller: _sortOrderCtrl,
                label: 'Sort order (optional)',
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 14),
              _ToggleRow(
                icon: Icons.play_circle_outline,
                color: const Color(0xFF2E7D32),
                title: 'Active in tap-cycle',
                subtitle: 'Visible on the live homepage wheel',
                value: _isActive,
                onChanged: (v) => setState(() => _isActive = v),
              ),
            ],
          ),
          if (!_isNew) ...[
            const SizedBox(height: 16),
            _SectionCard(
              icon: Icons.pie_chart_outline,
              title: 'Wedges',
              subtitle: _itemsLoaded ? '${_items.length}' : null,
              children: [
                if (!_itemsLoaded)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Center(
                      child: SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                else if (_items.isEmpty)
                  Text(
                    'No wedges yet — add the first one below.',
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  )
                else
                  ..._items.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _WedgeRow(
                        item: item,
                        onTap: () => _openWedgeSheet(item: item),
                        onDelete: () => _deleteWedge(item),
                      ),
                    ),
                  ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => _openWedgeSheet(),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Wedge'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: FilledButton.icon(
            onPressed: _submitting ? null : _submit,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            icon: _submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(_isNew ? Icons.add : Icons.check),
            label: Text(
              _submitting
                  ? 'Saving…'
                  : (_isNew ? 'Create Mode' : 'Save Changes'),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Live preview ─────────────────────────────────────────────────────────

class _WheelPreviewCard extends StatelessWidget {
  final String glyph, label;
  final List<WheelItem> items;
  const _WheelPreviewCard({
    required this.glyph,
    required this.label,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.maroon.withValues(alpha: 0.10),
            AppColors.turmeric.withValues(alpha: 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          SizedBox(
            width: 160,
            height: 160,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size(160, 160),
                  painter: _WheelPreviewPainter(
                    items: items,
                    centerColor: AppColors.maroon,
                  ),
                ),
                Container(
                  width: 66,
                  height: 66,
                  decoration: BoxDecoration(
                    color: AppColors.maroon,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.turmeric, width: 2),
                  ),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.all(4),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        glyph,
                        style: const TextStyle(
                          fontSize: 16,
                          color: AppColors.parchment,
                        ),
                      ),
                      Text(
                        label,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                          color: AppColors.parchment,
                          height: 1.1,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            items.isEmpty
                ? 'Live wheel preview — add wedges to see them here'
                : 'Live preview · ${items.length} wedge${items.length == 1 ? '' : 's'}',
            style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _WheelPreviewPainter extends CustomPainter {
  final List<WheelItem> items;
  final Color centerColor;
  _WheelPreviewPainter({required this.items, required this.centerColor});

  static const _fallbackColors = [
    AppColors.maroon,
    AppColors.turmeric,
    AppColors.paprika,
    AppColors.cumin,
    Color(0xFF3D6B57),
    Color(0xFF7A5C9E),
    Color(0xFFC98A1F),
    Color(0xFF5A6B7A),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2;
    if (items.isEmpty) {
      canvas.drawCircle(
        center,
        radius,
        Paint()..color = centerColor.withValues(alpha: 0.12),
      );
      return;
    }
    final sweep = (2 * 3.14159265358979) / items.length;
    var start = -3.14159265358979 / 2;
    for (var i = 0; i < items.length; i++) {
      final color =
          parseHexColor(items[i].color) ??
          _fallbackColors[i % _fallbackColors.length];
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        sweep,
        true,
        Paint()..color = color.withValues(alpha: 0.88),
      );
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        sweep,
        true,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.7)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _WheelPreviewPainter oldDelegate) => true;
}

// ── Shared section/field widgets ────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final List<Widget> children;
  const _SectionCard({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: AppColors.maroon.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 16, color: AppColors.maroon),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (subtitle != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.turmeric.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    subtitle!,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.maroon,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? helper;
  final TextInputType? keyboardType;
  const _Field({
    required this.controller,
    required this.label,
    this.helper,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    keyboardType: keyboardType,
    decoration: InputDecoration(labelText: label, helperText: helper),
  );
}

class _ToggleRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _ToggleRow({
    required this.icon,
    required this.color,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: value
            ? color.withValues(alpha: 0.06)
            : scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: value
              ? color.withValues(alpha: 0.3)
              : scheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

// ── Wedge row + edit sheet ──────────────────────────────────────────────

class _WedgeRow extends StatelessWidget {
  final WheelItem item;
  final VoidCallback onTap, onDelete;
  const _WedgeRow({
    required this.item,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = parseHexColor(item.color) ?? AppColors.cumin;
    return Material(
      color: scheme.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.label,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      item.href,
                      style: TextStyle(
                        fontSize: 11,
                        color: scheme.onSurfaceVariant,
                        fontFamily: 'IBMPlexMono',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.delete_outline, size: 20, color: scheme.error),
                onPressed: onDelete,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WedgeInput {
  final String label, href;
  final String? color;
  _WedgeInput(this.label, this.href, this.color);
}

class _WedgeEditSheet extends StatefulWidget {
  final WheelItem? item;
  const _WedgeEditSheet({this.item});

  @override
  State<_WedgeEditSheet> createState() => _WedgeEditSheetState();
}

class _WedgeEditSheetState extends State<_WedgeEditSheet> {
  late final TextEditingController _labelCtrl, _hrefCtrl, _colorCtrl;

  @override
  void initState() {
    super.initState();
    final i = widget.item;
    _labelCtrl = TextEditingController(text: i?.label ?? '');
    _hrefCtrl = TextEditingController(text: i?.href ?? '');
    _colorCtrl = TextEditingController(
      text: (i?.color ?? '').replaceFirst('#', ''),
    )..addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    _hrefCtrl.dispose();
    _colorCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final label = _labelCtrl.text.trim();
    final href = _hrefCtrl.text.trim();
    if (label.isEmpty || href.isEmpty) return;
    final colorText = _colorCtrl.text.trim();
    final color = colorText.isEmpty
        ? null
        : (colorText.startsWith('#') ? colorText : '#$colorText');
    Navigator.pop(context, _WedgeInput(label, href, color));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final normalized = _colorCtrl.text.startsWith('#')
        ? _colorCtrl.text
        : '#${_colorCtrl.text}';
    final swatch = parseHexColor(normalized);
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
              Text(
                widget.item == null ? 'Add Wedge' : 'Edit Wedge',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _labelCtrl,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Label'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _hrefCtrl,
                decoration: const InputDecoration(
                  labelText: 'Link (site-relative)',
                  hintText: 'products/turmeric-powder',
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: swatch ?? scheme.surfaceContainerHighest,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.black.withValues(alpha: 0.12),
                      ),
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _colorCtrl,
                      style: const TextStyle(fontFamily: 'IBMPlexMono'),
                      decoration: const InputDecoration(
                        labelText: 'Color hex (optional)',
                        hintText: 'e.g. C1502E',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              FilledButton(
                onPressed: _submit,
                child: Text(widget.item == null ? 'Add Wedge' : 'Save Wedge'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
