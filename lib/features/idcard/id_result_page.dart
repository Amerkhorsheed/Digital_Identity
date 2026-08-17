import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

/// Final screen: the identity card, flippable in 3D with full front and back details.
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
  /// 0 = front, 1 = back. Settles on a face and stays there.
  late final AnimationController _flip;
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
                ? 'تم إصدار بطاقتك بنجاح. يمكنك معاينة وجهي البطاقة ورمز QR.'
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
    flip.value =
        (flip.value - details.primaryDelta! / cardWidth).clamp(0.0, 1.0);
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
