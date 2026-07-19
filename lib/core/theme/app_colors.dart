import 'package:flutter/material.dart';

/// Brand palette for Mom Masale — grounded in the spice tin, not a generic
/// Material default. Used as the seed/fallback when the phone doesn't
/// support dynamic (Material You) color.
class AppColors {
  AppColors._();

  static const Color maroon = Color(0xFF7B1120); // dried chili — primary
  static const Color turmeric = Color(
    0xFFD9A441,
  ); // turmeric gold — accent/signature
  static const Color paprika = Color(
    0xFFC1502E,
  ); // burnt paprika — sparing highlight
  static const Color cumin = Color(0xFF4A3226); // roasted cumin — warm ink
  static const Color parchment = Color(
    0xFFF7EFE1,
  ); // parchment — light background
  static const Color charcoal = Color(
    0xFF241713,
  ); // roasted charcoal — dark background
}
