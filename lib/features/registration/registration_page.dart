import 'package:flutter/material.dart';

import '../../app/theme/brand_colors.dart';
import '../../data/syria_places.dart';
import '../../models/applicant.dart';
import '../../models/vision_test.dart';
import '../../services/id_engine.dart';
import '../../services/id_record_store.dart';
import '../../shared/widgets/adaptive_layout.dart';
import '../../shared/widgets/animations.dart';
import '../../shared/widgets/brand_widgets.dart';
import '../../shared/widgets/ornament_background.dart';
import '../idcard/id_result_page.dart';
import '../verify/scan_card_page.dart';
import 'steps/health_step.dart';
import 'steps/identity_step.dart';
import 'steps/photo_step.dart';
import 'widgets/flow_header.dart';

/// Mutable draft of the applicant being registered. Each step edits the draft
/// in place and notifies the page so validation can re-run live.
class ApplicantDraft {
  String firstName = '';
  String lastName = '';
  AcademicYear? academicYear;
  UndergraduateDegree? degree;
  String? customDegree;
  String? governorate;
  String? city;
  String? customCity;
  int? heightCm;
  double? weightKg;
  BloodType? bloodType;
  VisualAcuity? rightEyeAcuity;
  VisualAcuity? leftEyeAcuity;
  VisionCorrection? visionCorrection;
  VisionTestReport? visionTest;
  String? photoPath;

  bool get hasPhoto => photoPath != null && photoPath!.isNotEmpty;

  /// The city as it will be printed on the card.
  String get resolvedCity =>
      city == kOtherPlace ? (customCity?.trim() ?? '') : (city ?? '');
}

/// The three-step registration journey. The header (brand + stepper) stays
/// pinned to the top of the screen while the content slides between steps.
class RegistrationPage extends StatefulWidget {
  const RegistrationPage({super.key, required this.store});

  final IdRecordStore store;

  @override
  State<RegistrationPage> createState() => _RegistrationPageState();
}

class _RegistrationPageState extends State<RegistrationPage> {
  static const int _stepCount = 3;
  static const List<String> _stepTitles = ['الهوية', 'الصحة', 'الصورة'];

  PageController _pageController = PageController();
  ApplicantDraft _draft = ApplicantDraft();

  /// Bumped on every fresh registration so the step widgets — and the text
  /// controllers they own — are rebuilt from scratch rather than reused.
  int _session = 0;

  int _step = 0;
  bool _generating = false;
  bool _showErrors = false;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  /// Clears the whole journey and returns to step one.
  void _startNewRegistration() {
    _pageController.dispose();
    setState(() {
      _pageController = PageController();
      _draft = ApplicantDraft();
      _session++;
      _step = 0;
      _showErrors = false;
      _generating = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final errors = _computeErrors(_step);
    final canGoBack = _step > 0 && !_generating;
    final canContinue = !_generating && errors.isEmpty;

    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _step > 0) _goBack();
      },
      child: Scaffold(
        // The action bar handles its own inset, so the body is not resized
        // out from under the form when the keyboard appears.
        resizeToAvoidBottomInset: true,
        body: OrnamentBackground(
          child: Column(
            children: [
              FlowHeader(
                currentStep: _step,
                totalSteps: _stepCount,
                stepTitles: _stepTitles,
                onScan: () =>
                    ScanCardPage.open(context, store: widget.store),
              ),
              Expanded(
                child: PageView(
                  key: ValueKey('registration-$_session'),
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (page) => setState(() {
                    _step = page;
                    _showErrors = false;
                  }),
                  children: [
                    IdentityStep(
                      draft: _draft,
                      errors: _visibleErrors(0),
                      onChanged: _refresh,
                    ),
                    HealthStep(
                      draft: _draft,
                      errors: _visibleErrors(1),
                      onChanged: _refresh,
                    ),
                    PhotoStep(
                      draft: _draft,
                      errors: _visibleErrors(2),
                      onChanged: _refresh,
                    ),
                  ],
                ),
              ),
              _ActionBar(
                step: _step,
                stepCount: _stepCount,
                generating: _generating,
                canGoBack: canGoBack,
                canContinue: canContinue,
                blockedReason: _showErrors || errors.isEmpty
                    ? null
                    : 'أكمل الحقول المطلوبة للمتابعة',
                onBack: _goBack,
                onContinue: _step == _stepCount - 1 ? _issueCard : _goForward,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Errors are computed live but only *shown* after the user tries to move
  /// on, so a pristine form never greets the user in red.
  Map<String, String> _visibleErrors(int step) =>
      _showErrors && step == _step ? _computeErrors(step) : const {};

  Map<String, String> _computeErrors(int step) {
    final errors = <String, String>{};
    final draft = _draft;
    switch (step) {
      case 0:
        if (draft.firstName.trim().length < 2) {
          errors['firstName'] = 'حرفان على الأقل';
        }
        if (draft.lastName.trim().length < 2) {
          errors['lastName'] = 'حرفان على الأقل';
        }
        if (draft.academicYear == null) {
          errors['academicYear'] = 'مطلوب';
        }
        if (draft.degree == null) {
          errors['degree'] = 'مطلوب';
        }
        if (draft.degree == UndergraduateDegree.other &&
            (draft.customDegree == null ||
                draft.customDegree!.trim().isEmpty)) {
          errors['customDegree'] = 'مطلوب';
        }
        if (draft.governorate == null) {
          errors['governorate'] = 'مطلوب';
        }
        if (draft.city == null || draft.city!.isEmpty) {
          errors['city'] = 'مطلوب';
        }
        if (draft.city == kOtherPlace && draft.resolvedCity.isEmpty) {
          errors['customCity'] = 'مطلوب';
        }
      case 1:
        if (draft.heightCm == null ||
            draft.heightCm! < 100 ||
            draft.heightCm! > 250) {
          errors['height'] = 'بين 100 و250 سم';
        }
        if (draft.weightKg == null ||
            draft.weightKg! < 30 ||
            draft.weightKg! > 250) {
          errors['weight'] = 'بين 30 و250 كجم';
        }
        if (draft.bloodType == null) {
          errors['bloodType'] = 'مطلوب';
        }
        if (draft.visionCorrection == null) {
          errors['correction'] = 'مطلوب';
        }
        if (draft.rightEyeAcuity == null || draft.leftEyeAcuity == null) {
          errors['vision'] = 'أجرِ فحص النظر أو أدخل نتيجة تقريرك الطبي';
        }
      case 2:
        if (!draft.hasPhoto) {
          errors['photo'] = 'الصورة مطلوبة لإصدار بطاقة الهوية';
        }
    }
    return errors;
  }

  void _goForward() {
    if (_computeErrors(_step).isNotEmpty) {
      setState(() => _showErrors = true);
      return;
    }
    setState(() => _showErrors = false);
    FocusScope.of(context).unfocus();
    _pageController.nextPage(
      duration: BrandDurations.slow,
      curve: Curves.easeOutCubic,
    );
  }

  void _goBack() {
    setState(() => _showErrors = false);
    FocusScope.of(context).unfocus();
    _pageController.previousPage(
      duration: BrandDurations.slow,
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _issueCard() async {
    if (_computeErrors(_step).isNotEmpty) {
      setState(() => _showErrors = true);
      return;
    }

    setState(() => _generating = true);
    final draft = _draft;
    final applicant = Applicant(
      firstName: draft.firstName.trim(),
      lastName: draft.lastName.trim(),
      academicYear: draft.academicYear!,
      degree: draft.degree!,
      customDegree: draft.degree == UndergraduateDegree.other
          ? draft.customDegree?.trim()
          : null,
      governorate: draft.governorate!,
      city: draft.resolvedCity,
      heightCm: draft.heightCm!,
      weightKg: draft.weightKg!,
      bloodType: draft.bloodType!,
      rightEyeAcuity: draft.rightEyeAcuity!,
      leftEyeAcuity: draft.leftEyeAcuity!,
      visionCorrection: draft.visionCorrection!,
      visionTest: draft.visionTest,
      photoPath: draft.photoPath,
    );

    try {
      final issuedAt = DateTime.now().toUtc();
      final personalId = await IdEngine.createPersonalId(applicant, issuedAt);
      final qrPayload = IdEngine.buildQrPayload(applicant, personalId, issuedAt);

      await widget.store.insert(
        id: personalId,
        payload: qrPayload,
        photoPath: applicant.photoPath,
        issuedAt: issuedAt,
      );

      if (!mounted) return;
      setState(() => _generating = false);

      final restart = await Navigator.of(context).push<bool>(
        PageRouteBuilder<bool>(
          pageBuilder: (context, animation, secondary) => IdResultPage(
            applicant: applicant,
            personalId: personalId,
            issuedAt: issuedAt,
          ),
          transitionsBuilder: (context, animation, secondary, child) {
            return FadeTransition(
              opacity: CurvedAnimation(parent: animation, curve: Curves.easeIn),
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 460),
        ),
      );

      if (!mounted) return;
      if (restart ?? false) _startNewRegistration();
    } catch (_) {
      if (!mounted) return;
      setState(() => _generating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذّر إصدار البطاقة. حاول مرة أخرى.'),
        ),
      );
    }
  }
}

/// Bottom action bar: back + primary action, pinned above the safe area.
class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.step,
    required this.stepCount,
    required this.generating,
    required this.canGoBack,
    required this.canContinue,
    required this.blockedReason,
    required this.onBack,
    required this.onContinue,
  });

  final int step;
  final int stepCount;
  final bool generating;
  final bool canGoBack;
  final bool canContinue;
  final String? blockedReason;
  final VoidCallback onBack;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final band = Adaptive.bandOf(context);
    final isLast = step == stepCount - 1;

    return Container(
      decoration: BoxDecoration(
        color: BrandColors.surface,
        border: const Border(top: BorderSide(color: BrandColors.outlineSoft)),
        boxShadow: [
          BoxShadow(
            color: BrandColors.pine.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: ResponsiveShell(
          // A primary button stretched across a TV reads as a banner, not a
          // button — cap it and keep it centred.
          maxWidth: band.isCompact ? double.infinity : 720,
          padding: EdgeInsets.symmetric(
            horizontal: band.gutter,
            vertical: 12,
          ),
          child: Row(
            children: [
              if (canGoBack) ...[
                IconButton.filledTonal(
                  onPressed: onBack,
                  tooltip: 'رجوع',
                  style: IconButton.styleFrom(
                    minimumSize: Size.square(52 * band.scale),
                    backgroundColor: BrandColors.ivoryDeep,
                    foregroundColor: BrandColors.pine,
                  ),
                  icon: const Icon(Icons.arrow_forward_rounded),
                ),
                SizedBox(width: 12 * band.scale),
              ],
              Expanded(
                child: generating
                    ? const Center(child: IssuingLoader(label: 'جارٍ الإصدار…'))
                    : Tooltip(
                        message: blockedReason ?? '',
                        triggerMode: blockedReason == null
                            ? TooltipTriggerMode.manual
                            : TooltipTriggerMode.tap,
                        child: BrandButton(
                          label: isLast ? 'إصدار بطاقة الهوية' : 'متابعة',
                          icon: isLast
                              ? Icons.badge_outlined
                              : Icons.arrow_back_rounded,
                          large: true,
                          muted: !canContinue,
                          onPressed: onContinue,
                        ),
                      ),
              ),
              if (canGoBack) ...[
                SizedBox(width: 12 * band.scale),
                SizedBox(width: 52 * band.scale),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Shared step hero: number badge, title and description above a card.
class StepHero extends StatelessWidget {
  const StepHero({
    super.key,
    required this.number,
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final int number;
  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final band = Adaptive.bandOf(context);
    final textTheme = Theme.of(context).textTheme;
    final badge = 52.0 * band.scale;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: badge,
          height: badge,
          decoration: BoxDecoration(
            gradient: BrandGradients.pine,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: BrandColors.pine.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Center(
            child: Icon(icon, color: BrandColors.goldGlow, size: badge * 0.5),
          ),
        ),
        SizedBox(width: 16 * band.scale),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'الخطوة $number من 3',
                style: textTheme.labelSmall?.copyWith(
                  color: BrandColors.goldDeep,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                title,
                style: textTheme.headlineSmall?.copyWith(
                  color: BrandColors.pine,
                  fontWeight: FontWeight.w700,
                  fontSize:
                      (textTheme.headlineSmall?.fontSize ?? 19) * band.scale,
                ),
              ),
              Text(
                subtitle,
                style: textTheme.bodySmall?.copyWith(
                  color: BrandColors.inkMuted,
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
