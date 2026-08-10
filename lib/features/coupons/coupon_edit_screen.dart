import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'coupons_api.dart';
import 'coupons_provider.dart';
import '../themes/themes_provider.dart';
import '../../core/auth/user_role.dart';
import '../../core/network/api_client_provider.dart';
import '../../core/network/api_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/haptics.dart';
import '../../shared/widgets/success_pulse.dart';
import '../../shared/widgets/swipe_confirm_sheet.dart';

/// Create/edit a coupon. Role decides what happens on submit, exactly the
/// same convention as ProductEditScreen:
///  - admin   → PATCH/POST straight to /api/admin/coupons, live immediately.
///  - manager → POST to /api/coupon-core/request, held for an admin to
///              approve/reject on the Approvals screen.
class CouponEditScreen extends ConsumerStatefulWidget {
  final Coupon? coupon; // null = creating a new coupon
  const CouponEditScreen({super.key, required this.coupon});

  @override
  ConsumerState<CouponEditScreen> createState() => _CouponEditScreenState();
}

class _CouponEditScreenState extends ConsumerState<CouponEditScreen> {
  late final TextEditingController _codeCtrl, _descCtrl;
  late final TextEditingController _valueCtrl, _maxDiscountCtrl;
  late final TextEditingController _minSubtotalCtrl,
      _usageLimitCtrl,
      _perUserLimitCtrl;
  late final TextEditingController _startsAtCtrl, _endsAtCtrl;
  late String _type;
  late bool _isActive;
  int? _themeId;
  bool _submitting = false, _deleting = false;

  bool get _isNew => widget.coupon == null;

  @override
  void initState() {
    super.initState();
    final c = widget.coupon;
    _codeCtrl = TextEditingController(text: c?.code ?? '');
    _descCtrl = TextEditingController(text: c?.description ?? '');
    _valueCtrl = TextEditingController(text: c?.value.round().toString() ?? '');
    _maxDiscountCtrl = TextEditingController(
      text: c?.maxDiscountAmount?.toString() ?? '',
    );
    _minSubtotalCtrl = TextEditingController(
      text: (c?.minSubtotal ?? 0) == 0 ? '' : c!.minSubtotal.toString(),
    );
    _usageLimitCtrl = TextEditingController(
      text: c?.usageLimit?.toString() ?? '',
    );
    _perUserLimitCtrl = TextEditingController(
      text: (c?.perUserLimit ?? 1).toString(),
    );
    _startsAtCtrl = TextEditingController(
      text: (c?.startsAt ?? '').split('T').first,
    );
    _endsAtCtrl = TextEditingController(text: (c?.endsAt ?? '').split('T').first);
    _type = c?.type ?? 'percent';
    _isActive = c?.isActive ?? true;
    _themeId = c?.themeId;
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _descCtrl.dispose();
    _valueCtrl.dispose();
    _maxDiscountCtrl.dispose();
    _minSubtotalCtrl.dispose();
    _usageLimitCtrl.dispose();
    _perUserLimitCtrl.dispose();
    _startsAtCtrl.dispose();
    _endsAtCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate(TextEditingController ctrl) async {
    final initial = DateTime.tryParse(ctrl.text) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      ctrl.text = picked.toIso8601String().substring(0, 10);
      setState(() {});
    }
  }

  String? _validate() {
    if (_codeCtrl.text.trim().isEmpty) return 'Code is required';
    if (!RegExp(r'^[A-Za-z0-9_-]{3,32}$').hasMatch(_codeCtrl.text.trim())) {
      return 'Code must be 3-32 characters: letters, numbers, hyphens, underscores';
    }
    final value = int.tryParse(_valueCtrl.text.trim());
    if (value == null || value <= 0) return 'Value must be a positive whole number';
    if (_type == 'percent' && value > 90) return 'Percent value cannot exceed 90';
    return null;
  }

  Map<String, dynamic> _buildPayload() {
    final maxDiscount = int.tryParse(_maxDiscountCtrl.text.trim());
    final minSubtotal = int.tryParse(_minSubtotalCtrl.text.trim()) ?? 0;
    final usageLimit = int.tryParse(_usageLimitCtrl.text.trim());
    final perUserLimit = int.tryParse(_perUserLimitCtrl.text.trim()) ?? 1;

    return {
      'code': _codeCtrl.text.trim().toUpperCase(),
      'description': _descCtrl.text.trim().isEmpty
          ? null
          : _descCtrl.text.trim(),
      'type': _type,
      'value': int.tryParse(_valueCtrl.text.trim()),
      if (_type == 'percent' && maxDiscount != null)
        'maxDiscountAmount': maxDiscount,
      'minSubtotal': minSubtotal,
      'usageLimit': usageLimit,
      'perUserLimit': perUserLimit,
      'isActive': _isActive,
      'themeId': _themeId,
      'startsAt': _startsAtCtrl.text.trim().isEmpty
          ? null
          : _startsAtCtrl.text.trim(),
      'endsAt': _endsAtCtrl.text.trim().isEmpty
          ? null
          : _endsAtCtrl.text.trim(),
    };
  }

  Future<void> _submit(bool isAdmin) async {
    final error = _validate();
    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    final saveColor = isAdmin ? const Color(0xFF2E7D32) : AppColors.turmeric;
    final confirmed = await SwipeConfirmSheet.show(
      context,
      icon: _isNew
          ? (isAdmin ? Icons.add_circle_outline : Icons.send_outlined)
          : (isAdmin ? Icons.publish_outlined : Icons.send_outlined),
      color: saveColor,
      message: Text.rich(
        TextSpan(
          style: Theme.of(context).textTheme.bodyMedium,
          children: [
            TextSpan(
              text: _isNew
                  ? (isAdmin ? 'Create coupon ' : 'Propose coupon ')
                  : (isAdmin ? 'Save changes to ' : 'Propose changes to '),
            ),
            TextSpan(
              text: _codeCtrl.text.trim().toUpperCase(),
              style: TextStyle(fontWeight: FontWeight.w700, color: saveColor),
            ),
            TextSpan(
              text: isAdmin
                  ? '? This goes live immediately.'
                  : ' for admin approval? Nothing goes live until it\'s approved.',
            ),
          ],
        ),
      ),
      swipeLabel: isAdmin ? 'Slide to save' : 'Slide to submit',
    );
    if (!confirmed) return;

    setState(() => _submitting = true);
    try {
      final api = ref.read(couponsApiProvider);
      final payload = _buildPayload();
      if (isAdmin) {
        if (_isNew) {
          await api.createDirect(payload);
        } else {
          await api.updateDirect(widget.coupon!.id, payload);
        }
      } else {
        if (_isNew) {
          await api.requestCreate(payload);
        } else {
          await api.requestUpdate(widget.coupon!.id, payload);
        }
      }
      ref.invalidate(couponsProvider);
      Haptics.success();
      if (mounted) {
        await SuccessPulse.show(
          context,
          isAdmin
              ? (_isNew ? 'Coupon created' : 'Coupon saved')
              : 'Submitted — awaiting admin approval',
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
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _delete() async {
    final coupon = widget.coupon;
    if (coupon == null) return;
    final confirmed = await SwipeConfirmSheet.show(
      context,
      icon: Icons.delete_outline,
      color: Theme.of(context).colorScheme.error,
      message: Text(
        coupon.usedCount > 0
            ? 'This coupon has been redeemed ${coupon.usedCount} time(s) and can\'t be deleted — deactivate it instead.'
            : 'Delete "${coupon.code}" permanently? This can\'t be undone.',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      swipeLabel: 'Slide to delete',
    );
    if (!confirmed) return;

    setState(() => _deleting = true);
    try {
      await ref.read(couponsApiProvider).deleteDirect(coupon.id);
      ref.invalidate(couponsProvider);
      Haptics.success();
      if (mounted) {
        await SuccessPulse.show(
          context,
          'Coupon deleted',
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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final role = ref.watch(authControllerProvider).role;
    final isAdmin = role == UserRole.admin;
    final themesAsync = ref.watch(themesProvider);
    final busy = _submitting || _deleting;

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      appBar: AppBar(
        title: Text(
          _isNew ? 'New Coupon' : widget.coupon!.code,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (!_isNew && isAdmin)
            IconButton(
              icon: _deleting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.delete_outline),
              onPressed: busy ? null : _delete,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          if (!isAdmin)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.primaryContainer.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 18,
                    color: scheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Changes you save here are sent to an admin for approval before they go live.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          _SectionCard(
            icon: Icons.sell_outlined,
            title: 'Code & Description',
            children: [
              _Field(
                controller: _codeCtrl,
                label: 'Coupon code',
                helper: 'Letters, numbers, hyphens, underscores',
                textCapitalization: TextCapitalization.characters,
              ),
              const SizedBox(height: 12),
              _Field(
                controller: _descCtrl,
                label: 'Description (optional, internal)',
                maxLines: 2,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SectionCard(
            icon: Icons.discount_outlined,
            title: 'Discount',
            children: [
              Text('Type', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: couponTypes
                    .map(
                      (t) => ChoiceChip(
                        label: Text(t == 'percent' ? 'Percent off' : 'Flat amount'),
                        selected: _type == t,
                        onSelected: (_) => setState(() => _type = t),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _Field(
                      controller: _valueCtrl,
                      label: _type == 'percent'
                          ? 'Percent off (1-90)'
                          : 'Flat amount off (₹)',
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  if (_type == 'percent') ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: _Field(
                        controller: _maxDiscountCtrl,
                        label: 'Max discount (₹, optional)',
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              _Field(
                controller: _minSubtotalCtrl,
                label: 'Minimum order subtotal (₹, optional)',
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SectionCard(
            icon: Icons.rule_outlined,
            title: 'Usage Limits',
            children: [
              Row(
                children: [
                  Expanded(
                    child: _Field(
                      controller: _usageLimitCtrl,
                      label: 'Total uses allowed (optional)',
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _Field(
                      controller: _perUserLimitCtrl,
                      label: 'Uses per customer',
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              if (!_isNew) ...[
                const SizedBox(height: 10),
                Text(
                  '${widget.coupon!.usedCount} use${widget.coupon!.usedCount == 1 ? '' : 's'} so far',
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          _SectionCard(
            icon: Icons.visibility_outlined,
            title: 'Status & Theme',
            children: [
              _ToggleRow(
                icon: Icons.toggle_on_outlined,
                color: const Color(0xFF2E7D32),
                title: 'Active',
                subtitle: 'Customers can redeem this code',
                value: _isActive,
                onChanged: (v) => setState(() => _isActive = v),
              ),
              const SizedBox(height: 12),
              themesAsync.maybeWhen(
                data: (themes) => DropdownButtonFormField<int?>(
                  initialValue: _themeId,
                  decoration: const InputDecoration(
                    labelText: 'Linked theme (optional)',
                  ),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('Not linked to a theme'),
                    ),
                    for (final t in themes)
                      DropdownMenuItem<int?>(value: t.id, child: Text(t.name)),
                  ],
                  onChanged: (v) => setState(() => _themeId = v),
                ),
                orElse: () => const SizedBox.shrink(),
              ),
              if (_themeId != null) ...[
                const SizedBox(height: 6),
                Text(
                  'Linked coupons turn on/off automatically when their theme is activated or deactivated.',
                  style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          _SectionCard(
            icon: Icons.schedule_outlined,
            title: 'Schedule',
            subtitle: 'Optional',
            children: [
              Row(
                children: [
                  Expanded(
                    child: _DateField(
                      controller: _startsAtCtrl,
                      label: 'Starts',
                      onTap: () => _pickDate(_startsAtCtrl),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _DateField(
                      controller: _endsAtCtrl,
                      label: 'Ends',
                      onTap: () => _pickDate(_endsAtCtrl),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: FilledButton.icon(
            onPressed: busy ? null : () => _submit(isAdmin),
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
                : Icon(isAdmin ? Icons.check : Icons.send),
            label: Text(
              _submitting
                  ? 'Saving…'
                  : (isAdmin
                        ? (_isNew ? 'Create Coupon' : 'Save Changes')
                        : 'Submit for Approval'),
            ),
          ),
        ),
      ),
    );
  }
}

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
                Text(
                  subtitle!,
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
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
  final int maxLines;
  final String? helper;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  const _Field({
    required this.controller,
    required this.label,
    this.maxLines = 1,
    this.helper,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      decoration: InputDecoration(labelText: label, helperText: helper),
    );
  }
}

class _DateField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final VoidCallback onTap;
  const _DateField({
    required this.controller,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      readOnly: true,
      onTap: onTap,
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
      ),
    );
  }
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
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant),
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
