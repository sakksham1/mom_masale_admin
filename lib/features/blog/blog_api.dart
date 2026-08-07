// lib/features/blog/blog_api.dart
import '../../core/network/api_client.dart';

const blogCategories = [
  'Articles',
  'FAQs',
  'Buying Guides',
  'Cooking Tips',
  'Ingredient Comparisons',
];
String? _asStringOrNull(dynamic v) => v is String ? v : null;
String _asString(dynamic v, [String fallback = '']) =>
    v is String ? v : fallback;
List<String> _asStringList(dynamic v) =>
    v is List ? v.map((e) => e.toString()).toList() : const [];

class BlogPost {
  final String slug, title, category, description, image;
  final String? imageAlt;
  final List<String> body;
  final List<String> relatedProducts, relatedRecipes;

  BlogPost({
    required this.slug,
    required this.title,
    required this.category,
    required this.description,
    required this.image,
    this.imageAlt,
    required this.body,
    required this.relatedProducts,
    required this.relatedRecipes,
  });

  factory BlogPost.fromJson(Map<String, dynamic> j) => BlogPost(
    slug: _asString(j['slug']),
    title: _asString(j['title']),
    category: _asString(j['category']),
    description: _asString(j['description']),
    image: _asString(j['image']),
    imageAlt: _asStringOrNull(j['imageAlt']),
    body: _asStringList(j['body']),
    relatedProducts: _asStringList(j['relatedProducts']),
    relatedRecipes: _asStringList(j['relatedRecipes']),
  );
}

class BlogApi {
  final ApiClient client;
  BlogApi(this.client);

  Future<List<BlogPost>> fetchPosts() async {
    final res = await client.get('/api/admin/blog');
    return (res.data as List)
        .map((p) => BlogPost.fromJson(Map<String, dynamic>.from(p)))
        .toList();
  }

  Future<BlogPost> create(Map<String, dynamic> body) async {
    final res = await client.post('/api/admin/blog', body);
    return BlogPost.fromJson(Map<String, dynamic>.from(res.data['post']));
  }

  Future<BlogPost> update(String slug, Map<String, dynamic> updates) async {
    final res = await client.patch('/api/admin/blog', {
      'slug': slug,
      'updates': updates,
    });
    return BlogPost.fromJson(Map<String, dynamic>.from(res.data['post']));
  }

  Future<void> delete(String slug) {
    return client.delete('/api/admin/blog?slug=${Uri.encodeComponent(slug)}');
  }
}
