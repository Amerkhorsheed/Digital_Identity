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

/// التخصص الدراسي / المجال الأكاديمي للمتقدّم.
enum UndergraduateDegree {
  engineering('هندسة وتكنولوجيا'),
  medical('علوم طبية وصحية'),
  business('اقتصاد وإدارة أعمال'),
  law('حقوق وعلوم سياسية'),
  arts('آداب وعلوم إنسانية'),
  science('علوم أساسية'),
  other('أخرى');

  const UndergraduateDegree(this.label);
  final String label;

  static UndergraduateDegree? fromLabel(String? label) {
    if (label == null) return null;
    for (final degree in values) {
      if (degree.label == label) return degree;
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

  /// أضعف من أعلى سطر في اللوحة — لم يُجتَز سطر 20/200 نفسه.
  ///
  /// تُلحَق آخر القائمة عن قصد: رمز QR يخزّن ترتيب القيمة لا نصّها، فإدراجها
  /// في الوسط يُفسد كل بطاقة مطبوعة سابقًا.
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

/// وسيلة تصحيح الإبصار المستخدمة أثناء الفحص.
enum VisionCorrection {
  none('بدون'),
  glasses('نظارات'),
  contacts('عدسات لاصقة');

  const VisionCorrection(this.label);
  final String label;

  static VisionCorrection? fromLabel(String? label) {
    if (label == null) return null;
    for (final correction in values) {
      if (correction.label == label) return correction;
    }
    return null;
  }
}

/// البيانات الشخصية التي تُجمع أثناء التسجيل.
@immutable
class Applicant {
  const Applicant({
    required this.firstName,
    required this.lastName,
    required this.academicYear,
    required this.degree,
    required this.governorate,
    required this.city,
    this.customDegree,
    required this.heightCm,
    required this.weightKg,
    required this.bloodType,
    required this.rightEyeAcuity,
    required this.leftEyeAcuity,
    required this.visionCorrection,
    this.visionTest,
    this.photoPath,
  });

  final String firstName;
  final String lastName;
  final AcademicYear academicYear;
  final UndergraduateDegree degree;

  /// المحافظة السورية التي يتبع لها المتقدّم.
  final String governorate;
  final String city;
  final String? customDegree;
  final int heightCm;
  final double weightKg;
  final BloodType bloodType;
  final VisualAcuity rightEyeAcuity;
  final VisualAcuity leftEyeAcuity;
  final VisionCorrection visionCorrection;

  /// تفاصيل فحص النظر التفاعلي عند إجرائه داخل التطبيق.
  final VisionTestReport? visionTest;
  final String? photoPath;

  /// نسخة معدّلة — تُستخدم مثلًا لإرفاق الصورة المحفوظة محليًا ببطاقة
  /// أُعيد بناؤها من رمز QR.
  Applicant copyWith({String? photoPath, VisionTestReport? visionTest}) {
    return Applicant(
      firstName: firstName,
      lastName: lastName,
      academicYear: academicYear,
      degree: degree,
      customDegree: customDegree,
      governorate: governorate,
      city: city,
      heightCm: heightCm,
      weightKg: weightKg,
      bloodType: bloodType,
      rightEyeAcuity: rightEyeAcuity,
      leftEyeAcuity: leftEyeAcuity,
      visionCorrection: visionCorrection,
      visionTest: visionTest ?? this.visionTest,
      photoPath: photoPath ?? this.photoPath,
    );
  }

  String get fullName => '$firstName $lastName'.trim();

  String get degreeLabel => degree == UndergraduateDegree.other
      ? (customDegree?.trim().isNotEmpty == true
          ? customDegree!.trim()
          : degree.label)
      : degree.label;

  /// العنوان المختصر كما يظهر على البطاقة: «دوما، ريف دمشق».
  String get placeLabel =>
      city == governorate ? governorate : '$city، $governorate';

  bool get hasPhoto => photoPath != null && photoPath!.isNotEmpty;

  /// مصدر قياس حدة الإبصار، لتوثيقه في رمز QR وشهادة PDF.
  String get visionSourceLabel =>
      visionTest?.methodLabel ?? 'إدخال يدوي من تقرير سابق';

  /// النسخة المختصرة من المصدر، لظهر البطاقة حيث المساحة ضيقة.
  String get visionSourceShortLabel =>
      visionTest?.shortMethodLabel ?? 'إدخال يدوي';
}
