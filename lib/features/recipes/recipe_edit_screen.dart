// lib/features/recipes/recipe_edit_screen.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'recipes_api.dart';
import 'recipes_provider.dart';
import '../catalog/catalog_provider.dart' show catalogApiProvider;
import '../../core/network/api_exception.dart';
import '../../core/config/env.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/haptics.dart';
import '../../shared/widgets/success_pulse.dart';
import '../../shared/widgets/swipe_confirm_sheet.dart';

/// Recipe create/edit. Admin-only backend (recipes.js) — writes commit
/// straight to data/recipes.json on GitHub, so changes go live immediately
/// (no approval queue involved), same tone as an admin's catalog edit.
class RecipeEditScreen extends ConsumerStatefulWidget {
  final Recipe? recipe; // null = creating a new recipe
  const RecipeEditScreen({super.key, required this.recipe});

  @override
  ConsumerState<RecipeEditScreen> createState() => _RecipeEditScreenState();
}

class _RecipeEditScreenState extends ConsumerState<RecipeEditScreen> {
  late final TextEditingController _titleCtrl,
      _categoryCtrl,
      _cuisineCtrl,
      _descCtrl,
      _prepCtrl,
      _cookCtrl,
      _servingsCtrl,
      _videoCtrl,
      _relatedProductsCtrl,
      _stepsCtrl;
  final List<TextEditingController> _ingredientCtrls = [];
  final List<TextEditingController> _ingredientSlugCtrls = [];

  bool _trending = false, _essentials = false;
  String? _pendingImagePath;
  Uint8List? _pendingImageBytes;
  bool _uploadingImage = false, _submitting = false, _deleting = false;

  bool get _isNew => widget.recipe == null;

  @override
  void initState() {
    super.initState();
    final r = widget.recipe;
    _titleCtrl = TextEditingController(text: r?.title ?? '');
    _categoryCtrl = TextEditingController(text: r?.category ?? '');
    _cuisineCtrl = TextEditingController(text: r?.cuisine ?? 'Indian');
    _descCtrl = TextEditingController(text: r?.description ?? '');
    _prepCtrl = TextEditingController(text: r?.prepTime ?? 'PT10M');
    _cookCtrl = TextEditingController(text: r?.cookTime ?? 'PT20M');
    _servingsCtrl = TextEditingController(text: '${r?.servings ?? 4}');
    _videoCtrl = TextEditingController(text: r?.video ?? '');
    _relatedProductsCtrl = TextEditingController(
      text: (r?.relatedProducts ?? []).join(', '),
    );
    _stepsCtrl = TextEditingController(text: (r?.steps ?? []).join('\n'));
    _trending = r?.trending ?? false;
    _essentials = r?.essentials ?? false;
    for (final ing in r?.ingredients ?? const <RecipeIngredient>[]) {
      _ingredientCtrls.add(TextEditingController(text: ing.text));
      _ingredientSlugCtrls.add(
        TextEditingController(text: ing.productSlug ?? ''),
      );
    }
    if (_ingredientCtrls.isEmpty) _addIngredientRow();
  }

  void _addIngredientRow() {
    setState(() {
      _ingredientCtrls.add(TextEditingController());
      _ingredientSlugCtrls.add(TextEditingController());
    });
  }

  void _removeIngredientRow(int i) {
    setState(() {
      _ingredientCtrls.removeAt(i).dispose();
      _ingredientSlugCtrls.removeAt(i).dispose();
    });
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _categoryCtrl.dispose();
    _cuisineCtrl.dispose();
    _descCtrl.dispose();
    _prepCtrl.dispose();
    _cookCtrl.dispose();
    _servingsCtrl.dispose();
    _videoCtrl.dispose();
    _relatedProductsCtrl.dispose();
    _stepsCtrl.dispose();
    for (final c in _ingredientCtrls) {
      c.dispose();
    }
    for (final c in _ingredientSlugCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
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
      _pendingImageBytes = bytes;
      _uploadingImage = true;
    });
    try {
      final path = await ref
          .read(catalogApiProvider)
          .uploadImage(bytes, file.name, folder: 'recipes');
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

  Map<String, dynamic> _buildBody() {
    final ingredients = <Map<String, dynamic>>[];
    for (var i = 0; i < _ingredientCtrls.length; i++) {
      final text = _ingredientCtrls[i].text.trim();
      if (text.isEmpty) continue;
      final slug = _ingredientSlugCtrls[i].text.trim();
      ingredients.add({'text': text, if (slug.isNotEmpty) 'productSlug': slug});
    }
    final steps = _stepsCtrl.text
        .split('\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    final relatedProducts = _relatedProductsCtrl.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    return {
      'title': _titleCtrl.text.trim(),
      'category': _categoryCtrl.text.trim(),
      'cuisine': _cuisineCtrl.text.trim(),
      'description': _descCtrl.text.trim(),
      'prepTime': _prepCtrl.text.trim(),
      'cookTime': _cookCtrl.text.trim(),
      'servings': int.tryParse(_servingsCtrl.text.trim()) ?? 4,
      'trending': _trending,
      'essentials': _essentials,
      'ingredients': ingredients,
      'steps': steps,
      'relatedProducts': relatedProducts,
      if (_videoCtrl.text.trim().isNotEmpty) 'video': _videoCtrl.text.trim(),
      if (_pendingImagePath != null) 'image': _pendingImagePath,
    };
  }

  Future<void> _submit() async {
    final body = _buildBody();
    if ((body['title'] as String).isEmpty ||
        (body['category'] as String).isEmpty ||
        (body['description'] as String).isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Title, category, and description are required'),
        ),
      );
      return;
    }

    final confirmed = await SwipeConfirmSheet.show(
      context,
      icon: _isNew ? Icons.add_circle_outline : Icons.publish_outlined,
      color: const Color(0xFF2E7D32),
      message: Text.rich(
        TextSpan(
          style: Theme.of(context).textTheme.bodyMedium,
          children: [
            TextSpan(text: _isNew ? 'Publish ' : 'Save changes to '),
            TextSpan(
              text: body['title'] as String,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const TextSpan(text: '? This goes live immediately.'),
          ],
        ),
      ),
      swipeLabel: _isNew ? 'Slide to publish' : 'Slide to save',
    );
    if (!confirmed) return;

    setState(() => _submitting = true);
    try {
      final api = ref.read(recipesApiProvider);
      if (_isNew) {
        await api.create(body);
      } else {
        await api.update(widget.recipe!.slug, body);
      }
      ref.invalidate(recipesProvider);
      Haptics.success();
      if (mounted) {
        await SuccessPulse.show(
          context,
          _isNew ? 'Recipe published' : 'Recipe updated',
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
    if (_isNew) return;
    final confirmed = await SwipeConfirmSheet.show(
      context,
      icon: Icons.delete_outline,
      color: Theme.of(context).colorScheme.error,
      message: Text(
        'Delete "${widget.recipe!.title}" permanently? This can\'t be undone.',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      swipeLabel: 'Slide to delete',
    );
    if (!confirmed) return;
    setState(() => _deleting = true);
    try {
      await ref.read(recipesApiProvider).delete(widget.recipe!.slug);
      ref.invalidate(recipesProvider);
      Haptics.success();
      if (mounted) {
        await SuccessPulse.show(
          context,
          'Recipe deleted',
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

  String? _resolveImageUrl() {
    final path = _pendingImagePath ?? widget.recipe?.image ?? '';
    if (path.isEmpty) return null;
    final uri = Uri.tryParse(path);
    if (uri != null && uri.hasScheme && uri.hasAuthority) return path;
    final normalized = path.startsWith('/') ? path : '/$path';
    return '${Env.apiBaseUrl}$normalized';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final imageUrl = _resolveImageUrl();

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      appBar: AppBar(
        title: Text(
          _isNew ? 'New Recipe' : widget.recipe!.title,
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
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.turmeric.withValues(alpha: 0.10),
                  AppColors.turmeric.withValues(alpha: 0.02),
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
                  'Tap the camera to set a photo',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            icon: Icons.badge_outlined,
            title: 'Basics',
            children: [
              _Field(controller: _titleCtrl, label: 'Title'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _Field(controller: _categoryCtrl, label: 'Category'),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _Field(controller: _cuisineCtrl, label: 'Cuisine'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _Field(controller: _descCtrl, label: 'Description', maxLines: 3),
            ],
          ),
          const SizedBox(height: 16),
          _SectionCard(
            icon: Icons.schedule_outlined,
            title: 'Timing & Servings',
            children: [
              _Field(
                controller: _prepCtrl,
                label: 'Prep time (ISO 8601, e.g. PT10M)',
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _Field(
                      controller: _cookCtrl,
                      label: 'Cook time (e.g. PT20M)',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _Field(
                      controller: _servingsCtrl,
                      label: 'Servings',
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SectionCard(
            icon: Icons.checklist_outlined,
            title: 'Ingredients',
            children: [
              for (var i = 0; i < _ingredientCtrls.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: _Field(
                          controller: _ingredientCtrls[i],
                          label: 'Ingredient ${i + 1}',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: _Field(
                          controller: _ingredientSlugCtrls[i],
                          label: 'Product slug (optional)',
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: _ingredientCtrls.length > 1
                            ? () => _removeIngredientRow(i)
                            : null,
                      ),
                    ],
                  ),
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _addIngredientRow,
                  icon: const Icon(Icons.add),
                  label: const Text('Add ingredient'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SectionCard(
            icon: Icons.list_alt_outlined,
            title: 'Steps',
            children: [
              _Field(
                controller: _stepsCtrl,
                label: 'Steps (one per line)',
                maxLines: 8,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SectionCard(
            icon: Icons.visibility_outlined,
            title: 'Visibility & Links',
            children: [
              _ToggleRow(
                icon: Icons.trending_up,
                color: AppColors.turmeric,
                title: 'Trending',
                value: _trending,
                onChanged: (v) => setState(() => _trending = v),
              ),
              const SizedBox(height: 8),
              _ToggleRow(
                icon: Icons.star_outline,
                color: AppColors.maroon,
                title: 'Essential',
                value: _essentials,
                onChanged: (v) => setState(() => _essentials = v),
              ),
              const SizedBox(height: 12),
              _Field(
                controller: _relatedProductsCtrl,
                label: 'Related product slugs (comma-separated)',
              ),
              const SizedBox(height: 12),
              _Field(controller: _videoCtrl, label: 'Video URL (optional)'),
            ],
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: FilledButton.icon(
            onPressed: _submitting ? null : _submit,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
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
                : Icon(_isNew ? Icons.publish : Icons.check),
            label: Text(
              _submitting
                  ? 'Saving…'
                  : (_isNew ? 'Publish Recipe' : 'Save Changes'),
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
  final int maxLines;
  final TextInputType? keyboardType;
  const _Field({
    required this.controller,
    required this.label,
    this.maxLines = 1,
    this.keyboardType,
  });
  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    maxLines: maxLines,
    keyboardType: keyboardType,
    decoration: InputDecoration(labelText: label),
  );
}

class _ToggleRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _ToggleRow({
    required this.icon,
    required this.color,
    required this.title,
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
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
