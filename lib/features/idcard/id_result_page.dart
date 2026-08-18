import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;

import '../../app/theme/brand_colors.dart';
import '../../config/verify_endpoint.dart';
import '../../models/applicant.dart';
import '../../services/export_service.dart';
import '../../shared/widgets/adaptive_layout.dart';
import '../../shared/widgets/animations.dart';
import '../../shared/widgets/ornament_background.dart';
import 'id_card_view.dart';
import 'qr_presenter.dart';

/// Where this card came from, which decides the page's framing and closing
/// action: a card you just issued, or someone else's card you just scanned.
enum IdResultMode { issued, scanned }

/// Final screen: the identity card opened out — both faces held in a single
/// object, so every detail is readable at once with nothing to flip.
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
    with SingleTickerProviderStateMixin {
  late final AnimationController _reveal;

  /// The string drawn into the QR: a link that rebuilds this exact card.
  late final String _qrData;

  @override
  void initState() {
    super.initState();
    _qrData = ExportService.cardLinkFor(
      applicant: widget.applicant,
      personalId: widget.personalId,
      issuedAt: widget.issuedAt,
    );
    _reveal = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
  }

  @override
  void dispose() {
    _reveal.dispose();
    super.dispose();
  }

  /// Blows the QR up to fill the screen — the size a camera needs.
  void _presentQr() {
    QrPresenterPage.open(
      context,
      data: _qrData,
      personalId: widget.personalId,
      hosted: kHasHostedVerifier,
    );
  }

  @override
  Widget build(BuildContext context) {
    final band = Adaptive.bandOf(context);
    final size = MediaQuery.sizeOf(context);
    final base = switch (band) {
      ScreenBand.compact => 340.0,
      ScreenBand.medium => 460.0,
      ScreenBand.expanded => 520.0,
      ScreenBand.television => 600.0,
    };
    // Both faces always stack, on every screen. Sitting them side by side saved
    // vertical space but cost each face half the width, and on a tablet the
    // pair ran wider than the column that held them — so one face ended up
    // tucked behind the other instead of beside it. Stacked, every face gets
    // the full width at every size and nothing can hide anything else.
    final available =
        math.min(size.width - band.gutter * 2, band.contentWidth);
    final cardWidth = math.min(base, available).clamp(240.0, 620.0);

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
                      _CardSpread(
                        reveal: _reveal,
                        cardWidth: cardWidth,
                        applicant: widget.applicant,
                        personalId: widget.personalId,
                        issuedAt: widget.issuedAt,
                        onTap: _presentQr,
                      ),
                      SizedBox(height: band.isCompact ? 20 : 24),
                      _QrModule(
                        reveal: _reveal,
                        cardWidth: cardWidth,
                        personalId: widget.personalId,
                        qrData: _qrData,
                        onPresent: _presentQr,
                      ),
                      const SizedBox(height: 14),
                      _SpreadControls(onPresent: _presentQr),
                      const SizedBox(height: 32),
                      Center(
                        child: OutlinedButton.icon(
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
          _SuccessBadge(
            icon: issued ? Icons.check_rounded : Icons.verified_rounded,
          ),
          const SizedBox(height: 18),
          Text(
            issued ? 'بطاقتك جاهزة' : 'تمت قراءة البطاقة',
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
                ? 'تم إصدار بطاقتك بنجاح. الوجهان معًا في بطاقة واحدة، ورمز التحقق أسفلها.'
                : 'تمت قراءة بيانات البطاقة ومعاينتها بنجاح.',
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
                const SnackBar(content: Text('تم نسخ رقم الانتساب.')),
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

// ------------------------------------------------------------- البطاقة المفتوحة

/// The card, opened out.
///
/// Both faces live inside a single shell — one radius, one gold edge, one
/// shadow — joined by a gold fold seam instead of being flipped between. They
/// always stack, at every screen size, so neither face can ever end up behind
/// the other. The faces themselves are the untouched [IdCardView] /
/// [IdCardBack] artwork, so the card stays identical to the exported and web
/// versions — only the way it is presented changed.
class _CardSpread extends StatelessWidget {
  const _CardSpread({
    required this.reveal,
    required this.cardWidth,
    required this.applicant,
    required this.personalId,
    required this.issuedAt,
    required this.onTap,
  });

  final Animation<double> reveal;
  final double cardWidth;
  final Applicant applicant;
  final String personalId;
  final DateTime issuedAt;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = Radius.circular(cardWidth * 0.045);
    final height = cardWidth * 0.625;
    final shell = BorderRadius.all(radius);

    // Outer corners keep the card's own curve; the corners that meet at the
    // seam are squared off so the two faces read as one continuous surface.
    final front = IdCardView(
      applicant: applicant,
      personalId: personalId,
      issuedAt: issuedAt,
      cardWidth: cardWidth,
      elevated: false,
      corners: BorderRadius.vertical(top: radius),
    );
    final back = IdCardBack(
      applicant: applicant,
      personalId: personalId,
      issuedAt: issuedAt,
      cardWidth: cardWidth,
      elevated: false,
      bordered: false,
      corners: BorderRadius.vertical(bottom: radius),
    );

    return Center(
      child: Semantics(
        button: true,
        label: 'البطاقة — الوجه الأمامي والخلفي، اضغط لتكبير رمز التحقق',
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: _RevealTransition(
            reveal: reveal,
            child: SizedBox(
              width: cardWidth,
              height: height * 2,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: shell,
                  boxShadow: [
                    BoxShadow(
                      color: BrandColors.pine.withValues(alpha: 0.28),
                      blurRadius: 40,
                      spreadRadius: -8,
                      offset: const Offset(0, 20),
                    ),
                    BoxShadow(
                      color: BrandColors.gold.withValues(alpha: 0.18),
                      blurRadius: 16,
                      spreadRadius: -4,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(borderRadius: shell),
                  foregroundDecoration: BoxDecoration(
                    borderRadius: shell,
                    border: Border.all(color: BrandColors.gold, width: 1.4),
                  ),
                  child: Stack(
                    children: [
                      Column(children: [front, back]),
                      Positioned.fill(
                        child: _FoldSeam(
                          reveal: reveal,
                          cardWidth: cardWidth,
                        ),
                      ),
                      Positioned.fill(
                        child: _Sheen(reveal: reveal, width: cardWidth),
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
}

/// The verification code, standing on its own under the card.
///
/// Keeping it off the card is what lets it be this big: the tile is sized for
/// a camera at arm's length rather than for a corner of a printed face, and it
/// arrives a beat after the card so the eye lands on the document first.
class _QrModule extends StatelessWidget {
  const _QrModule({
    required this.reveal,
    required this.cardWidth,
    required this.personalId,
    required this.qrData,
    required this.onPresent,
  });

  final Animation<double> reveal;
  final double cardWidth;
  final String personalId;
  final String qrData;
  final VoidCallback onPresent;

  @override
  Widget build(BuildContext context) {
    final rise = CurvedAnimation(
      parent: reveal,
      curve: const Interval(0.45, 1, curve: Curves.easeOutCubic),
    );

    return Center(
      child: AnimatedBuilder(
        animation: rise,
        child: IdCardQrPanel(
          personalId: personalId,
          qrData: qrData,
          cardWidth: cardWidth,
          onTap: onPresent,
        ),
        builder: (context, child) {
          final t = rise.value.clamp(0.0, 1.0);
          return Opacity(
            opacity: t,
            child: Transform.translate(
              offset: Offset(0, 18 * (1 - t)),
              child: child,
            ),
          );
        },
      ),
    );
  }
}

/// The card settles into place once: it rises, scales up and fades in.
class _RevealTransition extends StatelessWidget {
  const _RevealTransition({required this.reveal, required this.child});

  final Animation<double> reveal;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final settle = CurvedAnimation(
      parent: reveal,
      curve: const Interval(0, 0.75, curve: Curves.easeOutCubic),
    );

    return AnimatedBuilder(
      animation: settle,
      child: child,
      builder: (context, child) {
        final t = settle.value.clamp(0.0, 1.0);
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, 26 * (1 - t)),
            child: Transform.scale(scale: 0.94 + 0.06 * t, alignment: Alignment.center, child: child),
          ),
        );
      },
    );
  }
}

/// The join between the two faces: a gold hairline that draws itself out from
/// the middle across the fold, finished with the brand lozenge sitting astride
/// it.
class _FoldSeam extends StatelessWidget {
  const _FoldSeam({required this.reveal, required this.cardWidth});

  final Animation<double> reveal;
  final double cardWidth;

  @override
  Widget build(BuildContext context) {
    final line = CurvedAnimation(
      parent: reveal,
      curve: const Interval(0.35, 0.9, curve: Curves.easeOutCubic),
    );
    final mark = CurvedAnimation(
      parent: reveal,
      curve: const Interval(0.6, 1, curve: Curves.easeOutBack),
    );
    final markSize = cardWidth * 0.055;

    return IgnorePointer(
      child: AnimatedBuilder(
        animation: reveal,
        builder: (context, _) {
          final grow = line.value.clamp(0.0, 1.0);
          final pop = mark.value.clamp(0.0, 1.4);

          // The lozenge covers the middle of the rule, so the gold has to hold
          // its strength well out towards the edges or the seam disappears.
          final rule = Transform.scale(
            scaleX: grow,
            child: Container(
              width: double.infinity,
              height: 1.4,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  stops: const [0, 0.12, 0.88, 1],
                  colors: [
                    BrandColors.gold.withValues(alpha: 0.35),
                    BrandColors.gold,
                    BrandColors.gold,
                    BrandColors.gold.withValues(alpha: 0.35),
                  ],
                ),
              ),
            ),
          );

          return Stack(
            alignment: Alignment.center,
            children: [
              Center(
                child: SizedBox(
                  width: double.infinity,
                  height: markSize,
                  child: Center(child: rule),
                ),
              ),
              Transform.scale(
                scale: pop,
                child: Transform.rotate(
                  angle: math.pi / 4,
                  child: Container(
                    width: markSize,
                    height: markSize,
                    padding: EdgeInsets.all(markSize * 0.22),
                    decoration: BoxDecoration(
                      gradient: BrandGradients.gold,
                      borderRadius: BorderRadius.circular(markSize * 0.1),
                      border: Border.all(
                        color: BrandColors.goldDeep.withValues(alpha: 0.55),
                        width: 0.8,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: BrandColors.pineDeep.withValues(alpha: 0.28),
                          blurRadius: 7,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    // A pine core inside the gold lozenge — the same figure the
                    // ornament lattice repeats across the backdrop.
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: BrandColors.pine.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(markSize * 0.05),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// A single pass of light across the card as it appears — the glint you get
/// tilting a laminated card under a lamp. Plays once, then stays out of view.
class _Sheen extends StatelessWidget {
  const _Sheen({required this.reveal, required this.width});

  final Animation<double> reveal;
  final double width;

  @override
  Widget build(BuildContext context) {
    final sweep = CurvedAnimation(
      parent: reveal,
      curve: const Interval(0.25, 1, curve: Curves.easeInOutCubic),
    );

    return IgnorePointer(
      child: AnimatedBuilder(
        animation: sweep,
        builder: (context, _) {
          final t = sweep.value.clamp(0.0, 1.0);
          if (t == 0 || t == 1) return const SizedBox.shrink();
          final band = width * 0.4;
          return Transform.translate(
            offset: Offset(-width - band + (width * 2 + band * 2) * t, 0),
            child: Transform.rotate(
              angle: -0.28,
              child: Container(
                width: band,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0),
                      Colors.white.withValues(alpha: 0.16),
                      Colors.white.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Everything under the QR module. Nothing here switches faces — both are
/// already on screen — so the only action left is blowing the code up to full
/// screen, the one size a shared surface cannot hold on its own.
class _SpreadControls extends StatelessWidget {
  const _SpreadControls({required this.onPresent});

  final VoidCallback onPresent;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextButton.icon(
          onPressed: onPresent,
          icon: const Icon(Icons.fullscreen_rounded, size: 18),
          label: const Text('تكبير رمز التحقق'),
        ),
        const SizedBox(height: 2),
        Text(
          'اضغط على الرمز لعرضه بملء الشاشة عند التحقق',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: BrandColors.inkMuted,
              ),
        ),
      ],
    );
  }
}
