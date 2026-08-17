import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

import 'brand_colors.dart';

/// Material 3 theme tuned for the A Digital Identity brand.
///
/// Designed to look and feel premium across phones, tablets and TV:
/// generous hit targets, high contrast, and clear focus states for
/// remote/keyboard navigation.
abstract final class AppTheme {
  static const String displayFont = 'Almarai';
  static const String monoFont = 'SpaceMono';

  static ThemeData get light => _buildLight();

  static ThemeData _buildLight() {
    final colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: BrandColors.pine,
      onPrimary: Colors.white,
      primaryContainer: BrandColors.pineSoft,
      onPrimaryContainer: BrandColors.pineDeep,
      secondary: BrandColors.goldDeep,
      onSecondary: Colors.white,
      secondaryContainer: BrandColors.goldSoft,
      onSecondaryContainer: const Color(0xFF3E3415),
      error: BrandColors.error,
      onError: Colors.white,
      surface: BrandColors.surface,
      onSurface: BrandColors.ink,
      onSurfaceVariant: BrandColors.inkMuted,
      surfaceContainerLowest: BrandColors.surface,
      surfaceContainerLow: BrandColors.ivory,
      surfaceContainer: BrandColors.ivoryDeep,
      surfaceContainerHigh: const Color(0xFFEDE7D7),
      surfaceContainerHighest: const Color(0xFFE3DCC9),
      outline: BrandColors.outline,
      outlineVariant: BrandColors.outlineSoft,
      shadow: const Color(0x3317352F),
      scrim: const Color(0x8A0E231F),
      inverseSurface: BrandColors.pine,
      onInverseSurface: BrandColors.ivory,
      inversePrimary: BrandColors.goldGlow,
      surfaceTint: Colors.transparent,
    );

    final textTheme = _textTheme(BrandColors.ink);

    final fieldBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(BrandRadii.medium),
      borderSide: const BorderSide(color: BrandColors.outlineSoft),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: BrandColors.ivory,
      canvasColor: BrandColors.ivory,
      splashFactory: InkRipple.splashFactory,
      highlightColor: BrandColors.gold.withValues(alpha: 0.10),
      hoverColor: BrandColors.pine.withValues(alpha: 0.04),
      focusColor: BrandColors.gold.withValues(alpha: 0.16),
      disabledColor: BrandColors.inkMuted.withValues(alpha: 0.38),
      textTheme: textTheme,
      primaryTextTheme: _textTheme(Colors.white),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: Colors.transparent,
        foregroundColor: BrandColors.ink,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleLarge,
        iconTheme: const IconThemeData(color: BrandColors.pine, size: 24),
      ),
      cardTheme: CardThemeData(
        color: BrandColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BrandRadii.large),
          side: const BorderSide(color: BrandColors.outlineSoft),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: BrandColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(color: BrandColors.inkMuted),
        labelStyle: textTheme.bodyMedium,
        floatingLabelStyle: textTheme.bodySmall?.copyWith(
          color: BrandColors.pine,
          fontWeight: FontWeight.w600,
        ),
        prefixIconColor: BrandColors.goldDeep,
        suffixIconColor: BrandColors.inkMuted,
        border: fieldBorder,
        enabledBorder: fieldBorder,
        disabledBorder: fieldBorder,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(BrandRadii.medium),
          borderSide: const BorderSide(color: BrandColors.pine, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(BrandRadii.medium),
          borderSide: const BorderSide(color: BrandColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(BrandRadii.medium),
          borderSide: const BorderSide(color: BrandColors.error, width: 1.8),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: BrandColors.outlineSoft,
        thickness: 1,
        space: 1,
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: BrandColors.pine,
        textColor: BrandColors.ink,
        contentPadding: EdgeInsets.symmetric(horizontal: 16),
        minVerticalPadding: 12,
      ),
      iconTheme: const IconThemeData(color: BrandColors.pine, size: 24),
      chipTheme: ChipThemeData(
        backgroundColor: BrandColors.surface,
        selectedColor: BrandColors.goldMist,
        disabledColor: BrandColors.ivoryDeep,
        labelStyle: textTheme.labelLarge,
        secondaryLabelStyle: textTheme.labelLarge?.copyWith(
          color: BrandColors.goldDeep,
        ),
        side: const BorderSide(color: BrandColors.outlineSoft),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        showCheckmark: false,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: BrandColors.pine,
          foregroundColor: Colors.white,
          disabledBackgroundColor: BrandColors.ivoryDeep,
          disabledForegroundColor: BrandColors.inkMuted,
          minimumSize: const Size(64, 52),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: textTheme.labelLarge?.copyWith(
            fontFamily: displayFont,
            fontWeight: FontWeight.w600,
          ),
          shape: const StadiumBorder(),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: BrandColors.pine,
          minimumSize: const Size(64, 52),
          side: const BorderSide(color: BrandColors.pine, width: 1.4),
          shape: const StadiumBorder(),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: BrandColors.pine,
          textStyle: textTheme.labelLarge,
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: BrandColors.gold,
        linearTrackColor: BrandColors.goldSoft,
        circularTrackColor: BrandColors.goldSoft,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: BrandColors.surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: BrandColors.surface,
        modalBarrierColor: Color(0x8A0E231F),
        showDragHandle: true,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: BrandColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BrandRadii.extraLarge),
          side: const BorderSide(color: BrandColors.outlineSoft),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: BrandColors.pine,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BrandRadii.medium),
        ),
      ),
      pageTransitionsTheme: PageTransitionsTheme(
        builders: {
          TargetPlatform.android: const ZoomPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: const ZoomPageTransitionsBuilder(),
          TargetPlatform.linux: const ZoomPageTransitionsBuilder(),
        },
      ),
    );
  }

  static TextTheme _textTheme(Color color) {
    TextStyle style({
      required double size,
      required FontWeight weight,
      double height = 1.35,
      double? letterSpacing,
    }) {
      return TextStyle(
        color: color,
        fontFamily: displayFont,
        fontSize: size,
        fontWeight: weight,
        height: height,
        letterSpacing: letterSpacing,
      );
    }

    return TextTheme(
      displayLarge: style(size: 44, weight: FontWeight.w700, height: 1.15),
      displayMedium: style(size: 36, weight: FontWeight.w700, height: 1.18),
      displaySmall: style(size: 30, weight: FontWeight.w700, height: 1.22),
      headlineLarge: style(size: 26, weight: FontWeight.w700, height: 1.28),
      headlineMedium: style(size: 22, weight: FontWeight.w700, height: 1.32),
      headlineSmall: style(size: 19, weight: FontWeight.w700, height: 1.36),
      titleLarge: style(size: 18, weight: FontWeight.w700, height: 1.40),
      titleMedium: style(size: 16, weight: FontWeight.w600, height: 1.42),
      titleSmall: style(size: 14, weight: FontWeight.w600, height: 1.42),
      bodyLarge: style(size: 16, weight: FontWeight.w400, height: 1.65),
      bodyMedium: style(size: 14, weight: FontWeight.w400, height: 1.60),
      bodySmall: style(size: 12, weight: FontWeight.w400, height: 1.55),
      labelLarge: style(size: 13, weight: FontWeight.w600, height: 1.35),
      labelMedium: style(size: 11, weight: FontWeight.w600, height: 1.35),
      labelSmall: style(size: 10, weight: FontWeight.w600, height: 1.30),
    );
  }
}
