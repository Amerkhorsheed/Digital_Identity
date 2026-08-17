import 'package:a_digital_id/models/biometric_capture.dart';
import 'package:a_digital_id/services/biometric_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth_platform_interface/local_auth_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// Stands in for the real `BiometricPrompt` / Touch ID plugin so the service's
/// capability probing and error mapping can be exercised without a device.
class _FakeLocalAuth extends LocalAuthPlatform with MockPlatformInterfaceMixin {
  _FakeLocalAuth({
    this.supportsBiometrics = true,
    this.deviceSupported = true,
    this.enrolled = const <BiometricType>[BiometricType.fingerprint],
    this.authResult = true,
    this.throwOnAuth,
    this.throwOnProbe,
  });

  bool supportsBiometrics;
  bool deviceSupported;
  List<BiometricType> enrolled;
  bool authResult;
  LocalAuthException? throwOnAuth;
  LocalAuthException? throwOnProbe;

  /// Records the options the service asked for, so the test can assert that a
  /// registration scan really does demand a biometric and not a passcode.
  AuthenticationOptions? lastOptions;

  @override
  Future<bool> deviceSupportsBiometrics() async {
    final error = throwOnProbe;
    if (error != null) throw error;
    return supportsBiometrics;
  }

  @override
  Future<bool> isDeviceSupported() async => deviceSupported;

  @override
  Future<List<BiometricType>> getEnrolledBiometrics() async => enrolled;

  @override
  Future<bool> authenticate({
    required String localizedReason,
    required Iterable<AuthMessages> authMessages,
    AuthenticationOptions options = const AuthenticationOptions(),
  }) async {
    lastOptions = options;
    final error = throwOnAuth;
    if (error != null) throw error;
    return authResult;
  }

  @override
  Future<bool> stopAuthentication() async => true;
}

/// A channel that reports the settings screens can be opened, like Android's.
MethodChannel _enrolmentChannel({bool canOpen = true, bool opened = true}) {
  const channel = MethodChannel('test/biometric');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (call) async {
    return switch (call.method) {
      'canOpenEnrollment' => canOpen,
      'openEnrollment' || 'openBiometricSettings' => opened,
      _ => null,
    };
  });
  return channel;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  BiometricService serviceWith(_FakeLocalAuth fake, {MethodChannel? channel}) {
    LocalAuthPlatform.instance = fake;
    return BiometricService(channel: channel ?? _enrolmentChannel());
  }

  group('capabilities', () {
    test('reports a ready fingerprint sensor', () async {
      final service = serviceWith(_FakeLocalAuth());
      final capabilities = await service.capabilities();

      expect(capabilities.availability, BiometricAvailability.ready);
      expect(capabilities.isReady, isTrue);
      expect(capabilities.hasFingerprint, isTrue);
      expect(capabilities.expectedMethod, BiometricMethod.fingerprint);
      expect(capabilities.statusLabel, contains('جاهز'));
    });

    test('distinguishes hardware with nothing enrolled', () async {
      final service = serviceWith(
        _FakeLocalAuth(enrolled: const <BiometricType>[]),
      );
      final capabilities = await service.capabilities();

      expect(capabilities.availability, BiometricAvailability.notEnrolled);
      expect(capabilities.hasHardware, isTrue);
      expect(capabilities.canOpenEnrollment, isTrue);
      expect(capabilities.statusLabel, contains('لا توجد بصمة مسجّلة'));
    });

    test('reports a device with no biometric hardware at all', () async {
      final service = serviceWith(
        _FakeLocalAuth(supportsBiometrics: false, deviceSupported: false),
      );
      final capabilities = await service.capabilities();

      expect(capabilities.availability, BiometricAvailability.noHardware);
      expect(capabilities.hasHardware, isFalse);
    });

    test('falls back to "no hardware" when the platform blows up', () async {
      final service = serviceWith(
        _FakeLocalAuth(
          throwOnProbe: const LocalAuthException(
            code: LocalAuthExceptionCode.noBiometricHardware,
          ),
        ),
      );

      // A broken probe must degrade to a clear "no hardware", never crash the
      // registration step.
      expect(
        (await service.capabilities()).availability,
        BiometricAvailability.noHardware,
      );
    });

    test('prefers face when only face is enrolled', () async {
      final service = serviceWith(
        _FakeLocalAuth(enrolled: const <BiometricType>[BiometricType.face]),
      );
      final capabilities = await service.capabilities();

      expect(capabilities.expectedMethod, BiometricMethod.face);
    });
  });

  group('authenticate', () {
    const ready = BiometricCapabilities(
      availability: BiometricAvailability.ready,
      enrolledTypes: <BiometricType>[BiometricType.fingerprint],
    );

    test('records a hardware capture on a successful match', () async {
      final fake = _FakeLocalAuth();
      final service = serviceWith(fake);

      final result = await service.authenticate(capabilities: ready);

      expect(result.isSuccess, isTrue);
      final capture = result.capture!;
      expect(capture.method, BiometricMethod.fingerprint);
      expect(capture.sensorLabel, isNotEmpty);
      // The attestation is a SHA-256 digest of the match context — the OS
      // never hands over fingerprint data, so there is nothing else to store.
      expect(capture.attestation, hasLength(64));
      expect(
        capture.shortAttestation,
        matches(RegExp(r'^[0-9A-F]{4}(-[0-9A-F]{4}){2}$')),
      );
    });

    test('demands a biometric rather than the device passcode', () async {
      final fake = _FakeLocalAuth();
      final service = serviceWith(fake);

      await service.authenticate(capabilities: ready);

      expect(fake.lastOptions?.biometricOnly, isTrue);
      expect(fake.lastOptions?.sensitiveTransaction, isTrue);
    });

    test('treats a non-matching finger as a retryable mismatch', () async {
      final service = serviceWith(_FakeLocalAuth(authResult: false));

      final result = await service.authenticate(capabilities: ready);

      expect(result.isSuccess, isFalse);
      expect(result.status, BiometricAuthStatus.mismatch);
      expect(result.capture, isNull);
      expect(result.message, contains('لم يتعرّف المستشعر'));
    });

    test('maps every platform failure to a status and Arabic guidance', () async {
      const expectations = <LocalAuthExceptionCode, BiometricAuthStatus>{
        LocalAuthExceptionCode.userCanceled: BiometricAuthStatus.canceled,
        LocalAuthExceptionCode.systemCanceled: BiometricAuthStatus.canceled,
        LocalAuthExceptionCode.timeout: BiometricAuthStatus.canceled,
        LocalAuthExceptionCode.userRequestedFallback:
            BiometricAuthStatus.canceled,
        LocalAuthExceptionCode.noBiometricsEnrolled:
            BiometricAuthStatus.notEnrolled,
        LocalAuthExceptionCode.noCredentialsSet:
            BiometricAuthStatus.notEnrolled,
        LocalAuthExceptionCode.noBiometricHardware:
            BiometricAuthStatus.noHardware,
        LocalAuthExceptionCode.temporaryLockout: BiometricAuthStatus.lockedOut,
        LocalAuthExceptionCode.biometricLockout: BiometricAuthStatus.lockedOut,
        LocalAuthExceptionCode.biometricHardwareTemporarilyUnavailable:
            BiometricAuthStatus.unavailable,
        LocalAuthExceptionCode.uiUnavailable: BiometricAuthStatus.unavailable,
        LocalAuthExceptionCode.authInProgress: BiometricAuthStatus.unavailable,
        LocalAuthExceptionCode.deviceError: BiometricAuthStatus.error,
        LocalAuthExceptionCode.unknownError: BiometricAuthStatus.error,
      };

      for (final entry in expectations.entries) {
        final service = serviceWith(
          _FakeLocalAuth(throwOnAuth: LocalAuthException(code: entry.key)),
        );
        final result = await service.authenticate(capabilities: ready);

        expect(result.status, entry.value, reason: 'for ${entry.key}');
        expect(result.capture, isNull, reason: 'for ${entry.key}');
        expect(
          result.message,
          isNotEmpty,
          reason: 'every failure needs guidance — ${entry.key}',
        );
      }
    });

    test('an unenrolled device points at both ways forward', () async {
      final service = serviceWith(
        _FakeLocalAuth(
          throwOnAuth: const LocalAuthException(
            code: LocalAuthExceptionCode.noBiometricsEnrolled,
          ),
        ),
      );

      final result = await service.authenticate(capabilities: ready);

      expect(result.suggestsEnrollment, isTrue);
      expect(result.message, contains('الإعدادات'));
    });
  });

  group('enrolment shortcut', () {
    test('reports success when the platform opens the settings screen', () async {
      final service = serviceWith(
        _FakeLocalAuth(),
        channel: _enrolmentChannel(opened: true),
      );
      expect(await service.openEnrollmentSettings(), isTrue);
    });

    test('reports failure on a platform with no such screen', () async {
      final service = serviceWith(
        _FakeLocalAuth(),
        channel: _enrolmentChannel(opened: false),
      );
      expect(await service.openEnrollmentSettings(), isFalse);
    });

    test('can also open the screen for deleting an enrolled print', () async {
      final service = serviceWith(
        _FakeLocalAuth(),
        channel: _enrolmentChannel(opened: true),
      );
      expect(await service.openBiometricSettings(), isTrue);
    });

    test('never throws when the channel is missing entirely', () async {
      LocalAuthPlatform.instance = _FakeLocalAuth();
      final service = BiometricService(
        channel: const MethodChannel('test/absent-biometric-channel'),
      );
      expect(await service.openEnrollmentSettings(), isFalse);
      expect(await service.openBiometricSettings(), isFalse);
    });
  });
}
