import '../../core/network/api_client.dart';

class ReviewItem {
  final int id;
  final int rating;
  final String? title;
  final String body;
  final List<String> images;
  final bool verifiedPurchase;
  final String createdAt;
  final String productSlug, productName;
  final int userId;
  final String userName, userEmail;

  ReviewItem({
    required this.id,
    required this.rating,
    this.title,
    required this.body,
    required this.images,
    required this.verifiedPurchase,
    required this.createdAt,
    required this.productSlug,
    required this.productName,
    required this.userId,
    required this.userName,
    required this.userEmail,
  });

  factory ReviewItem.fromJson(Map<String, dynamic> j) => ReviewItem(
    id: j['id'],
    rating: j['rating'] ?? 0,
    title: j['title'],
    body: j['body'] ?? '',
    images: List<String>.from(j['images'] ?? []),
    verifiedPurchase:
        j['verified_purchase'] == 1 || j['verified_purchase'] == true,
    createdAt: j['created_at'] ?? '',
    productSlug: j['product_slug'] ?? '',
    productName: j['product_name'] ?? '',
    userId: j['user_id'] ?? 0,
    userName: j['user_name'] ?? 'Unknown',
    userEmail: j['user_email'] ?? '',
  );
}

class ReviewsApi {
  final ApiClient client;
  ReviewsApi(this.client);

  Future<List<ReviewItem>> fetchReviews({String status = 'pending'}) async {
    final res = await client.get(
      '/api/admin/reviews',
      query: {'status': status},
    );
    return (res.data['reviews'] as List)
        .map((r) => ReviewItem.fromJson(r))
        .toList();
  }

  /// admin-only on the backend. Approve syncs live to the site; reject
  /// hard-deletes the review row + its R2 images server-side.
  Future<void> decide({
    required int reviewId,
    required String decision, // 'approved' | 'rejected'
    String? reason,
  }) {
    return client.patch('/api/admin/reviews', {
      'reviewId': reviewId,
      'decision': decision,
      if (reason != null && reason.isNotEmpty) 'reason': reason,
    });
  }
}
