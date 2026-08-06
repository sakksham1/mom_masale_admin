// lib/features/recipes/recipes_api.dart
import '../../core/network/api_client.dart';

class RecipeIngredient {
  String text;
  String? productSlug;
  RecipeIngredient({required this.text, this.productSlug});

  factory RecipeIngredient.fromJson(dynamic j) {
    if (j is String) return RecipeIngredient(text: j);
    final m = Map<String, dynamic>.from(j as Map);
    return RecipeIngredient(
      text: (m['text'] ?? m['name'] ?? '').toString(),
      productSlug: m['productSlug'],
    );
  }
}

class Recipe {
  final String slug, title, category, cuisine, description, image;
  final String? imageAlt, prepTime, cookTime, video;
  final int servings;
  final bool trending, essentials;
  final List<RecipeIngredient> ingredients;
  final List<String> steps;
  final List<String> relatedProducts;

  Recipe({
    required this.slug,
    required this.title,
    required this.category,
    required this.cuisine,
    required this.description,
    required this.image,
    this.imageAlt,
    this.prepTime,
    this.cookTime,
    this.video,
    required this.servings,
    required this.trending,
    required this.essentials,
    required this.ingredients,
    required this.steps,
    required this.relatedProducts,
  });

  factory Recipe.fromJson(Map<String, dynamic> j) => Recipe(
    slug: j['slug'] ?? '',
    title: j['title'] ?? '',
    category: j['category'] ?? '',
    cuisine: j['cuisine'] ?? 'Indian',
    description: j['description'] ?? '',
    image: j['image'] ?? '',
    imageAlt: j['imageAlt'],
    prepTime: j['prepTime'],
    cookTime: j['cookTime'],
    video: j['video'],
    servings: j['servings'] is int
        ? j['servings']
        : int.tryParse('${j['servings']}') ?? 4,
    trending: j['trending'] == true,
    essentials: j['essentials'] == true,
    ingredients: (j['ingredients'] as List? ?? [])
        .map((e) => RecipeIngredient.fromJson(e))
        .toList(),
    steps: List<String>.from(
      (j['steps'] as List? ?? []).map((e) => e.toString()),
    ),
    relatedProducts: List<String>.from(j['relatedProducts'] ?? []),
  );
}

class RecipesApi {
  final ApiClient client;
  RecipesApi(this.client);

  Future<List<Recipe>> fetchRecipes() async {
    final res = await client.get('/api/admin/recipes');
    return (res.data as List)
        .map((r) => Recipe.fromJson(Map<String, dynamic>.from(r)))
        .toList();
  }

  Future<Recipe> create(Map<String, dynamic> body) async {
    final res = await client.post('/api/admin/recipes', body);
    return Recipe.fromJson(Map<String, dynamic>.from(res.data['recipe']));
  }

  Future<Recipe> update(String slug, Map<String, dynamic> updates) async {
    final res = await client.patch('/api/admin/recipes', {
      'slug': slug,
      'updates': updates,
    });
    return Recipe.fromJson(Map<String, dynamic>.from(res.data['recipe']));
  }

  Future<void> delete(String slug) {
    return client.delete(
      '/api/admin/recipes?slug=${Uri.encodeComponent(slug)}',
    );
  }
}
