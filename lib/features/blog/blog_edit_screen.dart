// lib/features/blog/blog_edit_screen.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'blog_api.dart';
import 'blog_provider.dart';
import '../catalog/catalog_provider.dart' show catalogApiProvider;
import '../../core/network/api_exception.dart';
import '../../core/config/env.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/haptics.dart';
import '../../shared/widgets/success_pulse.dart';
import '../../shared/widgets/swipe_confirm_sheet.dart';

class BlogEditScreen extends ConsumerStatefulWidget {
  final BlogPost? post;
  const BlogEditScreen({super.key, required this.post});

  @override
  ConsumerState<BlogEditScreen> createState() => _BlogEditScreenState();
}

class _BlogEditScreenState extends ConsumerState<BlogEditScreen> {
  late final TextEditingController _titleCtrl,
      _descCtrl,
      _bodyCtrl,
      _relatedProductsCtrl,
      _relatedRecipesCtrl;
  late String _category;
  String? _pendingImagePath;
  Uint8List? _pendingImageBytes;
  bool _uploadingImage = false, _submitting = false, _deleting = false;

  bool get _isNew => widget.post == null;

  @override
  void initState() {
    super.initState();
    final p = widget.post;
    _titleCtrl = TextEditingController(text: p?.title ?? '');
    _descCtrl = TextEditingController(text: p?.description ?? '');
    _bodyCtrl = TextEditingController(text: (p?.body ?? []).join('\n\n'));
    _relatedProductsCtrl = TextEditingController(
      text: (p?.relatedProducts ?? []).join(', '),
    );
    _relatedRecipesCtrl = TextEditingController(
      text: (p?.relatedRecipes ?? []).join(', '),
    );
    _category = (p != null && p.category.isNotEmpty)
        ? p.category
        : blogCategories.first;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _bodyCtrl.dispose();
    _relatedProductsCtrl.dispose();
    _relatedRecipesCtrl.dispose();
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
          .uploadImage(bytes, file.name, folder: 'blog');
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
    final body = _bodyCtrl.text
        .split('\n\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    final relatedProducts = _relatedProductsCtrl.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    final relatedRecipes = _relatedRecipesCtrl.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    return {
      'title': _titleCtrl.text.trim(),
      'category': _category,
      'description': _descCtrl.text.trim(),
      'body': body,
      'relatedProducts': relatedProducts,
      'relatedRecipes': relatedRecipes,
      if (_pendingImagePath != null) 'image': _pendingImagePath,
    };
  }

  Future<void> _submit() async {
    final body = _buildBody();
    if ((body['title'] as String).isEmpty ||
        (body['description'] as String).isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title and description are required')),
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
      final api = ref.read(blogApiProvider);
      if (_isNew) {
        await api.create(body);
      } else {
        await api.update(widget.post!.slug, body);
      }
      ref.invalidate(blogPostsProvider);
      Haptics.success();
      if (mounted) {
        await SuccessPulse.show(
          context,
          _isNew ? 'Post published' : 'Post updated',
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
        'Delete "${widget.post!.title}" permanently? This can\'t be undone.',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      swipeLabel: 'Slide to delete',
    );
    if (!confirmed) return;
    setState(() => _deleting = true);
    try {
      await ref.read(blogApiProvider).delete(widget.post!.slug);
      ref.invalidate(blogPostsProvider);
      Haptics.success();
      if (mounted) {
        await SuccessPulse.show(
          context,
          'Post deleted',
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
    final path = _pendingImagePath ?? widget.post?.image ?? '';
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
          _isNew ? 'New Post' : widget.post!.title,
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
                  const Color(0xFF3D6B57).withValues(alpha: 0.10),
                  const Color(0xFF3D6B57).withValues(alpha: 0.02),
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
              Text('Category', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: blogCategories
                    .map(
                      (c) => ChoiceChip(
                        label: Text(c),
                        selected: _category == c,
                        onSelected: (_) => setState(() => _category = c),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 12),
              _Field(controller: _descCtrl, label: 'Description', maxLines: 3),
            ],
          ),
          const SizedBox(height: 16),
          _SectionCard(
            icon: Icons.article_outlined,
            title: 'Body',
            children: [
              _Field(
                controller: _bodyCtrl,
                label: 'Paragraphs (separate with a blank line)',
                maxLines: 10,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SectionCard(
            icon: Icons.link,
            title: 'Related Content',
            children: [
              _Field(
                controller: _relatedProductsCtrl,
                label: 'Related product slugs (comma-separated)',
              ),
              const SizedBox(height: 12),
              _Field(
                controller: _relatedRecipesCtrl,
                label: 'Related recipe slugs (comma-separated)',
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
                  : (_isNew ? 'Publish Post' : 'Save Changes'),
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
  const _Field({
    required this.controller,
    required this.label,
    this.maxLines = 1,
  });
  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    maxLines: maxLines,
    decoration: InputDecoration(labelText: label),
  );
}
