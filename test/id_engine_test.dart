import 'dart:convert';

import 'package:a_digital_id/models/applicant.dart';
import 'package:a_digital_id/services/id_engine.dart';
import 'package:flutter_test/flutter_test.dart';

const _applicant = Applicant(
  fullName: 'سارة محمد المزيد',
  birthYear: 2001,
  academicYear: AcademicYear.bachelor,
  governorate: 'دمشق',
  heightCm: 165,
  weightKg: 58.5,
  bloodType: BloodType.oPositive,
  rightEyeAcuity: VisualAcuity.twentyTwenty,
  leftEyeAcuity: VisualAcuity.twentyTwenty,
  hasBiometric: true,
  photoPath: '/tmp/photo.jpg',
);

void main() {
  group('IdEngine.createPersonalId', () {
    test('follows the A-YYMMDD-XXXXXX format', () async {
      final id = await IdEngine.createPersonalId(_applicant, DateTime.utc(2026, 8, 16));
      expect(RegExp(r'^A-\d{6}-[2-9A-HJ-NP-Z]{6}$').hasMatch(id), isTrue);
    });

    test('stays unique even for identical input and date', () async {
      final issuedAt = DateTime.utc(2026, 8, 16, 12);
      final a = await IdEngine.createPersonalId(_applicant, issuedAt);
      final b = await IdEngine.createPersonalId(_applicant, issuedAt);
      expect(a, isNot(b));
      expect(a, isNot(''));
    });

    test('varies across applicants and dates', () async {
      final sara = await IdEngine.createPersonalId(_applicant, DateTime.utc(2026, 8, 16));
      final other = await IdEngine.createPersonalId(
        const Applicant(
          fullName: 'عمر خالد الحداد',
          birthYear: 1999,
          academicYear: AcademicYear.master,
          governorate: 'اللاذقية',
          heightCm: 182,
          weightKg: 81,
          bloodType: BloodType.aNegative,
          rightEyeAcuity: VisualAcuity.twentyTwentyFive,
          leftEyeAcuity: VisualAcuity.twentyThirty,
          hasBiometric: true,
        ),
        DateTime.utc(2026, 8, 16),
      );
      expect(sara, isNot(other));

      final tomorrow = await IdEngine.createPersonalId(
        _applicant,
        DateTime.utc(2026, 8, 17),
      );
      expect(tomorrow, isNot(sara));
    });
  });

  group('IdEngine.buildQrPayload', () {
    test('encodes every identity detail as JSON', () {
      final payload = IdEngine.buildQrPayload(
        _applicant,
        'A-260816-ABC123',
        DateTime.utc(2026, 8, 16, 9, 30),
      );
      final data = jsonDecode(payload) as Map<String, dynamic>;

      expect(data['schema'], 'a-id/v1');
      expect(data['id'], 'A-260816-ABC123');
      expect(data['name'], 'سارة محمد المزيد');
      expect(data['birthYear'], 2001);
      expect(data['academicYear'], 'إجازة جامعية (بكالوريوس)');
      expect(data['governorate'], 'دمشق');
      expect(data['country'], 'الجمهورية العربية السورية');
      expect(data['heightCm'], 165);
      expect(data['weightKg'], 58.5);
      expect(data['bloodType'], 'O+');
      expect(data['rightEye'], '20/20');
      expect(data['leftEye'], '20/20');
      expect(data['biometric'], 'موثقة');
      expect(data['issuedAt'], '2026-08-16T09:30:00.000Z');
      expect(data['visionSource'], 'إدخال يدوي من تقرير سابق');
      expect(data['issuedBy'], 'الهوية الرقمية — أ');
    });
  });
}
