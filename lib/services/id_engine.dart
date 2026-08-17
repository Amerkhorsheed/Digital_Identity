import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';

import '../models/applicant.dart';

/// Generates cryptographically-backed personal IDs and their QR payloads.
///
/// ID format: `A-YYMMDD-XXXXXX` where the checksum section is derived from a
/// SHA-256 digest of the applicant's data plus a time-salted nonce, encoded in
/// a confusion-free base32 alphabet.
abstract final class IdEngine {
  static const String brand = 'A';
  static const String schema = 'a-id/v1';

  /// Alphabet without characters that are easy to confuse (0/O, 1/I/L).
  static const String _alphabet = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';

  static final Random _random = Random.secure();

  /// Creates a unique personal ID for [applicant], issued at [issuedAtUtc].
  static Future<String> createPersonalId(
    Applicant applicant,
    DateTime issuedAtUtc,
  ) async {
    final salt = List<int>.generate(16, (_) => _random.nextInt(256));
    final canonical = '${applicant.fullName}|${applicant.degreeLabel}'
        '|${applicant.governorate}|${applicant.city}|${applicant.bloodType.label}'
        '|${applicant.heightCm}|${applicant.weightKg}'
        '|${applicant.rightEyeAcuity.label}|${applicant.leftEyeAcuity.label}'
        '|${applicant.academicYear.label}';
    final payload = utf8.encode('$canonical|${issuedAtUtc.toIso8601String()}|$salt');
    final hash = await Sha256().hash(payload);

    final yymmdd =
        '${issuedAtUtc.year % 100}'
        '${issuedAtUtc.month.toString().padLeft(2, '0')}'
        '${issuedAtUtc.day.toString().padLeft(2, '0')}';

    final bytes = hash.bytes;
    final checksum = StringBuffer();
    for (var i = 0; i < 6; i++) {
      final b = bytes[i * 2] ^ bytes[i * 2 + 1];
      checksum.write(_alphabet[b % _alphabet.length]);
    }
    return '${IdEngine.brand}-$yymmdd-$checksum';
  }

  /// Builds the JSON payload encoded inside the QR code. Scanning the code
  /// reveals every identity detail in a machine-readable form.
  static String buildQrPayload(
    Applicant applicant,
    String personalId,
    DateTime issuedAtUtc,
  ) {
    final payload = <String, dynamic>{
      'schema': schema,
      'id': personalId,
      'issuedAt': issuedAtUtc.toUtc().toIso8601String(),
      'name': applicant.fullName,
      'academicYear': applicant.academicYear.label,
      'degree': applicant.degreeLabel,
      'governorate': applicant.governorate,
      'city': applicant.city,
      'country': 'الجمهورية العربية السورية',
      'heightCm': applicant.heightCm,
      'weightKg': applicant.weightKg,
      'bloodType': applicant.bloodType.label,
      'rightEye': applicant.rightEyeAcuity.label,
      'leftEye': applicant.leftEyeAcuity.label,
      'visionCorrection': applicant.visionCorrection.label,
      'visionSource': applicant.visionSourceLabel,
      'issuedBy': 'الهوية الرقمية — أ',
    };
    return const JsonEncoder.withIndent(null).convert(payload);
  }
}
