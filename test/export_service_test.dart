import 'dart:io';

import 'package:a_digital_id/models/applicant.dart';
import 'package:a_digital_id/models/biometric_capture.dart';
import 'package:a_digital_id/services/export_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

final _applicant = Applicant(
  fullName: 'Sara Almaziad',
  birthYear: 2001,
  academicYear: AcademicYear.university,
  governorate: 'دمشق',
  heightCm: 165,
  weightKg: 58.5,
  bloodType: BloodType.oPositive,
  rightEyeAcuity: VisualAcuity.twentyTwenty,
  leftEyeAcuity: VisualAcuity.twentyTwentyFive,
  biometric: BiometricCapture(
    method: BiometricMethod.fingerprint,
    capturedAtUtc: DateTime.utc(2026, 8, 16, 9, 25),
    sensorLabel: 'مستشعر بصمة الإصبع',
    attestation:
        '9f2a4c1b7e05d38a6c4b0f19d27e5a3c8b6104ff2d9e7a5c3b18604d7e2f9a1c',
  ),
);

final _issuedAt = DateTime.utc(2026, 8, 16, 9, 30);

class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  @override
  Future<String?> getTemporaryPath() async => Directory.systemTemp.path;

  @override
  Future<String?> getApplicationDocumentsPath() async =>
      Directory.systemTemp.path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  PathProviderPlatform.instance = _FakePathProvider();

  test('exportPdf writes a valid PDF file', () async {
    final file = await ExportService.exportPdf(
      applicant: _applicant,
      personalId: 'A-260816-TEST12',
      issuedAt: _issuedAt,
    );

    expect(file.existsSync(), isTrue);
    final bytes = file.readAsBytesSync();
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    file.deleteSync();
  });

  test('exportPng writes a PNG file with the card sheet', () async {
    final file = await ExportService.exportPng(
      applicant: _applicant,
      personalId: 'A-260816-TEST12',
      issuedAt: _issuedAt,
    );

    expect(file.existsSync(), isTrue);
    final bytes = file.readAsBytesSync();
    // PNG magic header.
    expect(bytes.take(8).toList(), [
      0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
    ]);
    file.deleteSync();
  });
}
