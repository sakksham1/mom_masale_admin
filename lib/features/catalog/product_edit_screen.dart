import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'catalog_api.dart';
import 'catalog_provider.dart';
import '../../core/auth/user_role.dart';
import '../../core/network/api_client_provider.dart';
import '../../core/network/api_exception.dart';
import '../../core/config/env.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/haptics.dart';
import '../../shared/widgets/success_pulse.dart';
import '../../shared/widgets/status_badge.dart';

/// Edits one product's catalog data — name, category, image, prices, the
/// four visibility flags, and SEO copy. No stock/quantity fields here;
/// inventory has its own dedicated flow elsewhere in the app.
///
/// Role decides what happens on submit:
///  - admin   → PATCH straight to /api/admin/products, live immediately.
///  - manager → POST to /api/product-core/request, held for an admin to
///              approve/reject on the Approvals screen. Nothing here ever
///              touches the live site until that happens.
///
/// The bottom action bar (Cancel / Submit) only appears once there's an
/// actual unsaved change — see `_isDirty`. Pushed via the root navigator
/// (see catalog_list_screen.dart) so it's a true full-screen route, clear
/// of HomeShell's floating bottom nav.
class ProductEditScreen extends ConsumerStatefulWidget {
  final CatalogProduct product;
  const ProductEditScreen({super.key, required this.product});

  @override
  ConsumerState<ProductEditScreen> createState() => _ProductEditScreenState();
}

class _ProductEditScreenState extends ConsumerState<ProductEditScreen> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _categoryCtrl;
  late final TextEditingController _seoTitleCtrl;
  late final TextEditingController _seoMetaCtrl;
  late final TextEditingController _seoShortCtrl;
  late final TextEditingController _seoLongCtrl;
  late final TextEditingController _seoKeywordsCtrl;
  final Map<String, TextEditingController> _priceCtrls = {};
  final _newSizeCtrl = TextEditingController();
  final _newPriceCtrl = TextEditingController();

  late bool _comingSoon, _featured, _bestseller, _newArrival;

  String? _pendingImagePath; // set once a picked photo finishes uploading
  Uint8List? _pendingImageBytes; // local preview shown immediately
  bool _uploadingImage = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _nameCtrl = TextEditingController(text: p.name)
      ..addListener(_onFieldChanged);
    _categoryCtrl = TextEditingController(text: p.category)
      ..addListener(_onFieldChanged);
    _seoTitleCtrl = TextEditingController(text: p.seo.title)
      ..addListener(_onFieldChanged);
    _seoMetaCtrl = TextEditingController(text: p.seo.metaDescription)
      ..addListener(_onFieldChanged);
    _seoShortCtrl = TextEditingController(text: p.seo.shortDescription)
      ..addListener(_onFieldChanged);
    _seoLongCtrl = TextEditingController(text: p.seo.longDescription)
      ..addListener(_onFieldChanged);
    _seoKeywordsCtrl = TextEditingController(text: p.seo.keywords.join(', '))
      ..addListener(_onFieldChanged);
    _comingSoon = p.comingSoon;
    _featured = p.featured;
    _bestseller = p.bestseller;
    _newArrival = p.newArrival;
    for (final s in p.sizes) {
      _priceCtrls[s.size] = TextEditingController(text: _trimNum(s.price))
        ..addListener(_onFieldChanged);
    }
  }

  void _onFieldChanged() {
    if (mounted) setState(() {});
  }

  String _trimNum(num n) =>
      n == n.roundToDouble() ? n.toInt().toString() : n.toString();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _categoryCtrl.dispose();
    _seoTitleCtrl.dispose();
    _seoMetaCtrl.dispose();
    _seoShortCtrl.dispose();
    _seoLongCtrl.dispose();
    _seoKeywordsCtrl.dispose();
    for (final c in _priceCtrls.values) {
      c.dispose();
    }
    _newSizeCtrl.dispose();
    _newPriceCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final XFile? file;
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
      _pendingImageBytes = bytes;
      _uploadingImage = true;
    });
    try {
      final path = await ref
          .read(catalogApiProvider)
          .uploadImage(bytes, file.name);
      if (!mounted) return;
      setState(() => _pendingImagePath = path);
      Haptics.tap();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Upload failed: ${e.message}')));
        setState(() => _pendingImageBytes = null);
      }
    } finally {
      if (mounted) setState(() => _uploadingImage = false);
    }
  }

  void _showImageSourceSheet() {
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
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(sheetContext);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _addSize() {
    final size = _newSizeCtrl.text.trim();
    final price = _newPriceCtrl.text.trim();
    if (size.isEmpty || price.isEmpty || _priceCtrls.containsKey(size)) return;
    if (num.tryParse(price) == null) return;
    setState(() {
      _priceCtrls[size] = TextEditingController(text: price)
        ..addListener(_onFieldChanged);
      _newSizeCtrl.clear();
      _newPriceCtrl.clear();
    });
    Haptics.tap();
  }

  bool _priceChanged(String size, num original) {
    final parsed = num.tryParse(_priceCtrls[size]!.text.trim());
    return parsed != null && parsed != original;
  }

  Map<String, dynamic> _buildUpdates() {
    final p = widget.product;
    final updates = <String, dynamic>{};

    final name = _nameCtrl.text.trim();
    if (name.isNotEmpty && name != p.name) updates['name'] = name;

    final category = _categoryCtrl.text.trim();
    if (category.isNotEmpty && category != p.category) {
      updates['category'] = category;
    }

    if (_pendingImagePath != null && _pendingImagePath != p.image) {
      updates['image'] = _pendingImagePath;
    }

    if (_comingSoon != p.comingSoon) updates['comingSoon'] = _comingSoon;
    if (_featured != p.featured) updates['featured'] = _featured;
    if (_bestseller != p.bestseller) updates['bestseller'] = _bestseller;
    if (_newArrival != p.newArrival) updates['newArrival'] = _newArrival;

    final originalPrices = {for (final s in p.sizes) s.size: s.price};
    final priceUpdates = <String, num>{};
    for (final entry in _priceCtrls.entries) {
      final newPrice = num.tryParse(entry.value.text.trim());
      if (newPrice == null || newPrice <= 0) continue;
      if (originalPrices[entry.key] != newPrice) {
        priceUpdates[entry.key] = newPrice;
      }
    }
    if (priceUpdates.isNotEmpty) updates['prices'] = priceUpdates;

    final seo = <String, dynamic>{};
    if (_seoTitleCtrl.text.trim() != p.seo.title) {
      seo['title'] = _seoTitleCtrl.text.trim();
    }
    if (_seoMetaCtrl.text.trim() != p.seo.metaDescription) {
      seo['metaDescription'] = _seoMetaCtrl.text.trim();
    }
    if (_seoShortCtrl.text.trim() != p.seo.shortDescription) {
      seo['shortDescription'] = _seoShortCtrl.text.trim();
    }
    if (_seoLongCtrl.text.trim() != p.seo.longDescription) {
      seo['longDescription'] = _seoLongCtrl.text.trim();
    }
    final newKeywords = _seoKeywordsCtrl.text
        .split(',')
        .map((k) => k.trim())
        .where((k) => k.isNotEmpty)
        .toList();
    if (newKeywords.join(',') != p.seo.keywords.join(',')) {
      seo['keywords'] = newKeywords;
    }
    if (seo.isNotEmpty) updates['seo'] = seo;

    return updates;
  }

  bool get _isDirty => _buildUpdates().isNotEmpty;

  /// Reverts every field back to the product's original values — used by
  /// the "Cancel" action in the bottom bar. Any size added during this
  /// session is dropped entirely rather than reset.
  void _resetChanges() {
    final p = widget.product;
    setState(() {
      _nameCtrl.text = p.name;
      _categoryCtrl.text = p.category;
      _seoTitleCtrl.text = p.seo.title;
      _seoMetaCtrl.text = p.seo.metaDescription;
      _seoShortCtrl.text = p.seo.shortDescription;
      _seoLongCtrl.text = p.seo.longDescription;
      _seoKeywordsCtrl.text = p.seo.keywords.join(', ');
      _comingSoon = p.comingSoon;
      _featured = p.featured;
      _bestseller = p.bestseller;
      _newArrival = p.newArrival;
      _pendingImagePath = null;
      _pendingImageBytes = null;

      final originalPrices = {for (final s in p.sizes) s.size: s.price};
      _priceCtrls.removeWhere((size, ctrl) {
        final isExtra = !originalPrices.containsKey(size);
        if (isExtra) ctrl.dispose();
        return isExtra;
      });
      for (final entry in originalPrices.entries) {
        _priceCtrls[entry.key]!.text = _trimNum(entry.value);
      }
    });
    Haptics.tap();
  }

  Future<void> _submit() async {
    final updates = _buildUpdates();
    if (updates.isEmpty) return; // bar shouldn't be visible in this case anyway

    final role = ref.read(authControllerProvider).role;
    final isAdmin = role == UserRole.admin;

    if (!isAdmin) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Submit for approval?'),
          content: Text(
            'This sends ${updates.length} change${updates.length == 1 ? '' : 's'} to '
            '"${widget.product.name}" to an admin for review. Nothing goes live on the '
            'site until it\'s approved.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Submit'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    setState(() => _submitting = true);
    try {
      final api = ref.read(catalogApiProvider);
      if (isAdmin) {
        await api.updateDirect(widget.product.slug, updates);
      } else {
        await api.requestUpdate(widget.product.id, updates);
      }
      ref.invalidate(catalogProvider);
      Haptics.success();
      if (mounted) {
        await SuccessPulse.show(
          context,
          isAdmin ? 'Changes saved' : 'Submitted — awaiting admin approval',
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

  String? _resolveImageUrl() {
    final path = _pendingImagePath ?? widget.product.image;
    if (path.isEmpty) return null;
    final uri = Uri.tryParse(path);
    if (uri != null && uri.hasScheme && uri.hasAuthority) return path;
    final normalized = path.startsWith('/') ? path : '/$path';
    return '${Env.apiBaseUrl}$normalized';
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(authControllerProvider).role;
    final isAdmin = role == UserRole.admin;
    final scheme = Theme.of(context).colorScheme;
    final imageUrl = _resolveImageUrl();
    final dirty = _isDirty;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.product.name, overflow: TextOverflow.ellipsis),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
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

          // ── Hero: photo + quick identity ──
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.maroon.withValues(alpha: 0.10),
                  AppColors.maroon.withValues(alpha: 0.02),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.4),
              ),
            ),
            child: Column(
              children: [
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: Container(
                        width: 148,
                        height: 148,
                        color: scheme.surfaceContainerHighest,
                        child: _pendingImageBytes != null
                            ? Image.memory(
                                _pendingImageBytes!,
                                fit: BoxFit.cover,
                              )
                            : (imageUrl != null
                                  ? Image.network(
                                      imageUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) => const Icon(
                                        Icons.image_not_supported_outlined,
                                        size: 32,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.image_not_supported_outlined,
                                      size: 32,
                                    )),
                      ),
                    ),
                    if (_uploadingImage)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: const Center(
                            child: SizedBox(
                              width: 28,
                              height: 28,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      right: -6,
                      bottom: -6,
                      child: IconButton.filled(
                        onPressed: _uploadingImage
                            ? null
                            : _showImageSourceSheet,
                        icon: const Icon(Icons.camera_alt_outlined, size: 18),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Tap the camera to change the photo',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  alignment: WrapAlignment.center,
                  children: [
                    if (widget.product.comingSoon)
                      _FlagChip('Coming Soon', AppColors.paprika),
                    if (widget.product.featured)
                      _FlagChip('Featured', AppColors.turmeric),
                    if (widget.product.bestseller)
                      _FlagChip('Bestseller', AppColors.maroon),
                    if (widget.product.newArrival)
                      _FlagChip('New', const Color(0xFF2E7D32)),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
          _SectionCard(
            icon: Icons.badge_outlined,
            title: 'Basics',
            children: [
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Product name',
                  prefixIcon: Icon(Icons.local_offer_outlined),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _categoryCtrl,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  prefixIcon: Icon(Icons.category_outlined),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          _SectionCard(
            icon: Icons.sell_outlined,
            title: 'Pricing',
            children: [
              ..._priceCtrls.entries.map((e) {
                final original = widget.product.sizes
                    .where((s) => s.size == e.key)
                    .map((s) => s.price)
                    .cast<num?>()
                    .firstOrNull;
                final changed =
                    original != null && _priceChanged(e.key, original);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: changed
                            ? AppColors.turmeric.withValues(alpha: 0.6)
                            : scheme.outlineVariant.withValues(alpha: 0.4),
                        width: changed ? 1.4 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.cumin.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            e.key,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: e.value,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              prefixText: '₹ ',
                              border: InputBorder.none,
                              isDense: true,
                            ),
                          ),
                        ),
                        if (changed)
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(left: 4),
                            decoration: const BoxDecoration(
                              color: AppColors.turmeric,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: scheme.outlineVariant,
                    style: BorderStyle.solid,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Add a size',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: _newSizeCtrl,
                            decoration: const InputDecoration(
                              hintText: 'e.g. 500g',
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _newPriceCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              hintText: 'Price',
                              isDense: true,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: _addSize,
                          icon: const Icon(Icons.add_circle),
                          color: scheme.primary,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          _SectionCard(
            icon: Icons.visibility_outlined,
            title: 'Visibility',
            children: [
              _ToggleRow(
                icon: Icons.schedule,
                color: AppColors.paprika,
                title: 'Coming Soon',
                subtitle: 'Hides "Add to Cart" on the site',
                value: _comingSoon,
                onChanged: (v) => setState(() => _comingSoon = v),
              ),
              const SizedBox(height: 8),
              _ToggleRow(
                icon: Icons.star_outline,
                color: AppColors.turmeric,
                title: 'Featured',
                value: _featured,
                onChanged: (v) => setState(() => _featured = v),
              ),
              const SizedBox(height: 8),
              _ToggleRow(
                icon: Icons.local_fire_department_outlined,
                color: AppColors.maroon,
                title: 'Bestseller',
                value: _bestseller,
                onChanged: (v) => setState(() => _bestseller = v),
              ),
              const SizedBox(height: 8),
              _ToggleRow(
                icon: Icons.fiber_new_outlined,
                color: const Color(0xFF2E7D32),
                title: 'New Arrival',
                value: _newArrival,
                onChanged: (v) => setState(() => _newArrival = v),
              ),
            ],
          ),

          const SizedBox(height: 16),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Theme(
              data: Theme.of(
                context,
              ).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                leading: Icon(Icons.search, color: scheme.onSurfaceVariant),
                title: const Text(
                  'SEO & Description',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  TextField(
                    controller: _seoTitleCtrl,
                    decoration: const InputDecoration(labelText: 'SEO title'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _seoMetaCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Meta description',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _seoShortCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Short description',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _seoLongCtrl,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Long description',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _seoKeywordsCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Keywords (comma-separated)',
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Breathing room so content never sits directly under the
          // animated action bar when it's showing.
          SizedBox(height: dirty ? 88 : 8),
        ],
      ),
      bottomNavigationBar: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        transitionBuilder: (child, animation) => SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
          child: FadeTransition(opacity: animation, child: child),
        ),
        child: dirty
            ? _buildActionBar(isAdmin)
            : const SizedBox.shrink(key: ValueKey('hidden')),
      ),
    );
  }

  Widget _buildActionBar(bool isAdmin) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      key: const ValueKey('bar'),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _submitting ? null : _resetChanges,
                  icon: const Icon(Icons.close),
                  label: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: _submitting ? null : _submit,
                  icon: _submitting
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(isAdmin ? Icons.check : Icons.send),
                  label: Text(
                    _submitting
                        ? 'Saving…'
                        : (isAdmin ? 'Save Changes' : 'Submit for Approval'),
                  ),
                ),
              ),
            ],
          ),
        ),
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: scheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// Rounded row for a boolean flag — icon badge on the left (consistent with
/// StatusBadge elsewhere in the app), title/subtitle, switch on the right.
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
            : scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: value
              ? color.withValues(alpha: 0.3)
              : scheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          StatusBadge(icon: icon, color: color, size: 34),
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

class _FlagChip extends StatelessWidget {
  final String label;
  final Color color;
  const _FlagChip(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
