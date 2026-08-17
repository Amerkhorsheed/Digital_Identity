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
  fullName: 'سارة محمد الحلبي',
  birthYear: 2001,
  academicYear: AcademicYear.bachelor,
  governorate: 'ريف دمشق',
  heightCm: 165,
  weightKg: 58.5,
  bloodType: BloodType.oPositive,
  rightEyeAcuity: VisualAcuity.twentyTwenty,
  leftEyeAcuity: VisualAcuity.twentyThirty,
  hasBiometric: true,
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
    expect(kHasHostedVerifier, isFalse);
    expect(_encode(), startsWith('adigitalid://card?v=2&d='));
  });

  test('reads a hosted verifier link with the payload in its fragment', () {
    final payload = CardLink.encodePayload(
      applicant: _applicant,
      personalId: _id,
      issuedAtUtc: _issuedAt,
    );
    for (final host in [
      'https://example.com/id',
      'https://someone.github.io/a-id/',
      'http://192.168.1.4:8765/index.html',
    ]) {
      final card = CardLink.decode('$host#$payload');
      expect(card, isNotNull, reason: host);
      expect(card!.personalId, _id);
      expect(card.applicant.governorate, 'ريف دمشق');
    }
  });

  test('keeps the payload out of anything a server would ever see', () {
    final payload = CardLink.encodePayload(
      applicant: _applicant,
      personalId: _id,
      issuedAtUtc: _issuedAt,
    );
    final uri = Uri.parse('https://example.com/id#$payload');
    expect(uri.path, '/id');
    expect(uri.query, isEmpty);
    expect(uri.fragment, payload);
  });

  test('stays small enough for a comfortably scannable symbol', () {
    expect(_encode().length, lessThan(300));
  });

  test('round-trips every field the card prints', () {
    final card = CardLink.decode(_encode())!;

    expect(card.personalId, _id);
    expect(card.issuedAt, _issuedAt);
    expect(card.applicant.fullName, 'سارة محمد الحلبي');
    expect(card.applicant.birthYear, 2001);
    expect(card.applicant.academicYear, AcademicYear.bachelor);
    expect(card.applicant.governorate, 'ريف دمشق');
    expect(card.applicant.placeLabel, 'ريف دمشق');
    expect(card.applicant.heightCm, 165);
    expect(card.applicant.weightKg, 58.5);
    expect(card.applicant.bloodType, BloodType.oPositive);
    expect(card.applicant.rightEyeAcuity, VisualAcuity.twentyTwenty);
    expect(card.applicant.leftEyeAcuity, VisualAcuity.twentyThirty);
    expect(card.applicant.hasBiometric, isTrue);
    expect(card.applicant.visionSourceShortLabel, 'فحص تفاعلي · 40 سم');
  });

  test('marks a manually entered acuity as such', () {
    final manual = _applicant.copyWith();
    final withoutTest = Applicant(
      fullName: manual.fullName,
      birthYear: manual.birthYear,
      academicYear: manual.academicYear,
      governorate: manual.governorate,
      heightCm: manual.heightCm,
      weightKg: manual.weightKg,
      bloodType: manual.bloodType,
      rightEyeAcuity: manual.rightEyeAcuity,
      leftEyeAcuity: manual.leftEyeAcuity,
      hasBiometric: manual.hasBiometric,
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
