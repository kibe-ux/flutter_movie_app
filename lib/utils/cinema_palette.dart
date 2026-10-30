import 'package:flutter/material.dart';

class CinemaPalette {
  CinemaPalette._();

  static const background = Color(0xFF0B0A0D);
  static const surface = Color(0xFF171217);
  static const wine = Color(0xFF38131F);
  static const red = Color(0xFFE50914);
  static const gold = Color(0xFFE6BB83);
  static const ivory = Color(0xFFF6F0E8);
  static const muted = Color(0xFFB8ADB4);
  static const homeAccent = Color(0xFFC58B64);
  static const homeMuted = Color(0xFFC5B9B4);
  static const appBarText = Color(0xFFE8D5B5);

  static const homeHeaderGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFF29151C), Color(0xFF1D181C), Color(0xFF121214)],
  );

  static const appBarGradient = homeHeaderGradient;
}
