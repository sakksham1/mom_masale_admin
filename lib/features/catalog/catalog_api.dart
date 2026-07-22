import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import '../../core/network/api_client.dart';

class CatalogSize {
  final String size;
  final num price;
  final int stockQty;
  CatalogSize({
    required this.size,
    required this.price,
    required this.stockQty,
  });

  factory CatalogSize.fromJson(Map<String, dynamic> j) => CatalogSize(
    size: j['size'],
    price: j['price'] ?? 0,
    stockQty: j['stock_qty'] ?? 0,
  );
}

class CatalogFaq {
  final String question, answer;
  CatalogFaq({required this.question, required this.answer});
  factory CatalogFaq.fromJson(Map<String, dynamic> j) =>
      CatalogFaq(question: j['question'] ?? '', answer: j['answer'] ?? '');
}

class CatalogSeo {
  final String title, metaDescription, shortDescription, longDescription;
  final List<String> keywords;
  CatalogSeo({
    required this.title,
    required this.metaDescription,
    required this.shortDescription,
    required this.longDescription,
    required this.keywords,
  });

  factory CatalogSeo.fromRow(Map<String, dynamic> j) {
    List<String> kw = [];
    final raw = j['seo_keywords'];
    if (raw is String && raw.isNotEmpty) {
      try {
        kw = List<String>.from(jsonDecode(raw));
      } catch (_) {}
    } else if (raw is List) {
      kw = List<String>.from(raw);
    }
    return CatalogSeo(
      title: j['seo_title'] ?? '',
      metaDescription: j['seo_meta_description'] ?? '',
      shortDescription: j['seo_short_description'] ?? '',
      longDescription: j['seo_long_description'] ?? '',
      keywords: kw,
    );
  }
}

class CatalogProduct {
  final int id;
  final String slug, name, category, image;
  final String? imageAlt, amazonUrl, flipkartUrl, meeshoUrl;
  final bool comingSoon, featured, bestseller, newArrival;
  final CatalogSeo seo;
  final List<CatalogSize> sizes;
  final List<String> aliases;
  final List<CatalogFaq> faq;
  final List<String> relatedProducts;

  CatalogProduct({
    required this.id,
    required this.slug,
    required this.name,
    required this.category,
    required this.image,
    this.imageAlt,
    this.amazonUrl,
    this.flipkartUrl,
    this.meeshoUrl,
    required this.comingSoon,
    required this.featured,
    required this.bestseller,
    required this.newArrival,
    required this.seo,
    required this.sizes,
    required this.aliases,
    required this.faq,
    required this.relatedProducts,
  });

  factory CatalogProduct.fromJson(Map<String, dynamic> j) => CatalogProduct(
    id: j['id'],
    slug: j['slug'],
    name: j['name'],
    category: j['category'] ?? '',
    image: j['image'] ?? '',
    imageAlt: j['image_alt'],
    amazonUrl: j['amazon_url'],
    flipkartUrl: j['flipkart_url'],
    meeshoUrl: j['meesho_url'],
    comingSoon: j['coming_soon'] == 1 || j['coming_soon'] == true,
    featured: j['featured'] == 1 || j['featured'] == true,
    bestseller: j['bestseller'] == 1 || j['bestseller'] == true,
    newArrival: j['new_arrival'] == 1 || j['new_arrival'] == true,
    seo: CatalogSeo.fromRow(j),
    sizes: (j['sizes'] as List? ?? [])
        .map((s) => CatalogSize.fromJson(s))
        .toList(),
    aliases: List<String>.from(j['aliases'] ?? []),
    faq: (j['faq'] as List? ?? []).map((f) => CatalogFaq.fromJson(f)).toList(),
    relatedProducts: List<String>.from(j['related_products'] ?? []),
  );
}

MediaType _mediaTypeFor(String filename) {
  final lower = filename.toLowerCase();
  if (lower.endsWith('.png')) return MediaType('image', 'png');
  if (lower.endsWith('.jpg') || lower.endsWith('.jpeg'))
    return MediaType('image', 'jpeg');
  return MediaType('image', 'webp');
}

class CatalogApi {
  final ApiClient client;
  CatalogApi(this.client);

  Future<List<CatalogProduct>> fetchProducts() async {
    final res = await client.get('/api/admin/products');
    return (res.data['products'] as List)
        .map((p) => CatalogProduct.fromJson(p))
        .toList();
  }

  /// Admin only on the backend — applies immediately and re-syncs the site.
  Future<void> updateDirect(String slug, Map<String, dynamic> updates) {
    return client.patch('/api/admin/products', {
      'slug': slug,
      'updates': updates,
    });
  }

  /// Manager (or admin) — files a pending change; nothing goes live until
  /// an admin approves it via the Approvals screen.
  Future<void> requestUpdate(int productId, Map<String, dynamic> updates) {
    return client.post('/api/product-core/request', {
      'productId': productId,
      'updates': updates,
    });
  }

  /// Uploads a photo (admin or manager) and returns the D1-relative image
  /// path to use as the `image` field in an update/request.
  Future<String> uploadImage(
    List<int> bytes,
    String filename, {
    String folder = 'products',
  }) async {
    final form = FormData.fromMap({
      'folder': folder,
      'file': MultipartFile.fromBytes(
        bytes,
        filename: filename,
        contentType: _mediaTypeFor(filename),
      ),
    });
    final res = await client.postMultipart('/api/admin/upload', form);
    return res.data['path'] as String;
  }
}
