import 'package:flutter/material.dart';

import '../../app/theme/brand_colors.dart';
import 'adaptive_layout.dart';

/// Circular brand logo — the A mark inside a gold-ringed pine disc.
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.size = 56, this.ringed = true});

  final double size;
  final bool ringed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.12),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: BrandGradients.pine,
        border: ringed
            ? Border.all(color: BrandColors.gold, width: size * 0.05)
            : null,
        boxShadow: [
          BoxShadow(
            color: BrandColors.pine.withValues(alpha: 0.28),
            blurRadius: size * 0.35,
            offset: Offset(0, size * 0.1),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.2),
        child: Image.asset('assets/A.jpg', fit: BoxFit.cover),
      ),
    );
  }
}

/// Gold-gradient primary action button with a shine sweep on hover/focus.
class BrandButton extends StatefulWidget {
  const BrandButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.destructive = false,
    this.large = false,
    this.muted = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool destructive;
  final bool large;

  /// Visually de-emphasised but still tappable — used when a step is
  /// incomplete, so tapping surfaces *which* field is missing instead of
  /// leaving the user with a dead button and no explanation.
  final bool muted;

  @override
  State<BrandButton> createState() => _BrandButtonState();
}

class _BrandButtonState extends State<BrandButton> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null && !widget.muted;
    final textTheme = Theme.of(context).textTheme;
    final highlighted = _hovered || _focused;

    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.icon != null) ...[
          Icon(
            widget.icon,
            size: widget.large ? 24 : 20,
            color: enabled ? const Color(0xFF243028) : null,
          ),
          const SizedBox(width: 10),
        ],
        Text(
          widget.label,
          style: textTheme.labelLarge?.copyWith(
            color: enabled
                ? (widget.destructive ? Colors.white : const Color(0xFF243028))
                : null,
            fontSize: widget.large ? 16 : 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );

    final band = Adaptive.bandOf(context);
    final height = (widget.large ? 58.0 : 50.0) * band.scale;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: FocusableActionDetector(
        onShowFocusHighlight: (value) => setState(() => _focused = value),
        child: AnimatedContainer(
          duration: BrandDurations.micro,
          height: height,
          constraints: const BoxConstraints(minWidth: 0),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: widget.destructive
                ? null
                : (enabled
                    ? (widget.large
                        ? BrandGradients.goldPine
                        : BrandGradients.gold)
                    : null),
            color: widget.destructive
                ? BrandColors.error
                : (enabled ? null : BrandColors.ivoryDeep),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: widget.destructive
                  ? BrandColors.error
                  : enabled
                      ? BrandColors.goldDeep.withValues(alpha: 0.35)
                      : BrandColors.outline,
              width: _focused ? 2.4 : 1,
            ),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: (widget.destructive
                              ? BrandColors.error
                              : BrandColors.gold)
                          .withValues(alpha: highlighted ? 0.45 : 0.28),
                      blurRadius: highlighted ? 20 : 12,
                      offset: Offset(0, highlighted ? 6 : 4),
                    ),
                  ]
                : null,
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            child: InkWell(
              onTap: widget.onPressed,
              borderRadius: BorderRadius.circular(999),
              child: Center(
                child: AnimatedScale(
                  scale: highlighted && enabled ? 1.03 : 1.0,
                  duration: BrandDurations.micro,
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Outlined secondary action.
class GhostButton extends StatelessWidget {
  const GhostButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon ?? Icons.arrow_forward_rounded, size: 20),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(140, 52),
        side: const BorderSide(color: BrandColors.pine, width: 1.4),
        textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        shape: const StadiumBorder(),
      ),
    );
  }
}

/// Small gold "chip" label.
class GoldChip extends StatelessWidget {
  const GoldChip({super.key, required this.label, this.icon});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: BrandColors.goldMist,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: BrandColors.gold.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: BrandColors.goldDeep),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: BrandColors.goldDeep,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
          ),
        ],
      ),
    );
  }
}

/// Section card with gold top hairline and soft shadow.
class SectionCard extends StatelessWidget {
  const SectionCard({super.key, required this.child, this.padding});

  final Widget child;
  final double? padding;

  @override
  Widget build(BuildContext context) {
    final band = Adaptive.bandOf(context);
    final inset = padding ?? (band.isCompact ? 20.0 : 26.0 * band.scale);

    return Container(
      padding: EdgeInsets.all(inset),
      decoration: BoxDecoration(
        color: BrandColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: BrandColors.outlineSoft),
        boxShadow: [
          BoxShadow(
            color: BrandColors.pine.withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 3,
            decoration: BoxDecoration(
              gradient: BrandGradients.gold,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }
}
