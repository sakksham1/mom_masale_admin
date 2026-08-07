// lib/features/recipes/recipes_api.dart
import '../../core/network/api_client.dart';

/// Backend data (data/recipes.json) is hand-edited JSON, not schema-checked —
/// a stray object where a string is expected (imageAlt/prepTime/cookTime/
/// video/productSlug) used to crash the whole Recipes screen with a cast
/// error. These coerce defensively instead of throwing.
String? _asStringOrNull(dynamic v) => v is String ? v : null;
String _asString(dynamic v, [String fallback = '']) =>
    v is String ? v : fallback;
List<dynamic> _asList(dynamic v) => v is List ? v : const [];
List<String> _asStringList(dynamic v) =>
    v is List ? v.map((e) => e.toString()).toList() : const [];

class RecipeIngredient {
  String text;
  String? productSlug;
  RecipeIngredient({required this.text, this.productSlug});

  factory RecipeIngredient.fromJson(dynamic j) {
    if (j is String) return RecipeIngredient(text: j);
    if (j is! Map) return RecipeIngredient(text: j?.toString() ?? '');
    final m = Map<String, dynamic>.from(j);
    final rawText = m['text'] ?? m['name'];
    return RecipeIngredient(
      text: rawText is String ? rawText : (rawText?.toString() ?? ''),
      productSlug: _asStringOrNull(m['productSlug']),
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
    slug: _asString(j['slug']),
    title: _asString(j['title']),
    category: _asString(j['category']),
    cuisine: _asString(j['cuisine'], 'Indian'),
    description: _asString(j['description']),
    image: _asString(j['image']),
    imageAlt: _asStringOrNull(j['imageAlt']),
    prepTime: _asStringOrNull(j['prepTime']),
    cookTime: _asStringOrNull(j['cookTime']),
    video: _asStringOrNull(j['video']),
    servings: j['servings'] is int
        ? j['servings']
        : int.tryParse('${j['servings']}') ?? 4,
    trending: j['trending'] == true,
    essentials: j['essentials'] == true,
    ingredients: _asList(
      j['ingredients'],
    ).map((e) => RecipeIngredient.fromJson(e)).toList(),
    steps: _asStringList(j['steps']),
    relatedProducts: _asStringList(j['relatedProducts']),
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
