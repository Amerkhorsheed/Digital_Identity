import 'package:flutter/foundation.dart';

import 'vision_test.dart';

/// المرحلة الدراسية / المؤهل العلمي للمتقدّم.
enum AcademicYear {
  bachelor('إجازة جامعية (بكالوريوس)'),
  diploma('دبلوم معهد تقاني'),
  master('ماجستير'),
  phd('دكتوراه'),
  secondary('الشهادة الثانوية'),
  other('أخرى');

  const AcademicYear(this.label);
  final String label;

  static AcademicYear? fromLabel(String? label) {
    if (label == null) return null;
    for (final year in values) {
      if (year.label == label) return year;
    }
    return null;
  }
}

/// فصيلة الدم وفق نظام ABO / Rh.
enum BloodType {
  aPositive('A+'),
  aNegative('A−'),
  bPositive('B+'),
  bNegative('B−'),
  abPositive('AB+'),
  abNegative('AB−'),
  oPositive('O+'),
  oNegative('O−');

  const BloodType(this.label);
  final String label;

  static BloodType? fromLabel(String? label) {
    if (label == null) return null;
    for (final type in values) {
      if (type.label == label) return type;
    }
    return null;
  }
}

/// قراءات حدة الإبصار وفق جدول سنيلن.
enum VisualAcuity {
  twentyTen('20/10'),
  twentyThirteen('20/13'),
  twentySixteen('20/16'),
  twentyTwenty('20/20'),
  twentyTwentyFive('20/25'),
  twentyThirty('20/30'),
  twentyForty('20/40'),
  twentyFifty('20/50'),
  twentySeventy('20/70'),
  twentyHundred('20/100'),
  twentyTwoHundred('20/200'),
  worseThanTwentyTwoHundred('أسوأ من 20/200');

  const VisualAcuity(this.label);
  final String label;

  static VisualAcuity? fromLabel(String? label) {
    if (label == null) return null;
    for (final acuity in values) {
      if (acuity.label == label) return acuity;
    }
    return null;
  }
}

/// البيانات الشخصية التي تُجمع أثناء التسجيل.
@immutable
class Applicant {
  const Applicant({
    required this.fullName,
    required this.birthYear,
    required this.academicYear,
    required this.governorate,
    required this.heightCm,
    required this.weightKg,
    required this.bloodType,
    required this.rightEyeAcuity,
    required this.leftEyeAcuity,
    this.turnNumber = 'A-001',
    this.hasBiometric = true,
    this.visionTest,
    this.photoPath,
  });

  /// رقم الدور المحجوز (مثال: A-001).
  final String turnNumber;

  /// الاسم الثلاثي للمتقدّم.
  final String fullName;

  /// سنة الميلاد (مثال: 2001).
  final int birthYear;

  /// المرحلة الدراسية / المؤهل العلمي.
  final AcademicYear academicYear;

  /// المحافظة السورية التي يتبع لها المتقدّم.
  final String governorate;

  /// الطول بالسنتيمتر.
  final int heightCm;

  /// الوزن بالكيلوجرام.
  final double weightKg;

  /// فصيلة الدم.
  final BloodType bloodType;

  /// حدة إبصار العين اليمنى.
  final VisualAcuity rightEyeAcuity;

  /// حدة إبصار العين اليسرى.
  final VisualAcuity leftEyeAcuity;

  /// هل تم التحقق من بصمة الإصبع بيومترياً.
  final bool hasBiometric;

  /// تفاصيل فحص النظر التفاعلي عند إجرائه داخل التطبيق.
  final VisionTestReport? visionTest;

  /// مسار الصورة الشخصية محلياً.
  final String? photoPath;

  /// نسخة معدّلة.
  Applicant copyWith({
    String? fullName,
    int? birthYear,
    AcademicYear? academicYear,
    String? governorate,
    int? heightCm,
    double? weightKg,
    BloodType? bloodType,
    VisualAcuity? rightEyeAcuity,
    VisualAcuity? leftEyeAcuity,
    String? turnNumber,
    bool? hasBiometric,
    String? photoPath,
    VisionTestReport? visionTest,
  }) {
    return Applicant(
      fullName: fullName ?? this.fullName,
      birthYear: birthYear ?? this.birthYear,
      academicYear: academicYear ?? this.academicYear,
      governorate: governorate ?? this.governorate,
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
      bloodType: bloodType ?? this.bloodType,
      rightEyeAcuity: rightEyeAcuity ?? this.rightEyeAcuity,
      leftEyeAcuity: leftEyeAcuity ?? this.leftEyeAcuity,
      turnNumber: turnNumber ?? this.turnNumber,
      hasBiometric: hasBiometric ?? this.hasBiometric,
      visionTest: visionTest ?? this.visionTest,
      photoPath: photoPath ?? this.photoPath,
    );
  }

  /// العنوان كما يظهر على البطاقة.
  String get placeLabel => governorate;

  bool get hasPhoto => photoPath != null && photoPath!.isNotEmpty;

  /// مصدر قياس حدة الإبصار، لتوثيقه في رمز QR وشهادة PDF.
  String get visionSourceLabel =>
      visionTest?.methodLabel ?? 'إدخال يدوي من تقرير سابق';

  /// النسخة المختصرة من المصدر، لظهر البطاقة.
  String get visionSourceShortLabel =>
      visionTest?.shortMethodLabel ?? 'إدخال يدوي';
}
