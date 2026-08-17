import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/theme/brand_colors.dart';
import '../../../shared/widgets/adaptive_layout.dart';
import '../../../shared/widgets/brand_widgets.dart';

/// The persistent brand header shown on every registration screen.
///
/// Carries the logo/emblem, the wordmark, the current turn ticket badge (e.g. A-001),
/// and the live step indicator so the user always knows where they are in the journey.
class FlowHeader extends StatelessWidget {
  const FlowHeader({
    super.key,
    required this.currentStep,
    required this.totalSteps,
    required this.stepTitles,
    this.turnNumber = 'A-001',
    this.onResetTurn,
    this.onScan,
  });

  final int currentStep;
  final int totalSteps;
  final List<String> stepTitles;
  final String turnNumber;
  final VoidCallback? onResetTurn;

  /// Opens the card scanner. Hidden when null.
  final VoidCallback? onScan;

  @override
  Widget build(BuildContext context) {
    final band = Adaptive.bandOf(context);
    final short = Adaptive.isShort(context);
    final scale = band.scale;

    final vertical = short ? 8.0 : 14.0 * scale;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Material(
        color: BrandColors.pine,
        elevation: 0,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: BrandGradients.pine,
            boxShadow: [
              BoxShadow(
                color: BrandColors.pineDeep.withValues(alpha: 0.28),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: SafeArea(
            bottom: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!short)
                  ResponsiveShell(
                    padding: EdgeInsets.symmetric(
                      horizontal: band.gutter,
                      vertical: vertical,
                    ),
                    child: _BrandRow(
                      band: band,
                      turnNumber: turnNumber,
                      onResetTurn: onResetTurn,
                      onScan: onScan,
                    ),
                  ),
                Container(
                  height: 1,
                  color: BrandColors.gold.withValues(alpha: 0.35),
                ),
                ResponsiveShell(
                  maxWidth: band.isCompact ? double.infinity : 760,
                  padding: EdgeInsets.symmetric(
                    horizontal: band.gutter,
                    vertical: short ? 8 : 12 * scale,
                  ),
                  child: StepIndicator(
                    currentStep: currentStep,
                    titles: stepTitles,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BrandRow extends StatelessWidget {
  const _BrandRow({
    required this.band,
    required this.turnNumber,
    this.onResetTurn,
    this.onScan,
  });

  final ScreenBand band;
  final String turnNumber;
  final VoidCallback? onResetTurn;
  final VoidCallback? onScan;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final logoSize = 42.0 * band.scale;

    return Row(
      children: [
        BrandLogo(size: logoSize),
        SizedBox(width: 12 * band.scale),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'إدارة القوى البشرية',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: (textTheme.titleMedium?.fontSize ?? 15) * band.scale,
                ),
              ),
              Text(
                'رحلة حياة المنتسب · الهوية الرقمية',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.labelSmall?.copyWith(
                  color: BrandColors.goldGlow,
                  fontSize: (textTheme.labelSmall?.fontSize ?? 10) * band.scale,
                ),
              ),
            ],
          ),
        ),
        // Turn ticket pill badge
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: 12 * band.scale,
            vertical: 4 * band.scale,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(BrandRadii.pill),
            border: Border.all(
              color: BrandColors.goldGlow.withValues(alpha: 0.8),
              width: 1.2,
            ),
            color: BrandColors.gold.withValues(alpha: 0.15),
          ),
          child: Text(
            turnNumber,
            style: TextStyle(
              color: BrandColors.goldGlow,
              fontFamily: 'SpaceMono',
              fontWeight: FontWeight.w800,
              fontSize: 13 * band.scale,
              letterSpacing: 0.8,
            ),
          ),
        ),
        if (onResetTurn != null) ...[
          SizedBox(width: 6 * band.scale),
          Tooltip(
            message: 'سحب دور جديد',
            child: Material(
              color: Colors.transparent,
              shape: const CircleBorder(),
              child: InkWell(
                onTap: onResetTurn,
                customBorder: const CircleBorder(),
                child: Padding(
                  padding: EdgeInsets.all(6 * band.scale),
                  child: Icon(
                    Icons.refresh_rounded,
                    size: 20 * band.scale,
                    color: Colors.white70,
                  ),
                ),
              ),
            ),
          ),
        ],
        if (onScan != null) ...[
          SizedBox(width: 6 * band.scale),
          Tooltip(
            message: 'مسح بطاقة',
            child: Material(
              color: BrandColors.gold.withValues(alpha: 0.14),
              shape: const CircleBorder(),
              child: InkWell(
                onTap: onScan,
                customBorder: const CircleBorder(),
                child: Padding(
                  padding: EdgeInsets.all(8 * band.scale),
                  child: Icon(
                    Icons.qr_code_scanner_rounded,
                    size: 20 * band.scale,
                    color: BrandColors.goldGlow,
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Animated horizontal stepper with connected nodes.
class StepIndicator extends StatelessWidget {
  const StepIndicator({
    super.key,
    required this.currentStep,
    required this.titles,
  });

  final int currentStep;
  final List<String> titles;

  @override
  Widget build(BuildContext context) {
    final band = Adaptive.bandOf(context);
    final showLabels = MediaQuery.sizeOf(context).width >= 360;

    return Semantics(
      label: 'الخطوة ${currentStep + 1} من ${titles.length}',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < titles.length; i++) ...[
            _StepNode(
              index: i,
              title: titles[i],
              current: currentStep,
              showLabel: showLabels,
              band: band,
            ),
            if (i != titles.length - 1)
              Expanded(
                child: _Connector(active: i < currentStep, band: band),
              ),
          ],
        ],
      ),
    );
  }
}

class _StepNode extends StatelessWidget {
  const _StepNode({
    required this.index,
    required this.title,
    required this.current,
    required this.showLabel,
    required this.band,
  });

  final int index;
  final String title;
  final int current;
  final bool showLabel;
  final ScreenBand band;

  @override
  Widget build(BuildContext context) {
    final done = index < current;
    final active = index == current;
    final size = 28.0 * band.scale;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: BrandDurations.standard,
          curve: Curves.easeOutCubic,
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: active || done
                ? BrandGradients.gold
                : const LinearGradient(
                    colors: [Color(0xFF24463E), Color(0xFF1D3932)],
                  ),
            border: Border.all(
              color: done || active
                  ? BrandColors.goldGlow
                  : BrandColors.gold.withValues(alpha: 0.4),
              width: 1.4,
            ),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: BrandColors.gold.withValues(alpha: 0.5),
                      blurRadius: 12,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: done
                ? Icon(
                    Icons.check_rounded,
                    size: size * 0.55,
                    color: const Color(0xFF243028),
                  )
                : Text(
                    '${index + 1}',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: active
                              ? const Color(0xFF243028)
                              : BrandColors.goldGlow,
                          fontWeight: FontWeight.w700,
                          fontSize: size * 0.42,
                        ),
                  ),
          ),
        ),
        if (showLabel) ...[
          SizedBox(width: 8 * band.scale),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: active
                      ? Colors.white
                      : Colors.white.withValues(alpha: done ? 0.85 : 0.5),
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  fontSize:
                      (Theme.of(context).textTheme.labelMedium?.fontSize ??
                              11) *
                          band.scale,
                  letterSpacing: 0.3,
                ),
          ),
        ],
      ],
    );
  }
}

class _Connector extends StatelessWidget {
  const _Connector({required this.active, required this.band});

  final bool active;
  final ScreenBand band;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 6 * band.scale),
      child: AnimatedContainer(
        duration: BrandDurations.standard,
        curve: Curves.easeOutCubic,
        height: 2.2,
        decoration: BoxDecoration(
          gradient: active
              ? BrandGradients.gold
              : const LinearGradient(
                  colors: [Color(0xFF2A4F45), Color(0xFF24463E)],
                ),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}
