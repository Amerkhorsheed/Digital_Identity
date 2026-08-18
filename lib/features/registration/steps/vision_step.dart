import 'package:flutter/material.dart';

import '../../../app/theme/brand_colors.dart';
import '../../../models/applicant.dart';
import '../../../models/vision_test.dart';
import '../../../shared/widgets/brand_widgets.dart';
import '../../eyetest/eye_test_page.dart';
import '../registration_page.dart';
import '../widgets/step_layout.dart';

/// Step 4 — the sight check, on a page of its own.
///
/// It used to share the health page with the body measurements, which put a
/// task that takes real concentration directly under a pair of sliders. On its
/// own page there is nothing else to look at while the chart is being read,
/// and the result has room to be shown properly once it comes back.
class VisionStep extends StatefulWidget {
  const VisionStep({
    super.key,
    required this.draft,
    required this.errors,
    required this.onChanged,
  });

  final ApplicantDraft draft;
  final Map<String, String> errors;
  final VoidCallback onChanged;

  @override
  State<VisionStep> createState() => _VisionStepState();
}

class _VisionStepState extends State<VisionStep> {
  Future<void> _runEyeTest() async {
    final report = await EyeTestPage.show(context);
    if (report == null || !mounted) return;
    widget.draft.visionTest = report;
    widget.draft.rightEyeAcuity = report.right.acuity;
    widget.draft.leftEyeAcuity = report.left.acuity;
    widget.onChanged();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        const SnackBar(
          content: Text('تم تسجيل نتيجة فحص النظر بنجاح.'),
          // The result is already on the panel behind this bar, so the message
          // is a confirmation and not something anyone stops to read — it
          // clears itself well before it starts feeling like it is in the way.
          duration: Duration(milliseconds: 1200),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final draft = widget.draft;
    final hasResult =
        draft.rightEyeAcuity != null && draft.leftEyeAcuity != null;
    final error = widget.errors['vision'];

    return StepLayout(
      hero: const StepHero(
        number: 3,
        icon: Icons.remove_red_eye_outlined,
        title: 'فحص النظر',
        subtitle: 'فحص تفاعلي سريع بالعينين معاً لقياس حدة الإبصار.',
      ),
      children: [
        _VisionPanel(
          report: draft.visionTest,
          rightEye: draft.rightEyeAcuity,
          leftEye: draft.leftEyeAcuity,
          error: error,
          hasResult: hasResult,
          onStartTest: _runEyeTest,
        ),
      ],
    );
  }
}

/// The sight-check block: launches the interactive chart and shows the measured
/// result. There is no manual fallback — the card records a measurement this
/// app made, so a number typed in from elsewhere has no place on it.
class _VisionPanel extends StatelessWidget {
  const _VisionPanel({
    required this.report,
    required this.rightEye,
    required this.leftEye,
    required this.error,
    required this.hasResult,
    required this.onStartTest,
  });

  final VisionTestReport? report;
  final VisualAcuity? rightEye;
  final VisualAcuity? leftEye;
  final String? error;
  final bool hasResult;
  final VoidCallback onStartTest;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hasResult)
          _ResultCard(
            report: report,
            rightEye: rightEye!,
            leftEye: leftEye!,
            onRetest: onStartTest,
          )
        else
          _StartPrompt(onStart: onStartTest, hasError: error != null),
        if (error != null) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.error_outline_rounded,
                  size: 16, color: BrandColors.error),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  error!,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: BrandColors.error,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _StartPrompt extends StatelessWidget {
  const _StartPrompt({required this.onStart, required this.hasError});

  final VoidCallback onStart;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 26, 20, 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [BrandColors.goldMist, BrandColors.surface],
        ),
        borderRadius: BorderRadius.circular(BrandRadii.large),
        border: Border.all(
          color: hasError ? BrandColors.error : BrandColors.goldSoft,
          width: 1.4,
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: BrandColors.pine.withValues(alpha: 0.07),
              shape: BoxShape.circle,
              border: Border.all(color: BrandColors.goldSoft, width: 1.6),
            ),
            child: const Icon(
              Icons.visibility_outlined,
              size: 38,
              color: BrandColors.pine,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'خمس محاولات فقط',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: BrandColors.pine,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'ستظهر لك خمسة أحرف بأحجام متدرّجة، وكل ما عليك تحديد اتجاه '
            'فتحة الحرف. أمسك الجهاز على مسافة ٤٠ سم تقريباً.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              color: BrandColors.inkMuted,
              height: 1.8,
            ),
          ),
          const SizedBox(height: 20),
          BrandButton(
            label: 'ابدأ الفحص الآن',
            icon: Icons.play_arrow_rounded,
            onPressed: onStart,
          ),
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({
    required this.report,
    required this.rightEye,
    required this.leftEye,
    required this.onRetest,
  });

  final VisionTestReport? report;
  final VisualAcuity rightEye;
  final VisualAcuity leftEye;
  final VoidCallback onRetest;

  @override
  Widget build(BuildContext context) {
    final unified = rightEye == leftEye;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [BrandColors.goldMist, BrandColors.surface],
        ),
        borderRadius: BorderRadius.circular(BrandRadii.large),
        border: Border.all(color: BrandColors.goldSoft, width: 1.4),
      ),
      child: Column(
        children: [
          if (unified)
            _ScorePill(
              title: 'حدة الإبصار (بالعينين معاً)',
              score: rightEye.label,
              icon: Icons.visibility_rounded,
            )
          else
            Row(
              children: [
                Expanded(
                  child: _ScorePill(
                    title: 'العين اليمنى',
                    score: rightEye.label,
                    icon: Icons.remove_red_eye_rounded,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ScorePill(
                    title: 'العين اليسرى',
                    score: leftEye.label,
                    icon: Icons.remove_red_eye_outlined,
                  ),
                ),
              ],
            ),
          if (report != null) ...[
            const SizedBox(height: 12),
            const Text(
              'أُجري الفحص تفاعلياً (٥ فحوصات معيارية)',
              style: TextStyle(fontSize: 12, color: BrandColors.inkMuted),
            ),
          ],
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onRetest,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('إعادة الفحص'),
            style: OutlinedButton.styleFrom(
              foregroundColor: BrandColors.pine,
              side: const BorderSide(color: BrandColors.goldSoft),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(BrandRadii.pill),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScorePill extends StatelessWidget {
  const _ScorePill({
    required this.title,
    required this.score,
    required this.icon,
  });

  final String title;
  final String score;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(BrandRadii.medium),
        border: Border.all(color: BrandColors.goldSoft),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: BrandColors.pine),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: BrandColors.pine,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            score,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: BrandColors.pine,
              fontFamily: 'SpaceMono',
            ),
          ),
        ],
      ),
    );
  }
}
