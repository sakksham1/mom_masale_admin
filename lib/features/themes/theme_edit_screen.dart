import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'themes_api.dart';
import 'themes_provider.dart';
import 'themes_screen.dart' show parseHexColor;
import '../catalog/catalog_provider.dart' show catalogApiProvider;
import '../../core/network/api_exception.dart';
import '../../core/config/env.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/haptics.dart';
import '../../shared/widgets/success_pulse.dart';
import '../../shared/widgets/swipe_confirm_sheet.dart';

/// Create/edit a seasonal site theme. admin + manager both write directly —
/// unlike the catalog, themes.js allows manager the same access as admin,
/// so there's no approval-queue branch here.
class ThemeEditScreen extends ConsumerStatefulWidget {
  final SiteTheme? theme; // null = creating a new theme
  const ThemeEditScreen({super.key, required this.theme});

  @override
  ConsumerState<ThemeEditScreen> createState() => _ThemeEditScreenState();
}

class _ThemeEditScreenState extends ConsumerState<ThemeEditScreen> {
  late final TextEditingController _nameCtrl, _keyCtrl;
  late final TextEditingController _featuredSectionTitleCtrl,
      _promoBannerTextCtrl;
  late final TextEditingController _heroTitleCtrl,
      _heroCtaLabelCtrl,
      _heroCtaUrlCtrl;
  late final TextEditingController _bannerTitleCtrl,
      _bannerBodyCtrl,
      _bannerCtaLabelCtrl,
      _bannerCtaUrlCtrl;
  late final TextEditingController _discountPercentCtrl, _couponCodeCtrl;
  late final TextEditingController _startsAtCtrl, _endsAtCtrl;
  final Map<String, TextEditingController> _colorCtrls = {};

  String? _heroImagePath;
  String? _bannerImagePath;
  Uint8List? _pendingHeroBytes;
  Uint8List? _pendingBannerBytes;
  bool _uploadingHero = false, _uploadingBanner = false;

  late bool _bannerEnabled;
  bool _submitting = false, _deleting = false, _activating = false;

  bool get _isNew => widget.theme == null;

  @override
  void initState() {
    super.initState();
    final t = widget.theme;
    _nameCtrl = TextEditingController(text: t?.name ?? '');
    _keyCtrl = TextEditingController(text: t?.key ?? '');
    _featuredSectionTitleCtrl = TextEditingController(
      text: t?.featuredSectionTitle ?? '',
    );
    _promoBannerTextCtrl = TextEditingController(
      text: t?.promoBannerText ?? '',
    );
    _heroTitleCtrl = TextEditingController(text: t?.heroTitle ?? '');
    _heroCtaLabelCtrl = TextEditingController(text: t?.heroCtaLabel ?? '');
    _heroCtaUrlCtrl = TextEditingController(text: t?.heroCtaUrl ?? '');
    _bannerTitleCtrl = TextEditingController(text: t?.bannerTitle ?? '');
    _bannerBodyCtrl = TextEditingController(text: t?.bannerBody ?? '');
    _bannerCtaLabelCtrl = TextEditingController(
      text: t?.bannerCtaLabel ?? '',
    );
    _bannerCtaUrlCtrl = TextEditingController(text: t?.bannerCtaUrl ?? '');
    _discountPercentCtrl = TextEditingController(
      text: t?.discountPercent?.toString() ?? '',
    );
    _couponCodeCtrl = TextEditingController(text: t?.couponCode ?? '');
    _startsAtCtrl = TextEditingController(
      text: (t?.startsAt ?? '').split('T').first,
    );
    _endsAtCtrl = TextEditingController(text: (t?.endsAt ?? '').split('T').first);
    _bannerEnabled = t?.bannerEnabled ?? false;
    _heroImagePath = t?.heroImage;
    _bannerImagePath = t?.bannerImage;
    for (final key in themeColorKeys) {
      _colorCtrls[key] = TextEditingController(text: t?.colors[key] ?? '');
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _keyCtrl.dispose();
    _featuredSectionTitleCtrl.dispose();
    _promoBannerTextCtrl.dispose();
    _heroTitleCtrl.dispose();
    _heroCtaLabelCtrl.dispose();
    _heroCtaUrlCtrl.dispose();
    _bannerTitleCtrl.dispose();
    _bannerBodyCtrl.dispose();
    _bannerCtaLabelCtrl.dispose();
    _bannerCtaUrlCtrl.dispose();
    _discountPercentCtrl.dispose();
    _couponCodeCtrl.dispose();
    _startsAtCtrl.dispose();
    _endsAtCtrl.dispose();
    for (final c in _colorCtrls.values) {
      c.dispose();
    }
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

  Future<void> _pickImage(
    ImageSource source, {
    required bool isHero,
  }) async {
    final picker = ImagePicker();
    XFile? file;
    try {
      file = await picker.pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 88,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open camera/gallery: $e')),
        );
      }
      return;
    }
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() {
      if (isHero) {
        _pendingHeroBytes = bytes;
        _uploadingHero = true;
      } else {
        _pendingBannerBytes = bytes;
        _uploadingBanner = true;
      }
    });
    try {
      final path = await ref
          .read(catalogApiProvider)
          .uploadImage(bytes, file.name, folder: 'themes');
      if (!mounted) return;
      setState(() {
        if (isHero) {
          _heroImagePath = path;
        } else {
          _bannerImagePath = path;
        }
      });
      Haptics.tap();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Upload failed: ${e.message}')));
        setState(() {
          if (isHero) {
            _pendingHeroBytes = null;
          } else {
            _pendingBannerBytes = null;
          }
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          if (isHero) {
            _uploadingHero = false;
          } else {
            _uploadingBanner = false;
          }
        });
      }
    }
  }

  void _showImageSourceSheet({required bool isHero}) {
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.pop(sheetContext);
                _pickImage(ImageSource.camera, isHero: isHero);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(sheetContext);
                _pickImage(ImageSource.gallery, isHero: isHero);
              },
            ),
          ],
        ),
      ),
    );
  }

  Map<String, dynamic> _buildBody() {
    final colors = <String, String>{};
    for (final key in themeColorKeys) {
      final v = _colorCtrls[key]!.text.trim();
      if (v.isNotEmpty) colors[key] = v.startsWith('#') ? v : '#$v';
    }
    final discount = int.tryParse(_discountPercentCtrl.text.trim());

    return {
      'name': _nameCtrl.text.trim(),
      if (_keyCtrl.text.trim().isNotEmpty) 'key': _keyCtrl.text.trim(),
      'colors': colors,
      'featuredSectionTitle': _featuredSectionTitleCtrl.text.trim(),
      'promoBannerText': _promoBannerTextCtrl.text.trim(),
      'heroTitle': _heroTitleCtrl.text.trim(),
      'heroCtaLabel': _heroCtaLabelCtrl.text.trim(),
      'heroCtaUrl': _heroCtaUrlCtrl.text.trim(),
      'heroImage': _heroImagePath ?? '',
      'bannerEnabled': _bannerEnabled,
      'bannerTitle': _bannerTitleCtrl.text.trim(),
      'bannerBody': _bannerBodyCtrl.text.trim(),
      'bannerImage': _bannerImagePath ?? '',
      'bannerCtaLabel': _bannerCtaLabelCtrl.text.trim(),
      'bannerCtaUrl': _bannerCtaUrlCtrl.text.trim(),
      'discountPercent': discount,
      'couponCode': _couponCodeCtrl.text.trim().isEmpty
          ? null
          : _couponCodeCtrl.text.trim(),
      'startsAt': _startsAtCtrl.text.trim().isEmpty
          ? null
          : _startsAtCtrl.text.trim(),
      'endsAt': _endsAtCtrl.text.trim().isEmpty
          ? null
          : _endsAtCtrl.text.trim(),
    };
  }

  Future<void> _submit() async {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Name is required')));
      return;
    }
    final discountText = _discountPercentCtrl.text.trim();
    if (discountText.isNotEmpty) {
      final d = int.tryParse(discountText);
      if (d == null || d < 0 || d > 90) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Discount must be a whole number between 0 and 90'),
          ),
        );
        return;
      }
    }

    final confirmed = await SwipeConfirmSheet.show(
      context,
      icon: _isNew ? Icons.add_circle_outline : Icons.save_outlined,
      color: AppColors.turmeric,
      message: Text.rich(
        TextSpan(
          style: Theme.of(context).textTheme.bodyMedium,
          children: [
            TextSpan(text: _isNew ? 'Create theme ' : 'Save changes to '),
            TextSpan(
              text: _nameCtrl.text.trim(),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const TextSpan(text: '?'),
          ],
        ),
      ),
      swipeLabel: _isNew ? 'Slide to create' : 'Slide to save',
    );
    if (!confirmed) return;

    setState(() => _submitting = true);
    try {
      final api = ref.read(themesApiProvider);
      final body = _buildBody();
      if (_isNew) {
        await api.create(body);
      } else {
        await api.update(widget.theme!.id, body);
      }
      ref.invalidate(themesProvider);
      Haptics.success();
      if (mounted) {
        await SuccessPulse.show(
          context,
          _isNew ? 'Theme created' : 'Theme saved',
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

  Future<void> _toggleActive() async {
    final theme = widget.theme;
    if (theme == null) return;
    final activating = !theme.isActive;

    final confirmed = await SwipeConfirmSheet.show(
      context,
      icon: activating ? Icons.auto_awesome : Icons.brightness_low_outlined,
      color: activating ? const Color(0xFF2E7D32) : AppColors.cumin,
      message: Text(
        activating
            ? 'Make "${theme.name}" the live site theme? This replaces whatever theme is active now.'
            : 'Revert to the default site look?',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      swipeLabel: activating ? 'Slide to activate' : 'Slide to deactivate',
    );
    if (!confirmed) return;

    setState(() => _activating = true);
    try {
      final api = ref.read(themesApiProvider);
      if (activating) {
        await api.activate(theme.id);
      } else {
        await api.deactivate();
      }
      ref.invalidate(themesProvider);
      Haptics.success();
      if (mounted) {
        await SuccessPulse.show(
          context,
          activating ? 'Theme activated' : 'Reverted to default look',
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
      if (mounted) setState(() => _activating = false);
    }
  }

  Future<void> _delete() async {
    final theme = widget.theme;
    if (theme == null) return;
    final confirmed = await SwipeConfirmSheet.show(
      context,
      icon: Icons.delete_outline,
      color: Theme.of(context).colorScheme.error,
      message: Text(
        'Delete "${theme.name}" permanently? This can\'t be undone.',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      swipeLabel: 'Slide to delete',
    );
    if (!confirmed) return;

    setState(() => _deleting = true);
    try {
      await ref.read(themesApiProvider).delete(theme.id);
      ref.invalidate(themesProvider);
      Haptics.success();
      if (mounted) {
        await SuccessPulse.show(
          context,
          'Theme deleted',
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

  String? _resolveImageUrl(String? path) {
    if (path == null || path.isEmpty) return null;
    final uri = Uri.tryParse(path);
    if (uri != null && uri.hasScheme && uri.hasAuthority) return path;
    final normalized = path.startsWith('/') ? path : '/$path';
    return '${Env.apiBaseUrl}$normalized';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = widget.theme;
    final busy = _submitting || _deleting || _activating;

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      appBar: AppBar(
        title: Text(_isNew ? 'New Theme' : theme!.name, overflow: TextOverflow.ellipsis),
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
              onPressed: busy ? null : _delete,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          if (!_isNew)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _StatusBanner(
                isActive: theme!.isActive,
                busy: _activating,
                onToggle: _toggleActive,
              ),
            ),
          _SectionCard(
            icon: Icons.badge_outlined,
            title: 'Basics',
            children: [
              _Field(controller: _nameCtrl, label: 'Theme name'),
              const SizedBox(height: 12),
              _Field(
                controller: _keyCtrl,
                label: 'Key (optional — auto from name)',
                helper: 'Used as a stable identifier; letters, numbers, hyphens.',
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SectionCard(
            icon: Icons.palette_outlined,
            title: 'Colors',
            subtitle: 'Hex codes, e.g. 7B1120',
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final key in themeColorKeys)
                    SizedBox(
                      width: 160,
                      child: _ColorField(
                        controller: _colorCtrls[key]!,
                        label: themeColorLabels[key]!,
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SectionCard(
            icon: Icons.storefront_outlined,
            title: 'Hero & Featured',
            children: [
              _ThemeImageField(
                label: 'Hero image',
                imageUrl: _resolveImageUrl(_heroImagePath),
                pendingBytes: _pendingHeroBytes,
                uploading: _uploadingHero,
                onTap: () => _showImageSourceSheet(isHero: true),
              ),
              const SizedBox(height: 12),
              _Field(controller: _heroTitleCtrl, label: 'Hero title'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _Field(
                      controller: _heroCtaLabelCtrl,
                      label: 'Hero button label',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _Field(
                      controller: _heroCtaUrlCtrl,
                      label: 'Hero button URL',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _Field(
                controller: _featuredSectionTitleCtrl,
                label: 'Featured section title',
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SectionCard(
            icon: Icons.campaign_outlined,
            title: 'Promo Banner',
            children: [
              _ToggleRow(
                icon: Icons.campaign_outlined,
                color: AppColors.paprika,
                title: 'Show banner',
                subtitle: 'A dismissible strip at the top of the site',
                value: _bannerEnabled,
                onChanged: (v) => setState(() => _bannerEnabled = v),
              ),
              if (_bannerEnabled) ...[
                const SizedBox(height: 14),
                _Field(
                  controller: _promoBannerTextCtrl,
                  label: 'Short promo text (ribbon)',
                ),
                const SizedBox(height: 12),
                _ThemeImageField(
                  label: 'Banner image',
                  imageUrl: _resolveImageUrl(_bannerImagePath),
                  pendingBytes: _pendingBannerBytes,
                  uploading: _uploadingBanner,
                  onTap: () => _showImageSourceSheet(isHero: false),
                ),
                const SizedBox(height: 12),
                _Field(controller: _bannerTitleCtrl, label: 'Banner title'),
                const SizedBox(height: 12),
                _Field(
                  controller: _bannerBodyCtrl,
                  label: 'Banner body',
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _Field(
                        controller: _bannerCtaLabelCtrl,
                        label: 'Button label',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _Field(
                        controller: _bannerCtaUrlCtrl,
                        label: 'Button URL',
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          _SectionCard(
            icon: Icons.sell_outlined,
            title: 'Discount & Coupon',
            children: [
              Row(
                children: [
                  Expanded(
                    child: _Field(
                      controller: _discountPercentCtrl,
                      label: 'Site-wide discount (%, optional)',
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _Field(
                      controller: _couponCodeCtrl,
                      label: 'Featured coupon code (optional)',
                    ),
                  ),
                ],
              ),
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
            onPressed: busy ? null : _submit,
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
                  : (_isNew ? 'Create Theme' : 'Save Changes'),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final bool isActive;
  final bool busy;
  final VoidCallback onToggle;
  const _StatusBanner({
    required this.isActive,
    required this.busy,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive ? const Color(0xFF2E7D32) : AppColors.cumin;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(
            isActive ? Icons.auto_awesome : Icons.brightness_auto_outlined,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isActive ? 'Live on the storefront now' : 'Not currently active',
              style: TextStyle(fontWeight: FontWeight.w600, color: color),
            ),
          ),
          TextButton(
            onPressed: busy ? null : onToggle,
            child: busy
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: color,
                    ),
                  )
                : Text(isActive ? 'Deactivate' : 'Activate'),
          ),
        ],
      ),
    );
  }
}

class _ThemeImageField extends StatelessWidget {
  final String label;
  final String? imageUrl;
  final Uint8List? pendingBytes;
  final bool uploading;
  final VoidCallback onTap;
  const _ThemeImageField({
    required this.label,
    required this.imageUrl,
    required this.pendingBytes,
    required this.uploading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: uploading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.6)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: 52,
                height: 52,
                color: scheme.surfaceContainerHighest,
                child: uploading
                    ? const Center(
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : pendingBytes != null
                    ? Image.memory(pendingBytes!, fit: BoxFit.cover)
                    : (imageUrl != null
                          ? Image.network(
                              imageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => const Icon(
                                Icons.image_not_supported_outlined,
                                size: 20,
                              ),
                            )
                          : const Icon(Icons.image_outlined, size: 20)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
            Icon(Icons.camera_alt_outlined, color: scheme.onSurfaceVariant, size: 18),
          ],
        ),
      ),
    );
  }
}

class _ColorField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  const _ColorField({required this.controller, required this.label});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final swatch = parseHexColor(controller.text);
        return Container(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.6),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 16,
                    height: 16,
                    margin: const EdgeInsets.only(top: 4, bottom: 4, right: 6),
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
                      controller: controller,
                      style: const TextStyle(
                        fontFamily: 'IBMPlexMono',
                        fontSize: 13,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'e.g. 7B1120',
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.only(bottom: 4),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
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
  const _Field({
    required this.controller,
    required this.label,
    this.maxLines = 1,
    this.helper,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
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
