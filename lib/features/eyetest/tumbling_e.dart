import 'package:flutter/material.dart';

import '../../models/vision_test.dart';

/// رمز الفحص البصري «E المتدحرج» مرسومًا وفق معيار سنيلن.
///
/// يُبنى الحرف داخل مربّع من 5×5 وحدات: ثلاثة أضلاع أفقية وعمود رأسي، سماكة
/// كل ضلع تساوي خُمس ارتفاع الحرف — وهي النسبة نفسها المستخدمة في لوحات
/// العيادات، ما يجعل الزاوية البصرية للفتحة دقيقة عند كل مسافة.
class TumblingE extends StatelessWidget {
  const TumblingE({
    super.key,
    required this.size,
    required this.direction,
    this.color = const Color(0xFF0E231F),
  });

  /// ارتفاع الحرف (وعرضه) بالبكسل المنطقي.
  final double size;
  final EDirection direction;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'رمز فحص النظر',
      excludeSemantics: true,
      child: SizedBox(
        width: size,
        height: size,
        child: Transform.rotate(
          angle: direction.radians,
          child: CustomPaint(
            painter: _TumblingEPainter(color: color),
            size: Size.square(size),
          ),
        ),
      ),
    );
  }
}

class _TumblingEPainter extends CustomPainter {
  const _TumblingEPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final unit = size.width / 5;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    // العمود الرأسي (الجهة المغلقة) على اليسار، والفتحة نحو اليمين.
    canvas.drawRect(Rect.fromLTWH(0, 0, unit, size.height), paint);
    for (var i = 0; i < 3; i++) {
      canvas.drawRect(
        Rect.fromLTWH(unit, i * 2 * unit, size.width - unit, unit),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TumblingEPainter oldDelegate) =>
      oldDelegate.color != color;
}
