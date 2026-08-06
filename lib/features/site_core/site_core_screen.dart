// lib/features/site_core/site_core_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'site_core_api.dart';
import 'site_core_provider.dart';
import '../../core/network/api_exception.dart';
import '../../core/constants/layout_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/haptics.dart';
import '../../shared/widgets/success_pulse.dart';
import '../../shared/widgets/swipe_confirm_sheet.dart';

/// Edits data/settings.json's `commerce` block (shipping/pricing rules)
/// plus any string-valued fields under `business`. Admin-only backend,
/// direct GitHub commit — changes apply to new orders immediately.
class SiteCoreScreen extends ConsumerStatefulWidget {
  const SiteCoreScreen({super.key});
  @override
  ConsumerState<SiteCoreScreen> createState() => _SiteCoreScreenState();
}

class _SiteCoreScreenState extends ConsumerState<SiteCoreScreen> {
  bool _loaded = false;
  bool _saving = false;

  final _discountCtrl = TextEditingController();
  final _freeShipCtrl = TextEditingController();
  final _smallThresholdCtrl = TextEditingController();
  final _smallFeeCtrl = TextEditingController();
  final _localPrefixesCtrl = TextEditingController();
  final _localFeeCtrl = TextEditingController();
  final _upLoCtrl = TextEditingController();
  final _upHiCtrl = TextEditingController();
  final _upFeeCtrl = TextEditingController();
  final _nationalFeeCtrl = TextEditingController();
  final Map<String, TextEditingController> _businessCtrls = {};

  void _loadInto(SiteSettings s) {
    if (_loaded) return;
    _loaded = true;
    final commerce = s.commerce;
    _discountCtrl.text = '${commerce['discountPercent'] ?? 0}';
    _freeShipCtrl.text = '${commerce['freeShippingThreshold'] ?? 0}';
    _smallThresholdCtrl.text = '${commerce['smallOrderThreshold'] ?? 0}';
    _smallFeeCtrl.text = '${commerce['smallOrderFee'] ?? 0}';
    final zones = Map<String, dynamic>.from(commerce['shippingZones'] ?? {});
    final local = Map<String, dynamic>.from(zones['local'] ?? {});
    final up = Map<String, dynamic>.from(zones['up'] ?? {});
    final national = Map<String, dynamic>.from(zones['national'] ?? {});
    _localPrefixesCtrl.text = List<String>.from(
      local['prefixes'] ?? [],
    ).join(', ');
    _localFeeCtrl.text = '${local['fee'] ?? 0}';
    final range = List<dynamic>.from(up['prefixRange'] ?? [0, 0]);
    _upLoCtrl.text = '${range.isNotEmpty ? range[0] : 0}';
    _upHiCtrl.text = '${range.length > 1 ? range[1] : 0}';
    _upFeeCtrl.text = '${up['fee'] ?? 0}';
    _nationalFeeCtrl.text = '${national['fee'] ?? 0}';

    for (final entry in s.business.entries) {
      if (entry.value is String) {
        _businessCtrls[entry.key] = TextEditingController(
          text: entry.value as String,
        );
      }
    }
  }

  @override
  void dispose() {
    _discountCtrl.dispose();
    _freeShipCtrl.dispose();
    _smallThresholdCtrl.dispose();
    _smallFeeCtrl.dispose();
    _localPrefixesCtrl.dispose();
    _localFeeCtrl.dispose();
    _upLoCtrl.dispose();
    _upHiCtrl.dispose();
    _upFeeCtrl.dispose();
    _nationalFeeCtrl.dispose();
    for (final c in _businessCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final confirmed = await SwipeConfirmSheet.show(
      context,
      icon: Icons.tune_outlined,
      color: AppColors.maroon,
      message: Text(
        'Save these site settings? Shipping fees and pricing rules apply to new orders immediately.',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      swipeLabel: 'Slide to save',
    );
    if (!confirmed) return;

    setState(() => _saving = true);
    try {
      final commerce = {
        'discountPercent': num.tryParse(_discountCtrl.text.trim()) ?? 0,
        'freeShippingThreshold': int.tryParse(_freeShipCtrl.text.trim()) ?? 0,
        'smallOrderThreshold':
            int.tryParse(_smallThresholdCtrl.text.trim()) ?? 0,
        'smallOrderFee': int.tryParse(_smallFeeCtrl.text.trim()) ?? 0,
        'shippingZones': {
          'local': {
            'prefixes': _localPrefixesCtrl.text
                .split(',')
                .map((s) => s.trim())
                .where((s) => s.isNotEmpty)
                .toList(),
            'fee': int.tryParse(_localFeeCtrl.text.trim()) ?? 0,
          },
          'up': {
            'prefixRange': [
              int.tryParse(_upLoCtrl.text.trim()) ?? 0,
              int.tryParse(_upHiCtrl.text.trim()) ?? 0,
            ],
            'fee': int.tryParse(_upFeeCtrl.text.trim()) ?? 0,
          },
          'national': {'fee': int.tryParse(_nationalFeeCtrl.text.trim()) ?? 0},
        },
      };
      final business = {
        for (final e in _businessCtrls.entries) e.key: e.value.text.trim(),
      };

      await ref
          .read(siteCoreApiProvider)
          .updateSettings(business: business, commerce: commerce);
      ref.invalidate(siteSettingsProvider);
      Haptics.success();
      if (mounted) await SuccessPulse.show(context, 'Settings saved');
    } on ApiException catch (e) {
      Haptics.warning();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(siteSettingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Site Settings')),
      body: settingsAsync.when(
        data: (s) {
          _loadInto(s);
          return ListView(
            padding: EdgeInsets.fromLTRB(
              16,
              16,
              16,
              LayoutConstants.navBarClearance + 76,
            ),
            children: [
              _SectionCard(
                icon: Icons.local_shipping_outlined,
                title: 'Shipping & Pricing',
                children: [
                  _Field(
                    controller: _discountCtrl,
                    label: 'Site-wide discount (%)',
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _Field(
                    controller: _freeShipCtrl,
                    label: 'Free shipping above (₹)',
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _Field(
                          controller: _smallThresholdCtrl,
                          label: 'Small order threshold (₹)',
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _Field(
                          controller: _smallFeeCtrl,
                          label: 'Small order fee (₹)',
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _SectionCard(
                icon: Icons.map_outlined,
                title: 'Shipping Zones',
                children: [
                  Text('Local', style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 8),
                  _Field(
                    controller: _localPrefixesCtrl,
                    label: 'Pincode prefixes (comma-separated)',
                  ),
                  const SizedBox(height: 10),
                  _Field(
                    controller: _localFeeCtrl,
                    label: 'Local fee (₹)',
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Uttar Pradesh (2-digit pincode range)',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _Field(
                          controller: _upLoCtrl,
                          label: 'From',
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _Field(
                          controller: _upHiCtrl,
                          label: 'To',
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _Field(
                    controller: _upFeeCtrl,
                    label: 'UP fee (₹)',
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'National',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 8),
                  _Field(
                    controller: _nationalFeeCtrl,
                    label: 'National fee (₹)',
                    keyboardType: TextInputType.number,
                  ),
                ],
              ),
              if (_businessCtrls.isNotEmpty) ...[
                const SizedBox(height: 16),
                _SectionCard(
                  icon: Icons.storefront_outlined,
                  title: 'Business Info',
                  children: [
                    for (final entry in _businessCtrls.entries)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _Field(
                          controller: entry.value,
                          label: entry.key,
                        ),
                      ),
                  ],
                ),
              ],
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load settings: $e')),
      ),
      bottomNavigationBar: settingsAsync.maybeWhen(
        data: (_) => SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: FilledButton.icon(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check),
              label: Text(_saving ? 'Saving…' : 'Save Settings'),
            ),
          ),
        ),
        orElse: () => null,
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<Widget> children;
  const _SectionCard({
    required this.icon,
    required this.title,
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
  final TextInputType? keyboardType;
  const _Field({
    required this.controller,
    required this.label,
    this.keyboardType,
  });
  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    keyboardType: keyboardType,
    decoration: InputDecoration(labelText: label),
  );
}
