import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/theme/brand_colors.dart';
import '../../../shared/widgets/adaptive_layout.dart';
import '../registration_page.dart';

/// Step 0 — "مرحلة قطع الدور" / Reception & Turn Reservation stage.
///
/// Features a prominent stadium/oval ticket card displaying the reserved turn
/// (e.g. A-001), ticket regeneration with haptic feedback, and a clear "التالي" action.
class TurnStep extends StatefulWidget {
  const TurnStep({
    super.key,
    required this.draft,
    required this.onChanged,
    required this.onNext,
  });

  final ApplicantDraft draft;
  final VoidCallback onChanged;
  final VoidCallback onNext;

  @override
  State<TurnStep> createState() => _TurnStepState();
}

class _TurnStepState extends State<TurnStep>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _generateNewTurn() {
    HapticFeedback.mediumImpact();
    _pulseController.forward().then((_) => _pulseController.reverse());

    // Generate next sequential or salted turn code (e.g. A-001, A-002, ...)
    final currentStr = widget.draft.turnNumber.replaceAll(RegExp(r'[^0-9]'), '');
    final currentNum = int.tryParse(currentStr) ?? 1;
    final nextNum = currentNum >= 999 ? 1 : currentNum + 1;
    final nextCode = 'A-${nextNum.toString().padLeft(3, '0')}';

    setState(() {
      widget.draft.turnNumber = nextCode;
    });
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final band = Adaptive.bandOf(context);
    final scale = band.scale;

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: band.gutter,
        vertical: 24 * scale,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              // Stage badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: BrandColors.goldMist,
                  borderRadius: BorderRadius.circular(BrandRadii.pill),
                ),
                child: const Text(
                  'المرحلة الأولى',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: BrandColors.goldDeep,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Main title
              const Text(
                'مرحلة قطع الدور',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: BrandColors.pine,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 8),
              // Subtitle instruction
              const Text(
                'اضغط الزر أدناه للحصول على رقم دور جديد',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w500,
                  color: BrandColors.inkMuted,
                ),
              ),
              const SizedBox(height: 38),
              // The Stadium / Oval Ticket Card
              ScaleTransition(
                scale: _scaleAnimation,
                child: GestureDetector(
                  onTap: _generateNewTurn,
                  child: Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(
                      minHeight: 180,
                      maxWidth: 380,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 28,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAFAF7),
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(
                        color: const Color(0xFFC7B282),
                        width: 1.8,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: BrandColors.gold.withValues(alpha: 0.15),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'رقم دورك',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF8A774E),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.draft.turnNumber,
                          style: const TextStyle(
                            fontSize: 54,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2.0,
                            color: BrandColors.pine,
                            fontFamily: 'SpaceMono',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              // Secondary action to draw new turn
              TextButton.icon(
                onPressed: _generateNewTurn,
                icon: const Icon(Icons.sync_rounded, size: 18),
                label: const Text('سحب رقم دور جديد'),
                style: TextButton.styleFrom(
                  foregroundColor: BrandColors.goldDeep,
                  textStyle: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 36),
              // Primary "التالي" button
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380),
                child: SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: widget.onNext,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: BrandColors.pine,
                      foregroundColor: Colors.white,
                      elevation: 4,
                      shadowColor: BrandColors.pine.withValues(alpha: 0.4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(BrandRadii.pill),
                      ),
                    ),
                    child: const Text(
                      'التالي',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
