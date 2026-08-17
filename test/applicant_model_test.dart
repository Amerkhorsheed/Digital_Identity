import 'package:a_digital_id/models/applicant.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AcademicYear', () {
    test('round-trips through its label', () {
      for (final year in AcademicYear.values) {
        expect(AcademicYear.fromLabel(year.label), year);
      }
    });

    test('returns null for unknown labels', () {
      expect(AcademicYear.fromLabel('Fifty-first Year'), isNull);
      expect(AcademicYear.fromLabel(null), isNull);
    });
  });

  group('BloodType', () {
    test('covers the full ABO/Rh matrix', () {
      expect(BloodType.values, hasLength(8));
      expect(BloodType.aPositive.label, 'A+');
      expect(BloodType.oNegative.label, 'O−');
    });

    test('parses labels', () {
      expect(BloodType.fromLabel('AB−'), BloodType.abNegative);
      expect(BloodType.fromLabel('B+'), BloodType.bPositive);
      expect(BloodType.fromLabel('Z+'), isNull);
    });
  });

  group('VisualAcuity', () {
    test('contains standard Snellen values', () {
      expect(VisualAcuity.twentyTwenty.label, '20/20');
      expect(VisualAcuity.fromLabel('20/40'), VisualAcuity.twentyForty);
    });
  });

  group('Applicant', () {
    const base = Applicant(
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

    test('composes the full name', () {
      expect(base.fullName, 'سارة محمد المزيد');
    });

    test('renders the place as governorate', () {
      expect(base.placeLabel, 'دمشق');
    });

    test('falls back to a manual vision source without a test report', () {
      expect(base.visionSourceLabel, 'إدخال يدوي من تقرير سابق');
    });

    test('hasPhoto reflects the photo path', () {
      expect(base.hasPhoto, isTrue);
      const noPhoto = Applicant(
        fullName: 'عمر خالد الحداد',
        birthYear: 1999,
        academicYear: AcademicYear.master,
        governorate: 'حمص',
        heightCm: 170,
        weightKg: 70,
        bloodType: BloodType.oPositive,
        rightEyeAcuity: VisualAcuity.twentyTwenty,
        leftEyeAcuity: VisualAcuity.twentyTwenty,
      );
      expect(noPhoto.hasPhoto, isFalse);
    });
  });
}
