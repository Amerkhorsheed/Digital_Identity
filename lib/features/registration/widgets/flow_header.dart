import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/theme/brand_colors.dart';
import '../../../shared/widgets/adaptive_layout.dart';
import '../../../shared/widgets/brand_widgets.dart';

/// The persistent brand header shown on every registration screen.
///
/// Carries the A logo, the product wordmark and the live step indicator so the
/// user always knows where they are in the journey.
///
/// The pine block paints edge-to-edge *behind* the status bar / notch while its
/// content sits inside the safe area, so the header lines up with the physical
/// top of the screen on every device instead of sliding under the clock.
class FlowHeader extends StatelessWidget {
  const FlowHeader({
    super.key,
    required this.currentStep,
    required this.totalSteps,
    required this.stepTitles,
    this.onScan,
  });

  final int currentStep;
  final int totalSteps;
  final List<String> stepTitles;

  /// Opens the card scanner. Hidden when null.
  final VoidCallback? onScan;

  @override
  Widget build(BuildContext context) {
    final band = Adaptive.bandOf(context);
    final short = Adaptive.isShort(context);
    final scale = band.scale;

    // On a short screen (phone landscape, keyboard open) the brand row folds
    // away and only the stepper stays, so the form keeps the room it needs.
    final vertical = short ? 10.0 : 16.0 * scale;

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
                    child: _BrandRow(band: band, onScan: onScan),
                  ),
                Container(
                  height: 1,
                  color: BrandColors.gold.withValues(alpha: 0.35),
                ),
                ResponsiveShell(
                  // The stepper stays compact on wide screens; stretched to a
                  // TV's full width the connectors would swamp the nodes.
                  maxWidth: band.isCompact ? double.infinity : 760,
                  padding: EdgeInsets.symmetric(
                    horizontal: band.gutter,
                    vertical: short ? 10 : 14 * scale,
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
  const _BrandRow({required this.band, this.onScan});

  final ScreenBand band;
  final VoidCallback? onScan;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final logoSize = 44.0 * band.scale;

    return Row(
      children: [
        BrandLogo(size: logoSize),
        SizedBox(width: 14 * band.scale),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'الهوية الرقمية',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: (textTheme.titleMedium?.fontSize ?? 16) * band.scale,
                ),
              ),
              Text(
                'مركز التسجيل والإصدار',
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
        if (band.isWide) ...[
          _SecurityBadge(band: band),
          SizedBox(width: 8 * band.scale),
        ],
        if (onScan != null)
          Tooltip(
            message: 'مسح بطاقة',
            child: Material(
              color: BrandColors.gold.withValues(alpha: 0.14),
              shape: const CircleBorder(),
              child: InkWell(
                onTap: onScan,
                customBorder: const CircleBorder(),
                child: Padding(
                  padding: EdgeInsets.all(10 * band.scale),
                  child: Icon(
                    Icons.qr_code_scanner_rounded,
                    size: 22 * band.scale,
                    color: BrandColors.goldGlow,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Tablet-and-up trust badge beside the wordmark.
class _SecurityBadge extends StatelessWidget {
  const _SecurityBadge({required this.band});

  final ScreenBand band;

  @override
  Widget build(BuildContext context) {
    final labelStyle = Theme.of(context).textTheme.labelSmall;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 14 * band.scale,
        vertical: 8 * band.scale,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: BrandColors.gold.withValues(alpha: 0.6)),
        color: BrandColors.gold.withValues(alpha: 0.10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.verified_user_outlined,
            size: 16 * band.scale,
            color: BrandColors.goldGlow,
          ),
          SizedBox(width: 8 * band.scale),
          Text(
            'آمن · مشفّر · موثّق',
            maxLines: 1,
            style: labelStyle?.copyWith(
              color: BrandColors.goldGlow,
              fontSize: (labelStyle.fontSize ?? 10) * band.scale,
            ),
          ),
        ],
      ),
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
    // Labels only fit beside the nodes once there is real horizontal room.
    final showLabels = MediaQuery.sizeOf(context).width >= 420;

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
    final size = 32.0 * band.scale;

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
                      blurRadius: 14,
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
          SizedBox(width: 10 * band.scale),
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
                  letterSpacing: 0.4,
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
      padding: EdgeInsets.symmetric(horizontal: 8 * band.scale),
      child: AnimatedContainer(
        duration: BrandDurations.standard,
        curve: Curves.easeOutCubic,
        height: 2.4,
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
