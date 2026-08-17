import 'dart:convert';

import 'package:a_digital_id/config/verify_endpoint.dart';
import 'package:a_digital_id/models/applicant.dart';
import 'package:a_digital_id/models/vision_test.dart';
import 'package:a_digital_id/services/card_link.dart';
import 'package:flutter_test/flutter_test.dart';

final _report = VisionTestReport.decoded(
  right: VisualAcuity.twentyTwenty,
  left: VisualAcuity.twentyThirty,
  distanceCm: 40,
  testedAtUtc: DateTime.utc(2026, 8, 16),
);

final _applicant = Applicant(
  firstName: 'سارة',
  lastName: 'الحلبي',
  academicYear: AcademicYear.third,
  degree: UndergraduateDegree.bcs,
  governorate: 'ريف دمشق',
  city: 'دوما',
  heightCm: 165,
  weightKg: 58.5,
  bloodType: BloodType.oPositive,
  rightEyeAcuity: VisualAcuity.twentyTwenty,
  leftEyeAcuity: VisualAcuity.twentyThirty,
  visionCorrection: VisionCorrection.glasses,
  visionTest: _report,
  photoPath: '/tmp/portrait.jpg',
);

const _id = 'A-260816-K7M2QX';
final _issuedAt = DateTime.utc(2026, 8, 16, 9, 30);

String _encode([Applicant? applicant]) => CardLink.encode(
      applicant: applicant ?? _applicant,
      personalId: _id,
      issuedAtUtc: _issuedAt,
    );

void main() {
  test('produces a link, not a wall of JSON', () {
    final link = _encode();
    expect(CardLink.looksLikeCard(link), isTrue);
    // Whatever a scanner reads, it must not be raw personal data.
    expect(link, isNot(contains('سارة')));
  });

  test('falls back to the app scheme until a verifier page is configured', () {
    // A phone camera cannot act on this — which is exactly why the hosted
    // https page exists. The fallback only keeps the in-app scanner working.
    expect(kHasHostedVerifier, isFalse);
    expect(_encode(), startsWith('adigitalid://card?v=2&d='));
  });

  test('reads a hosted verifier link with the payload in its fragment', () {
    final payload = CardLink.encodePayload(
      applicant: _applicant,
      personalId: _id,
      issuedAtUtc: _issuedAt,
    );
    // The host is not part of the contract: the page can be rehosted, and old
    // cards keep working, because only the fragment carries the data.
    for (final host in [
      'https://example.com/id',
      'https://someone.github.io/a-id/',
      'http://192.168.1.4:8765/index.html',
    ]) {
      final card = CardLink.decode('$host#$payload');
      expect(card, isNotNull, reason: host);
      expect(card!.personalId, _id);
      expect(card.applicant.city, 'دوما');
    }
  });

  test('keeps the payload out of anything a server would ever see', () {
    final payload = CardLink.encodePayload(
      applicant: _applicant,
      personalId: _id,
      issuedAtUtc: _issuedAt,
    );
    final uri = Uri.parse('https://example.com/id#$payload');
    // Fragments are never transmitted in an HTTP request.
    expect(uri.path, '/id');
    expect(uri.query, isEmpty);
    expect(uri.fragment, payload);
  });

  test('stays small enough for a comfortably scannable symbol', () {
    // A dense QR is a slow, failure-prone QR; the raw JSON payload was ~450
    // characters. Anything under 300 scans instantly at card size.
    expect(_encode().length, lessThan(300));
  });

  test('round-trips every field the card prints', () {
    final card = CardLink.decode(_encode())!;

    expect(card.personalId, _id);
    expect(card.issuedAt, _issuedAt);
    expect(card.applicant.fullName, 'سارة الحلبي');
    expect(card.applicant.academicYear, AcademicYear.third);
    expect(card.applicant.degreeLabel, 'بكالوريوس علوم الحاسب');
    expect(card.applicant.governorate, 'ريف دمشق');
    expect(card.applicant.city, 'دوما');
    expect(card.applicant.placeLabel, 'دوما، ريف دمشق');
    expect(card.applicant.heightCm, 165);
    expect(card.applicant.weightKg, 58.5);
    expect(card.applicant.bloodType, BloodType.oPositive);
    expect(card.applicant.rightEyeAcuity, VisualAcuity.twentyTwenty);
    expect(card.applicant.leftEyeAcuity, VisualAcuity.twentyThirty);
    expect(card.applicant.visionCorrection, VisionCorrection.glasses);
    expect(card.applicant.visionSourceShortLabel, 'فحص تفاعلي · 40 سم');
  });

  test('carries a custom major through verbatim', () {
    final custom = Applicant(
      firstName: 'عمر',
      lastName: 'الحداد',
      academicYear: AcademicYear.first,
      degree: UndergraduateDegree.other,
      customDegree: 'بكالوريوس فنون جميلة',
      governorate: 'حلب',
      city: 'منبج',
      heightCm: 180,
      weightKg: 75,
      bloodType: BloodType.aNegative,
      rightEyeAcuity: VisualAcuity.twentyForty,
      leftEyeAcuity: VisualAcuity.twentyFifty,
      visionCorrection: VisionCorrection.none,
    );

    final card = CardLink.decode(_encode(custom))!;
    expect(card.applicant.degree, UndergraduateDegree.other);
    expect(card.applicant.degreeLabel, 'بكالوريوس فنون جميلة');
  });

  test('marks a manually entered acuity as such', () {
    final manual = _applicant.copyWith();
    final withoutTest = Applicant(
      firstName: manual.firstName,
      lastName: manual.lastName,
      academicYear: manual.academicYear,
      degree: manual.degree,
      governorate: manual.governorate,
      city: manual.city,
      heightCm: manual.heightCm,
      weightKg: manual.weightKg,
      bloodType: manual.bloodType,
      rightEyeAcuity: manual.rightEyeAcuity,
      leftEyeAcuity: manual.leftEyeAcuity,
      visionCorrection: manual.visionCorrection,
    );

    final card = CardLink.decode(_encode(withoutTest))!;
    expect(card.applicant.visionTest, isNull);
    expect(card.applicant.visionSourceShortLabel, 'إدخال يدوي');
  });

  group('rejects anything that is not a valid card', () {
    test('other QR codes', () {
      expect(CardLink.decode('https://example.com'), isNull);
      expect(CardLink.decode('just some text'), isNull);
      expect(CardLink.decode(''), isNull);
      expect(CardLink.looksLikeCard('https://example.com'), isFalse);
    });

    test('a corrupted payload', () {
      final link = _encode();
      // Flip a character in the middle of the data.
      final index = link.length ~/ 2;
      final corrupted = link.replaceRange(
        index,
        index + 1,
        link[index] == 'A' ? 'B' : 'A',
      );
      expect(CardLink.decode(corrupted), isNull);
    });

    test('a truncated payload', () {
      final link = _encode();
      expect(CardLink.decode(link.substring(0, link.length - 12)), isNull);
    });

    test('a newer format version', () {
      final payload = CardLink.encodePayload(
        applicant: _applicant,
        personalId: _id,
        issuedAtUtc: _issuedAt,
      );
      final bytes = base64Url.decode(base64Url.normalize(payload));
      bytes[0] = 99;
      final bumped = base64Url.encode(bytes).replaceAll('=', '');
      expect(CardLink.decode('https://example.com/id#$bumped'), isNull);
    });
  });

  test('the photo never travels in the code — it cannot fit', () {
    final card = CardLink.decode(_encode())!;
    expect(card.applicant.photoPath, isNull);
  });
}
