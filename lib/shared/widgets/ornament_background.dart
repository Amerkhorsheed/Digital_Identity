import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/brand_colors.dart';

/// Elegant ornamental backdrop for the A Digital Identity experience.
///
/// Paints a fine 8-point star lattice (a classic Islamic geometric motif) in
/// the brand colors at low opacity, finished with soft radial glows in pine
/// and gold. The lattice is tiled procedurally so it stays crisp on any
/// screen size — phone, tablet or TV.
class OrnamentBackground extends StatelessWidget {
  const OrnamentBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    // The corner frame is inset past the notch and home indicator so it never
    // collides with system chrome.
    final padding = MediaQuery.paddingOf(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(
          child: CustomPaint(painter: _OrnamentPainter(safeArea: padding)),
        ),
        child,
      ],
    );
  }
}

class _OrnamentPainter extends CustomPainter {
  const _OrnamentPainter({required this.safeArea});

  final EdgeInsets safeArea;

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;

    _paintGlow(
      canvas,
      center: Offset(width * 0.10, height * 0.05),
      radius: width * 0.45,
      color: BrandColors.gold.withValues(alpha: 0.14),
    );
    _paintGlow(
      canvas,
      center: Offset(width * 0.94, height * 0.90),
      radius: width * 0.5,
      color: BrandColors.pine.withValues(alpha: 0.09),
    );

    final tile = math.max(width, height) / 7.0;
    final grid = 3.0;

    final pine = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..color = BrandColors.pine.withValues(alpha: 0.05);
    final gold = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..color = BrandColors.gold.withValues(alpha: 0.09);

    for (var gx = -1; gx < grid + 1; gx++) {
      for (var gy = -1; gy < grid + 1; gy++) {
        final center = Offset(
          width * 0.5 + (gx - grid / 2) * tile,
          height * 0.5 + (gy - grid / 2) * tile,
        );
        _drawStar(canvas, center, tile * 0.30, pine);
        _drawStar(canvas, center, tile * 0.24, gold);
        _drawDiamond(canvas, center, tile * 0.42, gold);
      }
    }

    _drawCorners(canvas, size);
  }

  void _paintGlow(
    Canvas canvas, {
    required Offset center,
    required double radius,
    required Color color,
  }) {
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [color, color.withValues(alpha: 0)],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, paint);
  }

  void _drawStar(Canvas canvas, Offset center, double radius, Paint paint) {
    final path = Path();
    for (var i = 0; i < 16; i++) {
      final angle = math.pi / 8 * i;
      final r = i.isEven ? radius : radius * 0.38;
      final point = center + Offset(math.cos(angle) * r, math.sin(angle) * r);
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  void _drawDiamond(Canvas canvas, Offset center, double radius, Paint paint) {
    final path = Path()
      ..moveTo(center.dx, center.dy - radius)
      ..lineTo(center.dx + radius, center.dy)
      ..lineTo(center.dx, center.dy + radius)
      ..lineTo(center.dx - radius, center.dy)
      ..close();
    canvas.drawPath(path, paint);
  }

  void _drawCorners(Canvas canvas, Size size) {
    final goldPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..color = BrandColors.gold.withValues(alpha: 0.32);
    final pinePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..color = BrandColors.pine.withValues(alpha: 0.22);

    const archLength = 46.0;
    const gap = 18.0;
    final top = safeArea.top + gap;
    final bottom = size.height - safeArea.bottom - gap;
    final left = safeArea.left + gap;
    final right = size.width - safeArea.right - gap;

    _drawCornerArch(
      canvas,
      base: Offset(left, top),
      direction: const Offset(1, 1),
      length: archLength,
      paint: goldPaint,
    );
    _drawCornerArch(
      canvas,
      base: Offset(right, top),
      direction: const Offset(-1, 1),
      length: archLength,
      paint: goldPaint,
    );
    _drawCornerArch(
      canvas,
      base: Offset(left, bottom),
      direction: const Offset(1, -1),
      length: archLength,
      paint: pinePaint,
    );
    _drawCornerArch(
      canvas,
      base: Offset(right, bottom),
      direction: const Offset(-1, -1),
      length: archLength,
      paint: pinePaint,
    );
  }

  /// Two nested right-angle brackets — the corner motif from the splash,
  /// drawn cleanly so the frame reads as an ornament rather than a stray mark.
  void _drawCornerArch(
    Canvas canvas, {
    required Offset base,
    required Offset direction,
    required double length,
    required Paint paint,
  }) {
    void bracket(Offset origin, double size) {
      final path = Path()
        ..moveTo(origin.dx, origin.dy + direction.dy * size)
        ..lineTo(origin.dx, origin.dy)
        ..lineTo(origin.dx + direction.dx * size, origin.dy);
      canvas.drawPath(path, paint);
    }

    bracket(base, length);
    const inset = 9.0;
    bracket(
      Offset(base.dx + direction.dx * inset, base.dy + direction.dy * inset),
      length * 0.52,
    );
  }

  @override
  bool shouldRepaint(covariant _OrnamentPainter oldDelegate) =>
      oldDelegate.safeArea != safeArea;
}
