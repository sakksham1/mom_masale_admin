import '../../core/network/api_client.dart';

class ProductSize {
  final String size;
  final int price;
  final int stockQty;

  ProductSize({
    required this.size,
    required this.price,
    required this.stockQty,
  });

  factory ProductSize.fromJson(Map<String, dynamic> j) => ProductSize(
    size: j['size'],
    price: j['price'],
    stockQty: j['stock_qty'] ?? 0,
  );
}

class Product {
  final int id;
  final String slug, name, category, image;
  final bool comingSoon, featured, bestseller, newArrival;
  final List<ProductSize> sizes;

  Product({
    required this.id,
    required this.slug,
    required this.name,
    required this.category,
    required this.image,
    required this.comingSoon,
    required this.featured,
    required this.bestseller,
    required this.newArrival,
    required this.sizes,
  });

  int get totalStock => sizes.fold(0, (sum, s) => sum + s.stockQty);
  bool get anyLowStock => sizes.any((s) => s.stockQty > 0 && s.stockQty <= 10);
  bool get anyOutOfStock => sizes.any((s) => s.stockQty == 0);

  factory Product.fromJson(Map<String, dynamic> j) => Product(
    id: j['id'],
    slug: j['slug'],
    name: j['name'],
    category: j['category'],
    image: j['image'] ?? '',
    comingSoon: j['coming_soon'] == 1 || j['coming_soon'] == true,
    featured: j['featured'] == 1 || j['featured'] == true,
    bestseller: j['bestseller'] == 1 || j['bestseller'] == true,
    newArrival: j['new_arrival'] == 1 || j['new_arrival'] == true,
    sizes: (j['sizes'] as List? ?? [])
        .map((s) => ProductSize.fromJson(s))
        .toList(),
  );
}

const productStockAdjustReasons = [
  'restock',
  'adjustment',
  'damaged',
  'correction',
];

class ProductsApi {
  final ApiClient client;
  ProductsApi(this.client);

  Future<List<Product>> fetchProducts() async {
    final res = await client.get('/api/admin/products');
    return (res.data['products'] as List)
        .map((p) => Product.fromJson(p))
        .toList();
  }

  /// warehouser-only on the backend. Doesn't change stock immediately — files
  /// a pending product_stock_transactions row that a manager/admin approves
  /// via /api/manager/approvals/decide. Mirrors RawMaterialsApi.submitAdjustment.
  Future<void> submitStockAdjustment({
    required int productId,
    required String size,
    required int changeQty,
    required String reason,
    String? note,
  }) {
    return client.post('/api/warehouse/products/adjust', {
      'productId': productId,
      'size': size,
      'changeQty': changeQty,
      'reason': reason,
      if (note != null && note.isNotEmpty) 'note': note,
    });
  }
}
