import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:qr_flutter/qr_flutter.dart';

import '../../app/theme/app_theme.dart';
import '../../app/theme/brand_colors.dart';
import '../../models/applicant.dart';

/// The emblem, cut out of its paper.
///
/// `assets/A.jpg` is the eagle printed flat gold on black. That makes its own
/// luminance a clean alpha mask, and `assets/A_mark.png` is exactly that mask
/// — a white body with the eagle's alpha — so the same artwork can be tinted
/// gold on the pine face and pine on the ivory face without ever dragging a
/// black rectangle along with it.
const String kEmblemAsset = 'assets/A.jpg';
const String kEmblemMaskAsset = 'assets/A_mark.png';

/// Fully decoded artwork for the identity card.
///
/// On screen the card can happily use [Image.asset] / [Image.file] / a live
/// [QrImageView], because Flutter resolves those asynchronously and repaints
/// when they arrive. An off-screen export has no second chance to repaint —
/// so exports pre-decode every image here and the card paints them
/// synchronously through [RawImage]. This is what makes PNG output reliable
/// instead of occasionally blank.
class CardImages {
  const CardImages({
    required this.logo,
    required this.mark,
    required this.qr,
    this.portrait,
  });

  final ui.Image logo;

  /// The emblem as an alpha mask, for the tinted backdrop and the mini crest.
  final ui.Image mark;
  final ui.Image qr;
  final ui.Image? portrait;

  static Future<CardImages> load({
    required String qrData,
    String? photoPath,
    double qrPixels = 900,
  }) async {
    final logoData = await rootBundle.load(kEmblemAsset);
    final logo = await decodeBytes(logoData.buffer.asUint8List());
    final markData = await rootBundle.load(kEmblemMaskAsset);
    final mark = await decodeBytes(markData.buffer.asUint8List());

    ui.Image? portrait;
    if (photoPath != null && photoPath.isNotEmpty) {
      final file = File(photoPath);
      if (file.existsSync()) {
        portrait = await decodeBytes(await file.readAsBytes());
      }
    }

    final painter = QrPainter(
      data: qrData,
      version: QrVersions.auto,
      gapless: true,
      errorCorrectionLevel: QrErrorCorrectLevel.M,
    );
    final qr = await painter.toImage(qrPixels);

    return CardImages(logo: logo, mark: mark, qr: qr, portrait: portrait);
  }

  static Future<ui.Image> decodeBytes(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  void dispose() {
    logo.dispose();
    mark.dispose();
    qr.dispose();
    portrait?.dispose();
  }
}

/// The issued identity card — front face with portrait and personal ID, back
/// face with the full identity details, and the verification code carried
/// separately below both.
///
/// The QR deliberately lives *outside* the card: a scan code is a live
/// instrument, not print, so it gets its own module at a size a camera can
/// actually lock onto instead of a stamp squeezed into a corner.
///
/// Rendered at [cardWidth] so the same widget powers the live screen and the
/// PNG/PDF exports.
class IdCardSheet extends StatelessWidget {
  const IdCardSheet({
    super.key,
    required this.applicant,
    required this.personalId,
    required this.qrData,
    required this.issuedAt,
    this.cardWidth = 440,
    this.images,
  });

  final Applicant applicant;
  final String personalId;
  final String qrData;
  final DateTime issuedAt;
  final double cardWidth;
  final CardImages? images;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IdCardView(
          applicant: applicant,
          personalId: personalId,
          issuedAt: issuedAt,
          cardWidth: cardWidth,
          images: images,
        ),
        SizedBox(height: cardWidth * 0.045),
        IdCardBack(
          applicant: applicant,
          personalId: personalId,
          issuedAt: issuedAt,
          cardWidth: cardWidth,
          images: images,
        ),
        SizedBox(height: cardWidth * 0.045),
        IdCardQrPanel(
          personalId: personalId,
          qrData: qrData,
          cardWidth: cardWidth,
          images: images,
        ),
      ],
    );
  }
}

/// Front face: pine gradient over the crest, portrait, name and personal ID.
///
/// [corners] and [elevated] exist so a caller can fuse this face into a larger
/// surface — the result page joins both faces edge to edge inside one shell.
/// Left at their defaults the face renders exactly as it always has, which is
/// what the PNG/PDF exports rely on.
class IdCardView extends StatelessWidget {
  const IdCardView({
    super.key,
    required this.applicant,
    required this.personalId,
    required this.issuedAt,
    required this.cardWidth,
    this.images,
    this.corners,
    this.elevated = true,
  });

  final Applicant applicant;
  final String personalId;
  final DateTime issuedAt;
  final double cardWidth;
  final CardImages? images;
  final BorderRadiusGeometry? corners;
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final height = cardWidth * 0.625;
    final photoW = cardWidth * 0.22;
    final photoH = height * 0.46;
    final radius = corners ?? BorderRadius.circular(cardWidth * 0.045);

    return Container(
      width: cardWidth,
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: BrandGradients.pine,
        boxShadow: elevated
            ? [
                BoxShadow(
                  color: BrandColors.pine.withValues(alpha: 0.35),
                  blurRadius: 30,
                  offset: const Offset(0, 14),
                ),
              ]
            : null,
      ),
      child: Stack(
        children: [
          // The crest, printed large across the face and bleeding off the
          // leading edge — a state emblem behaves like a watermark, so it sits
          // under everything at a strength you can read but never fight.
          PositionedDirectional(
            start: -cardWidth * 0.13,
            top: -height * 0.16,
            child: _EmblemGlow(
              diameter: height * 1.30,
              color: BrandColors.gold.withValues(alpha: 0.16),
            ),
          ),
          PositionedDirectional(
            start: -cardWidth * 0.06,
            top: height * 0.05,
            child: _EmblemMark(
              image: images?.mark,
              width: cardWidth * 0.52,
              color: BrandColors.goldGlow.withValues(alpha: 0.20),
            ),
          ),
          // A second, much smaller crest anchored to the trailing edge, half
          // off the card: the same trick a passport uses to prove the artwork
          // runs to the die cut rather than stopping at a safe margin.
          PositionedDirectional(
            end: -cardWidth * 0.11,
            bottom: -height * 0.20,
            child: _EmblemMark(
              image: images?.mark,
              width: cardWidth * 0.40,
              color: BrandColors.gold.withValues(alpha: 0.10),
            ),
          ),
          // A single diagonal light pass, so the surface reads as laminate
          // rather than flat paint.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  stops: const [0, 0.45, 0.62, 1],
                  colors: [
                    Colors.white.withValues(alpha: 0.05),
                    Colors.white.withValues(alpha: 0.0),
                    Colors.black.withValues(alpha: 0.06),
                    Colors.black.withValues(alpha: 0.20),
                  ],
                ),
              ),
            ),
          ),
          // Hairline gold frame set in from the die cut — the detail that
          // separates an issued document from a printed rectangle.
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.all(cardWidth * 0.018),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(cardWidth * 0.032),
                  border: Border.all(
                    color: BrandColors.gold.withValues(alpha: 0.30),
                    width: 0.9,
                  ),
                ),
              ),
            ),
          ),
          // Content
          Padding(
            padding: EdgeInsets.all(cardWidth * 0.04),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _MiniLogo(size: cardWidth * 0.075, image: images?.mark),
                    SizedBox(width: cardWidth * 0.022),
                    Text(
                      'إدارة القوى البشرية',
                      style: TextStyle(
                        fontSize: cardWidth * 0.028,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: Colors.white,
                      ),
                    ),
                    const Spacer(),
                    _VerifiedChip(cardWidth: cardWidth),
                  ],
                ),
                const Spacer(),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _Portrait(
                      photoPath: applicant.photoPath,
                      image: images?.portrait,
                      width: photoW,
                      height: photoH,
                      radius: cardWidth * 0.03,
                    ),
                    SizedBox(width: cardWidth * 0.04),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            applicant.fullName.toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: cardWidth * 0.048,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: cardWidth * 0.012),
                          Text(
                            '${applicant.academicYear.label}  ·  مواليد ${applicant.birthYear}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: cardWidth * 0.021,
                              color: BrandColors.goldGlow,
                            ),
                          ),
                          SizedBox(height: cardWidth * 0.008),
                          Row(
                            children: [
                              Icon(
                                Icons.location_on_outlined,
                                size: cardWidth * 0.022,
                                color: BrandColors.goldGlow,
                              ),
                              SizedBox(width: cardWidth * 0.008),
                              Flexible(
                                child: Text(
                                  applicant.placeLabel,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: cardWidth * 0.02,
                                    color: Colors.white70,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Container(
                  height: 1,
                  color: BrandColors.gold.withValues(alpha: 0.45),
                ),
                SizedBox(height: cardWidth * 0.02),
                Row(
                  children: [
                    Text(
                      'رقم الانتساب',
                      style: TextStyle(
                        fontSize: cardWidth * 0.015,
                        letterSpacing: 0.5,
                        color: Colors.white54,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'صدرت في ${_formatDate(issuedAt)}',
                      style: TextStyle(
                        fontSize: cardWidth * 0.015,
                        letterSpacing: 0.5,
                        color: Colors.white54,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: cardWidth * 0.008),
                Text(
                  personalId,
                  style: TextStyle(
                    fontFamily: AppTheme.monoFont,
                    fontSize: cardWidth * 0.038,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 3,
                    color: BrandColors.goldGlow,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _formatDate(DateTime date) {
  const months = ['يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو', 'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

/// Back face: the full identity register, laid out like a passport data page.
///
/// The verification code used to sit here in a corner; it now lives in its own
/// [IdCardQrPanel] outside the card, which frees the whole face for the data
/// and lets every value be read at a glance.
///
/// See [IdCardView] for [corners] and [elevated]; [bordered] drops the gold
/// edge for the same reason — inside a spread the shell carries the edge.
class IdCardBack extends StatelessWidget {
  const IdCardBack({
    super.key,
    required this.applicant,
    required this.personalId,
    required this.issuedAt,
    required this.cardWidth,
    this.images,
    this.corners,
    this.elevated = true,
    this.bordered = true,
  });

  final Applicant applicant;
  final String personalId;
  final DateTime issuedAt;
  final double cardWidth;
  final CardImages? images;
  final BorderRadiusGeometry? corners;
  final bool elevated;
  final bool bordered;

  @override
  Widget build(BuildContext context) {
    final height = cardWidth * 0.625;

    return Container(
      width: cardWidth,
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: corners ?? BorderRadius.circular(cardWidth * 0.045),
        color: BrandColors.ivory,
        border:
            bordered ? Border.all(color: BrandColors.gold, width: 1.4) : null,
        boxShadow: elevated
            ? [
                BoxShadow(
                  color: BrandColors.pine.withValues(alpha: 0.18),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ]
            : null,
      ),
      child: Stack(
        children: [
          // The same crest as the front, centred and barely there: a paper
          // watermark, held under the register rather than beside it.
          Positioned.fill(
            child: Center(
              child: _EmblemMark(
                image: images?.mark,
                width: cardWidth * 0.62,
                color: BrandColors.gold.withValues(alpha: 0.13),
              ),
            ),
          ),
          PositionedDirectional(
            end: -cardWidth * 0.10,
            bottom: -height * 0.24,
            child: _EmblemMark(
              image: images?.mark,
              width: cardWidth * 0.36,
              color: BrandColors.goldDeep.withValues(alpha: 0.07),
            ),
          ),
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.all(cardWidth * 0.018),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(cardWidth * 0.032),
                  border: Border.all(
                    color: BrandColors.gold.withValues(alpha: 0.28),
                    width: 0.9,
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(cardWidth * 0.045),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'بيانات المنتسب',
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: cardWidth * 0.028,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                        color: BrandColors.pine,
                      ),
                    ),
                    const Spacer(),
                    Flexible(
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: cardWidth * 0.024,
                          vertical: cardWidth * 0.010,
                        ),
                        decoration: BoxDecoration(
                          color: BrandColors.goldMist,
                          borderRadius:
                              BorderRadius.circular(cardWidth * 0.024),
                          border: Border.all(
                            color: BrandColors.gold.withValues(alpha: 0.55),
                          ),
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            personalId,
                            maxLines: 1,
                            style: TextStyle(
                              fontFamily: AppTheme.monoFont,
                              fontSize: cardWidth * 0.021,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                              color: BrandColors.goldDeep,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: cardWidth * 0.012),
                Container(
                  height: 1,
                  color: BrandColors.gold.withValues(alpha: 0.35),
                ),
                const Spacer(),
                _DetailGrid(
                  cardWidth: cardWidth,
                  items: [
                    ('فصيلة الدم', applicant.bloodType.label),
                    ('سنة الميلاد', '${applicant.birthYear}'),
                    ('الطول', '${applicant.heightCm} سم'),
                    ('الوزن', _formatWeight(applicant.weightKg)),
                    ('العين اليمنى', applicant.rightEyeAcuity.label),
                    ('العين اليسرى', applicant.leftEyeAcuity.label),
                    ('المحافظة', applicant.placeLabel),
                    ('السنة الدراسية', applicant.academicYear.label),
                  ],
                ),
                const Spacer(),
                Container(
                  height: 1,
                  color: BrandColors.gold.withValues(alpha: 0.4),
                ),
                SizedBox(height: cardWidth * 0.015),
                // How this card's fingerprint was taken — the path, its
                // quality, and the template fingerprint.
                Row(
                  children: [
                    Icon(
                      applicant.hasBiometric
                          ? Icons.fingerprint_rounded
                          : Icons.fingerprint_outlined,
                      size: cardWidth * 0.022,
                      color: applicant.hasBiometric
                          ? BrandColors.goldDeep
                          : BrandColors.inkMuted,
                    ),
                    SizedBox(width: cardWidth * 0.01),
                    Expanded(
                      child: Text(
                        applicant.biometricShortLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: cardWidth * 0.0155,
                          color: BrandColors.inkMuted,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: cardWidth * 0.008),
                Row(
                  children: [
                    Icon(
                      applicant.visionTest != null
                          ? Icons.verified_rounded
                          : Icons.qr_code_scanner_rounded,
                      size: cardWidth * 0.022,
                      color: BrandColors.goldDeep,
                    ),
                    SizedBox(width: cardWidth * 0.01),
                    Expanded(
                      child: Text(
                        applicant.visionSourceShortLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: cardWidth * 0.0155,
                          color: BrandColors.inkMuted,
                        ),
                      ),
                    ),
                    Text(
                      _formatDate(issuedAt),
                      style: TextStyle(
                        fontSize: cardWidth * 0.0155,
                        fontWeight: FontWeight.w600,
                        color: BrandColors.goldDeep,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _formatWeight(double weight) {
    if (weight == weight.roundToDouble()) {
      return '${weight.round()} كجم';
    }
    return '${weight.toStringAsFixed(1)} كجم';
  }
}

/// The verification code, as its own instrument.
///
/// A QR is the one part of the document a machine reads, so it is given a
/// dedicated pine module the width of the card: an oversized white tile that a
/// camera locks onto immediately, the personal ID beside it, and a gold rule
/// tying it back to the card it belongs to.
class IdCardQrPanel extends StatelessWidget {
  const IdCardQrPanel({
    super.key,
    required this.personalId,
    required this.qrData,
    required this.cardWidth,
    this.images,
    this.elevated = true,
    this.onTap,
  });

  final String personalId;
  final String qrData;
  final double cardWidth;
  final CardImages? images;
  final bool elevated;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tile = cardWidth * 0.235;
    final radius = BorderRadius.circular(cardWidth * 0.045);

    final panel = Container(
      width: cardWidth,
      clipBehavior: Clip.antiAlias,
      padding: EdgeInsets.all(cardWidth * 0.042),
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: BrandGradients.pine,
        border: Border.all(
          color: BrandColors.gold.withValues(alpha: 0.55),
          width: 1.2,
        ),
        boxShadow: elevated
            ? [
                BoxShadow(
                  color: BrandColors.pine.withValues(alpha: 0.28),
                  blurRadius: 26,
                  offset: const Offset(0, 12),
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          // The scan target: pure white, generous quiet zone, gold ring.
          Container(
            padding: EdgeInsets.all(cardWidth * 0.022),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(cardWidth * 0.030),
              border: Border.all(color: BrandColors.gold, width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: BrandColors.goldGlow.withValues(alpha: 0.35),
                  blurRadius: 18,
                  spreadRadius: -4,
                ),
              ],
            ),
            child: SizedBox.square(
              dimension: tile,
              child: images?.qr != null
                  ? RawImage(
                      image: images!.qr,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.none,
                    )
                  : QrImageView(
                      data: qrData,
                      version: QrVersions.auto,
                      errorCorrectionLevel: QrErrorCorrectLevel.M,
                      gapless: true,
                      size: tile,
                      backgroundColor: Colors.white,
                      padding: EdgeInsets.zero,
                    ),
            ),
          ),
          SizedBox(width: cardWidth * 0.04),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.qr_code_scanner_rounded,
                      size: cardWidth * 0.030,
                      color: BrandColors.goldGlow,
                    ),
                    SizedBox(width: cardWidth * 0.016),
                    Expanded(
                      child: Text(
                        'رمز التحقق الرقمي',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: cardWidth * 0.030,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: cardWidth * 0.018),
                Text(
                  'امسح الرمز للتحقق من صحة البطاقة وبياناتها.',
                  maxLines: 2,
                  style: TextStyle(
                    fontSize: cardWidth * 0.020,
                    height: 1.6,
                    color: Colors.white.withValues(alpha: 0.75),
                  ),
                ),
                SizedBox(height: cardWidth * 0.026),
                Container(
                  height: 1,
                  color: BrandColors.gold.withValues(alpha: 0.4),
                ),
                SizedBox(height: cardWidth * 0.020),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    personalId,
                    maxLines: 1,
                    style: TextStyle(
                      fontFamily: AppTheme.monoFont,
                      fontSize: cardWidth * 0.026,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.6,
                      color: BrandColors.goldGlow,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return panel;
    return Semantics(
      button: true,
      label: 'رمز التحقق الرقمي — اضغط لتكبيره',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: panel,
      ),
    );
  }
}

/// Three-column register of identity details, laid out like a passport data
/// page: a small caption above each value so neither is ever truncated.
class _DetailGrid extends StatelessWidget {
  const _DetailGrid({required this.cardWidth, required this.items});

  final double cardWidth;
  final List<(String, String)> items;

  @override
  Widget build(BuildContext context) {
    const columns = 4;
    final rows = <List<(String, String)>>[];
    for (var i = 0; i < items.length; i += columns) {
      rows.add(
        items.sublist(i, i + columns > items.length ? items.length : i + columns),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var r = 0; r < rows.length; r++) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var j = 0; j < columns; j++) ...[
                Expanded(
                  child: j < rows[r].length
                      ? _DetailCell(
                          label: rows[r][j].$1,
                          value: rows[r][j].$2,
                          cardWidth: cardWidth,
                        )
                      : const SizedBox(),
                ),
                if (j != columns - 1) SizedBox(width: cardWidth * 0.018),
              ],
            ],
          ),
          if (r != rows.length - 1) SizedBox(height: cardWidth * 0.030),
        ],
      ],
    );
  }
}

class _DetailCell extends StatelessWidget {
  const _DetailCell({
    required this.label,
    required this.value,
    required this.cardWidth,
  });

  final String label;
  final String value;
  final double cardWidth;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: cardWidth * 0.0165,
            height: 1.2,
            letterSpacing: 0.2,
            color: BrandColors.inkMuted,
          ),
        ),
        SizedBox(height: cardWidth * 0.004),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: Text(
            value,
            maxLines: 1,
            style: TextStyle(
              fontSize: cardWidth * 0.026,
              height: 1.2,
              fontWeight: FontWeight.w700,
              color: BrandColors.ink,
            ),
          ),
        ),
      ],
    );
  }
}

/// The crest, tinted and sized for whatever surface it is printed on.
///
/// Takes the pre-decoded mask during an export and the asset on screen, so
/// both paths draw byte-identical artwork.
class _EmblemMark extends StatelessWidget {
  const _EmblemMark({
    required this.image,
    required this.width,
    required this.color,
  });

  final ui.Image? image;
  final double width;

  /// Tint *and* strength: the mask is pure alpha, so this colour's own opacity
  /// is what sets how loud the crest prints.
  final Color color;

  @override
  Widget build(BuildContext context) {
    // The mask keeps the source artwork's 499×374 proportions.
    final height = width * 374 / 499;

    return IgnorePointer(
      child: SizedBox(
        width: width,
        height: height,
        child: image != null
            ? RawImage(
                image: image,
                width: width,
                height: height,
                fit: BoxFit.contain,
                color: color,
                colorBlendMode: BlendMode.srcIn,
              )
            : Image.asset(
                kEmblemMaskAsset,
                width: width,
                height: height,
                fit: BoxFit.contain,
                color: color,
                colorBlendMode: BlendMode.srcIn,
              ),
      ),
    );
  }
}

/// The soft light the crest sits in, so it reads as printed into the surface
/// rather than pasted on top of it.
class _EmblemGlow extends StatelessWidget {
  const _EmblemGlow({required this.diameter, required this.color});

  final double diameter;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: diameter,
        height: diameter,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, color.withValues(alpha: 0)],
            stops: const [0.15, 1],
          ),
        ),
      ),
    );
  }
}

class _Portrait extends StatelessWidget {
  const _Portrait({
    required this.photoPath,
    required this.image,
    required this.width,
    required this.height,
    required this.radius,
  });

  final String? photoPath;
  final ui.Image? image;
  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final Widget portrait;
    if (image != null) {
      portrait = RawImage(image: image, fit: BoxFit.cover);
    } else if (photoPath != null && photoPath!.isNotEmpty) {
      portrait = Image.file(
        File(photoPath!),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stack) => const _FallbackPortrait(),
      );
    } else {
      portrait = const _FallbackPortrait();
    }

    return Container(
      width: width,
      height: height,
      padding: EdgeInsets.all(width * 0.045),
      decoration: BoxDecoration(
        gradient: BrandGradients.gold,
        borderRadius: BorderRadius.circular(radius * 1.6),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: SizedBox.expand(child: portrait),
      ),
    );
  }
}

class _FallbackPortrait extends StatelessWidget {
  const _FallbackPortrait();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: BrandColors.pineSoft,
      child: const Center(
        child: Icon(Icons.person_outline_rounded, color: BrandColors.pine, size: 40),
      ),
    );
  }
}

class _VerifiedChip extends StatelessWidget {
  const _VerifiedChip({required this.cardWidth});

  final double cardWidth;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: cardWidth * 0.026,
        vertical: cardWidth * 0.012,
      ),
      decoration: BoxDecoration(
        color: BrandColors.gold,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.verified_rounded,
            size: cardWidth * 0.022,
            color: BrandColors.pineDeep,
          ),
          SizedBox(width: cardWidth * 0.008),
          Text(
            'موثّقة',
            style: TextStyle(
              fontSize: cardWidth * 0.017,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: BrandColors.pineDeep,
            ),
          ),
        ],
      ),
    );
  }
}

/// The crest at chip size, struck in gold on a pine disc.
class _MiniLogo extends StatelessWidget {
  const _MiniLogo({required this.size, this.image});

  final double size;
  final ui.Image? image;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: BrandColors.pineDeep,
        border: Border.all(
          color: BrandColors.gold.withValues(alpha: 0.75),
          width: size * 0.045,
        ),
      ),
      child: _EmblemMark(
        image: image,
        width: size * 0.66,
        color: BrandColors.goldGlow,
      ),
    );
  }
}
