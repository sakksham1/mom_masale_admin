// lib/features/recipes/recipes_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'recipes_api.dart';
import 'recipes_provider.dart';
import 'recipe_edit_screen.dart';
import '../../core/constants/layout_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/tap_scale.dart';
import '../../shared/widgets/staggered_fade_in.dart';
import '../../shared/widgets/product_avatar.dart';

class RecipesScreen extends ConsumerStatefulWidget {
  const RecipesScreen({super.key});
  @override
  ConsumerState<RecipesScreen> createState() => _RecipesScreenState();
}

class _RecipesScreenState extends ConsumerState<RecipesScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _openNew() async {
    await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(builder: (_) => const RecipeEditScreen(recipe: null)),
    );
    ref.invalidate(recipesProvider);
  }

  @override
  Widget build(BuildContext context) {
    final recipesAsync = ref.watch(recipesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Recipes')),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(
          bottom: LayoutConstants.fabScaffoldExtraPadding,
        ),
        child: FloatingActionButton.extended(
          onPressed: _openNew,
          icon: const Icon(Icons.add),
          label: const Text('New Recipe'),
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
                hintText: 'Search recipes…',
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
              onRefresh: () async => ref.invalidate(recipesProvider),
              child: recipesAsync.when(
                data: (recipes) {
                  final filtered = _query.isEmpty
                      ? recipes
                      : recipes
                            .where(
                              (r) =>
                                  r.title.toLowerCase().contains(
                                    _query.toLowerCase(),
                                  ) ||
                                  r.category.toLowerCase().contains(
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
                              recipes.isEmpty
                                  ? 'No recipes yet.'
                                  : 'No recipes match "$_query".',
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
                      key: ValueKey('recipe_fade_${filtered[i].slug}'),
                      index: i,
                      child: _RecipeTile(
                        key: ValueKey('recipe_${filtered[i].slug}'),
                        recipe: filtered[i],
                      ),
                    ),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) =>
                    Center(child: Text('Could not load recipes: $e')),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecipeTile extends ConsumerWidget {
  final Recipe recipe;
  const _RecipeTile({super.key, required this.recipe});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return TapScale(
      scaleDown: 0.985,
      onTap: () async {
        await Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute(builder: (_) => RecipeEditScreen(recipe: recipe)),
        );
        ref.invalidate(recipesProvider);
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
            ProductAvatar(image: recipe.image, radius: 26),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recipe.title,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${recipe.category} · ${recipe.cuisine}',
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  if (recipe.trending || recipe.essentials) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      children: [
                        if (recipe.trending)
                          const _FlagChip('Trending', AppColors.turmeric),
                        if (recipe.essentials)
                          const _FlagChip('Essential', AppColors.maroon),
                      ],
                    ),
                  ],
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

class _FlagChip extends StatelessWidget {
  final String label;
  final Color color;
  const _FlagChip(this.label, this.color);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color),
    ),
  );
}
