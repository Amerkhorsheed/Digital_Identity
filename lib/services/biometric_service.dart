import 'dart:convert';
import 'dart:io' show Platform;

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';
import 'package:local_auth_darwin/local_auth_darwin.dart';

import '../models/biometric_capture.dart';

export 'package:local_auth/local_auth.dart' show BiometricType;

/// حالة عتاد القياس الحيوي على هذا الجهاز.
enum BiometricAvailability {
  /// لم يُفحص بعد.
  unknown,

  /// الجهاز لا يملك مستشعرًا بيومتريًا إطلاقًا.
  noHardware,

  /// يوجد مستشعر لكنه غير متاح حاليًا (مشغول أو معطّل مؤقتًا).
  hardwareUnavailable,

  /// يوجد مستشعر لكن لا توجد أي بصمة مسجّلة في إعدادات الجهاز.
  notEnrolled,

  /// المستشعر جاهز وتوجد بصمة مسجّلة.
  ready,

  /// المستشعر مقفل بعد محاولات فاشلة متكررة.
  lockedOut,
}

/// وصف قدرات الجهاز البيومترية كما بلّغ عنها نظام التشغيل.
@immutable
class BiometricCapabilities {
  const BiometricCapabilities({
    required this.availability,
    this.enrolledTypes = const <BiometricType>[],
    this.canOpenEnrollment = false,
  });

  static const BiometricCapabilities unknown =
      BiometricCapabilities(availability: BiometricAvailability.unknown);

  final BiometricAvailability availability;

  /// أنواع القياسات الحيوية المسجّلة والمتاحة للتطبيق.
  final List<BiometricType> enrolledTypes;

  /// هل يمكن فتح شاشة تسجيل البصمة في الإعدادات من داخل التطبيق؟
  final bool canOpenEnrollment;

  bool get isReady => availability == BiometricAvailability.ready;

  bool get hasHardware =>
      availability != BiometricAvailability.noHardware &&
      availability != BiometricAvailability.unknown;

  bool get hasFingerprint => enrolledTypes.contains(BiometricType.fingerprint);

  bool get hasFace => enrolledTypes.contains(BiometricType.face);

  bool get hasIris => enrolledTypes.contains(BiometricType.iris);

  /// الوسيلة التي ستُسجَّل عند نجاح المطابقة.
  ///
  /// نظام التشغيل لا يُبلّغ أي وسيلة طابقت فعلاً، لذا نعتمد على النوع المسجّل
  /// الأعلى أولوية، ونفضّل بصمة الإصبع لأنها المطلوبة في هذا التسجيل.
  BiometricMethod get expectedMethod {
    if (hasFingerprint) return BiometricMethod.fingerprint;
    if (hasFace) return BiometricMethod.face;
    if (hasIris) return BiometricMethod.iris;
    return BiometricMethod.strongBiometric;
  }

  /// اسم المستشعر كما يُعرض للمشغّل.
  String get sensorLabel {
    if (hasFingerprint) {
      return Platform.isIOS ? 'Touch ID' : 'مستشعر بصمة الإصبع';
    }
    if (hasFace) return Platform.isIOS ? 'Face ID' : 'مستشعر التعرّف على الوجه';
    if (hasIris) return 'مستشعر القزحية';
    return 'المستشعر البيومتري';
  }

  /// شرح حالة العتاد بالعربية.
  String get statusLabel => switch (availability) {
        BiometricAvailability.unknown => 'جارٍ فحص مستشعر الجهاز...',
        BiometricAvailability.noHardware =>
          'لا يحتوي هذا الجهاز على مستشعر بصمة.',
        BiometricAvailability.hardwareUnavailable =>
          'مستشعر الجهاز غير متاح حاليًا.',
        BiometricAvailability.notEnrolled =>
          'المستشعر يعمل، لكن لا توجد بصمة مسجّلة على هذا الجهاز بعد.',
        BiometricAvailability.lockedOut =>
          'أُقفل المستشعر بعد محاولات فاشلة متكررة.',
        BiometricAvailability.ready => 'المستشعر جاهز — $sensorLabel.',
      };
}

/// تصنيف نتيجة المطابقة.
enum BiometricAuthStatus {
  success,
  canceled,
  mismatch,
  notEnrolled,
  noHardware,
  lockedOut,
  unavailable,
  error,
}

/// نتيجة محاولة مطابقة على مستشعر الجهاز.
@immutable
class BiometricAuthResult {
  const BiometricAuthResult._({
    required this.status,
    this.capture,
    this.message,
  });

  factory BiometricAuthResult.success(BiometricCapture capture) =>
      BiometricAuthResult._(
        status: BiometricAuthStatus.success,
        capture: capture,
      );

  factory BiometricAuthResult.failure(
    BiometricAuthStatus status,
    String message,
  ) =>
      BiometricAuthResult._(status: status, message: message);

  final BiometricAuthStatus status;
  final BiometricCapture? capture;
  final String? message;

  bool get isSuccess => status == BiometricAuthStatus.success;

  /// هل يصلح فتح شاشة تسجيل البصمة كخطوة تصحيح؟
  bool get suggestsEnrollment => status == BiometricAuthStatus.notEnrolled;
}

/// يشغّل مستشعر البصمة المدمج في الجهاز عبر `BiometricPrompt` على أندرويد
/// و`Touch ID` / `Face ID` على iOS.
///
/// ## حدّ يفرضه نظام التشغيل، لا التطبيق
///
/// المستشعر المدمج يطابق **فقط** البصمات المسجّلة في إعدادات الجهاز، ولا
/// يسلّم التطبيق صورة ولا قالبًا — يعيد قرار مطابقة موقّعًا لا غير. هذا مبيّت
/// في المنطقة الموثوقة (TEE) داخل المعالج نفسه، ولا توجد واجهة برمجية عامة
/// تتجاوزه على أي هاتف.
///
/// عمليًا، توثيق متقدّم لم تُسجَّل بصمته يمرّ بثلاث خطوات:
/// تسجيل بصمته في الإعدادات ← مطابقتها هنا ← حذفها بعد إصدار البطاقة.
/// لذلك تفتح [openEnrollmentSettings] شاشة التسجيل مباشرة، وتُعاد قراءة
/// [capabilities] تلقائيًا عند العودة إلى التطبيق.
class BiometricService {
  BiometricService({
    LocalAuthentication? auth,
    MethodChannel? channel,
  })  : _auth = auth ?? LocalAuthentication(),
        _channel = channel ?? const MethodChannel(channelName);

  /// قناة أصلية تفتح شاشات إعدادات القياسات الحيوية.
  static const String channelName = 'com.adigitalid.app/biometric';

  final LocalAuthentication _auth;
  final MethodChannel _channel;

  /// يفحص عتاد الجهاز وحالة التسجيل.
  Future<BiometricCapabilities> capabilities() async {
    try {
      final supportsBiometrics = await _auth.canCheckBiometrics;
      final deviceSupported = await _auth.isDeviceSupported();

      if (!supportsBiometrics && !deviceSupported) {
        return const BiometricCapabilities(
          availability: BiometricAvailability.noHardware,
        );
      }

      final enrolled = await _auth.getAvailableBiometrics();
      final canEnroll = await _invokeBool('canOpenEnrollment');

      if (enrolled.isEmpty) {
        return BiometricCapabilities(
          availability: supportsBiometrics
              ? BiometricAvailability.notEnrolled
              : BiometricAvailability.noHardware,
          canOpenEnrollment: canEnroll,
        );
      }

      return BiometricCapabilities(
        availability: BiometricAvailability.ready,
        enrolledTypes: enrolled,
        canOpenEnrollment: canEnroll,
      );
    } on LocalAuthException catch (error) {
      return BiometricCapabilities(
        availability: _availabilityFor(error.code),
        canOpenEnrollment: await _invokeBool('canOpenEnrollment'),
      );
    } catch (_) {
      return const BiometricCapabilities(
        availability: BiometricAvailability.noHardware,
      );
    }
  }

  /// يعرض واجهة النظام ويطلب مطابقة بيومترية حقيقية على المستشعر.
  ///
  /// `biometricOnly` مثبّتة على `true`: التسجيل يتطلّب وضع إصبع على المستشعر،
  /// ولا يقبل رمز قفل الجهاز أو نمطه بديلاً عنه.
  Future<BiometricAuthResult> authenticate({
    required BiometricCapabilities capabilities,
  }) async {
    try {
      final matched = await _auth.authenticate(
        localizedReason:
            'ضع إصبع المتقدّم على مستشعر الجهاز لتوثيق بصمته ضمن بطاقة الهوية.',
        biometricOnly: true,
        sensitiveTransaction: true,
        persistAcrossBackgrounding: true,
        authMessages: const <AuthMessages>[
          AndroidAuthMessages(
            signInTitle: 'التوثيق البيومتري',
            signInHint: 'ضع الإصبع على مستشعر البصمة',
            cancelButton: 'إلغاء',
          ),
          IOSAuthMessages(cancelButton: 'إلغاء'),
        ],
      );

      if (!matched) {
        return BiometricAuthResult.failure(
          BiometricAuthStatus.mismatch,
          'لم يتعرّف المستشعر على البصمة. نظّف الإصبع والمستشعر ثم أعد المحاولة.',
        );
      }

      final capturedAt = DateTime.now().toUtc();
      final method = capabilities.expectedMethod;
      final sensor = capabilities.sensorLabel;

      return BiometricAuthResult.success(
        BiometricCapture(
          method: method,
          capturedAtUtc: capturedAt,
          sensorLabel: sensor,
          attestation: await _attestation(
            method: method,
            capturedAtUtc: capturedAt,
            sensorLabel: sensor,
          ),
        ),
      );
    } on LocalAuthException catch (error) {
      return BiometricAuthResult.failure(
        _statusFor(error.code),
        _messageFor(error.code, error.description),
      );
    } catch (_) {
      return BiometricAuthResult.failure(
        BiometricAuthStatus.error,
        'تعذّر تشغيل مستشعر الجهاز.',
      );
    }
  }

  /// يلغي أي مطالبة مطابقة معروضة حاليًا.
  Future<void> cancel() async {
    try {
      await _auth.stopAuthentication();
    } catch (_) {
      // المطالبة إما أُغلقت أو لم تكن معروضة.
    }
  }

  /// يفتح شاشة **تسجيل** بصمة جديدة في إعدادات النظام.
  ///
  /// التسجيل نفسه لا يمكن أن يتم داخل التطبيق: أندرويد و iOS يحصرانه في
  /// الإعدادات خلف رمز قفل الجهاز. أقصى ما يستطيعه التطبيق هو إيصال المشغّل
  /// إلى الشاشة الصحيحة مباشرة، وهو ما تفعله هذه الدالة.
  Future<bool> openEnrollmentSettings() => _invokeBool('openEnrollment');

  /// يفتح شاشة **إدارة** البصمات المسجّلة، لحذف بصمة متقدّم بعد إصدار بطاقته.
  Future<bool> openBiometricSettings() => _invokeBool('openBiometricSettings');

  Future<bool> _invokeBool(String method) async {
    try {
      return await _channel.invokeMethod<bool>(method) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// بصمة تدقيق للمطابقة.
  ///
  /// ليست قالبًا بيومتريًا ولا مشتقة من بيانات بصمة — نظام التشغيل لا يعطي
  /// التطبيق أي بيانات بصمة — بل تجزيء يربط سجلّ البطاقة بلحظة المطابقة
  /// ووسيلتها والمستشعر المستخدَم.
  Future<String> _attestation({
    required BiometricMethod method,
    required DateTime capturedAtUtc,
    required String sensorLabel,
  }) async {
    final platform = kIsWeb ? 'web' : Platform.operatingSystem;
    final canonical =
        '${method.code}|${capturedAtUtc.toIso8601String()}|$platform|$sensorLabel';
    final hash = await Sha256().hash(utf8.encode(canonical));
    final buffer = StringBuffer();
    for (final byte in hash.bytes) {
      buffer.write(byte.toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }

  static BiometricAvailability _availabilityFor(LocalAuthExceptionCode code) =>
      switch (code) {
        LocalAuthExceptionCode.noBiometricHardware =>
          BiometricAvailability.noHardware,
        LocalAuthExceptionCode.noBiometricsEnrolled ||
        LocalAuthExceptionCode.noCredentialsSet =>
          BiometricAvailability.notEnrolled,
        LocalAuthExceptionCode.biometricLockout ||
        LocalAuthExceptionCode.temporaryLockout =>
          BiometricAvailability.lockedOut,
        LocalAuthExceptionCode.biometricHardwareTemporarilyUnavailable =>
          BiometricAvailability.hardwareUnavailable,
        _ => BiometricAvailability.noHardware,
      };

  static BiometricAuthStatus _statusFor(LocalAuthExceptionCode code) =>
      switch (code) {
        LocalAuthExceptionCode.userCanceled ||
        LocalAuthExceptionCode.systemCanceled ||
        LocalAuthExceptionCode.timeout ||
        LocalAuthExceptionCode.userRequestedFallback =>
          BiometricAuthStatus.canceled,
        LocalAuthExceptionCode.noBiometricsEnrolled ||
        LocalAuthExceptionCode.noCredentialsSet =>
          BiometricAuthStatus.notEnrolled,
        LocalAuthExceptionCode.noBiometricHardware =>
          BiometricAuthStatus.noHardware,
        LocalAuthExceptionCode.biometricLockout ||
        LocalAuthExceptionCode.temporaryLockout =>
          BiometricAuthStatus.lockedOut,
        LocalAuthExceptionCode.biometricHardwareTemporarilyUnavailable ||
        LocalAuthExceptionCode.uiUnavailable ||
        LocalAuthExceptionCode.authInProgress =>
          BiometricAuthStatus.unavailable,
        _ => BiometricAuthStatus.error,
      };

  static String _messageFor(LocalAuthExceptionCode code, String? description) =>
      switch (code) {
        LocalAuthExceptionCode.userCanceled ||
        LocalAuthExceptionCode.userRequestedFallback =>
          'أُلغيت عملية المسح. أعد المحاولة عندما يكون المتقدّم جاهزًا.',
        LocalAuthExceptionCode.systemCanceled =>
          'أوقف النظام عملية المسح. أبقِ التطبيق في المقدّمة وأعد المحاولة.',
        LocalAuthExceptionCode.timeout =>
          'انتهت مهلة المستشعر قبل قراءة البصمة. أعد المحاولة.',
        LocalAuthExceptionCode.noBiometricsEnrolled ||
        LocalAuthExceptionCode.noCredentialsSet =>
          'لا توجد بصمة مسجّلة على هذا الجهاز. سجّل بصمة المتقدّم من الإعدادات '
              'ثم عد وأعد المحاولة.',
        LocalAuthExceptionCode.noBiometricHardware =>
          'لا يحتوي هذا الجهاز على مستشعر بصمة.',
        LocalAuthExceptionCode.temporaryLockout =>
          'أُقفل المستشعر مؤقتًا بعد محاولات فاشلة. انتظر ثلاثين ثانية ثم أعد '
              'المحاولة.',
        LocalAuthExceptionCode.biometricLockout =>
          'أُقفل المستشعر. افتح قفل الجهاز برمز المرور مرة واحدة ثم أعد المحاولة.',
        LocalAuthExceptionCode.biometricHardwareTemporarilyUnavailable =>
          'مستشعر البصمة مشغول حاليًا. أغلق التطبيقات الأخرى وأعد المحاولة.',
        LocalAuthExceptionCode.uiUnavailable =>
          'تعذّر عرض واجهة المستشعر. أعد فتح التطبيق وحاول مجددًا.',
        LocalAuthExceptionCode.authInProgress =>
          'هناك عملية مسح جارية بالفعل. انتظر انتهاءها.',
        LocalAuthExceptionCode.deviceError ||
        LocalAuthExceptionCode.unknownError =>
          description == null || description.isEmpty
              ? 'حدث خطأ في مستشعر الجهاز. أعد المحاولة.'
              : 'خطأ في مستشعر الجهاز: $description',
      };
}
