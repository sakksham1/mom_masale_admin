import 'package:flutter/material.dart';
import '../../core/config/env.dart';

/// Safely resolves a product image into a circular avatar. Handles three
/// failure modes that used to crash mid-layout in scrolling/animating
/// lists: empty image strings, relative paths missing a host, and network
/// errors on already-mounted widgets. Uses Image.network + errorBuilder
/// instead of CircleAvatar.backgroundImage, which resolves more
/// predictably inside lists with per-item animations (ExpansionTile,
/// staggered fade-ins, etc).
class ProductAvatar extends StatelessWidget {
  final String image;
  final double radius;
  const ProductAvatar({super.key, required this.image, this.radius = 20});

  String? _resolve() {
    final trimmed = image.trim();
    if (trimmed.isEmpty) return null;
    final uri = Uri.tryParse(trimmed);
    if (uri == null) return null;
    if (uri.hasScheme && uri.hasAuthority) return trimmed;
    final path = trimmed.startsWith('/') ? trimmed : '/$trimmed';
    return '${Env.apiBaseUrl}$path';
  }

  @override
  Widget build(BuildContext context) {
    final size = radius * 2;
    final resolved = _resolve();

    Widget fallback() => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.image_not_supported_outlined, size: 18),
    );

    if (resolved == null) return fallback();

    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: Image.network(
          resolved,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => fallback(),
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return fallback();
          },
        ),
      ),
    );
  }
}
