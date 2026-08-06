// lib/features/recipes/recipes_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'recipes_api.dart';
import '../../core/network/api_client_provider.dart' show apiClientProvider;

final recipesApiProvider = Provider(
  (ref) => RecipesApi(ref.watch(apiClientProvider)),
);

final recipesProvider = FutureProvider<List<Recipe>>((ref) {
  return ref.watch(recipesApiProvider).fetchRecipes();
});
