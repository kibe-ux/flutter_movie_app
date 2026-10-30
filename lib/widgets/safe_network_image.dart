import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';

class SafeNetworkImage extends StatelessWidget {
  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final double placeholderIconSize;
  final BorderRadius? borderRadius;

  const SafeNetworkImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholderIconSize = 40,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.grey[850],
          borderRadius: borderRadius,
        ),
        child: Center(
          child: Icon(
            Icons.movie_rounded,
            color: Colors.white54,
            size: placeholderIconSize,
          ),
        ),
      );
    }

    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    final decodeWidth = width != null && width!.isFinite && width! > 0
        ? (width! * pixelRatio).ceil().clamp(1, 1600)
        : null;
    final decodeHeight = height != null && height!.isFinite && height! > 0
        ? (height! * pixelRatio).ceil().clamp(1, 1600)
        : null;
    Widget image = CachedNetworkImage(
      imageUrl: imageUrl!,
      width: width,
      height: height,
      fit: fit,
      memCacheWidth: decodeWidth,
      memCacheHeight: decodeWidth == null ? decodeHeight : null,
      fadeInDuration: const Duration(milliseconds: 120),
      fadeOutDuration: Duration.zero,
      placeholder: (context, url) => _buildLoadingPlaceholder(),
      errorWidget: (context, url, error) => Container(
        width: width,
        height: height,
        color: Colors.grey[850],
        child: Center(
          child: Icon(
            Icons.error_outline,
            color: Colors.white54,
            size: placeholderIconSize,
          ),
        ),
      ),
    );

    if (borderRadius != null) {
      return ClipRRect(
        borderRadius: borderRadius!,
        child: image,
      );
    }

    return image;
  }

  Widget _buildLoadingPlaceholder() {
    final placeholder = Container(
      width: width,
      height: height,
      color: const Color(0xFF20242B),
      child: Center(
        child: Icon(
          Icons.local_movies_rounded,
          color: Colors.white24,
          size: placeholderIconSize,
        ),
      ),
    );

    return Shimmer.fromColors(
      baseColor: const Color(0xFF20242B),
      highlightColor: const Color(0xFF383F4A),
      period: const Duration(milliseconds: 1300),
      child: placeholder,
    );
  }
}
