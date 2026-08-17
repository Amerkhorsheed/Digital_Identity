import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/theme/brand_colors.dart';
import '../../../services/touch_capture.dart';

/// مراحل لوحة الالتقاط.
enum FingerprintPadStage { idle, scanning, complete, rejected }

/// لوحة التقاط بصمة تعمل باللمس المباشر على الشاشة.
///
/// تقيس تماسّ الإصبع الفعلي على الزجاج — الموضع وثباته، ومساحة التماسّ
/// وضغطه على الأجهزة التي تدعمهما، ومدة الاستقرار — ثم تبني من هذه القياسات
/// درجة جودة وبصمة تدقيق. تعمل لأي عدد من المتقدّمين على الجهاز نفسه دون أي
/// تسجيل مسبق، وهو ما يجعلها المسار العملي على جهاز واحد يمرّ عليه الآلاف.
class FingerprintPad extends StatefulWidget {
  const FingerprintPad({
    super.key,
    required this.onCaptured,
    this.size = 210,
    this.enabled = true,
  });

  /// يُستدعى عند اكتمال التقاط اجتاز كل بوابات الجودة.
  final void Function(TouchMetrics metrics, TouchCaptureRecorder recorder)
      onCaptured;

  /// طول ضلع اللوحة.
  final double size;

  final bool enabled;

  @override
  State<FingerprintPad> createState() => _FingerprintPadState();
}

class _FingerprintPadState extends State<FingerprintPad>
    with TickerProviderStateMixin {
  /// مدة القراءة الكاملة، ومطابقة لما يستخدمه المسجّل.
  static const Duration _dwell = Duration(milliseconds: 1100);

  /// أقل مدة تكفي لقراءة صالحة — رفع الإصبع بعدها ينجح.
  static const Duration _minimumDwell = Duration(milliseconds: 550);

  late final AnimationController _progress = AnimationController(
    vsync: this,
    duration: _dwell,
  );

  final TouchCaptureRecorder _recorder = TouchCaptureRecorder(
    requiredDwell: _dwell,
    minimumDwell: _minimumDwell,
  );

  FingerprintPadStage _stage = FingerprintPadStage.idle;
  TouchMetrics _metrics = TouchMetrics.empty;
  String? _rejection;

  /// يُطلق نبضة واحدة لحظة بلوغ الحد الأدنى، فيشعر المستخدم بأن القراءة
  /// «التقطت» تمامًا كما يهتزّ مستشعر البصمة فور قراءته.
  bool _signalledMinimum = false;

  /// بذرة نمط الخطوط — تتغيّر مع كل التقاط فيبدو كل مسح مختلفًا.
  int _seed = 20260817;

  /// موضع التماسّ الحيّ داخل اللوحة، لرسم الوهج تحت الإصبع.
  Offset? _localContact;
  double _contactRadius = 26;

  @override
  void initState() {
    super.initState();
    _progress
      ..addListener(_onFrame)
      ..addStatusListener(_onStatus);
  }

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  void _onFrame() {
    // الإصبع الثابت لا يولّد أحداث حركة، فالمؤقّت هو مصدر مرور الوقت.
    _recorder.tick(_progress.lastElapsedDuration ?? Duration.zero);
    final metrics = _recorder.metrics();
    if (metrics.metMinimum && !_signalledMinimum) {
      _signalledMinimum = true;
      HapticFeedback.selectionClick();
    }
    if (mounted) setState(() => _metrics = metrics);
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) _complete();
  }

  // ---------------------------------------------------------------------------
  // أحداث اللمس
  // ---------------------------------------------------------------------------

  void _onPointerDown(PointerDownEvent event) {
    if (!widget.enabled || _stage == FingerprintPadStage.scanning) return;
    _recorder.begin(event);
    _signalledMinimum = false;
    setState(() {
      _stage = FingerprintPadStage.scanning;
      _rejection = null;
      _seed = event.timeStamp.inMicroseconds & 0x7fffffff;
      _localContact = _toLocal(event.position);
      _contactRadius = _radiusOf(event);
    });
    HapticFeedback.selectionClick();
    _progress.forward(from: 0);
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (_stage != FingerprintPadStage.scanning) return;
    final withinTolerance = _recorder.update(
      event,
      _progress.lastElapsedDuration ?? Duration.zero,
    );
    setState(() {
      _localContact = _toLocal(event.position);
      _contactRadius = _radiusOf(event);
    });
    if (!withinTolerance) {
      _abort('مُرِّر الإصبع بدل وضعه. ضعه على اللوحة دون تحريكه.');
    }
  }

  /// رفع الإصبع لا يعني الفشل.
  ///
  /// مستشعر البصمة الحقيقي ينهي القراءة فور حصوله على بيانات كافية، فإن كانت
  /// اللمسة قد بلغت الحد الأدنى تُعتمد القراءة فورًا؛ وإلا يُطلب تكرارها.
  void _onPointerUp() {
    if (_stage != FingerprintPadStage.scanning) return;
    _progress.stop();

    final metrics = _recorder.metrics();
    if (metrics.accepted) {
      _finish(metrics);
    } else {
      _abort(metrics.failureReason!);
    }
  }

  Offset? _toLocal(Offset global) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    return box.globalToLocal(global);
  }

  double _radiusOf(PointerEvent event) =>
      event.radiusMajor > 0 ? event.radiusMajor.clamp(14.0, 48.0) : 26.0;

  // ---------------------------------------------------------------------------
  // إنهاء الالتقاط
  // ---------------------------------------------------------------------------

  void _abort(String reason) {
    _progress.stop();
    _progress.value = 0;
    _recorder.reset();
    if (!mounted) return;
    setState(() {
      _stage = FingerprintPadStage.rejected;
      _rejection = reason;
      _metrics = TouchMetrics.empty;
      _localContact = null;
    });
    HapticFeedback.lightImpact();
  }

  /// اكتملت المدة الكاملة والإصبع ما زال موضوعًا — أعلى جودة ممكنة.
  void _complete() {
    if (!mounted) return;
    // بلوغ المؤقّت نهايته هو نفسه اكتمال المدة؛ آخر إطار قد يقصّر عنها بقليل.
    _recorder.tick(_dwell);
    final metrics = _recorder.metrics();
    final reason = metrics.failureReason;

    if (reason != null) {
      _abort(reason);
      return;
    }
    _finish(metrics);
  }

  void _finish(TouchMetrics metrics) {
    setState(() {
      _stage = FingerprintPadStage.complete;
      _metrics = metrics;
      _rejection = null;
      _localContact = null;
    });
    HapticFeedback.heavyImpact();
    widget.onCaptured(metrics, _recorder);
  }

  /// يعيد اللوحة إلى وضع الانتظار استعدادًا لمتقدّم جديد.
  void reset() {
    _progress.stop();
    _progress.value = 0;
    _recorder.reset();
    if (!mounted) return;
    setState(() {
      _stage = FingerprintPadStage.idle;
      _metrics = TouchMetrics.empty;
      _rejection = null;
      _localContact = null;
    });
  }

  // ---------------------------------------------------------------------------
  // البناء
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final scanning = _stage == FingerprintPadStage.scanning;
    final complete = _stage == FingerprintPadStage.complete;

    return Column(
      // The pad must hug its content; letting it fill the column leaves a dead
      // region under the plate that looks tappable but is not.
      mainAxisSize: MainAxisSize.min,
      children: [
        Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: _onPointerDown,
          onPointerMove: _onPointerMove,
          onPointerUp: (_) => _onPointerUp(),
          onPointerCancel: (_) => _onPointerUp(),
          child: Semantics(
            label: 'لوحة التقاط البصمة — ضع إصبعك واثبت',
            child: SizedBox.square(
              dimension: widget.size,
              child: AnimatedBuilder(
                animation: _progress,
                builder: (context, _) => CustomPaint(
                  painter: _FingerprintPadPainter(
                    progress: _progress.value,
                    stage: _stage,
                    readable: _metrics.metMinimum,
                    seed: _seed,
                    contact: _localContact,
                    contactRadius: _contactRadius,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        _PadCaption(
          stage: _stage,
          metrics: _metrics,
          rejection: _rejection,
        ),
        if (scanning || complete) ...[
          const SizedBox(height: 14),
          _QualityBars(metrics: _metrics),
        ],
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// الرسم
// -----------------------------------------------------------------------------

/// يرسم سطح اللوحة، ونمط الخطوط الذي ينكشف تدريجيًا، وشريط المسح، وحلقة
/// التقدّم، ونقاط التفاصيل الدقيقة عند الاكتمال.
class _FingerprintPadPainter extends CustomPainter {
  _FingerprintPadPainter({
    required this.progress,
    required this.stage,
    required this.readable,
    required this.seed,
    required this.contact,
    required this.contactRadius,
  });

  final double progress;
  final FingerprintPadStage stage;

  /// هل بلغت القراءة الحد الذي يجعلها صالحة؟ يضيء الإطار أخضر عندها، فيعرف
  /// المستخدم أنه يستطيع رفع إصبعه — كما يضيء مستشعر البصمة فور قراءته.
  final bool readable;
  final int seed;
  final Offset? contact;
  final double contactRadius;

  static const Color _plateTop = Color(0xFF1B3A31);
  static const Color _plateBottom = Color(0xFF0B1C17);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final radius = Radius.circular(size.width * 0.30);
    final plate = RRect.fromRectAndRadius(rect.deflate(6), radius);

    _paintPlate(canvas, plate);
    _paintRidges(canvas, plate, size);
    if (contact != null && stage == FingerprintPadStage.scanning) {
      _paintContactGlow(canvas, plate);
    }
    if (stage == FingerprintPadStage.scanning) {
      _paintSweep(canvas, plate, size);
    }
    if (stage == FingerprintPadStage.complete) {
      _paintMinutiae(canvas, plate, size);
    }
    _paintBezel(canvas, plate, size);
    _paintProgressRing(canvas, rect, size);
  }

  // --- سطح اللوحة -----------------------------------------------------------

  void _paintPlate(Canvas canvas, RRect plate) {
    canvas.drawRRect(
      plate,
      Paint()
        ..shader = ui.Gradient.linear(
          plate.outerRect.topCenter,
          plate.outerRect.bottomCenter,
          const [_plateTop, _plateBottom],
        ),
    );

    // لمعة زجاجية خفيفة في الربع العلوي.
    canvas.save();
    canvas.clipRRect(plate);
    canvas.drawRect(
      plate.outerRect,
      Paint()
        ..shader = ui.Gradient.linear(
          plate.outerRect.topLeft,
          plate.outerRect.centerLeft,
          [
            Colors.white.withValues(alpha: 0.07),
            Colors.white.withValues(alpha: 0),
          ],
        ),
    );
    canvas.restore();
  }

  // --- نمط الخطوط ----------------------------------------------------------

  /// يرسم نمط دوّامة (whorl) واقعيًا: حلقات متحدة المركز مشوّهة عضويًا مع
  /// انقطاعات تمثّل نهايات الخطوط، تمامًا كما تبدو بصمة حقيقية.
  void _paintRidges(Canvas canvas, RRect plate, Size size) {
    canvas.save();
    canvas.clipRRect(plate.deflate(2));

    final core = Offset(size.width * 0.5, size.height * 0.46);
    final ridges = _buildRidges(core, size);

    // الطبقة الخافتة: النمط كاملًا، ليبدو السطح كمستشعر لا كمربّع فارغ.
    final dim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true
      ..color = BrandColors.goldSoft
          .withValues(alpha: stage == FingerprintPadStage.idle ? 0.10 : 0.14);
    for (final ridge in ridges) {
      canvas.drawPath(ridge, dim);
    }

    // الطبقة المضيئة: تنكشف من الأعلى مع تقدّم القراءة.
    final revealed = stage == FingerprintPadStage.complete
        ? 1.0
        : (stage == FingerprintPadStage.scanning ? progress : 0.0);
    if (revealed > 0) {
      canvas.save();
      canvas.clipRect(
        Rect.fromLTWH(0, 0, size.width, size.height * revealed),
      );
      final bright = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.9
        ..strokeCap = StrokeCap.round
        ..isAntiAlias = true
        ..shader = ui.Gradient.linear(
          Offset(0, 0),
          Offset(0, size.height),
          const [BrandColors.goldGlow, BrandColors.gold],
        );
      for (final ridge in ridges) {
        canvas.drawPath(ridge, bright);
      }
      canvas.restore();
    }

    canvas.restore();
  }

  /// يبني مسارات الخطوط. النمط ثابت لبذرة معيّنة، فلا يرتجف بين الإطارات.
  List<Path> _buildRidges(Offset core, Size size) {
    final random = math.Random(seed);
    final paths = <Path>[];
    final spacing = size.width * 0.038;

    // إزاحات عشوائية تُحسب مرة واحدة لكل خط، فتبقى ثابتة طوال الالتقاط.
    for (var i = 0; i < 22; i++) {
      final baseRadius = spacing * (i + 1.2);
      final phase = random.nextDouble() * math.pi * 2;
      final wobble = 0.06 + random.nextDouble() * 0.07;
      // فجوات تمثّل نهايات الخطوط وتشعّباتها.
      final gapStart = random.nextDouble() * math.pi * 2;
      final gapWidth = random.nextDouble() < 0.55
          ? 0.25 + random.nextDouble() * 0.55
          : 0.0;

      final path = Path();
      var drawing = false;

      const steps = 132;
      for (var s = 0; s <= steps; s++) {
        final theta = s / steps * math.pi * 2;

        // داخل الفجوة يُرفع القلم فيبدو الخط منتهيًا لا مقطوعًا.
        final delta = (theta - gapStart) % (math.pi * 2);
        if (gapWidth > 0 && delta < gapWidth) {
          drawing = false;
          continue;
        }

        final r = baseRadius *
            (1 +
                wobble * math.sin(2 * theta + phase) +
                wobble * 0.5 * math.sin(5 * theta + phase * 1.7));
        // استطالة رأسية خفيفة تعطي شكل البصمة الحقيقي لا دائرة مثالية.
        final point = Offset(
          core.dx + r * math.cos(theta),
          core.dy + r * math.sin(theta) * 1.22,
        );

        if (drawing) {
          path.lineTo(point.dx, point.dy);
        } else {
          path.moveTo(point.dx, point.dy);
          drawing = true;
        }
      }
      paths.add(path);
    }
    return paths;
  }

  // --- وهج التماسّ ----------------------------------------------------------

  /// وهج ناعم يتبع نقطة التماسّ الفعلية، فتستجيب اللوحة للإصبع الحقيقي.
  void _paintContactGlow(Canvas canvas, RRect plate) {
    final point = contact!;
    canvas.save();
    canvas.clipRRect(plate);
    canvas.drawCircle(
      point,
      contactRadius * 2.1,
      Paint()
        ..shader = ui.Gradient.radial(
          point,
          contactRadius * 2.1,
          [
            BrandColors.goldGlow.withValues(alpha: 0.30),
            BrandColors.goldGlow.withValues(alpha: 0),
          ],
        ),
    );
    canvas.restore();
  }

  // --- شريط المسح ----------------------------------------------------------

  void _paintSweep(Canvas canvas, RRect plate, Size size) {
    canvas.save();
    canvas.clipRRect(plate);
    final y = size.height * progress;

    // هالة أسفل الخط تعطي إحساس الضوء المنعكس.
    canvas.drawRect(
      Rect.fromLTWH(0, y - 26, size.width, 26),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, y - 26),
          Offset(0, y),
          [
            BrandColors.goldGlow.withValues(alpha: 0),
            BrandColors.goldGlow.withValues(alpha: 0.22),
          ],
        ),
    );

    canvas.drawRect(
      Rect.fromLTWH(0, y - 1.4, size.width, 2.8),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, y),
          Offset(size.width, y),
          [
            BrandColors.goldGlow.withValues(alpha: 0),
            Colors.white.withValues(alpha: 0.95),
            BrandColors.goldGlow.withValues(alpha: 0),
          ],
          const [0.0, 0.5, 1.0],
        )
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2),
    );
    canvas.restore();
  }

  // --- نقاط التفاصيل الدقيقة ------------------------------------------------

  /// علامات صغيرة عند نهايات الخطوط، كما تعرضها برامج تحليل البصمات.
  void _paintMinutiae(Canvas canvas, RRect plate, Size size) {
    canvas.save();
    canvas.clipRRect(plate);
    final random = math.Random(seed ^ 0x5eed);
    final core = Offset(size.width * 0.5, size.height * 0.46);

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = BrandColors.success.withValues(alpha: 0.9);

    for (var i = 0; i < 9; i++) {
      final theta = random.nextDouble() * math.pi * 2;
      final r = size.width * (0.10 + random.nextDouble() * 0.26);
      final at = Offset(
        core.dx + r * math.cos(theta),
        core.dy + r * math.sin(theta) * 1.22,
      );
      canvas.drawCircle(at, 4.2, stroke);
      canvas.drawCircle(
        at,
        1.5,
        Paint()..color = BrandColors.success.withValues(alpha: 0.9),
      );
    }
    canvas.restore();
  }

  // --- الإطار وحلقة التقدّم -------------------------------------------------

  void _paintBezel(Canvas canvas, RRect plate, Size size) {
    final accent = switch (stage) {
      FingerprintPadStage.complete => BrandColors.success,
      FingerprintPadStage.rejected => BrandColors.error,
      FingerprintPadStage.scanning =>
        readable ? BrandColors.success : BrandColors.goldGlow,
      FingerprintPadStage.idle => BrandColors.goldSoft,
    };

    canvas.drawRRect(
      plate,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..color = accent.withValues(
          alpha: stage == FingerprintPadStage.idle ? 0.65 : 0.95,
        ),
    );
  }

  void _paintProgressRing(Canvas canvas, Rect rect, Size size) {
    if (stage != FingerprintPadStage.scanning &&
        stage != FingerprintPadStage.complete) {
      return;
    }
    final value = stage == FingerprintPadStage.complete ? 1.0 : progress;
    final ring = rect.deflate(2.5);
    final radius = Radius.circular(size.width * 0.32);

    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(ring, radius));
    final metrics = path.computeMetrics().toList();
    if (metrics.isEmpty) return;

    final metric = metrics.first;
    // يبدأ القوس من منتصف الحافة العليا فيقرأ كحلقة تقدّم لا كخط عشوائي.
    final start = metric.length * 0.125;
    final sweep = metric.length * value;

    final drawn = Path();
    final first = metric.extractPath(start, math.min(metric.length, start + sweep));
    drawn.addPath(first, Offset.zero);
    final overflow = start + sweep - metric.length;
    if (overflow > 0) {
      drawn.addPath(metric.extractPath(0, overflow), Offset.zero);
    }

    canvas.drawPath(
      drawn,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.4
        ..strokeCap = StrokeCap.round
        ..color = stage == FingerprintPadStage.complete
            ? BrandColors.success
            : BrandColors.goldGlow,
    );
  }

  @override
  bool shouldRepaint(_FingerprintPadPainter old) =>
      old.progress != progress ||
      old.stage != stage ||
      old.readable != readable ||
      old.seed != seed ||
      old.contact != contact ||
      old.contactRadius != contactRadius;
}

// -----------------------------------------------------------------------------
// النصوص والمقاييس أسفل اللوحة
// -----------------------------------------------------------------------------

class _PadCaption extends StatelessWidget {
  const _PadCaption({
    required this.stage,
    required this.metrics,
    required this.rejection,
  });

  final FingerprintPadStage stage;
  final TouchMetrics metrics;
  final String? rejection;

  @override
  Widget build(BuildContext context) {
    final (icon, text, tone) = switch (stage) {
      FingerprintPadStage.idle => (
          Icons.touch_app_rounded,
          'ضع إصبع المتقدّم على اللوحة',
          BrandColors.ink,
        ),
      FingerprintPadStage.scanning => (
          Icons.graphic_eq_rounded,
          metrics.metMinimum
              ? 'تمّت القراءة — ارفع إصبعك أو أبقِه لجودة أعلى'
              : 'جارٍ القراءة...',
          metrics.metMinimum ? BrandColors.success : BrandColors.goldDeep,
        ),
      FingerprintPadStage.complete => (
          Icons.check_circle_rounded,
          'اكتملت القراءة بجودة ${metrics.score}٪',
          BrandColors.success,
        ),
      FingerprintPadStage.rejected => (
          Icons.error_outline_rounded,
          rejection ?? 'تعذّرت القراءة. أعد المحاولة.',
          BrandColors.error,
        ),
    };

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 17, color: tone),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.6,
              fontWeight: FontWeight.w700,
              color: tone,
            ),
          ),
        ),
      ],
    );
  }
}

/// أشرطة المقاييس المقيسة فعلًا — تجعل سبب القبول أو الرفض مرئيًا.
class _QualityBars extends StatelessWidget {
  const _QualityBars({required this.metrics});

  final TouchMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final bars = <(String, double)>[
      ('الاستقرار', metrics.dwell),
      ('الثبات', metrics.steadiness),
      if (metrics.contactReported) ('التماسّ', metrics.contact),
      if (metrics.pressureReported) ('الضغط', metrics.firmness),
    ];

    return Row(
      children: [
        for (final (label, value) in bars)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(BrandRadii.pill),
                    child: LinearProgressIndicator(
                      value: value.clamp(0.0, 1.0),
                      minHeight: 5,
                      backgroundColor: BrandColors.outlineSoft,
                      valueColor: AlwaysStoppedAnimation(
                        value >= 0.6 ? BrandColors.success : BrandColors.gold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 10,
                      color: BrandColors.inkMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
