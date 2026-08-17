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

/// Step 2 — health profile: body measurements, blood type and the eye test.
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
  late final TextEditingController _height;
  late final TextEditingController _weight;

  bool _manualEntry = false;

  @override
  void initState() {
    super.initState();
    _height =
        TextEditingController(text: widget.draft.heightCm?.toString() ?? '');
    _weight = TextEditingController(
      text: widget.draft.weightKg?.toStringAsFixed(1) ?? '',
    );
  }

  @override
  void dispose() {
    _height.dispose();
    _weight.dispose();
    super.dispose();
  }

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

    return StepLayout(
      hero: const StepHero(
        number: 2,
        icon: Icons.favorite_outline_rounded,
        title: 'الملف الصحي',
        subtitle: 'القياسات الجسمية، فصيلة الدم، وفحص حقيقي لحدة الإبصار.',
      ),
      children: [
        FormGrid(
          children: [
            BrandNumberField(
              label: 'الطول',
              controller: _height,
              unit: 'سم',
              icon: Icons.height_rounded,
              error: widget.errors['height'],
              onChanged: (value) =>
                  _update(() => draft.heightCm = int.tryParse(value)),
            ),
            BrandNumberField(
              label: 'الوزن',
              controller: _weight,
              unit: 'كجم',
              icon: Icons.monitor_weight_outlined,
              allowDecimal: true,
              error: widget.errors['weight'],
              onChanged: (value) =>
                  _update(() => draft.weightKg = double.tryParse(value)),
            ),
            BrandDropdown<BloodType>(
              label: 'فصيلة الدم',
              value: draft.bloodType,
              items: BloodType.values,
              labelFor: (type) => type.label,
              icon: Icons.bloodtype_outlined,
              error: widget.errors['bloodType'],
              onChanged: (value) => _update(() => draft.bloodType = value),
            ),
            BrandDropdown<VisionCorrection>(
              label: 'تصحيح الإبصار',
              value: draft.visionCorrection,
              items: VisionCorrection.values,
              labelFor: (correction) => correction.label,
              icon: Icons.visibility_outlined,
              error: widget.errors['correction'],
              onChanged: (value) =>
                  _update(() => draft.visionCorrection = value),
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
          color: error != null
              ? BrandColors.error
              : BrandColors.gold.withValues(alpha: 0.45),
          width: error != null ? 1.4 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: BrandGradients.pine,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.remove_red_eye_rounded,
                  color: BrandColors.goldGlow,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'فحص حدة الإبصار',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: BrandColors.pine,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'لوحة E المتدحرج بخمسة أسطر متدرجة — نفس مبدأ لوحة العيادة، '
                      'بأحجام محسوبة بالمليمتر حسب مسافة الفحص.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: BrandColors.inkMuted,
                            height: 1.6,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (error != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  size: 16,
                  color: BrandColors.error,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    error!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: BrandColors.error,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 18),
          if (hasResult) ...[
            _AcuitySummary(
              rightEye: rightEye!,
              leftEye: leftEye!,
              report: report,
            ),
            const SizedBox(height: 16),
          ],
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: band.isCompact ? double.infinity : 260,
                child: BrandButton(
                  label: hasResult ? 'إعادة الفحص' : 'ابدأ فحص النظر',
                  icon: hasResult
                      ? Icons.replay_rounded
                      : Icons.play_circle_outline_rounded,
                  large: true,
                  onPressed: onStartTest,
                ),
              ),
              TextButton.icon(
                onPressed: onToggleManual,
                icon: Icon(
                  manualEntry
                      ? Icons.expand_less_rounded
                      : Icons.edit_note_rounded,
                  size: 18,
                ),
                label: Text(
                  manualEntry ? 'إخفاء الإدخال اليدوي' : 'لديّ تقرير طبي جاهز',
                ),
              ),
            ],
          ),
          AnimatedCrossFade(
            duration: BrandDurations.quick,
            crossFadeState: manualEntry
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.only(top: 18),
              child: FormGrid(
                children: [
                  BrandDropdown<VisualAcuity>(
                    label: 'العين اليمنى — حدة الإبصار',
                    value: rightEye,
                    items: VisualAcuity.values,
                    labelFor: (acuity) => acuity.label,
                    icon: Icons.remove_red_eye_outlined,
                    onChanged: onRightChanged,
                  ),
                  BrandDropdown<VisualAcuity>(
                    label: 'العين اليسرى — حدة الإبصار',
                    value: leftEye,
                    items: VisualAcuity.values,
                    labelFor: (acuity) => acuity.label,
                    icon: Icons.remove_red_eye_outlined,
                    onChanged: onLeftChanged,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AcuitySummary extends StatelessWidget {
  const _AcuitySummary({
    required this.rightEye,
    required this.leftEye,
    required this.report,
  });

  final VisualAcuity rightEye;
  final VisualAcuity leftEye;
  final VisionTestReport? report;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _AcuityTile(title: 'العين اليمنى', acuity: rightEye),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _AcuityTile(title: 'العين اليسرى', acuity: leftEye),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Icon(
              report != null
                  ? Icons.verified_rounded
                  : Icons.assignment_outlined,
              size: 15,
              color: report != null
                  ? BrandColors.success
                  : BrandColors.inkMuted,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                report?.methodLabel ?? 'مُدخل يدويًا من تقرير سابق',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: BrandColors.inkMuted,
                    ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _AcuityTile extends StatelessWidget {
  const _AcuityTile({required this.title, required this.acuity});

  final String title;
  final VisualAcuity acuity;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: BrandColors.surface,
        borderRadius: BorderRadius.circular(BrandRadii.medium),
        border: Border.all(color: BrandColors.outlineSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: BrandColors.inkMuted,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            acuity.label,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontFamily: 'SpaceMono',
                  color: BrandColors.goldDeep,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}
