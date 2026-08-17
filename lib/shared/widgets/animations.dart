import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/theme/brand_colors.dart';

/// Direction-aware entrance animation (slide + fade) used across steps.
///
/// The animation is driven through an [AnimatedBuilder] so the subtree
/// repaints on every tick. Building straight from `controller.value` without
/// listening leaves content stuck at opacity `0` until an unrelated rebuild
/// happens — which is why screens used to appear blank until they were tapped.
class Entrance extends StatefulWidget {
  const Entrance({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.offset = const Offset(0, 24),
    this.duration = const Duration(milliseconds: 480),
  });

  final Widget child;
  final Duration delay;
  final Offset offset;
  final Duration duration;

  @override
  State<Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<Entrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _curve;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _curve = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      _timer = Timer(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Honour the platform "reduce motion" setting, and make sure content is
    // never left invisible if the ticker is muted while this widget is alive.
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _timer?.cancel();
      _controller.value = 1;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _curve,
      child: widget.child,
      builder: (context, child) {
        final t = _curve.value.clamp(0.0, 1.0);
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: widget.offset * (1 - t),
            child: child,
          ),
        );
      },
    );
  }
}

/// Staggered entrance for a list of widgets.
class EntranceList extends StatelessWidget {
  const EntranceList({
    super.key,
    required this.children,
    this.delayMs = 60,
    this.spacing = 0,
  });

  final List<Widget> children;
  final int delayMs;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          Entrance(
            // Cap the cascade so long forms never wait seconds to appear.
            delay: Duration(milliseconds: (i * delayMs).clamp(0, 420)),
            child: children[i],
          ),
          if (spacing > 0 && i != children.length - 1) SizedBox(height: spacing),
        ],
      ],
    );
  }
}

/// Brand pulsing indicator used while a card is being issued.
class IssuingLoader extends StatefulWidget {
  const IssuingLoader({super.key, required this.label});

  final String label;

  @override
  State<IssuingLoader> createState() => _IssuingLoaderState();
}

class _IssuingLoaderState extends State<IssuingLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 46,
              height: 46,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Transform.scale(
                    scale: 0.7 + 0.5 * t,
                    child: Opacity(
                      opacity: 1 - t,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: BrandColors.gold,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: BrandGradients.gold,
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.badge_outlined,
                        size: 16,
                        color: Color(0xFF243028),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Text(
              widget.label,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: BrandColors.pine,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        );
      },
    );
  }
}
