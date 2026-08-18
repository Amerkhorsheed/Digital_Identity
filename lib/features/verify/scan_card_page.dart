import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../app/theme/brand_colors.dart';
import '../../services/card_link.dart';
import '../../services/id_record_store.dart';
import '../../shared/widgets/adaptive_layout.dart';
import '../../shared/widgets/brand_widgets.dart';
import '../idcard/id_result_page.dart';

/// Scan a card's QR code and get the card itself back — as a PNG or a PDF.
///
/// The code carries the identity data, not the file (no QR can hold a 600 KB
/// image), so this screen decodes it and hands the result straight to
/// [IdResultPage], where the download buttons live. When the scanned card was
/// issued on *this* device, the stored portrait is attached too, so the
/// rebuilt card is byte-for-byte the original.
class ScanCardPage extends StatefulWidget {
  const ScanCardPage({super.key, this.store});

  /// Optional local vault, used to recover the portrait of a card this device
  /// issued. Scanning still works fully without it.
  final IdRecordStore? store;

  static Future<void> open(BuildContext context, {IdRecordStore? store}) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => ScanCardPage(store: store),
      ),
    );
  }

  @override
  State<ScanCardPage> createState() => _ScanCardPageState();
}

class _ScanCardPageState extends State<ScanCardPage> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [BarcodeFormat.qrCode],
  );
  final TextEditingController _manual = TextEditingController();

  bool _handling = false;
  bool _manualOpen = false;
  bool _cameraFailed = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    _manual.dispose();
    super.dispose();
  }

  Future<void> _handle(String raw) async {
    if (_handling) return;
    setState(() {
      _handling = true;
      _error = null;
    });

    final card = CardLink.decode(raw);
    if (card == null) {
      setState(() {
        _handling = false;
        _error = CardLink.looksLikeCard(raw)
            ? 'الرمز تالف أو غير مكتمل. حاول مسحه مرة أخرى.'
            : 'هذا ليس رمز بطاقة رقمية.';
      });
      await HapticFeedback.heavyImpact();
      return;
    }

    await HapticFeedback.mediumImpact();

    // A card issued on this device still has its portrait in the local vault.
    var applicant = card.applicant;
    final record = await widget.store?.findById(card.personalId);
    final photoPath = record?['photo_path'] as String?;
    if (photoPath != null && photoPath.isNotEmpty) {
      applicant = applicant.copyWith(photoPath: photoPath);
    }

    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => IdResultPage(
          applicant: applicant,
          personalId: card.personalId,
          issuedAt: card.issuedAt,
          mode: IdResultMode.scanned,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final band = Adaptive.bandOf(context);

    return Scaffold(
      backgroundColor: BrandColors.pineDeep,
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            errorBuilder: (context, error) {
              // The viewfinder frame only makes sense over a live preview.
              if (!_cameraFailed) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) setState(() => _cameraFailed = true);
                });
              }
              return _CameraUnavailable(
                message: _cameraMessage(error),
                onManual: () => setState(() => _manualOpen = true),
              );
            },
            onDetect: (capture) {
              final value = capture.barcodes
                  .map((barcode) => barcode.rawValue)
                  .firstWhere((value) => value != null, orElse: () => null);
              if (value != null) _handle(value);
            },
          ),
          if (!_cameraFailed) const _ScanReticle(),
          SafeArea(
            child: Column(
              children: [
                _ScanBar(
                  onClose: () => Navigator.of(context).maybePop(),
                  onTorch: _controller.toggleTorch,
                ),
                const Spacer(),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    band.gutter,
                    0,
                    band.gutter,
                    24,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: _ScanFooter(
                      error: _error,
                      busy: _handling,
                      manualOpen: _manualOpen,
                      manual: _manual,
                      onToggleManual: () =>
                          setState(() => _manualOpen = !_manualOpen),
                      onSubmitManual: () => _handle(_manual.text),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _cameraMessage(MobileScannerException error) {
    return switch (error.errorCode) {
      MobileScannerErrorCode.permissionDenied =>
        'لم يُسمح للتطبيق باستخدام الكاميرا. فعّل الإذن من إعدادات الجهاز، '
            'أو الصق نص الرمز يدويًا.',
      MobileScannerErrorCode.unsupported =>
        'الكاميرا غير متوفرة على هذا الجهاز. الصق نص الرمز يدويًا.',
      _ => 'تعذّر تشغيل الكاميرا. الصق نص الرمز يدويًا.',
    };
  }
}

class _ScanBar extends StatelessWidget {
  const _ScanBar({required this.onClose, required this.onTorch});

  final VoidCallback onClose;
  final VoidCallback onTorch;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: onClose,
            tooltip: 'إغلاق',
            icon: const Icon(Icons.close_rounded, color: Colors.white),
          ),
          Expanded(
            child: Text(
              'امسح رمز البطاقة',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
          IconButton(
            onPressed: onTorch,
            tooltip: 'الإضاءة',
            icon: const Icon(Icons.flashlight_on_rounded, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

/// The gold viewfinder: a dimmed screen with a clear window in the middle.
class _ScanReticle extends StatelessWidget {
  const _ScanReticle();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = (constraints.biggest.shortestSide * 0.68).clamp(200.0, 460.0);
        return Stack(
          alignment: Alignment.center,
          children: [
            ColorFiltered(
              colorFilter: ColorFilter.mode(
                BrandColors.pineDeep.withValues(alpha: 0.72),
                BlendMode.srcOut,
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // srcOut punches the window out of the dim overlay.
                  DecoratedBox(
                    decoration: const BoxDecoration(
                      color: Colors.black,
                      backgroundBlendMode: BlendMode.dstOut,
                    ),
                  ),
                  Center(
                    child: Container(
                      width: side,
                      height: side,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            IgnorePointer(
              child: Container(
                width: side,
                height: side,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: BrandColors.gold, width: 2.4),
                  boxShadow: [
                    BoxShadow(
                      color: BrandColors.gold.withValues(alpha: 0.35),
                      blurRadius: 24,
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ScanFooter extends StatelessWidget {
  const _ScanFooter({
    required this.error,
    required this.busy,
    required this.manualOpen,
    required this.manual,
    required this.onToggleManual,
    required this.onSubmitManual,
  });

  final String? error;
  final bool busy;
  final bool manualOpen;
  final TextEditingController manual;
  final VoidCallback onToggleManual;
  final VoidCallback onSubmitManual;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: BrandColors.surface,
        borderRadius: BorderRadius.circular(BrandRadii.large),
        border: Border.all(color: BrandColors.gold.withValues(alpha: 0.4)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                busy
                    ? Icons.hourglass_top_rounded
                    : error != null
                        ? Icons.error_outline_rounded
                        : Icons.qr_code_scanner_rounded,
                color: error != null ? BrandColors.error : BrandColors.goldDeep,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  busy
                      ? 'جارٍ إعادة بناء البطاقة…'
                      : error ??
                          'وجّه الكاميرا نحو رمز QR على البطاقة، وستظهر '
                              'البطاقة كاملة جاهزة للتنزيل PNG أو PDF.',
                  style: textTheme.bodySmall?.copyWith(
                    color: error != null
                        ? BrandColors.error
                        : BrandColors.inkMuted,
                    height: 1.6,
                    fontWeight:
                        error != null ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
          AnimatedCrossFade(
            duration: BrandDurations.quick,
            crossFadeState: manualOpen
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: manual,
                    maxLines: 2,
                    minLines: 1,
                    textDirection: TextDirection.ltr,
                    decoration: const InputDecoration(
                      hintText: 'adigitalid://card?v=1&d=…',
                      prefixIcon: Icon(Icons.link_rounded, size: 20),
                    ),
                  ),
                  const SizedBox(height: 12),
                  BrandButton(
                    label: 'فتح البطاقة',
                    icon: Icons.badge_outlined,
                    large: true,
                    onPressed: busy ? null : onSubmitManual,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          TextButton.icon(
            onPressed: onToggleManual,
            icon: Icon(
              manualOpen
                  ? Icons.expand_less_rounded
                  : Icons.keyboard_alt_outlined,
              size: 18,
            ),
            label: Text(
              manualOpen ? 'إخفاء الإدخال اليدوي' : 'إدخال نص الرمز يدويًا',
            ),
          ),
        ],
      ),
    );
  }
}

class _CameraUnavailable extends StatelessWidget {
  const _CameraUnavailable({required this.message, required this.onManual});

  final String message;
  final VoidCallback onManual;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: BrandColors.pineDeep,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.no_photography_outlined,
                size: 48,
                color: BrandColors.goldGlow,
              ),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white,
                      height: 1.7,
                    ),
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: onManual,
                style: OutlinedButton.styleFrom(
                  foregroundColor: BrandColors.goldGlow,
                  side: const BorderSide(color: BrandColors.gold),
                  shape: const StadiumBorder(),
                  minimumSize: const Size(200, 50),
                ),
                icon: const Icon(Icons.keyboard_alt_outlined),
                label: const Text('إدخال نص الرمز'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
