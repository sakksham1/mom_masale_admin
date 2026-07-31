import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'reviews_api.dart';
import '../../core/network/api_client_provider.dart' show apiClientProvider;

final reviewsApiProvider = Provider(
  (ref) => ReviewsApi(ref.watch(apiClientProvider)),
);

final pendingReviewsProvider = FutureProvider<List<ReviewItem>>((ref) {
  return ref.watch(reviewsApiProvider).fetchReviews(status: 'pending');
});

final approvedReviewsProvider = FutureProvider<List<ReviewItem>>((ref) {
  return ref.watch(reviewsApiProvider).fetchReviews(status: 'approved');
});
