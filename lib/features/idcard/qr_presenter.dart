import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../app/theme/brand_colors.dart';

/// Presents the card's QR code big enough for another phone to actually read.
///
/// A camera needs roughly half a millimetre per QR module at normal scanning
/// distance. The code printed on the card back is only a few millimetres wide
/// — a camera sees *a* code there but cannot resolve its modules. This screen
/// gives the symbol the whole display, on pure white with a proper quiet zone,
/// which is what makes the difference between "it scans" and "it works".
class QrPresenterPage extends StatelessWidget {
  const QrPresenterPage({
    super.key,
    required this.data,
    required this.personalId,
    this.hosted = true,
  });

  final String data;
  final String personalId;

  /// Whether the code carries a web link (any camera can open it) or only the
  /// app link (the built-in scanner is then the only reader).
  final bool hosted;

  static Future<void> open(
    BuildContext context, {
    required String data,
    required String personalId,
    bool hosted = true,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => QrPresenterPage(
          data: data,
          personalId: personalId,
          hosted: hosted,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    // Fill the display, leaving room for the caption and the quiet zone.
    final side = math.min(size.width - 32, size.height * 0.62);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        // Pure white maximises the contrast a camera has to work with.
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    tooltip: 'إغلاق',
                    icon: const Icon(Icons.close_rounded),
                    color: BrandColors.pine,
                  ),
                  Expanded(
                    child: Text(
                      'اعرض هذا الرمز للماسح',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: BrandColors.pine,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
              Expanded(
                child: Center(
                  child: RepaintBoundary(
                    child: Container(
                      // The white quiet zone around the symbol is part of the
                      // spec — without it, readers struggle to lock on.
                      padding: EdgeInsets.all(side * 0.05),
                      color: Colors.white,
                      child: QrImageView(
                        data: data,
                        version: QrVersions.auto,
                        errorCorrectionLevel: QrErrorCorrectLevel.M,
                        gapless: true,
                        size: side,
                        backgroundColor: Colors.white,
                        eyeStyle: const QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: Colors.black,
                        ),
                        dataModuleStyle: const QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: Colors.black,
                        ),
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      personalId,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontFamily: 'SpaceMono',
                            color: BrandColors.goldDeep,
                            letterSpacing: 1.6,
                          ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      hosted
                          ? 'ارفع سطوع الشاشة، ووجّه كاميرا الهاتف الآخر نحو '
                              'الرمز. ستفتح البطاقة جاهزة للتنزيل PNG أو PDF.'
                          : 'ارفع سطوع الشاشة، وامسح الرمز من داخل التطبيق. '
                              'لتفعيل المسح بكاميرا أي هاتف اضبط عنوان صفحة '
                              'التحقق.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: BrandColors.inkMuted,
                            height: 1.7,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
