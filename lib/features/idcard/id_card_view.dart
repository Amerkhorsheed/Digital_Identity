import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:qr_flutter/qr_flutter.dart';

import '../../app/theme/app_theme.dart';
import '../../app/theme/brand_colors.dart';
import '../../models/applicant.dart';

/// Fully decoded artwork for the identity card.
///
/// On screen the card can happily use [Image.asset] / [Image.file] / a live
/// [QrImageView], because Flutter resolves those asynchronously and repaints
/// when they arrive. An off-screen export has no second chance to repaint —
/// so exports pre-decode every image here and the card paints them
/// synchronously through [RawImage]. This is what makes PNG output reliable
/// instead of occasionally blank.
class CardImages {
  const CardImages({required this.logo, required this.qr, this.portrait});

  final ui.Image logo;
  final ui.Image qr;
  final ui.Image? portrait;

  static Future<CardImages> load({
    required String qrData,
    String? photoPath,
    double qrPixels = 900,
  }) async {
    final logoData = await rootBundle.load('assets/A.jpg');
    final logo = await decodeBytes(logoData.buffer.asUint8List());

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

    return CardImages(logo: logo, qr: qr, portrait: portrait);
  }

  static Future<ui.Image> decodeBytes(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  void dispose() {
    logo.dispose();
    qr.dispose();
    portrait?.dispose();
  }
}

/// The issued identity card — front face with portrait and personal ID,
/// back face with the verifiable QR code and full health details.
///
/// Rendered at [cardWidth] so the same widget powers the live screen, the
/// flip animation and the PNG/PDF exports.
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
          qrData: qrData,
          issuedAt: issuedAt,
          cardWidth: cardWidth,
          images: images,
        ),
      ],
    );
  }
}

/// Front face: pine gradient, portrait, name and personal ID.
class IdCardView extends StatelessWidget {
  const IdCardView({
    super.key,
    required this.applicant,
    required this.personalId,
    required this.issuedAt,
    required this.cardWidth,
    this.images,
  });

  final Applicant applicant;
  final String personalId;
  final DateTime issuedAt;
  final double cardWidth;
  final CardImages? images;

  @override
  Widget build(BuildContext context) {
    final height = cardWidth * 0.625;
    final photoW = cardWidth * 0.22;
    final photoH = height * 0.46;

    return Container(
      width: cardWidth,
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(cardWidth * 0.045),
        gradient: BrandGradients.pine,
        boxShadow: [
          BoxShadow(
            color: BrandColors.pine.withValues(alpha: 0.35),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Watermark
          Positioned(
            right: -cardWidth * 0.10,
            bottom: -height * 0.42,
            child: Text(
              'A',
              style: TextStyle(
                fontSize: height * 1.35,
                fontWeight: FontWeight.w800,
                color: BrandColors.gold.withValues(alpha: 0.12),
              ),
            ),
          ),
          Positioned(
            left: -cardWidth * 0.14,
            top: -height * 0.30,
            child: Container(
              width: cardWidth * 0.55,
              height: height * 0.9,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: BrandColors.gold.withValues(alpha: 0.06),
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
                    _MiniLogo(size: cardWidth * 0.075, image: images?.logo),
                    SizedBox(width: cardWidth * 0.022),
                    Text(
                      'الهوية الرقمية',
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
                      'الرقم الشخصي',
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

/// Back face: verifiable QR code plus the full identity details.
class IdCardBack extends StatelessWidget {
  const IdCardBack({
    super.key,
    required this.applicant,
    required this.personalId,
    required this.qrData,
    required this.issuedAt,
    required this.cardWidth,
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
    final height = cardWidth * 0.625;

    return Container(
      width: cardWidth,
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(cardWidth * 0.045),
        color: BrandColors.ivory,
        border: Border.all(color: BrandColors.gold, width: 1.4),
        boxShadow: [
          BoxShadow(
            color: BrandColors.pine.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            left: -cardWidth * 0.12,
            bottom: -height * 0.40,
            child: Text(
              'A',
              style: TextStyle(
                fontSize: height * 1.3,
                fontWeight: FontWeight.w800,
                color: BrandColors.gold.withValues(alpha: 0.10),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(cardWidth * 0.04),
            child: Row(
              children: [
                // QR block
                Container(
                  width: cardWidth * 0.285,
                  padding: EdgeInsets.all(cardWidth * 0.02),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(cardWidth * 0.028),
                    border: Border.all(color: BrandColors.gold, width: 1.2),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox.square(
                        dimension: cardWidth * 0.235,
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
                                size: cardWidth * 0.235,
                                backgroundColor: Colors.white,
                                padding: EdgeInsets.zero,
                              ),
                      ),
                      SizedBox(height: cardWidth * 0.012),
                      Text(
                        'امسح للتحقق',
                        style: TextStyle(
                          fontSize: cardWidth * 0.014,
                          letterSpacing: 0.5,
                          fontWeight: FontWeight.w700,
                          color: BrandColors.goldDeep,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: cardWidth * 0.035),
                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'بيانات الهوية',
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: cardWidth * 0.024,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                          color: BrandColors.pine,
                        ),
                      ),
                      SizedBox(height: cardWidth * 0.006),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          personalId,
                          maxLines: 1,
                          style: TextStyle(
                            fontFamily: AppTheme.monoFont,
                            fontSize: cardWidth * 0.019,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            color: BrandColors.goldDeep,
                          ),
                        ),
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
                        ],
                      ),
                      const Spacer(),
                      Container(
                        height: 1,
                        color: BrandColors.gold.withValues(alpha: 0.4),
                      ),
                      SizedBox(height: cardWidth * 0.015),
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

/// Three-column register of identity details, laid out like a passport data
/// page: a small caption above each value so neither is ever truncated.
class _DetailGrid extends StatelessWidget {
  const _DetailGrid({required this.cardWidth, required this.items});

  final double cardWidth;
  final List<(String, String)> items;

  @override
  Widget build(BuildContext context) {
    const columns = 3;
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
          if (r != rows.length - 1) SizedBox(height: cardWidth * 0.035),
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

class _MiniLogo extends StatelessWidget {
  const _MiniLogo({required this.size, this.image});

  final double size;
  final ui.Image? image;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.14),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.18),
        child: SizedBox.expand(
          child: image != null
              ? RawImage(image: image, fit: BoxFit.cover)
              : Image.asset('assets/A.jpg', fit: BoxFit.cover),
        ),
      ),
    );
  }
}
