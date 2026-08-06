// lib/features/blog/blog_api.dart
import '../../core/network/api_client.dart';

const blogCategories = [
  'Articles',
  'FAQs',
  'Buying Guides',
  'Cooking Tips',
  'Ingredient Comparisons',
];

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
    slug: j['slug'] ?? '',
    title: j['title'] ?? '',
    category: j['category'] ?? '',
    description: j['description'] ?? '',
    image: j['image'] ?? '',
    imageAlt: j['imageAlt'],
    body: List<String>.from(
      (j['body'] as List? ?? []).map((e) => e.toString()),
    ),
    relatedProducts: List<String>.from(j['relatedProducts'] ?? []),
    relatedRecipes: List<String>.from(j['relatedRecipes'] ?? []),
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
