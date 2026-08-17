import 'package:flutter/material.dart';

/// Brand palette for the A Digital Identity system.
///
/// The two hero colors — deep pine `#17352F` and imperial gold `#B9A779` —
/// define every surface, ornament and accent in the experience.
abstract final class BrandColors {
  static const Color pine = Color(0xFF17352F);
  static const Color pineDeep = Color(0xFF0E231F);
  static const Color pineRaised = Color(0xFF1E453C);
  static const Color pineSoft = Color(0xFFDDE8E3);
  static const Color pineMist = Color(0xFFEEF4F0);

  static const Color gold = Color(0xFFB9A779);
  static const Color goldDeep = Color(0xFF8A7443);
  static const Color goldSoft = Color(0xFFE9E1CC);
  static const Color goldMist = Color(0xFFF6F1E4);
  static const Color goldGlow = Color(0xFFD9C79B);

  static const Color ivory = Color(0xFFFAF7EF);
  static const Color ivoryDeep = Color(0xFFF3EDDD);
  static const Color surface = Color(0xFFFFFFFF);

  static const Color ink = Color(0xFF16211E);
  static const Color inkMuted = Color(0xFF5C6B66);
  static const Color outline = Color(0xFFDCD5C4);
  static const Color outlineSoft = Color(0xFFEAE4D5);
  static const Color error = Color(0xFFB3261E);
  static const Color success = Color(0xFF2E7D5B);
}

abstract final class BrandDurations {
  static const Duration micro = Duration(milliseconds: 120);
  static const Duration quick = Duration(milliseconds: 220);
  static const Duration standard = Duration(milliseconds: 380);
  static const Duration slow = Duration(milliseconds: 640);
  static const Duration splash = Duration(milliseconds: 2600);
}

abstract final class BrandRadii {
  static const double small = 10;
  static const double medium = 16;
  static const double large = 24;
  static const double extraLarge = 32;
  static const double pill = 999;
}

abstract final class BrandGradients {
  static const LinearGradient pine = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [BrandColors.pineRaised, BrandColors.pine, BrandColors.pineDeep],
  );

  static const LinearGradient gold = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [BrandColors.gold, BrandColors.goldGlow, BrandColors.gold],
  );

  static const LinearGradient goldPine = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [BrandColors.goldDeep, BrandColors.gold],
  );

  static LinearGradient pineGlow = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      BrandColors.pine.withValues(alpha: 0.10),
      BrandColors.pine.withValues(alpha: 0.0),
    ],
  );
}
