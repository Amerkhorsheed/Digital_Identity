import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'applicant.dart';

/// العين المفحوصة.
enum EyeSide {
  right('العين اليمنى', 'اليمنى'),
  left('العين اليسرى', 'اليسرى');

  const EyeSide(this.label, this.shortLabel);
  final String label;
  final String shortLabel;

  EyeSide get other => this == EyeSide.right ? EyeSide.left : EyeSide.right;
}

/// اتجاه فتحة حرف E في اختبار «E المتدحرج» (Tumbling E).
enum EDirection {
  right(0, 'يمين'),
  down(1, 'أسفل'),
  left(2, 'يسار'),
  up(3, 'أعلى');

  const EDirection(this.quarterTurns, this.label);

  /// عدد أرباع الدورة بدءًا من الوضع الافتراضي (الفتحة نحو اليمين).
  final int quarterTurns;
  final String label;

  double get radians => quarterTurns * math.pi / 2;
}

/// سطر من لوحة الفحص: حدة إبصار مع الزاوية البصرية المقابلة له.
@immutable
class AcuityLine {
  const AcuityLine({
    required this.acuity,
    required this.snellenDenominator,
  });

  final VisualAcuity acuity;

  /// المقام في كسر سنيلن (20/‏[snellenDenominator]).
  final int snellenDenominator;

  /// حجم الرمز البصري بالمليمتر على مسافة [distanceCm].
  ///
  /// يرتكز على المعيار السريري: رمز سطر 20/20 يقابل زاوية 5 دقائق قوسية
  /// عند عين الفاحص، ويتضاعف حجمه بنسبة المقام إلى 20.
  double optotypeHeightMm(double distanceCm) {
    final arcMinutes = 5.0 * snellenDenominator / 20.0;
    final radians = arcMinutes * (math.pi / (180 * 60));
    return 2 * (distanceCm * 10) * math.tan(radians / 2);
  }

  /// سماكة ضلع الحرف: خُمس ارتفاعه في شبكة سنيلن 5×5.
  ///
  /// هذه هي أصغر تفصيلة في الرمز، وهي ما يحدّ فعليًا قدرة الشاشة على عرضه.
  double strokeWidthMm(double distanceCm) => optotypeHeightMm(distanceCm) / 5;

  /// النسبة العشرية لحدة الإبصار (1.0 تعني 20/20).
  double get decimal => 20 / snellenDenominator;

  String get label => '20/$snellenDenominator';
}

/// أسطر اللوحة — تدرّج سنيلن التقليدي الكامل من 20/200 إلى 20/20.
///
/// ثمانية أسطر لا خمسة: الفجوات الواسعة (200 ← 100 ← 50) كانت تُقرِّب النتيجة
/// إلى أقرب سطر بعيد، فيُسجَّل لمن يرى 20/40 نتيجةُ 20/50 أو 20/30. أسطر
/// 70 و40 و25 تجعل الخطوة بين درجتين متجاورتين قريبة من 0.1 لوغاريتمية،
/// وهي حدود الخطأ المقبول سريريًا.
const List<AcuityLine> kAcuityLines = [
  AcuityLine(acuity: VisualAcuity.twentyTwoHundred, snellenDenominator: 200),
  AcuityLine(acuity: VisualAcuity.twentyHundred, snellenDenominator: 100),
  AcuityLine(acuity: VisualAcuity.twentySeventy, snellenDenominator: 70),
  AcuityLine(acuity: VisualAcuity.twentyFifty, snellenDenominator: 50),
  AcuityLine(acuity: VisualAcuity.twentyForty, snellenDenominator: 40),
  AcuityLine(acuity: VisualAcuity.twentyThirty, snellenDenominator: 30),
  AcuityLine(acuity: VisualAcuity.twentyTwentyFive, snellenDenominator: 25),
  AcuityLine(acuity: VisualAcuity.twentyTwenty, snellenDenominator: 20),
];

/// عدد الرموز في كل سطر، وعدد الإجابات الصحيحة اللازمة لاجتيازه.
///
/// أربعة رموز و‏ثلاث إجابات صحيحة — بروتوكول Peek Acuity المُتحقَّق منه
/// سريريًا. للرمز أربعة اتجاهات، أي أن التخمين الأعمى يصيب بنسبة 25%، فاحتمال
/// «اجتياز» سطرٍ بالتخمين وحده = 5.1% فقط؛ ولأن فشل السطر يُنهي الفحص فورًا
/// فإن احتمال الوصول إلى 20/20 بالتخمين يساوي هذه النسبة مرفوعة للقوة ثمانية
/// — أي صفر عمليًا.
const int kOptotypesPerLine = 4;
const int kCorrectToPass = 3;

/// عدد الإجابات الخاطئة التي تُنهي السطر.
const int kWrongToFail = kOptotypesPerLine - kCorrectToPass + 1;

/// أدنى سماكة ضلع تستطيع الشاشة رسمها: بكسل فيزيائي واحد.
const double _minStrokeDevicePx = 1.0;

/// الأسطر التي تستطيع هذه الشاشة رسمها فعلًا على هذه المسافة.
///
/// دون بكسل فيزيائي واحد لسماكة الضلع يتحوّل الحرف إلى لطخة رمادية، فتقيس
/// اللوحة حدّة الشاشة لا حدّة العين. تُقتطع الأسطر الأدقّ من ذلك بدلًا من
/// عرضها ونسبة نتيجتها إلى المفحوص. الأسطر مرتبة من الأكبر إلى الأصغر، لذا
/// المجموعة القابلة للرسم دائمًا بادئة من القائمة.
List<AcuityLine> renderableAcuityLines({
  required double pxPerMm,
  required double distanceCm,
  required double devicePixelRatio,
}) {
  final lines = [
    for (final line in kAcuityLines)
      if (line.strokeWidthMm(distanceCm) * pxPerMm * devicePixelRatio >=
          _minStrokeDevicePx)
        line,
  ];
  // حتى أسوأ الشاشات تعرض سطر 20/200؛ نُبقيه لئلا تخلو اللوحة تمامًا.
  return lines.isEmpty ? [kAcuityLines.first] : lines;
}

/// السطر المقابل لحدة إبصار، أو `null` للقيمة الواقعة تحت اللوحة.
AcuityLine? acuityLineFor(VisualAcuity acuity) {
  for (final line in kAcuityLines) {
    if (line.acuity == acuity) return line;
  }
  return null;
}

/// نتيجة فحص عين واحدة.
@immutable
class EyeResult {
  const EyeResult({
    required this.side,
    required this.acuity,
    required this.correctAnswers,
    required this.totalAnswers,
    required this.passedLines,
    required this.linesPresented,
  });

  final EyeSide side;
  final VisualAcuity acuity;
  final int correctAnswers;
  final int totalAnswers;

  /// عدد الأسطر المجتازة من أصل [linesPresented].
  final int passedLines;

  /// عدد أسطر اللوحة المعروضة فعلًا بعد اقتطاع ما تعجز الشاشة عن رسمه.
  final int linesPresented;

  /// لم يُجتَز أي سطر: الإبصار أضعف من أعلى سطر في اللوحة، ولا يجوز نسبة
  /// قيمة ذلك السطر إلى المفحوص.
  bool get belowChart => linesPresented > 0 && passedLines == 0;

  /// اكتملت اللوحة المعروضة دون أن تصل إلى 20/20 لأن الشاشة لا تكفي.
  bool get cappedByScreen =>
      linesPresented > 0 && linesPresented < kAcuityLines.length;

  double get accuracy => totalAnswers == 0 ? 0 : correctAnswers / totalAnswers;
}

/// تقرير فحص النظر الكامل، يُضمّن في البطاقة ورمز QR.
@immutable
class VisionTestReport {
  const VisionTestReport({
    required this.right,
    required this.left,
    required this.distanceCm,
    required this.testedAtUtc,
  });

  /// تقرير مُعاد بناؤه من رمز QR: يحمل حدة الإبصار وطريقة القياس، دون
  /// تفاصيل الإجابات لأن رمز QR لا يتسع لها ولا حاجة للبطاقة بها.
  factory VisionTestReport.decoded({
    required VisualAcuity right,
    required VisualAcuity left,
    required double distanceCm,
    required DateTime testedAtUtc,
  }) {
    return VisionTestReport(
      right: EyeResult(
        side: EyeSide.right,
        acuity: right,
        correctAnswers: 0,
        totalAnswers: 0,
        passedLines: 0,
        linesPresented: 0,
      ),
      left: EyeResult(
        side: EyeSide.left,
        acuity: left,
        correctAnswers: 0,
        totalAnswers: 0,
        passedLines: 0,
        linesPresented: 0,
      ),
      distanceCm: distanceCm,
      testedAtUtc: testedAtUtc,
    );
  }

  final EyeResult right;
  final EyeResult left;
  final double distanceCm;
  final DateTime testedAtUtc;

  /// الوصف الكامل للطريقة، يظهر في الشاشة و PDF.
  String get methodLabel =>
      'E المتدحرج · $kCorrectToPass من $kOptotypesPerLine لكل سطر · '
      '${distanceCm.round()} سم';

  /// وصف مختصر يناسب المساحة الضيقة على ظهر البطاقة.
  String get shortMethodLabel => 'فحص تفاعلي · ${distanceCm.round()} سم';
}
