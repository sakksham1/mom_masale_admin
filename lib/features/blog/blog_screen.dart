// lib/features/blog/blog_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'blog_api.dart';
import 'blog_provider.dart';
import 'blog_edit_screen.dart';
import '../../core/constants/layout_constants.dart';
import '../../shared/widgets/tap_scale.dart';
import '../../shared/widgets/staggered_fade_in.dart';
import '../../shared/widgets/product_avatar.dart';

class BlogScreen extends ConsumerStatefulWidget {
  const BlogScreen({super.key});
  @override
  ConsumerState<BlogScreen> createState() => _BlogScreenState();
}

class _BlogScreenState extends ConsumerState<BlogScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _openNew() async {
    await Navigator.of(
      context,
      rootNavigator: true,
    ).push(MaterialPageRoute(builder: (_) => const BlogEditScreen(post: null)));
    ref.invalidate(blogPostsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final postsAsync = ref.watch(blogPostsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Blog')),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(
          bottom: LayoutConstants.fabScaffoldExtraPadding,
        ),
        child: FloatingActionButton.extended(
          onPressed: _openNew,
          icon: const Icon(Icons.add),
          label: const Text('New Post'),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Search posts…',
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
              onRefresh: () async => ref.invalidate(blogPostsProvider),
              child: postsAsync.when(
                data: (posts) {
                  final filtered = _query.isEmpty
                      ? posts
                      : posts
                            .where(
                              (p) =>
                                  p.title.toLowerCase().contains(
                                    _query.toLowerCase(),
                                  ) ||
                                  p.category.toLowerCase().contains(
                                    _query.toLowerCase(),
                                  ),
                            )
                            .toList();
                  if (filtered.isEmpty) {
                    return ListView(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 64),
                          child: Center(
                            child: Text(
                              posts.isEmpty
                                  ? 'No posts yet.'
                                  : 'No posts match "$_query".',
                            ),
                          ),
                        ),
                      ],
                    );
                  }
                  return ListView.separated(
                    padding: EdgeInsets.fromLTRB(
                      12,
                      4,
                      12,
                      LayoutConstants.navBarClearance +
                          LayoutConstants.fabScaffoldExtraPadding,
                    ),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, i) => StaggeredFadeIn(
                      key: ValueKey('blog_fade_${filtered[i].slug}'),
                      index: i,
                      child: _BlogTile(
                        key: ValueKey('blog_${filtered[i].slug}'),
                        post: filtered[i],
                      ),
                    ),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) =>
                    Center(child: Text('Could not load posts: $e')),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BlogTile extends ConsumerWidget {
  final BlogPost post;
  const _BlogTile({super.key, required this.post});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return TapScale(
      scaleDown: 0.985,
      onTap: () async {
        await Navigator.of(
          context,
          rootNavigator: true,
        ).push(MaterialPageRoute(builder: (_) => BlogEditScreen(post: post)));
        ref.invalidate(blogPostsProvider);
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          children: [
            ProductAvatar(image: post.image, radius: 26),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post.title,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    post.category,
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
