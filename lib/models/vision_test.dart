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

  /// النسبة العشرية لحدة الإبصار (1.0 تعني 20/20).
  double get decimal => 20 / snellenDenominator;

  String get label => '20/$snellenDenominator';
}

/// أسطر اللوحة الخمسة — من الأكبر إلى الأصغر، تمامًا كلوحة الطبيب.
const List<AcuityLine> kAcuityLines = [
  AcuityLine(acuity: VisualAcuity.twentyTwoHundred, snellenDenominator: 200),
  AcuityLine(acuity: VisualAcuity.twentyHundred, snellenDenominator: 100),
  AcuityLine(acuity: VisualAcuity.twentyFifty, snellenDenominator: 50),
  AcuityLine(acuity: VisualAcuity.twentyThirty, snellenDenominator: 30),
  AcuityLine(acuity: VisualAcuity.twentyTwenty, snellenDenominator: 20),
];

/// عدد الرموز في كل سطر، وعدد الإجابات الصحيحة اللازمة لاجتيازه.
const int kOptotypesPerLine = 3;
const int kCorrectToPass = 2;

/// نتيجة فحص عين واحدة.
@immutable
class EyeResult {
  const EyeResult({
    required this.side,
    required this.acuity,
    required this.correctAnswers,
    required this.totalAnswers,
    required this.passedLines,
  });

  final EyeSide side;
  final VisualAcuity acuity;
  final int correctAnswers;
  final int totalAnswers;

  /// عدد الأسطر المجتازة من أصل [kAcuityLines].length.
  final int passedLines;

  double get accuracy => totalAnswers == 0 ? 0 : correctAnswers / totalAnswers;
}

/// تقرير فحص النظر الكامل، يُضمّن في بطاقة الهوية ورمز QR.
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
      ),
      left: EyeResult(
        side: EyeSide.left,
        acuity: left,
        correctAnswers: 0,
        totalAnswers: 0,
        passedLines: 0,
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
      'فحص تفاعلي (E المتدحرج) · ${distanceCm.round()} سم';

  /// وصف مختصر يناسب المساحة الضيقة على ظهر البطاقة.
  String get shortMethodLabel => 'فحص تفاعلي · ${distanceCm.round()} سم';
}
