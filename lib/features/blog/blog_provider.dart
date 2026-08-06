// lib/features/blog/blog_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'blog_api.dart';
import '../../core/network/api_client_provider.dart' show apiClientProvider;

final blogApiProvider = Provider(
  (ref) => BlogApi(ref.watch(apiClientProvider)),
);

final blogPostsProvider = FutureProvider<List<BlogPost>>((ref) {
  return ref.watch(blogApiProvider).fetchPosts();
});
