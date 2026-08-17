import 'package:flutter/material.dart';

import '../../app/theme/brand_colors.dart';
import '../../models/applicant.dart';
import '../../models/biometric_capture.dart';
import '../../models/vision_test.dart';
import '../../services/biometric_service.dart';
import '../../services/id_engine.dart';
import '../../services/id_record_store.dart';
import '../../shared/widgets/adaptive_layout.dart';
import '../../shared/widgets/brand_widgets.dart';
import '../../shared/widgets/ornament_background.dart';
import '../idcard/id_result_page.dart';
import '../verify/scan_card_page.dart';
import 'steps/health_step.dart';
import 'steps/identity_step.dart';
import 'steps/photo_step.dart';
import 'steps/turn_step.dart';
import 'widgets/flow_header.dart';

/// Mutable draft of the applicant being registered. Each step edits the draft
/// in place and notifies the page so validation can re-run live.
class ApplicantDraft {
  String turnNumber = 'A-001';
  String fullName = '';
  int? birthYear;
  AcademicYear? academicYear;
  String? governorate;
  int? heightCm = 172;
  double? weightKg = 68.0;
  BloodType? bloodType;
  VisualAcuity? rightEyeAcuity;
  VisualAcuity? leftEyeAcuity;
  BiometricCapture? biometric;
  VisionTestReport? visionTest;
  String? photoPath;

  bool get hasPhoto => photoPath != null && photoPath!.isNotEmpty;

  bool get hasBiometric => biometric != null;
}

/// The four-step registration journey:
/// 1. Reception & Turn reservation (الاستقبال / قطع الدور)
/// 2. Identity details (البيانات)
/// 3. Health measurements & Eye test (الصحة)
/// 4. Portrait & Biometric fingerprint (البصمة)
class RegistrationPage extends StatefulWidget {
  const RegistrationPage({
    super.key,
    required this.store,
    this.biometricService,
  });

  final IdRecordStore store;

  /// خدمة مستشعر البصمة — تُحقن في الاختبارات، وتُبنى تلقائيًا في التشغيل.
  final BiometricService? biometricService;

  @override
  State<RegistrationPage> createState() => _RegistrationPageState();
}

class _RegistrationPageState extends State<RegistrationPage> {
  static const int _stepCount = 4;
  static const List<String> _stepTitles = ['الاستقبال', 'البيانات', 'الصحة', 'البصمة'];

  PageController _pageController = PageController();
  ApplicantDraft _draft = ApplicantDraft();

  /// Bumped on every fresh registration so the step widgets — and the text
  /// controllers they own — are rebuilt from scratch rather than reused.
  int _session = 0;
  int _turnSequence = 1;

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

  void _resetTurn() {
    _turnSequence = _turnSequence >= 999 ? 1 : _turnSequence + 1;
    setState(() {
      _draft.turnNumber = 'A-${_turnSequence.toString().padLeft(3, '0')}';
    });
  }

  /// Clears the whole journey, advances to the next turn number, and returns to step zero.
  void _startNewRegistration() {
    _pageController.dispose();
    _turnSequence = _turnSequence >= 999 ? 1 : _turnSequence + 1;
    final nextTurn = 'A-${_turnSequence.toString().padLeft(3, '0')}';
    setState(() {
      _pageController = PageController();
      _draft = ApplicantDraft()..turnNumber = nextTurn;
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
        resizeToAvoidBottomInset: true,
        body: OrnamentBackground(
          child: Column(
            children: [
              FlowHeader(
                currentStep: _step,
                totalSteps: _stepCount,
                stepTitles: _stepTitles,
                turnNumber: _draft.turnNumber,
                onResetTurn: _resetTurn,
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
                    TurnStep(
                      draft: _draft,
                      onChanged: _refresh,
                      onNext: _goForward,
                    ),
                    IdentityStep(
                      draft: _draft,
                      errors: _visibleErrors(1),
                      onChanged: _refresh,
                    ),
                    HealthStep(
                      draft: _draft,
                      errors: _visibleErrors(2),
                      onChanged: _refresh,
                    ),
                    PhotoStep(
                      draft: _draft,
                      errors: _visibleErrors(3),
                      onChanged: _refresh,
                      biometricService: widget.biometricService,
                    ),
                  ],
                ),
              ),
              if (_step > 0)
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

  Map<String, String> _visibleErrors(int step) =>
      _showErrors && step == _step ? _computeErrors(step) : const {};

  Map<String, String> _computeErrors(int step) {
    final errors = <String, String>{};
    final draft = _draft;
    switch (step) {
      case 0:
        // Reception / Turn stage is always valid
        break;
      case 1:
        final nameParts = draft.fullName
            .trim()
            .split(RegExp(r'\s+'))
            .where((s) => s.isNotEmpty)
            .toList();
        if (nameParts.length < 3) {
          errors['fullName'] = 'يرجى إدخال الاسم الثلاثي كاملاً (٣ مقاطع)';
        }
        if (draft.birthYear == null ||
            draft.birthYear! < 1920 ||
            draft.birthYear! > DateTime.now().year) {
          errors['birthYear'] = 'سنة الميلاد مطلوبة';
        }
        if (draft.academicYear == null) {
          errors['academicYear'] = 'مطلوب';
        }
        if (draft.governorate == null || draft.governorate!.isEmpty) {
          errors['governorate'] = 'مطلوب';
        }
      case 2:
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
        if (draft.rightEyeAcuity == null || draft.leftEyeAcuity == null) {
          errors['vision'] = 'أجرِ فحص النظر أو أدخل نتيجة تقريرك الطبي';
        }
      case 3:
        if (!draft.hasPhoto) {
          errors['photo'] = 'الصورة مطلوبة لإصدار بطاقة الهوية';
        }
        if (!draft.hasBiometric) {
          errors['biometric'] =
              'أنجز التوثيق البيومتري بمسح البصمة على مستشعر الجهاز';
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
      turnNumber: draft.turnNumber,
      fullName: draft.fullName.trim(),
      birthYear: draft.birthYear!,
      academicYear: draft.academicYear!,
      governorate: draft.governorate!,
      heightCm: draft.heightCm!,
      weightKg: draft.weightKg!,
      bloodType: draft.bloodType!,
      rightEyeAcuity: draft.rightEyeAcuity!,
      leftEyeAcuity: draft.leftEyeAcuity!,
      biometric: draft.biometric,
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
          maxWidth: band.isCompact ? double.infinity : 680,
          padding: EdgeInsets.symmetric(
            horizontal: band.gutter,
            vertical: 12 * band.scale,
          ),
          child: Row(
            children: [
              if (canGoBack)
                OutlinedButton.icon(
                  onPressed: onBack,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: BrandColors.pine,
                    side: const BorderSide(color: BrandColors.outlineSoft),
                    minimumSize: Size(96 * band.scale, 48 * band.scale),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(BrandRadii.pill),
                    ),
                  ),
                  icon: const Icon(Icons.arrow_back_rounded, size: 18),
                  label: const Text('السابق'),
                ),
              if (canGoBack) SizedBox(width: 12 * band.scale),
              Expanded(
                child: Tooltip(
                  message: blockedReason ?? '',
                  child: BrandButton(
                    label: isLast ? 'إصدار بطاقة الهوية' : 'متابعة',
                    icon: isLast
                        ? Icons.card_membership_rounded
                        : Icons.arrow_forward_rounded,
                    large: true,
                    muted: !canContinue,
                    onPressed: generating ? null : onContinue,
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
                'الخطوة $number من 4',
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
