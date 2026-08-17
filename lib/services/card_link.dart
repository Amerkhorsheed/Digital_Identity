import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import '../config/verify_endpoint.dart';
import '../models/applicant.dart';
import '../models/biometric_capture.dart';
import '../models/vision_test.dart';

/// A decoded card retrieved from a QR scan or a deep link.
class ScannedCard {
  const ScannedCard({
    required this.applicant,
    required this.personalId,
    required this.issuedAt,
  });

  final Applicant applicant;
  final String personalId;
  final DateTime issuedAt;
}

/// Serializes and deserializes the self-contained payload stored in a card QR
/// code.
///
/// Format:
///
/// ```
/// [version: 1 byte][flags: 1 byte][crc16: 2 bytes big-endian][body...]
/// ```
///
/// - `version`: `3` (adds biometric provenance to the body).
/// - `flags`: bit 0 = payload is gzip compressed.
/// - `crc16`: CRC-16/CCITT-FALSE of `body`, rejecting truncated or corrupt scans.
/// - `body`: UTF-8 JSON map encoded as base64url without padding.
abstract final class CardLink {
  /// The scheme used when no hosted verifier page is configured.
  static const String scheme = 'adigitalid';
  static const String host = 'card';

  /// Binary format version. Incremented only when the frame layout changes.
  ///
  /// Version 3 adds the biometric provenance keys (`pm`, `pq`, `ph`). A
  /// version 2 code still decodes; it simply carries no provenance, so the
  /// card shows the verification flag without the path that produced it.
  static const int version = 3;

  static const int _flagGzip = 1 << 0;

  /// Builds the full URL that the QR code will encode.
  static String encode({
    required Applicant applicant,
    required String personalId,
    required DateTime issuedAtUtc,
  }) {
    final data = encodePayload(
      applicant: applicant,
      personalId: personalId,
      issuedAtUtc: issuedAtUtc,
    );
    if (!kHasHostedVerifier) {
      return '$scheme://$host?v=$version&d=$data';
    }
    final base = kVerifierBaseUrl.endsWith('/')
        ? kVerifierBaseUrl.substring(0, kVerifierBaseUrl.length - 1)
        : kVerifierBaseUrl;
    return '$base#$data';
  }

  /// The base64url payload on its own, without any URL around it.
  static String encodePayload({
    required Applicant applicant,
    required String personalId,
    required DateTime issuedAtUtc,
  }) {
    final map = <String, Object?>{
      'i': personalId,
      'n': applicant.fullName,
      'a': applicant.birthYear,
      'y': applicant.academicYear.index,
      'g': applicant.governorate,
      'h': applicant.heightCm,
      // Tenths of a kilogram keeps the payload integer-only.
      'w': (applicant.weightKg * 10).round(),
      'b': applicant.bloodType.index,
      'r': applicant.rightEyeAcuity.index,
      'l': applicant.leftEyeAcuity.index,
      'p': applicant.hasBiometric ? 1 : 0,
      't': issuedAtUtc.toUtc().millisecondsSinceEpoch ~/ 1000,
      if (applicant.visionTest != null)
        'm': applicant.visionTest!.distanceCm.round(),
      // Biometric provenance, packed into one field to keep the QR symbol
      // small: `method.secondsBeforeIssue.attestation12`.
      if (applicant.biometric != null)
        'pb': _packBiometric(applicant.biometric!, issuedAtUtc),
    };

    final json = utf8.encode(jsonEncode(map));
    final compressed = Uint8List.fromList(gzip.encode(json));
    final useGzip = compressed.length < json.length;
    final body = useGzip ? compressed : Uint8List.fromList(json);

    final crc = _crc16(body);
    final framed = Uint8List(4 + body.length)
      ..[0] = version
      ..[1] = useGzip ? _flagGzip : 0
      ..[2] = (crc >> 8) & 0xFF
      ..[3] = crc & 0xFF
      ..setRange(4, 4 + body.length, body);

    return base64Url.encode(framed).replaceAll('=', '');
  }

  /// Rebuilds a card from a scanned string, or returns `null` when the string
  /// is not one of ours, is corrupt, or uses a newer format.
  static ScannedCard? decode(String raw) {
    final data = _payloadOf(raw);
    if (data == null || data.isEmpty) return null;

    try {
      final framed = base64Url.decode(base64Url.normalize(data));
      if (framed.length < 5) return null;
      if (framed[0] > version) return null;

      final flags = framed[1];
      final crc = (framed[2] << 8) | framed[3];
      final body = Uint8List.sublistView(framed, 4);
      if (_crc16(body) != crc) return null;

      final json = (flags & _flagGzip) != 0 ? gzip.decode(body) : body;
      final map = jsonDecode(utf8.decode(json)) as Map<String, dynamic>;
      return _fromMap(map);
    } catch (_) {
      return null;
    }
  }

  /// True when [raw] looks like one of our cards, without fully decoding it.
  static bool looksLikeCard(String raw) => _payloadOf(raw) != null;

  /// Pulls the base64url payload out of either link shape.
  static String? _payloadOf(String raw) {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null) return null;

    if (uri.scheme == scheme && uri.host == host) {
      final data = uri.queryParameters['d'];
      return (data == null || data.isEmpty) ? null : data;
    }

    if (uri.scheme == 'https' || uri.scheme == 'http') {
      final fragment = uri.fragment;
      return fragment.isEmpty ? null : fragment;
    }

    return null;
  }

  static ScannedCard? _fromMap(Map<String, dynamic> map) {
    final personalId = map['i'] as String?;
    final fullName = (map['n'] as String?)?.trim();
    if (personalId == null || fullName == null || fullName.isEmpty) return null;

    final birthYear = map['a'] as int? ?? 2001;
    final issuedAt = DateTime.fromMillisecondsSinceEpoch(
      (map['t'] as int? ?? 0) * 1000,
      isUtc: true,
    );

    final right = VisualAcuity.values[_index(map['r'], VisualAcuity.values)];
    final left = VisualAcuity.values[_index(map['l'], VisualAcuity.values)];
    final distance = map['m'] as int?;

    final applicant = Applicant(
      fullName: fullName,
      birthYear: birthYear,
      academicYear:
          AcademicYear.values[_index(map['y'], AcademicYear.values)],
      governorate: map['g'] as String? ?? '',
      heightCm: map['h'] as int? ?? 0,
      weightKg: (map['w'] as int? ?? 0) / 10,
      bloodType: BloodType.values[_index(map['b'], BloodType.values)],
      rightEyeAcuity: right,
      leftEyeAcuity: left,
      biometric: _biometricFrom(map, issuedAt),
      visionTest: distance == null
          ? null
          : VisionTestReport.decoded(
              right: right,
              left: left,
              distanceCm: distance.toDouble(),
              testedAtUtc: issuedAt,
            ),
    );

    return ScannedCard(
      applicant: applicant,
      personalId: personalId,
      issuedAt: issuedAt,
    );
  }

  /// Packs the biometric record into `method.age.quality.attestation12`.
  ///
  /// The capture time is stored as seconds *before* issue rather than as an
  /// absolute stamp — it is always a small number, which keeps the field short.
  /// Quality is `-1` for a hardware match, which either succeeds or fails and
  /// so has no intermediate score. The attestation is truncated to 12 hex
  /// characters; 48 bits is ample to tie a scanned card back to its record.
  static String _packBiometric(BiometricCapture capture, DateTime issuedAtUtc) {
    final age = issuedAtUtc.toUtc().difference(capture.capturedAtUtc).inSeconds;
    final hash = capture.attestation ?? '';
    return '${capture.method.index}'
        '.${math.max(0, age)}'
        '.${capture.qualityScore ?? -1}'
        '.${hash.substring(0, math.min(12, hash.length))}';
  }

  /// Rebuilds the biometric record from a scanned payload.
  ///
  /// Returns `null` for a version 2 code, which carries only the `p` flag and
  /// no provenance — the honest reading of such a card is "we cannot tell how
  /// this was verified", not an invented method.
  static BiometricCapture? _biometricFrom(
    Map<String, dynamic> map,
    DateTime issuedAt,
  ) {
    final packed = map['pb'] as String?;
    if (packed == null) return null;

    final parts = packed.split('.');
    if (parts.length < 3) return null;

    final methodIndex = int.tryParse(parts[0]);
    if (methodIndex == null ||
        methodIndex < 0 ||
        methodIndex >= BiometricMethod.values.length) {
      return null;
    }

    final age = int.tryParse(parts[1]) ?? 0;
    final quality = int.tryParse(parts[2]) ?? -1;
    final hash = parts.length > 3 ? parts[3] : '';

    return BiometricCapture(
      method: BiometricMethod.values[methodIndex],
      capturedAtUtc: issuedAt.subtract(Duration(seconds: age)),
      attestation: hash.isEmpty ? null : hash,
      qualityScore: quality < 0 ? null : quality.clamp(0, 100),
    );
  }

  /// Clamps a stored enum index so a malformed code can never crash a scan.
  static int _index(Object? value, List<Object> values) {
    final index = value is int ? value : 0;
    return index >= 0 && index < values.length ? index : 0;
  }

  /// CRC-16/CCITT-FALSE — small, fast, and enough to reject a misread symbol.
  static int _crc16(List<int> bytes) {
    var crc = 0xFFFF;
    for (final byte in bytes) {
      crc ^= byte << 8;
      for (var i = 0; i < 8; i++) {
        crc = (crc & 0x8000) != 0 ? ((crc << 1) ^ 0x1021) : (crc << 1);
        crc &= 0xFFFF;
      }
    }
    return crc;
  }
}
