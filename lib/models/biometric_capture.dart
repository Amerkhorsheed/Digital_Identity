import 'package:flutter/foundation.dart';

/// وسيلة القياس الحيوي المستخدَمة في التوثيق.
///
/// المسارات الأربعة الأولى تمرّ عبر مستشعر الجهاز المدمج — `BiometricPrompt`
/// على أندرويد، و`Touch ID` / `Face ID` على iOS — فيشغّل نظام التشغيل المستشعر
/// ويعيد قرار مطابقة موقّعًا مقابل بصمة مسجّلة مسبقًا في الإعدادات.
///
/// [touchCapture] مسار مختلف في طبيعته: يقيس تماسّ الإصبع على لوحة اللمس
/// نفسها (مساحة التماس، والضغط، وثبات الموضع، ومدة الاستقرار). قياسات حقيقية
/// لإصبع حقيقي، لكنها **ليست** مطابقة لخطوط البصمة، ولا تتطلّب تسجيلًا مسبقًا
/// على الجهاز — وهو ما يجعلها المسار العملي حين يمرّ آلاف المتقدّمين على
/// الجهاز نفسه.
enum BiometricMethod {
  fingerprint(
    code: 'HW-FP',
    label: 'بصمة إصبع — مستشعر الجهاز',
    shortLabel: 'بصمة إصبع',
  ),
  face(
    code: 'HW-FACE',
    label: 'تعرّف على الوجه — مستشعر الجهاز',
    shortLabel: 'تعرّف على الوجه',
  ),
  iris(
    code: 'HW-IRIS',
    label: 'بصمة قزحية — مستشعر الجهاز',
    shortLabel: 'بصمة قزحية',
  ),
  strongBiometric(
    code: 'HW-BIO',
    label: 'قياس حيوي موثّق من الجهاز',
    shortLabel: 'قياس حيوي',
  ),
  touchCapture(
    code: 'TP-FP',
    label: 'التقاط بصمة — لوحة اللمس',
    shortLabel: 'التقاط لمسي',
  );

  const BiometricMethod({
    required this.code,
    required this.label,
    required this.shortLabel,
  });

  /// رمز مختصر لاتينيّ يُطبع في رمز QR وشهادة الـ PDF.
  final String code;

  /// الوصف الكامل بالعربية.
  final String label;

  /// وصف مختصر يظهر على ظهر البطاقة.
  final String shortLabel;

  /// هل هذه مطابقة موقّعة من عتاد الجهاز مقابل بصمة مسجّلة؟
  bool get isHardwareMatch => this != BiometricMethod.touchCapture;

  static BiometricMethod? fromCode(String? code) {
    if (code == null) return null;
    for (final method in values) {
      if (method.code == code) return method;
    }
    return null;
  }
}

/// سجلّ مطابقة بيومترية واحدة ناجحة، مرفق ببطاقة الهوية.
///
/// السجل يوثّق **كيف** أُثبتت الهوية لا مجرد أنها أُثبتت: الوسيلة المستخدمة،
/// واسم المستشعر كما بلّغ عنه النظام، ولحظة المطابقة، وبصمة تدقيق تربط كل ذلك
/// بسجلّ البطاقة.
@immutable
class BiometricCapture {
  const BiometricCapture({
    required this.method,
    required this.capturedAtUtc,
    this.sensorLabel,
    this.attestation,
    this.qualityScore,
  });

  /// الوسيلة التي تم بها التوثيق.
  final BiometricMethod method;

  /// لحظة نجاح الالتقاط (UTC).
  final DateTime capturedAtUtc;

  /// اسم المستشعر كما يُعرض للمشغّل (مثل `Touch ID`).
  final String? sensorLabel;

  /// بصمة تدقيق SHA-256 تربط السجل بلحظة الالتقاط ووسيلته ومستشعره.
  ///
  /// في مسار العتاد: ليست قالبًا بيومتريًا ولا مشتقة من بيانات بصمة — نظام
  /// التشغيل لا يعطي التطبيق أي بيانات بصمة على الإطلاق.
  /// في مسار اللمس: تُشتق من قياسات التماسّ الفعلية المسجّلة أثناء الالتقاط.
  final String? attestation;

  /// درجة جودة الالتقاط من 0 إلى 100 — لمسار اللمس فقط.
  ///
  /// مطابقة العتاد إمّا تنجح أو تفشل، فلا توجد لها درجة وسطية.
  final int? qualityScore;

  /// هل السجل ناتج عن مطابقة موقّعة من عتاد الجهاز؟
  bool get isHardwareMatch => method.isHardwareMatch;

  /// كيف تُوصَف حالة التوثيق على البطاقة وفي الشهادة.
  ///
  /// مطابقة العتاد «موثقة» لأن نظام التشغيل وقّع عليها؛ والتقاط اللمس
  /// «مُلتقطة» لأنه قياس تماسّ حقيقي لكنه ليس مطابقة موقّعة.
  String get verificationLabel => isHardwareMatch ? 'موثقة' : 'مُلتقطة';

  /// أول 12 محرفًا من بصمة التدقيق، بصيغة `A1B2-C3D4-E5F6` لعرضها على البطاقة.
  String? get shortAttestation {
    final hash = attestation;
    if (hash == null || hash.length < 12) return null;
    final head = hash.substring(0, 12).toUpperCase();
    return '${head.substring(0, 4)}-${head.substring(4, 8)}-${head.substring(8, 12)}';
  }

  /// السطر الذي يُطبع على ظهر البطاقة وفي شهادة الـ PDF.
  String get provenanceLabel {
    final buffer = StringBuffer(method.shortLabel);
    final sensor = sensorLabel;
    if (sensor != null && sensor.isNotEmpty) buffer.write(' · $sensor');
    final quality = qualityScore;
    if (quality != null) buffer.write(' · جودة $quality٪');
    final short = shortAttestation;
    if (short != null) buffer.write(' · $short');
    return buffer.toString();
  }

  BiometricCapture copyWith({
    BiometricMethod? method,
    DateTime? capturedAtUtc,
    String? sensorLabel,
    String? attestation,
    int? qualityScore,
  }) {
    return BiometricCapture(
      method: method ?? this.method,
      capturedAtUtc: capturedAtUtc ?? this.capturedAtUtc,
      sensorLabel: sensorLabel ?? this.sensorLabel,
      attestation: attestation ?? this.attestation,
      qualityScore: qualityScore ?? this.qualityScore,
    );
  }

  /// تمثيل مقروء آليًا يُدرج في حمولة رمز QR.
  Map<String, Object?> toJson() => <String, Object?>{
        'method': method.code,
        'methodLabel': method.label,
        'verification': verificationLabel,
        'capturedAt': capturedAtUtc.toIso8601String(),
        if (sensorLabel != null) 'sensor': sensorLabel,
        if (qualityScore != null) 'quality': qualityScore,
        if (attestation != null) 'attestation': attestation,
      };

  /// يعيد بناء السجل من حمولة رمز QR، أو `null` إن كانت غير صالحة.
  static BiometricCapture? fromJson(Map<String, Object?>? json) {
    if (json == null) return null;
    final method = BiometricMethod.fromCode(json['method'] as String?);
    if (method == null) return null;
    final capturedAt = DateTime.tryParse(json['capturedAt'] as String? ?? '');
    return BiometricCapture(
      method: method,
      capturedAtUtc:
          (capturedAt ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true))
              .toUtc(),
      sensorLabel: json['sensor'] as String?,
      attestation: json['attestation'] as String?,
      qualityScore: (json['quality'] as num?)?.round().clamp(0, 100),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BiometricCapture &&
          other.method == method &&
          other.capturedAtUtc == capturedAtUtc &&
          other.sensorLabel == sensorLabel &&
          other.attestation == attestation &&
          other.qualityScore == qualityScore;

  @override
  int get hashCode => Object.hash(
        method,
        capturedAtUtc,
        sensorLabel,
        attestation,
        qualityScore,
      );

  @override
  String toString() =>
      'BiometricCapture(${method.code}, ${shortAttestation ?? '—'})';
}
