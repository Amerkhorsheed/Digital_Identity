import 'dart:convert';

import 'package:a_digital_id/models/applicant.dart';
import 'package:a_digital_id/services/id_engine.dart';
import 'package:flutter_test/flutter_test.dart';

const _applicant = Applicant(
  firstName: 'Sara',
  lastName: 'Almaziad',
  academicYear: AcademicYear.bachelor,
  degree: UndergraduateDegree.engineering,
  governorate: 'دمشق',
  city: 'المزة',
  heightCm: 165,
  weightKg: 58.5,
  bloodType: BloodType.oPositive,
  rightEyeAcuity: VisualAcuity.twentyTwenty,
  leftEyeAcuity: VisualAcuity.twentyTwenty,
  visionCorrection: VisionCorrection.none,
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
          firstName: 'Omar',
          lastName: 'Haddad',
          academicYear: AcademicYear.master,
          degree: UndergraduateDegree.medical,
          governorate: 'اللاذقية',
          city: 'جبلة',
          heightCm: 182,
          weightKg: 81,
          bloodType: BloodType.aNegative,
          rightEyeAcuity: VisualAcuity.twentyTwentyFive,
          leftEyeAcuity: VisualAcuity.twentyThirty,
          visionCorrection: VisionCorrection.glasses,
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
      expect(data['name'], 'Sara Almaziad');
      expect(data['academicYear'], 'إجازة جامعية (بكالوريوس)');
      expect(data['degree'], 'هندسة وتكنولوجيا');
      expect(data['governorate'], 'دمشق');
      expect(data['city'], 'المزة');
      expect(data['country'], 'الجمهورية العربية السورية');
      expect(data['heightCm'], 165);
      expect(data['weightKg'], 58.5);
      expect(data['bloodType'], 'O+');
      expect(data['rightEye'], '20/20');
      expect(data['leftEye'], '20/20');
      expect(data['visionCorrection'], 'بدون');
      expect(data['issuedAt'], '2026-08-16T09:30:00.000Z');
      expect(data['visionSource'], 'إدخال يدوي من تقرير سابق');
      expect(data['issuedBy'], 'الهوية الرقمية — أ');
    });

    test('uses the custom degree in the payload', () {
      const other = Applicant(
        firstName: 'A',
        lastName: 'B',
        academicYear: AcademicYear.bachelor,
        degree: UndergraduateDegree.other,
        customDegree: 'B.A. Fine Arts',
        governorate: 'طرطوس',
        city: 'صافيتا',
        heightCm: 170,
        weightKg: 70,
        bloodType: BloodType.abPositive,
        rightEyeAcuity: VisualAcuity.twentyForty,
        leftEyeAcuity: VisualAcuity.twentyFifty,
        visionCorrection: VisionCorrection.contacts,
      );
      final payload = IdEngine.buildQrPayload(
        other,
        'A-260816-XYZ999',
        DateTime.utc(2026, 8, 16),
      );
      final data = jsonDecode(payload) as Map<String, dynamic>;
      expect(data['degree'], 'B.A. Fine Arts');
    });
  });
}
