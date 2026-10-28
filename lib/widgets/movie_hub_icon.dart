import 'package:flutter/material.dart';

class MovieHubIcon extends StatelessWidget {
  const MovieHubIcon({super.key, this.size = 96});

  final double size;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.22),
        child: Image.asset(
          'assets/images/popcorn.png',
          width: size,
          height: size,
          fit: BoxFit.cover,
          semanticLabel: 'Movie Hub app icon',
        ),
      );
}
