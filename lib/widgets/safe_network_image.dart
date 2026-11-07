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

    return LayoutBuilder(builder: (context, constraints) {
      final pixelRatio = MediaQuery.devicePixelRatioOf(context);
      // AspectRatio/grid children usually don't pass an explicit width. Use
      // their layout bounds so they don't decode full-size images unnecessarily.
      final layoutWidth =
          width ?? (constraints.hasBoundedWidth ? constraints.maxWidth : 180);
      final logicalWidth =
          layoutWidth.isFinite && layoutWidth > 0 ? layoutWidth : 180.0;
      // Buckets reuse decoded images when card widths differ by a few pixels.
      final decodeWidth =
          ((logicalWidth * pixelRatio / 64).ceil() * 64).clamp(64, 1280);
      Widget image = CachedNetworkImage(
        imageUrl: imageUrl!,
        width: width,
        height: height,
        fit: fit,
        memCacheWidth: decodeWidth,
        fadeInDuration: const Duration(milliseconds: 50),
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
    });
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
