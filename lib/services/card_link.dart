import 'dart:convert';
import 'dart:io' show gzip;
import 'dart:typed_data';

import '../config/verify_endpoint.dart';
import '../models/applicant.dart';
import '../models/vision_test.dart';

/// A card rebuilt from a scanned QR code.
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

/// The link encoded inside every identity card's QR code.
///
/// **Why a link and not the card file itself**: a QR code tops out at roughly
/// 2.9 KB, while the card is a ~600 KB PNG or a ~200 KB PDF. No QR symbol can
/// ever carry the file. So the code carries a compact, self-contained copy of
/// the identity data — every field the card prints — and whoever scans it
/// rebuilds the card and exports it as PNG or PDF. The bytes travel; the file
/// is regenerated at the other end.
///
/// **Why an https link**: phone cameras are built around https. They open one
/// immediately, and hand it to the app itself when it is installed (Universal
/// Links / App Links). A private scheme like `adigitalid://` is not reliably
/// surfaced by the camera and does nothing at all on a phone without the app —
/// which is every phone but the issuer's. See [kVerifierBaseUrl].
///
/// Emitted form (once a verifier is configured):
///
/// ```text
/// https://your.host/id#<base64url>
/// ```
///
/// The payload lives in the URL *fragment*, which HTTP never sends to the
/// server, so the identity data never leaves the scanner's device.
///
/// Payload framing: `[version][flags][crc16-hi][crc16-lo][body]`, where `body`
/// is a compact JSON map with single-letter keys, gzipped when that actually
/// saves space. The CRC stops a misread symbol from being accepted as a card.
abstract final class CardLink {
  static const String scheme = 'adigitalid';
  static const String host = 'card';

  /// Payload format version. Readers reject anything newer than they know.
  static const int version = 2;

  static const int _flagGzip = 0x01;

  /// Builds the string that is drawn into the card's QR code.
  ///
  /// Falls back to the app-only scheme while no verifier page is configured,
  /// so nothing breaks before the page is hosted.
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
      'y': applicant.academicYear.index,
      'd': applicant.degreeLabel,
      'g': applicant.governorate,
      'c': applicant.city,
      'h': applicant.heightCm,
      // Tenths of a kilogram keeps the payload integer-only.
      'w': (applicant.weightKg * 10).round(),
      'b': applicant.bloodType.index,
      'r': applicant.rightEyeAcuity.index,
      'l': applicant.leftEyeAcuity.index,
      'x': applicant.visionCorrection.index,
      't': issuedAtUtc.toUtc().millisecondsSinceEpoch ~/ 1000,
      if (applicant.visionTest != null)
        'm': applicant.visionTest!.distanceCm.round(),
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
  ///
  /// Accepts both shapes a card can carry: an https verifier link with the
  /// payload in its fragment (any host — only the fragment matters, so the
  /// page can be rehosted freely), and the app-only `adigitalid://` scheme.
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
    final name = (map['n'] as String?)?.trim();
    if (personalId == null || name == null || name.isEmpty) return null;

    final parts = name.split(RegExp(r'\s+'));
    final firstName = parts.first;
    final lastName = parts.length > 1 ? parts.sublist(1).join(' ') : '';

    final degreeLabel = map['d'] as String? ?? '';
    final degree = UndergraduateDegree.fromLabel(degreeLabel);
    final issuedAt = DateTime.fromMillisecondsSinceEpoch(
      (map['t'] as int) * 1000,
      isUtc: true,
    );

    final right = VisualAcuity.values[_index(map['r'], VisualAcuity.values)];
    final left = VisualAcuity.values[_index(map['l'], VisualAcuity.values)];
    final distance = map['m'] as int?;

    final applicant = Applicant(
      firstName: firstName,
      lastName: lastName,
      academicYear:
          AcademicYear.values[_index(map['y'], AcademicYear.values)],
      degree: degree ?? UndergraduateDegree.other,
      // An unrecognised label is a custom major, carried through verbatim.
      customDegree: degree == null ? degreeLabel : null,
      governorate: map['g'] as String? ?? '',
      city: map['c'] as String? ?? '',
      heightCm: map['h'] as int? ?? 0,
      weightKg: (map['w'] as int? ?? 0) / 10,
      bloodType: BloodType.values[_index(map['b'], BloodType.values)],
      rightEyeAcuity: right,
      leftEyeAcuity: left,
      visionCorrection:
          VisionCorrection.values[_index(map['x'], VisionCorrection.values)],
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
