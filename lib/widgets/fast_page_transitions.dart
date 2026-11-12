import 'package:flutter/cupertino.dart';

/// Short transitions retain native back-swipe behavior without Android's zoom.
class FastPageTransitionsBuilder extends CupertinoPageTransitionsBuilder {
  const FastPageTransitionsBuilder();

  @override
  Duration get transitionDuration => const Duration(milliseconds: 120);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 100);
}
