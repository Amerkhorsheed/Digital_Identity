import 'package:flutter/material.dart';

import '../../../app/theme/brand_colors.dart';
import '../../../models/applicant.dart';
import '../../../models/vision_test.dart';
import '../../../shared/widgets/adaptive_layout.dart';
import '../../../shared/widgets/brand_widgets.dart';
import '../../../shared/widgets/step_fields.dart';
import '../../eyetest/eye_test_page.dart';
import '../registration_page.dart';
import '../widgets/step_layout.dart';

/// Step 2 — health profile: body measurements (sliders), blood type and the eye test.
class HealthStep extends StatefulWidget {
  const HealthStep({
    super.key,
    required this.draft,
    required this.errors,
    required this.onChanged,
  });

  final ApplicantDraft draft;
  final Map<String, String> errors;
  final VoidCallback onChanged;

  @override
  State<HealthStep> createState() => _HealthStepState();
}

class _HealthStepState extends State<HealthStep> {
  bool _manualEntry = false;

  void _update(VoidCallback apply) {
    apply();
    widget.onChanged();
  }

  Future<void> _runEyeTest() async {
    final report = await EyeTestPage.show(context);
    if (report == null || !mounted) return;
    _update(() {
      widget.draft.visionTest = report;
      widget.draft.rightEyeAcuity = report.right.acuity;
      widget.draft.leftEyeAcuity = report.left.acuity;
      _manualEntry = false;
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        const SnackBar(content: Text('تم تسجيل نتيجة فحص النظر بنجاح.')),
      );
  }

  @override
  Widget build(BuildContext context) {
    final draft = widget.draft;
    final hasResult =
        draft.rightEyeAcuity != null && draft.leftEyeAcuity != null;

    final currentHeight = draft.heightCm ?? 172;
    final currentWeight = draft.weightKg ?? 68.0;

    return StepLayout(
      hero: const StepHero(
        number: 2,
        icon: Icons.favorite_outline_rounded,
        title: 'الملف الصحي',
        subtitle: 'حدد قياساتك الجسمية، فصيلة دمك، وفحص حدة الإبصار.',
      ),
      children: [
        FormGrid(
          children: [
            FormGridSpan(
              child: _MeasurementSlider(
                label: 'الطول',
                unit: 'سم',
                icon: Icons.height_rounded,
                value: currentHeight.toDouble(),
                min: 120,
                max: 220,
                divisions: 100,
                formattedValue: '$currentHeight سم',
                error: widget.errors['height'],
                onChanged: (val) => _update(() => draft.heightCm = val.round()),
              ),
            ),
            FormGridSpan(
              child: _MeasurementSlider(
                label: 'الوزن',
                unit: 'كجم',
                icon: Icons.monitor_weight_outlined,
                value: currentWeight,
                min: 40.0,
                max: 160.0,
                divisions: 240,
                formattedValue: '${currentWeight.toStringAsFixed(1)} كجم',
                error: widget.errors['weight'],
                onChanged: (val) => _update(() {
                  // Round to 1 decimal place.
                  draft.weightKg = (val * 2).round() / 2.0;
                }),
              ),
            ),
            FormGridSpan(
              child: BrandDropdown<BloodType>(
                label: 'فصيلة الدم',
                value: draft.bloodType,
                items: BloodType.values,
                labelFor: (type) => type.label,
                icon: Icons.bloodtype_outlined,
                error: widget.errors['bloodType'],
                onChanged: (value) => _update(() => draft.bloodType = value),
              ),
            ),
            FormGridSpan(
              child: _EyeTestPanel(
                report: draft.visionTest,
                rightEye: draft.rightEyeAcuity,
                leftEye: draft.leftEyeAcuity,
                error: widget.errors['vision'],
                manualEntry: _manualEntry,
                hasResult: hasResult,
                onStartTest: _runEyeTest,
                onToggleManual: () =>
                    setState(() => _manualEntry = !_manualEntry),
                onRightChanged: (value) => _update(() {
                  draft.rightEyeAcuity = value;
                  draft.visionTest = null;
                }),
                onLeftChanged: (value) => _update(() {
                  draft.leftEyeAcuity = value;
                  draft.visionTest = null;
                }),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// A luxury interactive slider with live badge and quick adjustment buttons.
class _MeasurementSlider extends StatelessWidget {
  const _MeasurementSlider({
    required this.label,
    required this.unit,
    required this.icon,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.formattedValue,
    required this.onChanged,
    this.error,
  });

  final String label;
  final String unit;
  final IconData icon;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String formattedValue;
  final ValueChanged<double> onChanged;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final clamped = value.clamp(min, max);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: BrandColors.surface,
        borderRadius: BorderRadius.circular(BrandRadii.medium),
        border: Border.all(
          color: error != null
              ? BrandColors.error
              : BrandColors.outlineSoft,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: BrandColors.pine.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 22, color: BrandColors.pine),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: BrandColors.ink,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                decoration: BoxDecoration(
                  gradient: BrandGradients.gold,
                  borderRadius: BorderRadius.circular(BrandRadii.pill),
                  boxShadow: [
                    BoxShadow(
                      color: BrandColors.gold.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  formattedValue,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.remove_circle_outline_rounded,
                    color: BrandColors.pine),
                onPressed: clamped > min
                    ? () {
                        final step = (max - min) / divisions;
                        onChanged((clamped - step).clamp(min, max));
                      }
                    : null,
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: BrandColors.pine,
                    inactiveTrackColor: BrandColors.outlineSoft,
                    thumbColor: BrandColors.goldDeep,
                    overlayColor: BrandColors.gold.withValues(alpha: 0.15),
                    trackHeight: 6.0,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 11.0,
                      elevation: 3,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 22.0,
                    ),
                  ),
                  child: Slider(
                    value: clamped,
                    min: min,
                    max: max,
                    divisions: divisions,
                    onChanged: onChanged,
                  ),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.add_circle_outline_rounded,
                    color: BrandColors.pine),
                onPressed: clamped < max
                    ? () {
                        final step = (max - min) / divisions;
                        onChanged((clamped + step).clamp(min, max));
                      }
                    : null,
              ),
            ],
          ),
          if (error != null) ...[
            const SizedBox(height: 4),
            Text(
              error!,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: BrandColors.error,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The eye-test block: launches the interactive Snellen chart, shows the
/// measured result, and keeps a manual fallback for users who already hold a
/// report from an optometrist.
class _EyeTestPanel extends StatelessWidget {
  const _EyeTestPanel({
    required this.report,
    required this.rightEye,
    required this.leftEye,
    required this.error,
    required this.manualEntry,
    required this.hasResult,
    required this.onStartTest,
    required this.onToggleManual,
    required this.onRightChanged,
    required this.onLeftChanged,
  });

  final VisionTestReport? report;
  final VisualAcuity? rightEye;
  final VisualAcuity? leftEye;
  final String? error;
  final bool manualEntry;
  final bool hasResult;
  final VoidCallback onStartTest;
  final VoidCallback onToggleManual;
  final ValueChanged<VisualAcuity?> onRightChanged;
  final ValueChanged<VisualAcuity?> onLeftChanged;

  @override
  Widget build(BuildContext context) {
    final band = Adaptive.bandOf(context);

    return Container(
      padding: EdgeInsets.all(band.isCompact ? 18 : 22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            BrandColors.goldMist,
            BrandColors.surface,
          ],
        ),
        borderRadius: BorderRadius.circular(BrandRadii.large),
        border: Border.all(
          color: error != null ? BrandColors.error : BrandColors.goldSoft,
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: BrandColors.gold.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: BrandColors.pine.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(BrandRadii.medium),
                ),
                child: const Icon(
                  Icons.remove_red_eye_outlined,
                  color: BrandColors.pine,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'فحص حدة الإبصار التفاعلي',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: BrandColors.pine,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'اختبار حقيقي للعينين بجدول سنيلن المعياري',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: BrandColors.inkMuted,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (hasResult && !manualEntry)
            _EyeTestResultCard(
              report: report,
              rightEye: rightEye!,
              leftEye: leftEye!,
              onRetest: onStartTest,
            )
          else if (!manualEntry)
            _StartTestPrompt(onStart: onStartTest),
          if (manualEntry) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: BrandDropdown<VisualAcuity>(
                    label: 'العين اليمنى — حدة الإبصار',
                    value: rightEye,
                    items: VisualAcuity.values,
                    labelFor: (acuity) => acuity.label,
                    icon: Icons.remove_red_eye_rounded,
                    onChanged: onRightChanged,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: BrandDropdown<VisualAcuity>(
                    label: 'العين اليسرى — حدة الإبصار',
                    value: leftEye,
                    items: VisualAcuity.values,
                    labelFor: (acuity) => acuity.label,
                    icon: Icons.remove_red_eye_outlined,
                    onChanged: onLeftChanged,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: onToggleManual,
              icon: Icon(
                manualEntry
                    ? Icons.videocam_outlined
                    : Icons.description_outlined,
                size: 18,
              ),
              label: Text(
                manualEntry
                    ? 'العودة إلى الفحص التفاعلي'
                    : 'لديّ تقرير طبي جاهز (إدخال يدوي)',
              ),
              style: TextButton.styleFrom(
                foregroundColor: BrandColors.ink,
                textStyle: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: 6),
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
      ),
    );
  }
}

class _StartTestPrompt extends StatelessWidget {
  const _StartTestPrompt({required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(BrandRadii.medium),
        border: Border.all(color: BrandColors.goldSoft),
      ),
      child: Column(
        children: [
          const Text(
            'فحص سريع ومباشر (٥ محاولات فقط) بالعينين معاً لتحديد حدة الإبصار.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              color: BrandColors.inkMuted,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          BrandButton(
            label: 'بدء فحص النظر السريع الآن',
            icon: Icons.play_arrow_rounded,
            onPressed: onStart,
          ),
        ],
      ),
    );
  }
}

class _EyeTestResultCard extends StatelessWidget {
  const _EyeTestResultCard({
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
    final isUnified = rightEye == leftEye;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(BrandRadii.medium),
        border: Border.all(color: BrandColors.goldSoft),
      ),
      child: Column(
        children: [
          if (isUnified)
            _EyeScorePill(
              title: 'حدة الإبصار (بالعينين معاً)',
              score: rightEye.label,
              icon: Icons.visibility_rounded,
            )
          else
            Row(
              children: [
                Expanded(
                  child: _EyeScorePill(
                    title: 'العين اليمنى',
                    score: rightEye.label,
                    icon: Icons.remove_red_eye_rounded,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _EyeScorePill(
                    title: 'العين اليسرى',
                    score: leftEye.label,
                    icon: Icons.remove_red_eye_outlined,
                  ),
                ),
              ],
            ),
          if (report != null) ...[
            const SizedBox(height: 10),
            Text(
              'أُجري الفحص السريع تفاعلياً (٥ فحوصات معيارية)',
              style: const TextStyle(
                fontSize: 12,
                color: BrandColors.inkMuted,
              ),
            ),
          ],
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRetest,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('إعادة فحص النظر'),
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

class _EyeScorePill extends StatelessWidget {
  const _EyeScorePill({
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: BrandColors.goldMist,
        borderRadius: BorderRadius.circular(BrandRadii.medium),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: BrandColors.pine),
              const SizedBox(width: 6),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: BrandColors.pine,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            score,
            style: const TextStyle(
              fontSize: 18,
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
