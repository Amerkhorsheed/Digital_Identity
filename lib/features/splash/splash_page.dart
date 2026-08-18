import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/theme/brand_colors.dart';
import '../../shared/widgets/brand_widgets.dart';

/// Cinematic splash: the A mark rises inside a gold ring while the brand
/// wordmark types itself into view, then hands off to registration.
class SplashPage extends StatefulWidget {
  const SplashPage({super.key, required this.onFinished});

  final VoidCallback onFinished;

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _ring;
  late final Animation<double> _logo;
  late final Animation<double> _fade;

  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
    _ring = CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.9, curve: Curves.easeOutCubic));
    _logo = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.05, 0.55, curve: Curves.easeOutCubic),
    );
    _fade = CurvedAnimation(parent: _controller, curve: const Interval(0.4, 1.0, curve: Curves.easeOut));
    _controller.forward();

    _timer = Timer(const Duration(milliseconds: 3400), () {
      if (mounted) widget.onFinished();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: BrandGradients.pine,
        ),
        child: Stack(
          children: [
            _glowOrbs(),
            _cornerOrnaments(),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedBuilder(
                    animation: _controller,
                    builder: (context, _) {
                      return SizedBox(
                        width: 208,
                        height: 208,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Transform.scale(
                              scale: 0.55 + 0.45 * _ring.value,
                              child: Opacity(
                                opacity: _ring.value,
                                child: Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: BrandColors.gold,
                                      width: 2.2,
                                    ),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(30),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: BrandColors.gold.withValues(alpha: 0.5),
                                          width: 1.2,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Transform.scale(
                              scale: 0.6 + 0.4 * _logo.value,
                              child: Opacity(
                                opacity: _logo.value,
                                child: const BrandLogo(size: 128),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 36),
                  AnimatedBuilder(
                    animation: _controller,
                    builder: (context, _) {
                      final visible = _fade.value;
                      return Opacity(
                        opacity: visible,
                        child: Column(
                          children: [
                            Text(
                              'إدارة القوى البشرية',
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              width: 160,
                              height: 2,
                              decoration: BoxDecoration(
                                gradient: BrandGradients.gold,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'تسجيل آمن · بيانات موثّقة · بطاقة فورية',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: BrandColors.goldGlow,
                                  ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 48),
                  _progressDots(),
                ],
              ),
            ),
            Positioned(
              bottom: 36,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  '© ${DateTime.now().year} إدارة القوى البشرية · جميع الحقوق محفوظة',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.white38,
                        letterSpacing: 0.5,
                      ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _glowOrbs() {
    return Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            colors: [
              BrandColors.gold.withValues(alpha: 0.20),
              Colors.transparent,
            ],
            radius: 0.5,
            center: const Alignment(0.7, -0.8),
          ),
        ),
      ),
    );
  }

  Widget _cornerOrnaments() {
    return Positioned.fill(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Stack(
          children: [
            Positioned(top: 0, left: 0, child: _CornerDecoration(alignment: Alignment.topLeft)),
            Positioned(top: 0, right: 0, child: _CornerDecoration(alignment: Alignment.topRight)),
            Positioned(bottom: 0, left: 0, child: _CornerDecoration(alignment: Alignment.bottomLeft)),
            Positioned(bottom: 0, right: 0, child: _CornerDecoration(alignment: Alignment.bottomRight)),
          ],
        ),
      ),
    );
  }

  Widget _progressDots() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 2000),
      curve: Curves.easeInOut,
      builder: (context, value, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 3; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: (value * 3).floor() == i ? 26 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: (value * 3).floor() >= i
                      ? BrandColors.gold
                      : BrandColors.gold.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _CornerDecoration extends StatelessWidget {
  const _CornerDecoration({required this.alignment});

  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final isLeft = alignment == Alignment.topLeft || alignment == Alignment.bottomLeft;
    final isTop = alignment == Alignment.topLeft || alignment == Alignment.topRight;
    return SizedBox(
      width: 90,
      height: 90,
      child: CustomPaint(
        painter: _CornerPainter(isLeft: isLeft, isTop: isTop),
      ),
    );
  }
}

class _CornerPainter extends CustomPainter {
  const _CornerPainter({required this.isLeft, required this.isTop});

  final bool isLeft;
  final bool isTop;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = BrandColors.gold.withValues(alpha: 0.55);

    final dx = isLeft ? 1.0 : -1.0;
    final dy = isTop ? 1.0 : -1.0;
    final anchor = Offset(
      size.width * (isLeft ? 0 : 1),
      size.height * (isTop ? 0 : 1),
    );

    // Corner bracket along the two edges meeting at this corner.
    final bracket = Path()
      ..moveTo(anchor.dx, anchor.dy + dy * size.height * 0.72)
      ..lineTo(anchor.dx, anchor.dy)
      ..lineTo(anchor.dx + dx * size.width * 0.72, anchor.dy);
    canvas.drawPath(bracket, paint);

    // Inner notched accent pointing at the corner.
    final inner = Path()
      ..moveTo(anchor.dx + dx * size.width * 0.30, anchor.dy)
      ..lineTo(anchor.dx + dx * size.width * 0.06, anchor.dy)
      ..lineTo(anchor.dx + dx * size.width * 0.06, anchor.dy + dy * size.height * 0.30);
    canvas.drawPath(inner, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
