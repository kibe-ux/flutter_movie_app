import 'package:flutter/material.dart';
import '../utils/cinema_palette.dart';

class CinemaAppBarSurface extends StatelessWidget {
  const CinemaAppBarSurface({super.key, this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: const BoxDecoration(
          gradient: CinemaPalette.appBarGradient,
        ),
        child: child ?? const SizedBox.expand(),
      );
}
