import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';

import '../app/theme/brand_colors.dart';
import '../features/idcard/id_card_view.dart';
import '../models/applicant.dart';
import 'card_link.dart';

/// Produces share-ready PNG and PDF exports of the issued identity card.
///
/// The PDF embeds the brand fonts (Almarai / SpaceMono) so the certificate
/// matches the on-screen identity card exactly, including full Unicode.
abstract final class ExportService {
  /// Width, in logical pixels, of the card used for exports.
  static const double exportCardWidth = 520;

  /// The off-screen canvas the PNG is rendered onto.
  ///
  /// Pinned rather than inherited from the device: without it the capture is
  /// constrained to whatever view the app happens to be running in, so a
  /// narrow or short phone silently crops the sheet. Fixed here, the same
  /// bytes come out of every handset.
  static const Size exportSheetSize = Size(exportCardWidth + 72, 1030);

  /// Renders [IdCardSheet] offscreen and returns a high-resolution PNG file.
  ///
  /// Every image is decoded *before* the off-screen render starts, so nothing
  /// in the captured frame depends on an async load that may not have landed.
  static Future<File> exportPng({
    required Applicant applicant,
    required String personalId,
    required DateTime issuedAt,
  }) async {
    final qrData = cardLinkFor(
      applicant: applicant,
      personalId: personalId,
      issuedAt: issuedAt,
    );
    final images = await CardImages.load(
      qrData: qrData,
      photoPath: applicant.photoPath,
    );
    try {
      final controller = ScreenshotController();
      final bytes = await controller.captureFromWidget(
        _PngCardSheet(
          applicant: applicant,
          personalId: personalId,
          qrData: qrData,
          issuedAt: issuedAt,
          images: images,
        ),
        pixelRatio: 3,
        targetSize: exportSheetSize,
        delay: const Duration(milliseconds: 40),
      );
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/${fileName(personalId, 'png')}');
      await file.writeAsBytes(bytes, flush: true);
      return file;
    } finally {
      images.dispose();
    }
  }

  /// Builds an A4 Digital Identity Certificate and returns the PDF file.
  static Future<File> exportPdf({
    required Applicant applicant,
    required String personalId,
    required DateTime issuedAt,
  }) async {
    final bytes = await buildPdfBytes(
      applicant: applicant,
      personalId: personalId,
      issuedAt: issuedAt,
    );
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/${fileName(personalId, 'pdf')}');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  /// The raw PDF bytes — used for both saving and native printing.
  static Future<Uint8List> buildPdfBytes({
    required Applicant applicant,
    required String personalId,
    required DateTime issuedAt,
  }) async {
    final document = pw.Document(
      title: 'شهادة هوية المنتسب — $personalId',
      author: 'إدارة القوى البشرية',
    );
    final palette = await _PdfPalette.create(
      await rootBundle.load('assets/A.jpg'),
      await rootBundle.load('assets/fonts/Almarai-Regular.ttf'),
      await rootBundle.load('assets/fonts/Almarai-Bold.ttf'),
      await rootBundle.load('assets/fonts/SpaceMono-Regular.ttf'),
      await rootBundle.load('assets/fonts/SpaceMono-Bold.ttf'),
    );
    final qrImage = pw.MemoryImage(
      await _qrPng(
        cardLinkFor(
          applicant: applicant,
          personalId: personalId,
          issuedAt: issuedAt,
        ),
      ),
    );
    final photoFile =
        applicant.photoPath == null ? null : File(applicant.photoPath!);
    final photo = photoFile != null && photoFile.existsSync()
        ? pw.MemoryImage(await photoFile.readAsBytes())
        : null;

    document.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (context) {
          return pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                _header(palette, personalId, issuedAt),
                pw.SizedBox(height: 14),
                _frontCard(palette, photo, applicant, personalId, issuedAt),
                pw.SizedBox(height: 14),
                _backCard(palette, applicant, personalId, issuedAt),
                pw.SizedBox(height: 14),
                _qrBlock(palette, qrImage, personalId),
                pw.SizedBox(height: 14),
                _footer(palette, personalId, issuedAt),
              ],
            ),
          );
        },
      ),
    );

    return document.save();
  }

  /// Opens the native save / share sheet for the exported [file].
  ///
  /// iPad presents the sheet as a popover and *requires* an anchor rectangle;
  /// without it the call fails and nothing is ever saved. [origin] should be
  /// the global bounds of the control the user tapped.
  static Future<ShareResult> share(
    BuildContext context,
    File file, {
    Rect? origin,
    String? subject,
  }) {
    return SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: _mimeFor(file))],
        subject: subject,
        sharePositionOrigin: origin ?? _fallbackOrigin(context),
      ),
    );
  }

  /// Opens the system print / "save to Files" dialog for the certificate.
  static Future<bool> printPdf({
    required Applicant applicant,
    required String personalId,
    required DateTime issuedAt,
  }) {
    return Printing.layoutPdf(
      name: fileName(personalId, 'pdf'),
      format: PdfPageFormat.a4,
      onLayout: (_) => buildPdfBytes(
        applicant: applicant,
        personalId: personalId,
        issuedAt: issuedAt,
      ),
    );
  }

  /// The scannable link printed on a card — the single source of truth for
  /// what its QR code contains, on screen and in every export.
  static String cardLinkFor({
    required Applicant applicant,
    required String personalId,
    required DateTime issuedAt,
  }) {
    return CardLink.encode(
      applicant: applicant,
      personalId: personalId,
      issuedAtUtc: issuedAt,
    );
  }

  /// Stable, filesystem-safe name for an exported card.
  static String fileName(String personalId, String extension) =>
      'A-ID-${personalId.replaceAll(RegExp(r'[^A-Za-z0-9\-]'), '')}.$extension';

  /// Anchor used when the caller could not measure the tapped control.
  static Rect _fallbackOrigin(BuildContext context) {
    final box = context.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize) {
      return box.localToGlobal(Offset.zero) & box.size;
    }
    final size = MediaQuery.sizeOf(context);
    return Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: 1,
      height: 1,
    );
  }

  static String _mimeFor(File file) =>
      file.path.toLowerCase().endsWith('.pdf') ? 'application/pdf' : 'image/png';

  static Future<Uint8List> _qrPng(String payload) async {
    final painter = QrPainter(
      data: payload,
      version: QrVersions.auto,
      gapless: true,
      errorCorrectionLevel: QrErrorCorrectLevel.M,
    );
    final data = await painter.toImageData(
      1200,
      format: ui.ImageByteFormat.png,
    );
    return data!.buffer.asUint8List();
  }

  static pw.Widget _header(_PdfPalette p, String personalId, DateTime issuedAt) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: pw.BoxDecoration(
        borderRadius: pw.BorderRadius.circular(16),
        gradient: pw.LinearGradient(
          begin: pw.Alignment.centerLeft,
          end: pw.Alignment.centerRight,
          colors: [p.pineRaised, p.pine],
        ),
      ),
      child: pw.Row(
        children: [
          pw.ClipRRect(
            horizontalRadius: 10,
            verticalRadius: 10,
            child: pw.Image(p.logo, width: 40, height: 40),
          ),
          pw.SizedBox(width: 12),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'إدارة القوى البشرية',
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 16,
                    font: p.bold,
                    letterSpacing: 1.4,
                  ),
                ),
                pw.Text(
                  'شهادة هوية رسمية',
                  style: pw.TextStyle(
                    color: p.gold,
                    fontSize: 10,
                    font: p.regular,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
          ),
          pw.Text(
            personalId,
            style: pw.TextStyle(
              color: PdfColors.white,
              fontSize: 13,
              font: p.monoBold,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _frontCard(
    _PdfPalette p,
    pw.ImageProvider? photo,
    Applicant applicant,
    String personalId,
    DateTime issuedAt,
  ) {
    final card = pw.Container(
      height: 190,
      decoration: pw.BoxDecoration(
        borderRadius: pw.BorderRadius.circular(18),
        gradient: pw.LinearGradient(
          begin: pw.Alignment.topLeft,
          end: pw.Alignment.bottomRight,
          colors: [p.pineRaised, p.pine, p.pineDeep],
        ),
      ),
      child: pw.Stack(
        children: [
          pw.Positioned(
            right: -30,
            bottom: -70,
            child: pw.Text(
              'A',
              style: pw.TextStyle(
                color: p.gold.withAlpha(0.14),
                fontSize: 240,
                font: p.bold,
              ),
            ),
          ),
          pw.Positioned.fill(
            child: pw.Padding(
              padding: const pw.EdgeInsets.all(18),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    children: [
                      pw.ClipRRect(
                        horizontalRadius: 8,
                        verticalRadius: 8,
                        child: pw.Image(p.logo, width: 34, height: 34),
                      ),
                      pw.SizedBox(width: 10),
                      pw.Text(
                        'إدارة القوى البشرية',
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 12,
                          font: p.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                      pw.Spacer(),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: pw.BoxDecoration(
                          color: p.gold,
                          borderRadius: pw.BorderRadius.circular(20),
                        ),
                        child: pw.Text(
                          'موثّقة',
                          style: pw.TextStyle(
                            color: p.pineDeep,
                            fontSize: 8,
                            font: p.bold,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ],
                  ),
                  pw.Spacer(),
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      if (photo != null)
                        pw.ClipRRect(
                          horizontalRadius: 12,
                          verticalRadius: 12,
                          child: pw.Image(photo, width: 86, height: 92),
                        )
                      else
                        pw.Container(
                          width: 86,
                          height: 92,
                          decoration: pw.BoxDecoration(
                            color: p.pineDeep,
                            borderRadius: pw.BorderRadius.circular(12),
                          ),
                          child: pw.Center(
                            child: pw.Text(
                              'A',
                              style: pw.TextStyle(
                                color: p.gold,
                                fontSize: 34,
                                font: p.bold,
                              ),
                            ),
                          ),
                        ),
                      pw.SizedBox(width: 16),
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              applicant.fullName.toUpperCase(),
                              style: pw.TextStyle(
                                color: PdfColors.white,
                                fontSize: 19,
                                font: p.bold,
                              ),
                            ),
                            pw.SizedBox(height: 6),
                            pw.Text(
                              '${applicant.academicYear.label} · مواليد ${applicant.birthYear}',
                              style: pw.TextStyle(
                                color: p.gold,
                                fontSize: 10,
                                font: p.regular,
                              ),
                            ),
                            pw.SizedBox(height: 4),
                            pw.Text(
                              applicant.placeLabel,
                              style: pw.TextStyle(
                                color: p.white70,
                                fontSize: 10,
                                font: p.regular,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  pw.Spacer(),
                  pw.Container(height: 1, color: p.gold.withAlpha(0.45)),
                  pw.SizedBox(height: 8),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'رقم الانتساب',
                        style: pw.TextStyle(
                          color: p.white54,
                          fontSize: 7,
                          font: p.regular,
                          letterSpacing: 1.4,
                        ),
                      ),
                      pw.Text(
                        'صدرت في ${_formatDate(issuedAt)}',
                        style: pw.TextStyle(
                          color: p.white54,
                          fontSize: 7,
                          font: p.regular,
                          letterSpacing: 1.4,
                        ),
                      ),
                    ],
                  ),
                  pw.Text(
                    personalId,
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 16,
                      font: p.monoBold,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    return pw.ClipRRect(
      horizontalRadius: 18,
      verticalRadius: 18,
      child: card,
    );
  }

  static pw.Widget _backCard(
    _PdfPalette p,
    Applicant applicant,
    String personalId,
    DateTime issuedAt,
  ) {
    pw.Widget detail(String label, String value) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              label.toUpperCase(),
              style: pw.TextStyle(
                color: p.inkMuted,
                fontSize: 7,
                font: p.regular,
                letterSpacing: 1.1,
              ),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              value,
              style: pw.TextStyle(
                color: p.ink,
                fontSize: 11,
                font: p.bold,
              ),
            ),
          ],
        );

    return pw.Container(
      padding: const pw.EdgeInsets.all(18),
      decoration: pw.BoxDecoration(
        borderRadius: pw.BorderRadius.circular(18),
        color: p.ivory,
        border: pw.Border.all(color: p.gold, width: 1.2),
      ),
      child: pw.Row(
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'بيانات الهوية',
                  style: pw.TextStyle(
                    color: p.ink,
                    fontSize: 13,
                    font: p.bold,
                    letterSpacing: 0.6,
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Wrap(
                  spacing: 28,
                  runSpacing: 12,
                  children: [
                    detail('فصيلة الدم', applicant.bloodType.label),
                    detail('سنة الميلاد', '${applicant.birthYear}'),
                    detail('المحافظة', applicant.governorate),
                    detail('الطول', '${applicant.heightCm} سم'),
                    detail('الوزن', _formatWeight(applicant.weightKg)),
                    detail('العين اليمنى', applicant.rightEyeAcuity.label),
                    detail('العين اليسرى', applicant.leftEyeAcuity.label),
                    detail(
                      'البصمة',
                      applicant.biometricStatusLabel,
                    ),
                    if (applicant.biometric != null)
                      detail('مسار التوثيق', applicant.biometric!.method.shortLabel),
                  ],
                ),
                pw.SizedBox(height: 12),
                pw.Container(height: 1, color: p.gold.withAlpha(0.4)),
                pw.SizedBox(height: 8),
                pw.Row(
                  children: [
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'مصدر قياس الإبصار: ${applicant.visionSourceLabel}',
                            style: pw.TextStyle(
                              color: p.inkMuted,
                              fontSize: 8,
                              font: p.regular,
                            ),
                          ),
                          pw.Text(
                            'مصدر تسجيل البصمة: '
                            '${applicant.biometricShortLabel}',
                            style: pw.TextStyle(
                              color: p.inkMuted,
                              fontSize: 8,
                              font: p.regular,
                            ),
                          ),
                        ],
                      ),
                    ),
                    pw.Text(
                      personalId,
                      style: pw.TextStyle(
                        color: p.goldDeep,
                        fontSize: 11,
                        font: p.monoBold,
                        letterSpacing: 1.1,
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

  /// The verification code, given its own module below the data page.
  ///
  /// Printed at 130pt on white with a wide quiet zone, it is a code a phone
  /// can read off the paper at arm's length — which a stamp in the corner of
  /// the card never was.
  static pw.Widget _qrBlock(
    _PdfPalette p,
    pw.ImageProvider qrImage,
    String personalId,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(18),
      decoration: pw.BoxDecoration(
        borderRadius: pw.BorderRadius.circular(18),
        color: p.pine,
        border: pw.Border.all(color: p.gold, width: 1.2),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.all(9),
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              border: pw.Border.all(color: p.gold, width: 1.2),
              borderRadius: pw.BorderRadius.circular(12),
            ),
            child: pw.Image(qrImage, width: 130, height: 130),
          ),
          pw.SizedBox(width: 20),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'رمز التحقق الرقمي',
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 14,
                    font: p.bold,
                    letterSpacing: 0.6,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  'امسح الرمز بكاميرا الهاتف للتحقق من صحة هذه الوثيقة '
                  'ومطابقة بياناتها مع السجلّ المُصدر.',
                  style: pw.TextStyle(
                    color: p.white70,
                    fontSize: 9,
                    font: p.regular,
                    lineSpacing: 3,
                  ),
                ),
                pw.SizedBox(height: 12),
                pw.Container(height: 1, color: p.gold.withAlpha(0.4)),
                pw.SizedBox(height: 10),
                pw.Text(
                  personalId,
                  style: pw.TextStyle(
                    color: p.gold,
                    fontSize: 12,
                    font: p.monoBold,
                    letterSpacing: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _footer(
    _PdfPalette p,
    String personalId,
    DateTime issuedAt,
  ) {
    return pw.Row(
      children: [
        pw.Expanded(
          child: pw.Text(
            'هذه الوثيقة صادرة رقميًا وقابلة للتحقق ذاتيًا. '
            'تُحفظ البيانات بشكل آمن على الجهاز المُصدر.',
            style: pw.TextStyle(
              color: p.goldDeep,
              fontSize: 8,
              font: p.regular,
            ),
          ),
        ),
        pw.Text(
          'A · $personalId · ${_formatDate(issuedAt)}',
          style: pw.TextStyle(
            color: p.pine,
            fontSize: 9,
            font: p.bold,
          ),
        ),
      ],
    );
  }

  static String _formatDate(DateTime date) {
    const months = ['يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو', 'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  static String _formatWeight(double weight) {
    if (weight == weight.roundToDouble()) {
      return '${weight.round()} كجم';
    }
    return '${weight.toStringAsFixed(1)} كجم';
  }
}

/// Colors and embedded fonts shared by every page of the PDF document.
class _PdfPalette {
  _PdfPalette({
    required this.logo,
    required this.regular,
    required this.bold,
    required this.monoRegular,
    required this.monoBold,
  });

  static Future<_PdfPalette> create(
    ByteData logoData,
    ByteData poppinsRegular,
    ByteData poppinsBold,
    ByteData monoRegular,
    ByteData monoBold,
  ) async {
    return _PdfPalette(
      logo: pw.MemoryImage(logoData.buffer.asUint8List()),
      regular: pw.Font.ttf(poppinsRegular),
      bold: pw.Font.ttf(poppinsBold),
      monoRegular: pw.Font.ttf(monoRegular),
      monoBold: pw.Font.ttf(monoBold),
    );
  }

  final pw.ImageProvider logo;
  final pw.Font regular;
  final pw.Font bold;
  final pw.Font monoRegular;
  final pw.Font monoBold;

  final PdfColor pine = PdfColor.fromInt(0xFF17352F);
  final PdfColor pineRaised = PdfColor.fromInt(0xFF1E453C);
  final PdfColor pineDeep = PdfColor.fromInt(0xFF0E231F);
  final PdfColor gold = PdfColor.fromInt(0xFFB9A779);
  final PdfColor goldDeep = PdfColor.fromInt(0xFF8A7443);
  final PdfColor ivory = PdfColor.fromInt(0xFFFAF7EF);
  final PdfColor ink = PdfColor.fromInt(0xFF16211E);
  final PdfColor inkMuted = PdfColor.fromInt(0xFF5C6B66);
  final PdfColor white70 = PdfColor.fromHex('B3FFFFFF');
  final PdfColor white54 = PdfColor.fromHex('8AFFFFFF');
}

/// The off-screen export canvas: both card faces on a branded backdrop.
class _PngCardSheet extends StatelessWidget {
  const _PngCardSheet({
    required this.applicant,
    required this.personalId,
    required this.qrData,
    required this.issuedAt,
    required this.images,
  });

  final Applicant applicant;
  final String personalId;
  final String qrData;
  final DateTime issuedAt;
  final CardImages images;

  @override
  Widget build(BuildContext context) {
    const width = ExportService.exportCardWidth;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: MediaQuery(
        // Pin the text scale so the export looks identical on every device.
        data: const MediaQueryData(textScaler: TextScaler.noScaling),
        child: Material(
          color: BrandColors.ivory,
          child: Container(
            width: ExportService.exportSheetSize.width,
            height: ExportService.exportSheetSize.height,
            padding: const EdgeInsets.fromLTRB(36, 36, 36, 30),
            decoration: const BoxDecoration(color: BrandColors.ivory),
            child: Column(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                IdCardSheet(
                  applicant: applicant,
                  personalId: personalId,
                  qrData: qrData,
                  issuedAt: issuedAt,
                  cardWidth: width,
                  images: images,
                ),
                const SizedBox(height: 22),
                Text(
                  'إدارة القوى البشرية · وثيقة صادرة رقميًا وقابلة للتحقق',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Almarai',
                    fontSize: 12,
                    color: BrandColors.goldDeep,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
