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

  group('UndergraduateDegree', () {
    test('round-trips through its label', () {
      for (final degree in UndergraduateDegree.values) {
        expect(UndergraduateDegree.fromLabel(degree.label), degree);
      }
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

  group('VisionCorrection', () {
    test('round-trips through its label', () {
      expect(VisionCorrection.fromLabel('نظارات'), VisionCorrection.glasses);
      expect(VisionCorrection.fromLabel('بدون'), VisionCorrection.none);
      expect(VisionCorrection.fromLabel('Laser'), isNull);
    });
  });

  group('Applicant', () {
    const base = Applicant(
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

    test('composes the full name', () {
      expect(base.fullName, 'Sara Almaziad');
    });

    test('renders the place as city then governorate', () {
      expect(base.placeLabel, 'المزة، دمشق');
    });

    test('collapses the place when the city is the governorate seat', () {
      const seat = Applicant(
        firstName: 'A',
        lastName: 'B',
        academicYear: AcademicYear.bachelor,
        degree: UndergraduateDegree.arts,
        governorate: 'حلب',
        city: 'حلب',
        heightCm: 170,
        weightKg: 70,
        bloodType: BloodType.oPositive,
        rightEyeAcuity: VisualAcuity.twentyTwenty,
        leftEyeAcuity: VisualAcuity.twentyTwenty,
        visionCorrection: VisionCorrection.none,
      );
      expect(seat.placeLabel, 'حلب');
    });

    test('falls back to a manual vision source without a test report', () {
      expect(base.visionSourceLabel, 'إدخال يدوي من تقرير سابق');
    });

    test('uses the custom degree label when Other is selected', () {
      const other = Applicant(
        firstName: 'A',
        lastName: 'B',
        academicYear: AcademicYear.bachelor,
        degree: UndergraduateDegree.other,
        customDegree: 'B.A. Fine Arts',
        governorate: 'حلب',
        city: 'حلب',
        heightCm: 180,
        weightKg: 75,
        bloodType: BloodType.aPositive,
        rightEyeAcuity: VisualAcuity.twentyTwenty,
        leftEyeAcuity: VisualAcuity.twentyTwenty,
        visionCorrection: VisionCorrection.none,
      );
      expect(other.degreeLabel, 'B.A. Fine Arts');
    });

    test('hasPhoto reflects the photo path', () {
      expect(base.hasPhoto, isTrue);
      const noPhoto = Applicant(
        firstName: 'A',
        lastName: 'B',
        academicYear: AcademicYear.bachelor,
        degree: UndergraduateDegree.arts,
        governorate: 'حمص',
        city: 'تدمر',
        heightCm: 170,
        weightKg: 70,
        bloodType: BloodType.oPositive,
        rightEyeAcuity: VisualAcuity.twentyTwenty,
        leftEyeAcuity: VisualAcuity.twentyTwenty,
        visionCorrection: VisionCorrection.none,
      );
      expect(noPhoto.hasPhoto, isFalse);
    });
  });
}
