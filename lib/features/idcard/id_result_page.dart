import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/brand_colors.dart';
import '../../config/verify_endpoint.dart';
import '../../models/applicant.dart';
import '../../services/export_service.dart';
import '../../services/id_engine.dart';
import '../../shared/widgets/adaptive_layout.dart';
import '../../shared/widgets/animations.dart';
import '../../shared/widgets/ornament_background.dart';
import 'id_card_view.dart';
import 'qr_presenter.dart';

/// Where this card came from, which decides the page's framing and closing
/// action: a card you just issued, or someone else's card you just scanned.
enum IdResultMode { issued, scanned }

/// Final screen: the identity card, flippable in 3D, ready to be saved as a
/// high-resolution PNG or a printable PDF certificate.
class IdResultPage extends StatefulWidget {
  const IdResultPage({
    super.key,
    required this.applicant,
    required this.personalId,
    required this.issuedAt,
    this.mode = IdResultMode.issued,
  });

  final Applicant applicant;
  final String personalId;
  final DateTime issuedAt;
  final IdResultMode mode;

  @override
  State<IdResultPage> createState() => _IdResultPageState();
}

class _IdResultPageState extends State<IdResultPage>
    with TickerProviderStateMixin {
  /// 0 = front, 1 = back. Never repeats — it settles on a face and stays there.
  late final AnimationController _flip;
  late final AnimationController _reveal;

  final GlobalKey _pngButtonKey = GlobalKey();
  final GlobalKey _pdfButtonKey = GlobalKey();

  /// The string drawn into the QR: a link that rebuilds this exact card.
  late final String _qrData;

  /// The same identity as readable JSON, for the "what's in the code" panel.
  late final String _readablePayload;

  bool _busyPng = false;
  bool _busyPdf = false;
  bool _busyPrint = false;
  bool _showJson = false;

  @override
  void initState() {
    super.initState();
    _qrData = ExportService.cardLinkFor(
      applicant: widget.applicant,
      personalId: widget.personalId,
      issuedAt: widget.issuedAt,
    );
    _readablePayload = IdEngine.buildQrPayload(
      widget.applicant,
      widget.personalId,
      widget.issuedAt,
    );
    _flip = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 620),
      value: 0,
    );
    _reveal = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 720),
    )..forward();
  }

  @override
  void dispose() {
    _flip.dispose();
    _reveal.dispose();
    super.dispose();
  }

  bool get _showingBack => _flip.value > 0.5;

  /// Blows the QR up to fill the screen — the size a camera needs.
  void _presentQr() {
    QrPresenterPage.open(
      context,
      data: _qrData,
      personalId: widget.personalId,
      hosted: kHasHostedVerifier,
    );
  }

  void _toggleFlip() {
    HapticFeedback.selectionClick();
    if (_showingBack) {
      _flip.animateBack(0, curve: Curves.easeOutCubic);
    } else {
      _flip.animateTo(1, curve: Curves.easeOutCubic);
    }
  }

  @override
  Widget build(BuildContext context) {
    final band = Adaptive.bandOf(context);
    final size = MediaQuery.sizeOf(context);
    final base = switch (band) {
      ScreenBand.compact => 340.0,
      ScreenBand.medium => 420.0,
      ScreenBand.expanded => 460.0,
      ScreenBand.television => 560.0,
    };
    final cardWidth =
        math.min(base, size.width - band.gutter * 2).clamp(240.0, 620.0);

    return Scaffold(
      body: OrnamentBackground(
        child: SafeArea(
          child: Scrollbar(
            child: SingleChildScrollView(
              primary: true,
              padding: EdgeInsets.fromLTRB(
                band.gutter,
                20,
                band.gutter,
                40,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: band.contentWidth),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _SuccessHeader(
                        personalId: widget.personalId,
                        mode: widget.mode,
                      ),
                      SizedBox(height: band.isCompact ? 24 : 32),
                      _FlipStage(
                        flip: _flip,
                        reveal: _reveal,
                        cardWidth: cardWidth,
                        onTap: _toggleFlip,
                        front: IdCardView(
                          applicant: widget.applicant,
                          personalId: widget.personalId,
                          issuedAt: widget.issuedAt,
                          cardWidth: cardWidth,
                        ),
                        back: IdCardBack(
                          applicant: widget.applicant,
                          personalId: widget.personalId,
                          qrData: _qrData,
                          issuedAt: widget.issuedAt,
                          cardWidth: cardWidth,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _FlipControls(
                        flip: _flip,
                        onToggle: _toggleFlip,
                        onPresent: _presentQr,
                      ),
                      const SizedBox(height: 24),
                      _DownloadPanel(
                        pngKey: _pngButtonKey,
                        pdfKey: _pdfButtonKey,
                        busyPng: _busyPng,
                        busyPdf: _busyPdf,
                        busyPrint: _busyPrint,
                        onPng: _downloadPng,
                        onPdf: _downloadPdf,
                        onPrint: _printPdf,
                      ),
                      const SizedBox(height: 24),
                      _IdentityPayload(
                        payload: _readablePayload,
                        expanded: _showJson,
                        onToggle: () => setState(() => _showJson = !_showJson),
                      ),
                      const SizedBox(height: 24),
                      Center(
                        child: OutlinedButton.icon(
                          // `true` tells the registration flow to reset; the
                          // old build only popped, landing the user back on a
                          // form still full of the previous applicant.
                          onPressed: () => Navigator.of(context).pop(true),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(180, 52),
                            side: const BorderSide(
                              color: BrandColors.pine,
                              width: 1.4,
                            ),
                            shape: const StadiumBorder(),
                          ),
                          icon: Icon(
                            widget.mode == IdResultMode.issued
                                ? Icons.replay_rounded
                                : Icons.qr_code_scanner_rounded,
                          ),
                          label: Text(
                            widget.mode == IdResultMode.issued
                                ? 'بدء تسجيل جديد'
                                : 'مسح بطاقة أخرى',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------- التصدير

  Rect? _originOf(GlobalKey key) {
    final box = key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  Future<void> _downloadPng() async {
    await _runExport(
      setBusy: (busy) => setState(() => _busyPng = busy),
      origin: _originOf(_pngButtonKey),
      export: () => ExportService.exportPng(
        applicant: widget.applicant,
        personalId: widget.personalId,
        issuedAt: widget.issuedAt,
      ),
    );
  }

  Future<void> _downloadPdf() async {
    await _runExport(
      setBusy: (busy) => setState(() => _busyPdf = busy),
      origin: _originOf(_pdfButtonKey),
      export: () => ExportService.exportPdf(
        applicant: widget.applicant,
        personalId: widget.personalId,
        issuedAt: widget.issuedAt,
      ),
    );
  }

  Future<void> _printPdf() async {
    setState(() => _busyPrint = true);
    try {
      await ExportService.printPdf(
        applicant: widget.applicant,
        personalId: widget.personalId,
        issuedAt: widget.issuedAt,
      );
    } catch (error) {
      _reportFailure(error);
    } finally {
      if (mounted) setState(() => _busyPrint = false);
    }
  }

  Future<void> _runExport({
    required ValueChanged<bool> setBusy,
    required Future<File> Function() export,
    Rect? origin,
  }) async {
    setBusy(true);
    try {
      final file = await export();
      if (!mounted) return;
      await ExportService.share(
        context,
        file,
        origin: origin,
        subject: 'بطاقة الهوية الرقمية — ${widget.personalId}',
      );
      if (!mounted) return;
      _report(
        'تم تجهيز الملف: ${file.uri.pathSegments.last}',
        icon: Icons.check_circle_outline_rounded,
      );
    } catch (error) {
      _reportFailure(error);
    } finally {
      if (mounted) setBusy(false);
    }
  }

  void _reportFailure(Object error) {
    if (!mounted) return;
    _report(
      'تعذّر إتمام العملية. حاول مرة أخرى.',
      icon: Icons.error_outline_rounded,
      error: true,
      detail: error.toString(),
    );
  }

  void _report(
    String message, {
    required IconData icon,
    bool error = false,
    String? detail,
  }) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          backgroundColor: error ? BrandColors.error : BrandColors.pine,
          content: Row(
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
          action: detail == null
              ? null
              : SnackBarAction(
                  label: 'التفاصيل',
                  textColor: Colors.white,
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('تفاصيل الخطأ'),
                      content: SingleChildScrollView(
                        child: SelectableText(
                          detail,
                          style: const TextStyle(
                            fontFamily: 'SpaceMono',
                            fontSize: 12,
                          ),
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('إغلاق'),
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      );
  }
}

// ---------------------------------------------------------------- الترويسة

class _SuccessHeader extends StatelessWidget {
  const _SuccessHeader({required this.personalId, required this.mode});

  final String personalId;
  final IdResultMode mode;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final issued = mode == IdResultMode.issued;

    return Entrance(
      child: Column(
        children: [
          _SuccessBadge(icon: issued ? Icons.check_rounded : Icons.verified_rounded),
          const SizedBox(height: 18),
          Text(
            issued ? 'بطاقة هويتك جاهزة' : 'تمت قراءة البطاقة',
            textAlign: TextAlign.center,
            style: textTheme.headlineMedium?.copyWith(
              color: BrandColors.pine,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          _IdBadge(personalId: personalId),
          const SizedBox(height: 12),
          Text(
            issued
                ? 'اقلب البطاقة لرؤية رمز QR، ثم نزّلها كصورة PNG عالية الدقة '
                    'أو مستند PDF رسمي قابل للطباعة.'
                : 'أُعيد بناء البطاقة من رمز QR. نزّلها الآن كصورة PNG عالية '
                    'الدقة أو مستند PDF رسمي قابل للطباعة.',
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(
              color: BrandColors.inkMuted,
              height: 1.7,
            ),
          ),
        ],
      ),
    );
  }
}

/// The personal ID, tappable to copy — the one string users need to keep.
class _IdBadge extends StatelessWidget {
  const _IdBadge({required this.personalId});

  final String personalId;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: BrandColors.goldMist,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: () async {
            await Clipboard.setData(ClipboardData(text: personalId));
            if (!context.mounted) return;
            ScaffoldMessenger.of(context)
              ..clearSnackBars()
              ..showSnackBar(
                const SnackBar(content: Text('تم نسخ الرقم الشخصي.')),
              );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: BrandColors.gold.withValues(alpha: 0.5),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.copy_rounded,
                  size: 15,
                  color: BrandColors.goldDeep,
                ),
                const SizedBox(width: 10),
                Text(
                  personalId,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: BrandColors.goldDeep,
                        fontFamily: 'SpaceMono',
                        letterSpacing: 1.4,
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

class _SuccessBadge extends StatefulWidget {
  const _SuccessBadge({required this.icon});

  final IconData icon;

  @override
  State<_SuccessBadge> createState() => _SuccessBadgeState();
}

class _SuccessBadgeState extends State<_SuccessBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value;
          return SizedBox(
            width: 96,
            height: 96,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Transform.scale(
                  scale: 1.0 + 0.5 * t,
                  child: Opacity(
                    opacity: (1 - t) * 0.6,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: BrandColors.gold, width: 2),
                      ),
                    ),
                  ),
                ),
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: BrandGradients.gold,
                    boxShadow: [
                      BoxShadow(
                        color: BrandColors.gold.withValues(alpha: 0.45),
                        blurRadius: 22,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Icon(
                    widget.icon,
                    size: 38,
                    color: const Color(0xFF243028),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ------------------------------------------------------------------ القلب 3D

/// A real two-sided card: the front face rotates away and the back face
/// rotates in behind it. The rotation is driven by a controller that always
/// settles on a face — it never loops.
class _FlipStage extends StatelessWidget {
  const _FlipStage({
    required this.flip,
    required this.reveal,
    required this.cardWidth,
    required this.front,
    required this.back,
    required this.onTap,
  });

  final AnimationController flip;
  final Animation<double> reveal;
  final double cardWidth;
  final Widget front;
  final Widget back;
  final VoidCallback onTap;

  void _onDragUpdate(DragUpdateDetails details) {
    // A full flip takes roughly the width of the card in drag distance.
    flip.value = (flip.value - details.primaryDelta! / cardWidth).clamp(0.0, 1.0);
  }

  void _onDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    final toBack = velocity.abs() > 300
        ? velocity < 0
        : flip.value > 0.5;
    if (toBack) {
      flip.animateTo(1, curve: Curves.easeOutCubic);
    } else {
      flip.animateBack(0, curve: Curves.easeOutCubic);
    }
  }

  @override
  Widget build(BuildContext context) {
    final entrance = CurvedAnimation(
      parent: reveal,
      curve: Curves.easeOutBack,
    );

    return Center(
      child: Semantics(
        button: true,
        label: 'بطاقة الهوية — اضغط لقلبها',
        child: GestureDetector(
          onTap: onTap,
          onHorizontalDragUpdate: _onDragUpdate,
          onHorizontalDragEnd: _onDragEnd,
          behavior: HitTestBehavior.opaque,
          child: AnimatedBuilder(
            animation: Listenable.merge([flip, reveal]),
            builder: (context, _) {
              final angle = flip.value * math.pi;
              final showBack = flip.value > 0.5;
              final scale = 0.88 + 0.12 * entrance.value.clamp(0.0, 1.2);

              return Opacity(
                opacity: reveal.value.clamp(0.0, 1.0),
                child: Transform.scale(
                  scale: scale,
                  child: Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.0012)
                      ..rotateY(angle),
                    child: showBack
                        // The back is pre-rotated so it reads correctly once
                        // the card has turned past the halfway point.
                        ? Transform(
                            alignment: Alignment.center,
                            transform: Matrix4.rotationY(math.pi),
                            child: back,
                          )
                        : front,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _FlipControls extends StatelessWidget {
  const _FlipControls({
    required this.flip,
    required this.onToggle,
    required this.onPresent,
  });

  final AnimationController flip;
  final VoidCallback onToggle;
  final VoidCallback onPresent;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: flip,
      builder: (context, _) {
        final showingBack = flip.value > 0.5;
        return Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _FaceDot(active: !showingBack, label: 'الوجه'),
                const SizedBox(width: 8),
                _FaceDot(active: showingBack, label: 'الظهر'),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 4,
              children: [
                TextButton.icon(
                  onPressed: onToggle,
                  icon: const Icon(Icons.threed_rotation_rounded, size: 18),
                  label: Text(
                    showingBack ? 'إظهار وجه البطاقة' : 'إظهار ظهر البطاقة',
                  ),
                ),
                TextButton.icon(
                  onPressed: onPresent,
                  icon: const Icon(Icons.fullscreen_rounded, size: 18),
                  label: const Text('تكبير رمز المسح'),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _FaceDot extends StatelessWidget {
  const _FaceDot({required this.active, required this.label});

  final bool active;
  final String label;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: BrandDurations.quick,
      padding: EdgeInsets.symmetric(horizontal: active ? 12 : 8, vertical: 5),
      decoration: BoxDecoration(
        color: active ? BrandColors.pine : BrandColors.ivoryDeep,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: active ? BrandColors.goldGlow : BrandColors.inkMuted,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

// ------------------------------------------------------------------ التنزيل

class _DownloadPanel extends StatelessWidget {
  const _DownloadPanel({
    required this.pngKey,
    required this.pdfKey,
    required this.busyPng,
    required this.busyPdf,
    required this.busyPrint,
    required this.onPng,
    required this.onPdf,
    required this.onPrint,
  });

  final GlobalKey pngKey;
  final GlobalKey pdfKey;
  final bool busyPng;
  final bool busyPdf;
  final bool busyPrint;
  final VoidCallback onPng;
  final VoidCallback onPdf;
  final VoidCallback onPrint;

  @override
  Widget build(BuildContext context) {
    final band = Adaptive.bandOf(context);
    final actions = [
      _DownloadAction(
        buttonKey: pngKey,
        icon: Icons.image_outlined,
        title: 'صورة PNG',
        subtitle: 'دقة ثلاثية · جاهزة للحفظ في الصور',
        busy: busyPng,
        onTap: onPng,
      ),
      _DownloadAction(
        buttonKey: pdfKey,
        icon: Icons.picture_as_pdf_outlined,
        title: 'مستند PDF',
        subtitle: 'شهادة A4 رسمية بالوجهين',
        busy: busyPdf,
        onTap: onPdf,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (band.isCompact)
          Column(
            children: [
              for (var i = 0; i < actions.length; i++) ...[
                actions[i],
                if (i != actions.length - 1) const SizedBox(height: 12),
              ],
            ],
          )
        else
          // IntrinsicHeight keeps both cards the same height inside a
          // vertically unbounded scroll view.
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < actions.length; i++) ...[
                  Expanded(child: actions[i]),
                  if (i != actions.length - 1) const SizedBox(width: 16),
                ],
              ],
            ),
          ),
        const SizedBox(height: 12),
        Center(
          child: TextButton.icon(
            onPressed: busyPrint ? null : onPrint,
            icon: busyPrint
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.print_outlined, size: 18),
            label: const Text('طباعة أو حفظ في الملفات'),
          ),
        ),
      ],
    );
  }
}

class _DownloadAction extends StatelessWidget {
  const _DownloadAction({
    required this.buttonKey,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.busy,
    required this.onTap,
  });

  final GlobalKey buttonKey;
  final IconData icon;
  final String title;
  final String subtitle;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: buttonKey,
      color: BrandColors.pine,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: busy ? null : onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              colors: [BrandColors.pineRaised, BrandColors.pine],
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: BrandColors.gold.withValues(alpha: 0.18),
                  border: Border.all(
                    color: BrandColors.gold.withValues(alpha: 0.5),
                  ),
                ),
                child: busy
                    ? const Padding(
                        padding: EdgeInsets.all(13),
                        child: CircularProgressIndicator(
                          strokeWidth: 2.6,
                          color: BrandColors.goldGlow,
                        ),
                      )
                    : Icon(icon, color: BrandColors.goldGlow, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      busy ? 'جارٍ التجهيز…' : 'تنزيل $title',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 2,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color:
                                BrandColors.goldGlow.withValues(alpha: 0.85),
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.download_for_offline_outlined,
                color: BrandColors.goldGlow,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ الحمولة

class _IdentityPayload extends StatelessWidget {
  const _IdentityPayload({
    required this.payload,
    required this.expanded,
    required this.onToggle,
  });

  final String payload;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final data = jsonDecode(payload) as Map<String, dynamic>;

    return Container(
      decoration: BoxDecoration(
        color: BrandColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: BrandColors.outlineSoft),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  const Icon(
                    Icons.data_object_rounded,
                    color: BrandColors.goldDeep,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'البيانات المضمنة في الرمز',
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    color: BrandColors.pine,
                                  ),
                        ),
                        Text(
                          '${data.length} حقول مشفّرة داخل رمز QR',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: BrandColors.inkMuted,
                                  ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: BrandDurations.quick,
                    child: const Icon(
                      Icons.expand_more_rounded,
                      color: BrandColors.pine,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: BrandDurations.standard,
            crossFadeState:
                expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            firstChild: const SizedBox(width: double.infinity, height: 0),
            secondChild: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: BrandColors.pineMist,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SelectableText(
                    _prettyPayload(data),
                    style: const TextStyle(
                      fontFamily: 'SpaceMono',
                      fontSize: 12,
                      height: 1.6,
                      color: BrandColors.pineDeep,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _prettyPayload(Map<String, dynamic> data) {
    final lines = data.entries.map((e) => '"${e.key}": ${_quote(e.value)}');
    return '{\n  ${lines.join(',\n  ')}\n}';
  }

  static String _quote(Object? value) {
    if (value is String) return '"$value"';
    return '$value';
  }
}
