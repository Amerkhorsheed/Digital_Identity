import 'dart:convert';
import 'dart:math' as math;

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';

/// عيّنة تماسّ واحدة كما بلّغت عنها لوحة اللمس.
@immutable
class TouchSample {
  const TouchSample({
    required this.offsetFromOrigin,
    required this.pressure,
    required this.radiusMajor,
    required this.radiusMinor,
    required this.elapsed,
  });

  /// إزاحة نقطة التماسّ عن أول نقطة لمس، بالبكسل المنطقي.
  final Offset offsetFromOrigin;

  /// ضغط الإصبع كما بلّغت عنه اللوحة (0..1). كثير من الأجهزة لا تدعمه.
  final double pressure;

  /// نصف القطر الأكبر لبيضاوي التماسّ.
  final double radiusMajor;

  /// نصف القطر الأصغر لبيضاوي التماسّ.
  final double radiusMinor;

  /// الزمن منذ بداية الالتقاط.
  final Duration elapsed;
}

/// خلاصة قياسات التماسّ لالتقاط واحد.
///
/// كل قيمة محسوبة من عيّنات لوحة اللمس الفعلية — لا شيء منها مُصطنع.
@immutable
class TouchMetrics {
  const TouchMetrics({
    required this.steadiness,
    required this.contact,
    required this.firmness,
    required this.dwell,
    required this.metMinimum,
    required this.swiped,
    required this.sampleCount,
    required this.maxDriftPx,
    required this.meanRadiusPx,
    required this.pressureReported,
    required this.contactReported,
  });

  static const TouchMetrics empty = TouchMetrics(
    steadiness: 0,
    contact: 0,
    firmness: 0,
    dwell: 0,
    metMinimum: false,
    swiped: false,
    sampleCount: 0,
    maxDriftPx: 0,
    meanRadiusPx: 0,
    pressureReported: false,
    contactReported: false,
  );

  /// ثبات الإصبع: 1 يعني بلا حراك، 0 يعني انزلاقًا يتجاوز حدّ القبول.
  final double steadiness;

  /// اتساع منطقة التماسّ منسوبًا إلى بَنان إصبع نموذجي.
  final double contact;

  /// ثبات الضغط عبر الالتقاط.
  final double firmness;

  /// نسبة إكمال مدة القراءة الكاملة.
  final double dwell;

  /// هل بقي الإصبع مدة كافية لقراءة صالحة؟
  ///
  /// القراءة تكتمل عند بلوغ هذا الحد، تمامًا كمستشعر حقيقي ينهي القراءة فور
  /// حصوله على بيانات كافية بدل انتظار مدة ثابتة.
  final bool metMinimum;

  /// هل مُرِّر الإصبع بدل وضعه؟ الحالة الوحيدة التي تُلغي القراءة فورًا.
  final bool swiped;

  /// عدد العيّنات المسجّلة — كثافتها دليل على جودة القراءة.
  final int sampleCount;

  /// أقصى انزلاق عن نقطة البداية بالبكسل.
  final double maxDriftPx;

  /// متوسط نصف قطر التماسّ بالبكسل.
  final double meanRadiusPx;

  /// هل بلّغت اللوحة عن ضغط فعلي؟ كثير من أجهزة أندرويد لا تدعمه.
  final bool pressureReported;

  /// هل بلّغت اللوحة عن مساحة تماسّ فعلية؟
  final bool contactReported;

  /// حدّ القبول النهائي للدرجة الكلية.
  ///
  /// منخفض عن قصد: البوابة الحقيقية هي [metMinimum] و[swiped]، والدرجة تصف
  /// جودة القراءة لا تمنعها. مستشعر البصمة الحقيقي يقبل قراءة متوسطة الجودة
  /// ولا يطلب إعادة المحاولة إلا حين يعجز عن القراءة أصلًا.
  static const int acceptThreshold = 35;

  /// الدرجة الكلية من 0 إلى 100.
  ///
  /// الأوزان تتكيّف مع ما تدعمه اللوحة فعلًا: إذا لم تُبلّغ عن ضغط أو مساحة
  /// تماسّ، يُعاد توزيع وزنهما على الثبات والاستقرار بدل احتساب صفر ظالم.
  int get score {
    final parts = <(double, double)>[
      (dwell, 0.34),
      (steadiness, 0.34),
      if (contactReported) (contact, 0.18),
      if (pressureReported) (firmness, 0.14),
    ];
    final totalWeight = parts.fold<double>(0, (sum, p) => sum + p.$2);
    if (totalWeight <= 0) return 0;
    final raw = parts.fold<double>(0, (sum, p) => sum + p.$1 * p.$2);
    return (raw / totalWeight * 100).round().clamp(0, 100);
  }

  bool get accepted => failureReason == null;

  /// سبب الرفض بالعربية، أو `null` عند القبول.
  ///
  /// بوابتان فقط تمنعان القبول — لمسة أقصر من أن تُقرأ، أو تمرير بدل وضع.
  /// ما عدا ذلك يخفض الدرجة ولا يُلغي القراءة، فلا يُضطر المتقدّم لتكرار
  /// المحاولة لأن إصبعه اهتزّ قليلًا.
  String? get failureReason {
    if (swiped) {
      return 'مُرِّر الإصبع بدل وضعه. ضع إصبعك على اللوحة دون تحريكه.';
    }
    if (!metMinimum) {
      return 'لمسة قصيرة جدًا. ضع إصبعك وأبقِه لحظة حتى تكتمل القراءة.';
    }
    if (contactReported && contact < 0.12) {
      return 'لم تُقرأ منطقة تماسّ كافية. ضع بَنان الإصبع لا طرفه.';
    }
    return null;
  }

  @override
  String toString() => 'TouchMetrics(score=$score, dwell=$dwell, '
      'steady=$steadiness, contact=$contact, firm=$firmness, n=$sampleCount)';
}

/// يجمّع عيّنات لوحة اللمس أثناء التقاط واحد ويحوّلها إلى [TouchMetrics].
///
/// ## ما الذي يُقاس فعلًا
///
/// لوحة اللمس تُبلّغ عن موضع نقطة التماسّ، وعن مساحتها وضغطها على الأجهزة
/// التي تدعم ذلك. هذه قياسات فيزيائية حقيقية لإصبع حقيقي موضوع على الزجاج،
/// وعليها تُبنى درجة الجودة وبصمة التدقيق.
///
/// ## ما الذي لا يُقاس
///
/// لوحة اللمس لا تملك دقّة كافية لقراءة خطوط البصمة، فهذا الالتقاط **ليس**
/// مطابقة لخطوط البصمة ولا بديلًا عن مستشعر بيومتري. ميزته أنه يعمل لأي عدد
/// من المتقدّمين على الجهاز نفسه دون أي تسجيل مسبق.
class TouchCaptureRecorder {
  TouchCaptureRecorder({
    this.requiredDwell = const Duration(milliseconds: 1100),
    this.minimumDwell = const Duration(milliseconds: 550),
    this.swipeThresholdPx = 80,
  });

  /// مدة القراءة الكاملة — عندها تكتمل تلقائيًا بأعلى درجة.
  ///
  /// قصيرة عن قصد: مستشعر البصمة الحقيقي يقرأ في أقل من ثانية، وأي انتظار
  /// أطول يجعل اللوحة تبدو عاطلة لا دقيقة.
  final Duration requiredDwell;

  /// أقل مدة تكفي لقراءة صالحة. رفع الإصبع بعدها يُنهي القراءة بنجاح.
  final Duration minimumDwell;

  /// المسافة التي يصبح التحرّك بعدها تمريرًا لا وضعًا.
  ///
  /// متسامحة عن قصد: الإصبع الموضوع على زجاج يتحرّك بضعة بكسلات دائمًا،
  /// وإلغاء القراءة لأجل ذلك هو سبب تكرار المحاولات.
  final double swipeThresholdPx;

  /// نصف قطر تماسّ نموذجي لبَنان إصبع بالغ على لوحة لمس، بالبكسل المنطقي.
  ///
  /// الأجهزة تختلف كثيرًا في وحدة `touchMajor`، فالمرجع منخفض حتى لا تُظلم
  /// الألواح التي تُبلّغ عن أرقام صغيرة.
  static const double _referenceRadiusPx = 14;

  final List<TouchSample> _samples = <TouchSample>[];
  Offset? _origin;
  Duration _elapsed = Duration.zero;

  bool get isRecording => _origin != null;

  List<TouchSample> get samples => List.unmodifiable(_samples);

  /// يبدأ التقاطًا جديدًا عند أول لمسة.
  void begin(PointerDownEvent event) {
    _samples.clear();
    _origin = event.position;
    _elapsed = Duration.zero;
    _add(event);
  }

  /// يسجّل حركة، ويعيد `false` فقط إذا كان ما يجري تمريرًا لا وضعًا.
  ///
  /// الاهتزاز الطبيعي لا يُلغي القراءة — يخفض درجة الثبات فقط.
  bool update(PointerMoveEvent event, Duration elapsed) {
    if (_origin == null) return false;
    _elapsed = elapsed;
    _add(event);
    return (event.position - _origin!).distance <= swipeThresholdPx;
  }

  /// يسجّل مرور الوقت دون حركة — الإصبع الثابت لا يولّد أحداث حركة.
  void tick(Duration elapsed) {
    _elapsed = elapsed;
  }

  void reset() {
    _samples.clear();
    _origin = null;
    _elapsed = Duration.zero;
  }

  void _add(PointerEvent event) {
    final origin = _origin;
    if (origin == null) return;
    _samples.add(
      TouchSample(
        offsetFromOrigin: event.position - origin,
        pressure: event.pressure,
        radiusMajor: event.radiusMajor,
        radiusMinor: event.radiusMinor,
        elapsed: _elapsed,
      ),
    );
  }

  /// يحسب القياسات النهائية للالتقاط الجاري.
  TouchMetrics metrics() {
    if (_samples.isEmpty) return TouchMetrics.empty;

    var maxDrift = 0.0;
    var radiusSum = 0.0;
    var radiusCount = 0;
    final pressures = <double>[];

    for (final sample in _samples) {
      maxDrift = math.max(maxDrift, sample.offsetFromOrigin.distance);
      final radius = sample.radiusMajor;
      if (radius > 0) {
        radiusSum += radius;
        radiusCount++;
      }
      if (sample.pressure > 0) pressures.add(sample.pressure);
    }

    // لوحة لا تدعم الضغط تُبلّغ عن 1.0 ثابتة في كل عيّنة.
    final pressureReported = pressures.length > 2 &&
        pressures.any((p) => (p - pressures.first).abs() > 0.001);
    final contactReported = radiusCount > 0;

    // منحنى متسامح: أول 12 بكسل من الاهتزاز لا تُحتسب إطلاقًا، فالإصبع
    // الموضوع على زجاج لا يثبت تمامًا أبدًا.
    const freeWobblePx = 12.0;
    final penalised = math.max(0.0, maxDrift - freeWobblePx);
    final steadiness = (1 - penalised / (swipeThresholdPx - freeWobblePx))
        .clamp(0.0, 1.0)
        .toDouble();

    final meanRadius = contactReported ? radiusSum / radiusCount : 0.0;
    final contact = contactReported
        ? (meanRadius / _referenceRadiusPx).clamp(0.0, 1.0).toDouble()
        : 0.0;

    // الثبات في الضغط أهم من مقداره: إصبع مستقر يعطي تباينًا منخفضًا.
    var firmness = 0.0;
    if (pressureReported) {
      final mean = pressures.reduce((a, b) => a + b) / pressures.length;
      final variance = pressures.fold<double>(
            0,
            (sum, p) => sum + (p - mean) * (p - mean),
          ) /
          pressures.length;
      firmness = (1 - math.sqrt(variance) * 4).clamp(0.0, 1.0).toDouble();
    }

    final dwell = (_elapsed.inMicroseconds / requiredDwell.inMicroseconds)
        .clamp(0.0, 1.0)
        .toDouble();

    return TouchMetrics(
      steadiness: steadiness,
      contact: contact,
      firmness: firmness,
      dwell: dwell,
      metMinimum: _elapsed >= minimumDwell,
      swiped: maxDrift > swipeThresholdPx,
      sampleCount: _samples.length,
      maxDriftPx: maxDrift,
      meanRadiusPx: meanRadius,
      pressureReported: pressureReported,
      contactReported: contactReported,
    );
  }

  /// يشتقّ بصمة تدقيق SHA-256 من قياسات التماسّ المسجّلة فعليًا.
  ///
  /// المدخل يضمّ الأرقام المقيسة (الانزلاق، ونصف القطر، وعدد العيّنات، ودرجة
  /// الجودة) مع لحظة الالتقاط، فيصبح لكل التقاط معرّف تدقيق خاصّ به.
  Future<String> digest(TouchMetrics metrics, DateTime capturedAtUtc) async {
    final canonical = <String>[
      BiometricAttestationDomain.touchCapture,
      capturedAtUtc.toIso8601String(),
      metrics.score.toString(),
      metrics.sampleCount.toString(),
      metrics.maxDriftPx.toStringAsFixed(3),
      metrics.meanRadiusPx.toStringAsFixed(3),
      metrics.steadiness.toStringAsFixed(4),
      metrics.contact.toStringAsFixed(4),
      metrics.firmness.toStringAsFixed(4),
      // عيّنة من مسار الإصبع نفسه — يختلف بين التقاط وآخر ولو تطابقت الأرقام.
      for (final s in _pathSignature())
        '${s.dx.toStringAsFixed(2)},${s.dy.toStringAsFixed(2)}',
    ].join('|');

    final hash = await Sha256().hash(utf8.encode(canonical));
    final buffer = StringBuffer();
    for (final byte in hash.bytes) {
      buffer.write(byte.toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }

  /// ستّ عيّنات موزّعة على طول مسار الإصبع.
  List<Offset> _pathSignature() {
    if (_samples.isEmpty) return const <Offset>[];
    const count = 6;
    return <Offset>[
      for (var i = 0; i < count; i++)
        _samples[(i * (_samples.length - 1) ~/ math.max(1, count - 1))
                .clamp(0, _samples.length - 1)]
            .offsetFromOrigin,
    ];
  }
}

/// فواصل مجال تمنع الخلط بين بصمات التدقيق المشتقّة من مسارات مختلفة.
abstract final class BiometricAttestationDomain {
  static const String touchCapture = 'a-id/touch-capture/v1';
  static const String hardware = 'a-id/hardware-match/v1';
}
