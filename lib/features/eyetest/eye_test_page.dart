import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/brand_colors.dart';
import '../../models/applicant.dart';
import '../../models/vision_test.dart';
import '../../shared/widgets/adaptive_layout.dart';
import '../../shared/widgets/animations.dart';
import '../../shared/widgets/brand_widgets.dart';
import 'screen_calibration.dart';
import 'tumbling_e.dart';

/// مراحل رحلة الفحص.
enum _Stage { setup, brief, testing, summary }

/// فحص نظر تفاعلي حقيقي بلوحة «E المتدحرج».
///
/// ثمانية أسطر بتدرّج سنيلن الكامل (20/200 → 20/20)؛ في كل سطر أربعة رموز
/// بزوايا عشوائية موحّدة، ويُجتاز السطر بثلاث إجابات صحيحة — بروتوكول
/// Peek Acuity. حجم كل رمز يُحسب بالمليمتر من الزاوية البصرية ومسافة الفحص
/// وقياس الشاشة المُعايَر، والأسطر التي تعجز دقة الشاشة عن رسمها تُقتطع من
/// اللوحة بدلًا من عرضها كلطخة رمادية.
///
/// لا يُخبر الفحص المفحوص بصحة أي إجابة، ولا يستثني الاتجاه السابق من
/// الاحتمالات: كلا الأمرين كان يسمح باستنتاج الإجابة بدل رؤيتها.
class EyeTestPage extends StatefulWidget {
  const EyeTestPage({super.key});

  /// يفتح الفحص ويعيد التقرير، أو `null` إذا انسحب المستخدم.
  static Future<VisionTestReport?> show(BuildContext context) {
    return Navigator.of(context).push<VisionTestReport>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const EyeTestPage(),
      ),
    );
  }

  @override
  State<EyeTestPage> createState() => _EyeTestPageState();
}

class _EyeTestPageState extends State<EyeTestPage> {
  static const List<double> _distances = [40, 100, 200, 300];

  /// فترة التعمية بين رمزين.
  static const Duration _maskDuration = Duration(milliseconds: 350);

  final math.Random _random = math.Random();

  _Stage _stage = _Stage.setup;
  double _pxPerMm = ScreenCalibration.initialGuess();
  double _distanceCm = 40;

  /// اللوحة المعروضة فعلًا: أسطر [kAcuityLines] التي تكفيها دقة هذه الشاشة
  /// على المسافة المختارة. تُحسب مرة واحدة عند بدء الفحص فتبقى العينان على
  /// اللوحة نفسها.
  List<AcuityLine> _lines = kAcuityLines;

  EyeSide _eye = EyeSide.right;
  int _lineIndex = 0;
  int _shownInLine = 0;
  int _correctInLine = 0;
  int _correctTotal = 0;
  int _answeredTotal = 0;
  int _bestLine = -1;
  EDirection _direction = EDirection.right;

  /// فترة تعمية قصيرة بين رمزين، تمنع مقارنة الرمز الجديد ببقايا السابق.
  /// لا تحمل أي إشارة إلى صحة الإجابة.
  bool _masking = false;

  final Map<EyeSide, EyeResult> _results = {};

  @override
  void initState() {
    super.initState();
    _direction = _randomDirection();
  }

  /// اتجاه عشوائي موحّد من أصل أربعة.
  ///
  /// بلا استثناء للاتجاه السابق: استثناؤه كان يُسقط احتمالًا من الأربعة، فيرفع
  /// فرصة التخمين الأعمى من 25% إلى 33% لمن يلاحظ أن الاتجاه لا يتكرر أبدًا.
  EDirection _randomDirection() =>
      EDirection.values[_random.nextInt(EDirection.values.length)];

  // ---------------------------------------------------------------- الفحص

  /// يثبّت المعايرة، يبني اللوحة القابلة للعرض، ثم يبدأ بالعين اليمنى.
  void _beginTest() {
    ScreenCalibration.set(_pxPerMm);
    _lines = renderableAcuityLines(
      pxPerMm: _pxPerMm,
      distanceCm: _distanceCm,
      devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
    );
    _startEye(EyeSide.right);
  }

  void _startEye(EyeSide side) {
    setState(() {
      _eye = side;
      _lineIndex = 0;
      _shownInLine = 0;
      _correctInLine = 0;
      _bestLine = -1;
      _direction = _randomDirection();
      _masking = false;
      _stage = _Stage.brief;
    });
  }

  void _answer(EDirection? answer) {
    if (_masking) return;

    final correct = answer == _direction;
    _answeredTotal++;
    _shownInLine++;
    if (correct) {
      _correctInLine++;
      _correctTotal++;
    }

    // تعمية قصيرة ثم الرمز التالي — بلا لون ولا علامة. إخبار المفحوص بصحة كل
    // إجابة يجعله يستدل على الأنماط ويعدّل تخمينه، ولا لوحة عيادة تفعل ذلك.
    setState(() => _masking = true);
    Future.delayed(_maskDuration, () {
      if (!mounted) return;
      _advance();
    });
  }

  void _advance() {
    final wrongInLine = _shownInLine - _correctInLine;
    final linePassed = _correctInLine >= kCorrectToPass;
    final lineFailed = wrongInLine >= kWrongToFail;

    if (!linePassed && !lineFailed) {
      setState(() {
        _masking = false;
        _direction = _randomDirection();
      });
      return;
    }

    if (linePassed) _bestLine = _lineIndex;

    final isLastLine = _lineIndex == _lines.length - 1;
    if (lineFailed || isLastLine) {
      _finishEye();
      return;
    }

    setState(() {
      _lineIndex++;
      _shownInLine = 0;
      _correctInLine = 0;
      _masking = false;
      _direction = _randomDirection();
    });
  }

  void _finishEye() {
    // لم يُجتَز أي سطر: لا يجوز نسبة قيمة أعلى سطر إلى من لم يقرأه.
    final acuity = _bestLine >= 0
        ? _lines[_bestLine].acuity
        : VisualAcuity.worseThanTwentyTwoHundred;
    _results[_eye] = EyeResult(
      side: _eye,
      acuity: acuity,
      correctAnswers: _correctTotal,
      totalAnswers: _answeredTotal,
      passedLines: _bestLine + 1,
      linesPresented: _lines.length,
    );

    if (_eye == EyeSide.right) {
      _correctTotal = 0;
      _answeredTotal = 0;
      _startEye(EyeSide.left);
    } else {
      setState(() => _stage = _Stage.summary);
    }
  }

  void _restart() {
    setState(() {
      _results.clear();
      _correctTotal = 0;
      _answeredTotal = 0;
      _lines = kAcuityLines;
      _stage = _Stage.setup;
    });
  }

  // ---------------------------------------------------------------- البناء

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BrandColors.ivory,
      body: SafeArea(
        child: Column(
          children: [
            _TestHeader(
              stage: _stage,
              eye: _eye,
              onClose: () => Navigator.of(context).maybePop(),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: BrandDurations.quick,
                child: switch (_stage) {
                  _Stage.setup => _buildSetup(),
                  _Stage.brief => _buildBrief(),
                  _Stage.testing => _buildTesting(),
                  _Stage.summary => _buildSummary(),
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------- الإعدادات

  Widget _buildSetup() {
    final band = Adaptive.bandOf(context);
    return SingleChildScrollView(
      key: const ValueKey('setup'),
      padding: EdgeInsets.fromLTRB(band.gutter, 20, band.gutter, 32),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: band.contentWidth),
          child: EntranceList(
            spacing: 20,
            children: [
              const _SectionTitle(
                icon: Icons.straighten_rounded,
                title: 'معايرة الشاشة',
                subtitle:
                    'ضع بطاقة بنكية أو هوية على الشاشة واضبط الإطار حتى يطابق '
                    'حوافها تمامًا. هذه الخطوة تجعل أحجام الرموز حقيقية بالمليمتر.',
              ),
              _CalibrationCard(
                pxPerMm: _pxPerMm,
                onChanged: (value) => setState(() => _pxPerMm = value),
              ),
              const _SectionTitle(
                icon: Icons.social_distance_rounded,
                title: 'مسافة الفحص',
                subtitle:
                    'اختر المسافة بين عينك والشاشة، وحافظ عليها طوال الفحص.',
              ),
              _DistanceSelector(
                distances: _distances,
                selected: _distanceCm,
                onChanged: (value) => setState(() => _distanceCm = value),
              ),
              _FeasibilityNote(
                pxPerMm: _pxPerMm,
                distanceCm: _distanceCm,
              ),
              const _SectionTitle(
                icon: Icons.checklist_rounded,
                title: 'قبل أن نبدأ',
                subtitle: 'تعليمات سريعة لنتيجة دقيقة.',
              ),
              const _InstructionsCard(),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: BrandButton(
                  label: 'ابدأ فحص العين اليمنى',
                  icon: Icons.play_arrow_rounded,
                  large: true,
                  onPressed: _beginTest,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------- تمهيد كل عين

  Widget _buildBrief() {
    final band = Adaptive.bandOf(context);
    return Center(
      key: ValueKey('brief-${_eye.name}'),
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: band.gutter, vertical: 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: band.contentWidth),
          child: Entrance(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _EyeCoverIllustration(eye: _eye, size: 150 * band.scale),
                const SizedBox(height: 28),
                Text(
                  'الآن نفحص ${_eye.label}',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: BrandColors.pine,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 10),
                Text(
                  'غطِّ ${_eye.other.label} بكفّ يدك دون ضغط، وأبقِ العينين '
                  'مفتوحتين. اجلس على بُعد ${_distanceCm.round()} سم من الشاشة.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: BrandColors.inkMuted,
                      ),
                ),
                const SizedBox(height: 24),
                const _HowToAnswerRow(),
                const SizedBox(height: 30),
                SizedBox(
                  width: math.min(360, MediaQuery.sizeOf(context).width - 48),
                  child: BrandButton(
                    label: 'أنا جاهز — ابدأ',
                    icon: Icons.visibility_rounded,
                    large: true,
                    onPressed: () => setState(() => _stage = _Stage.testing),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------- اللوحة

  Widget _buildTesting() {
    final line = _lines[_lineIndex];
    final band = Adaptive.bandOf(context);
    final optotypePx = line.optotypeHeightMm(_distanceCm) * _pxPerMm;

    return Column(
      key: const ValueKey('testing'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _LineProgress(
          lineIndex: _lineIndex,
          totalLines: _lines.length,
          line: line,
          shown: _shownInLine,
          eye: _eye,
        ),
        Expanded(
          child: _ChartSurface(
            optotypePx: optotypePx,
            direction: _direction,
            masking: _masking,
          ),
        ),
        _DirectionPad(
          enabled: !_masking,
          band: band,
          onAnswer: _answer,
          onCannotSee: () => _answer(null),
        ),
      ],
    );
  }

  // -------------------------------------------------------------- النتيجة

  Widget _buildSummary() {
    final band = Adaptive.bandOf(context);
    final right = _results[EyeSide.right]!;
    final left = _results[EyeSide.left]!;

    return SingleChildScrollView(
      key: const ValueKey('summary'),
      padding: EdgeInsets.fromLTRB(band.gutter, 20, band.gutter, 32),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: band.contentWidth),
          child: EntranceList(
            spacing: 18,
            children: [
              Column(
                children: [
                  Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: BrandGradients.gold,
                      boxShadow: [
                        BoxShadow(
                          color: BrandColors.gold.withValues(alpha: 0.4),
                          blurRadius: 22,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.remove_red_eye_rounded,
                      size: 40,
                      color: Color(0xFF243028),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'اكتمل فحص النظر',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: BrandColors.pine,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'مسافة ${_distanceCm.round()} سم · لوحة E المتدحرج '
                    '(${_lines.length} من ${kAcuityLines.length} أسطر) · '
                    '$kCorrectToPass إجابات صحيحة من $kOptotypesPerLine '
                    'لاجتياز السطر.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: BrandColors.inkMuted,
                        ),
                  ),
                ],
              ),
              if (band.isCompact)
                Column(
                  children: [
                    _ResultCard(result: right),
                    const SizedBox(height: 14),
                    _ResultCard(result: left),
                  ],
                )
              else
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: _ResultCard(result: right)),
                      const SizedBox(width: 16),
                      Expanded(child: _ResultCard(result: left)),
                    ],
                  ),
                ),
              const _MedicalDisclaimer(),
              BrandButton(
                label: 'اعتماد النتيجة',
                icon: Icons.check_circle_outline_rounded,
                large: true,
                onPressed: () {
                  Navigator.of(context).pop(
                    VisionTestReport(
                      right: right,
                      left: left,
                      distanceCm: _distanceCm,
                      testedAtUtc: DateTime.now().toUtc(),
                    ),
                  );
                },
              ),
              Center(
                child: TextButton.icon(
                  onPressed: _restart,
                  icon: const Icon(Icons.replay_rounded, size: 18),
                  label: const Text('إعادة الفحص من البداية'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ الترويسة

class _TestHeader extends StatelessWidget {
  const _TestHeader({
    required this.stage,
    required this.eye,
    required this.onClose,
  });

  final _Stage stage;
  final EyeSide eye;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final title = switch (stage) {
      _Stage.setup => 'فحص النظر — التهيئة',
      _Stage.brief => 'فحص النظر — ${eye.label}',
      _Stage.testing => 'فحص النظر — ${eye.label}',
      _Stage.summary => 'فحص النظر — النتيجة',
    };

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
      decoration: const BoxDecoration(
        color: BrandColors.surface,
        border: Border(bottom: BorderSide(color: BrandColors.outlineSoft)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onClose,
            tooltip: 'إغلاق',
            icon: const Icon(Icons.close_rounded),
          ),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: BrandColors.pine,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
          const GoldChip(label: 'Tumbling E', icon: Icons.visibility_outlined),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ المعايرة

/// Match-the-card calibration.
///
/// The outline is drawn at its true on-screen size — never scaled to fit —
/// because the whole point is that its width equals the real 53.98 mm short
/// edge of an ID-1 card once the user has lined the two up.
class _CalibrationCard extends StatelessWidget {
  const _CalibrationCard({required this.pxPerMm, required this.onChanged});

  final double pxPerMm;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // The outline can never be wider than the card it sits in.
        final maxPxPerMm =
            (constraints.maxWidth / ScreenCalibration.cardShortSideMm)
                .clamp(4.0, 14.0);
        final value = pxPerMm.clamp(3.0, maxPxPerMm);
        final outlineWidth = ScreenCalibration.cardShortSideMm * value;

        return SectionCard(
          padding: 14,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: outlineWidth,
                  height: 132,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: BrandColors.goldDeep, width: 2),
                    gradient: LinearGradient(
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                      colors: [
                        BrandColors.goldMist,
                        BrandColors.goldSoft.withValues(alpha: 0.55),
                      ],
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.credit_card_rounded,
                        color: BrandColors.goldDeep.withValues(alpha: 0.6),
                        size: 30,
                      ),
                      const SizedBox(height: 8),
                      Directionality(
                        textDirection: TextDirection.ltr,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.arrow_left_rounded,
                              size: 18,
                              color: BrandColors.goldDeep,
                            ),
                            Text(
                              '53.98 مم',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(color: BrandColors.goldDeep),
                            ),
                            const Icon(
                              Icons.arrow_right_rounded,
                              size: 18,
                              color: BrandColors.goldDeep,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Center(
                child: Text(
                  'طابق عرض الإطار مع الضلع القصير لبطاقتك',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: BrandColors.inkMuted,
                      ),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.remove_rounded, color: BrandColors.goldDeep),
                  Expanded(
                    child: Slider(
                      value: value,
                      min: 3.0,
                      max: maxPxPerMm,
                      divisions: 140,
                      activeColor: BrandColors.gold,
                      inactiveColor: BrandColors.goldSoft,
                      label: '${value.toStringAsFixed(2)} px/mm',
                      onChanged: onChanged,
                    ),
                  ),
                  const Icon(Icons.add_rounded, color: BrandColors.goldDeep),
                ],
              ),
              Center(
                child: Text(
                  'المقياس الحالي: ${value.toStringAsFixed(2)} بكسل لكل مليمتر',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: BrandColors.inkMuted,
                      ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DistanceSelector extends StatelessWidget {
  const _DistanceSelector({
    required this.distances,
    required this.selected,
    required this.onChanged,
  });

  final List<double> distances;
  final double selected;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < distances.length; i++) ...[
          Expanded(
            child: _ChoiceChipTile(
              label: distances[i] < 100
                  ? '${distances[i].round()} سم'
                  : '${(distances[i] / 100).toStringAsFixed(0)} م',
              // 3 م هي مسافة لوحة العيادة؛ 40 سم مسافة قراءة قريبة تعجز فيها
              // معظم الشاشات عن رسم أدقّ الأسطر.
              caption: switch (distances[i]) {
                40.0 => 'قريب',
                300.0 => 'قياسي',
                _ => 'بعيد',
              },
              selected: selected == distances[i],
              onTap: () => onChanged(distances[i]),
            ),
          ),
          if (i != distances.length - 1) const SizedBox(width: 10),
        ],
      ],
    );
  }
}

class _ChoiceChipTile extends StatelessWidget {
  const _ChoiceChipTile({
    required this.label,
    required this.caption,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String caption;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? BrandColors.pine : BrandColors.surface,
      borderRadius: BorderRadius.circular(BrandRadii.medium),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(BrandRadii.medium),
        child: Container(
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(BrandRadii.medium),
            border: Border.all(
              color: selected ? BrandColors.gold : BrandColors.outlineSoft,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: selected ? Colors.white : BrandColors.ink,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              Text(
                caption,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: selected
                          ? BrandColors.goldGlow
                          : BrandColors.inkMuted,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// يعلن مدى اللوحة الذي تستطيع هذه الشاشة قياسه فعلًا على المسافة المختارة.
///
/// الأسطر الأدقّ من قدرة الشاشة تُقتطع ولا تُعرض، لأن رمزًا سماكة ضلعه أقل من
/// بكسل فيزيائي واحد يقيس حدّة الشاشة لا حدّة العين.
class _FeasibilityNote extends StatelessWidget {
  const _FeasibilityNote({required this.pxPerMm, required this.distanceCm});

  final double pxPerMm;
  final double distanceCm;

  @override
  Widget build(BuildContext context) {
    final lines = renderableAcuityLines(
      pxPerMm: pxPerMm,
      distanceCm: distanceCm,
      devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
    );
    final full = lines.length == kAcuityLines.length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: full ? BrandColors.pineMist : const Color(0xFFFDF3E7),
        borderRadius: BorderRadius.circular(BrandRadii.medium),
        border: Border.all(
          color: full
              ? BrandColors.pineSoft
              : BrandColors.goldDeep.withValues(alpha: 0.45),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            full ? Icons.verified_rounded : Icons.info_outline_rounded,
            size: 20,
            color: full ? BrandColors.success : BrandColors.goldDeep,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              full
                  ? 'هذه الشاشة تعرض أسطر اللوحة الـ${kAcuityLines.length} '
                      'كاملةً حتى 20/20 على هذه المسافة.'
                  : 'على هذه المسافة تعجز الشاشة عن رسم ما هو أدقّ من '
                      '${lines.last.label}، فستتوقف اللوحة عند هذا السطر '
                      '(${lines.length} من ${kAcuityLines.length} أسطر). '
                      'زد المسافة لقياس الأسطر الأدقّ.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: full ? BrandColors.pine : BrandColors.goldDeep,
                    height: 1.6,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InstructionsCard extends StatelessWidget {
  const _InstructionsCard();

  @override
  Widget build(BuildContext context) {
    const steps = [
      (Icons.pan_tool_outlined, 'غطِّ العين غير المفحوصة بكفّ يدك دون ضغط.'),
      (Icons.light_mode_outlined, 'اجلس في إضاءة جيدة بلا انعكاس على الشاشة.'),
      (Icons.visibility_outlined, 'حدّد الجهة التي تفتح نحوها أضلاع الحرف E.'),
      // الاختيار القسري جزء من البروتوكول: التخمين عند الشك يقيس أفضل مما
      // يقيسه الامتناع، و«لا أستطيع» للعجز الحقيقي عن رؤية الرمز أصلًا.
      (Icons.help_outline_rounded, 'إن ترددت فخمّن أقرب اتجاه؛ لا تمتنع.'),
      (
        Icons.visibility_off_outlined,
        'إن لم ترَ الرمز إطلاقًا اختر «لا أستطيع التمييز».',
      ),
      (
        Icons.do_not_disturb_on_outlined,
        'لن يخبرك الفحص بصحة إجاباتك — كلوحة العيادة تمامًا.',
      ),
    ];

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < steps.length; i++) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: BrandColors.goldMist,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    steps[i].$1,
                    size: 18,
                    color: BrandColors.goldDeep,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Text(
                      steps[i].$2,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ),
              ],
            ),
            if (i != steps.length - 1) const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }
}

// -------------------------------------------------------------- شاشة التمهيد

class _EyeCoverIllustration extends StatelessWidget {
  const _EyeCoverIllustration({required this.eye, required this.size});

  final EyeSide eye;
  final double size;

  @override
  Widget build(BuildContext context) {
    // العين اليمنى للشخص تظهر على يسار الصورة من وجهة نظر الناظر إليه.
    final coverRight = eye == EyeSide.left;

    return SizedBox(
      width: size,
      height: size * 0.62,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _EyeGlyph(size: size * 0.42, covered: !coverRight),
          SizedBox(width: size * 0.10),
          _EyeGlyph(size: size * 0.42, covered: coverRight),
        ],
      ),
    );
  }
}

class _EyeGlyph extends StatelessWidget {
  const _EyeGlyph({required this.size, required this.covered});

  final double size;
  final bool covered;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: BrandDurations.standard,
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: covered ? BrandColors.pine : BrandColors.goldMist,
        border: Border.all(
          color: covered ? BrandColors.pineDeep : BrandColors.gold,
          width: 2,
        ),
        boxShadow: covered
            ? null
            : [
                BoxShadow(
                  color: BrandColors.gold.withValues(alpha: 0.4),
                  blurRadius: 18,
                ),
              ],
      ),
      child: Icon(
        covered ? Icons.back_hand_rounded : Icons.remove_red_eye_rounded,
        size: size * 0.46,
        color: covered ? BrandColors.goldGlow : BrandColors.goldDeep,
      ),
    );
  }
}

class _HowToAnswerRow extends StatelessWidget {
  const _HowToAnswerRow();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: BrandColors.surface,
        borderRadius: BorderRadius.circular(BrandRadii.large),
        border: Border.all(color: BrandColors.outlineSoft),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'أي جهة تفتح نحوها أضلاع الحرف؟',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: BrandColors.pine,
                ),
          ),
          const SizedBox(height: 14),
          Directionality(
            textDirection: TextDirection.ltr,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final direction in EDirection.values) ...[
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TumblingE(size: 26, direction: direction),
                      const SizedBox(height: 8),
                      Icon(
                        switch (direction) {
                          EDirection.right => Icons.keyboard_arrow_right_rounded,
                          EDirection.down => Icons.keyboard_arrow_down_rounded,
                          EDirection.left => Icons.keyboard_arrow_left_rounded,
                          EDirection.up => Icons.keyboard_arrow_up_rounded,
                        },
                        color: BrandColors.goldDeep,
                      ),
                    ],
                  ),
                  if (direction != EDirection.values.last)
                    const SizedBox(width: 26),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- شريط السطر

class _LineProgress extends StatelessWidget {
  const _LineProgress({
    required this.lineIndex,
    required this.totalLines,
    required this.line,
    required this.shown,
    required this.eye,
  });

  final int lineIndex;
  final int totalLines;
  final AcuityLine line;
  final int shown;
  final EyeSide eye;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
      color: BrandColors.surface,
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: BrandColors.pine,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.remove_red_eye_rounded,
                      size: 14,
                      color: BrandColors.goldGlow,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      eye.label,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                'السطر ${lineIndex + 1} من $totalLines · ${line.label}',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: BrandColors.goldDeep,
                      fontFamily: 'SpaceMono',
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (var i = 0; i < totalLines; i++) ...[
                Expanded(
                  child: AnimatedContainer(
                    duration: BrandDurations.quick,
                    height: 5,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(3),
                      gradient: i <= lineIndex ? BrandGradients.gold : null,
                      color: i <= lineIndex ? null : BrandColors.ivoryDeep,
                    ),
                  ),
                ),
                if (i != totalLines - 1) const SizedBox(width: 6),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < kOptotypesPerLine; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: AnimatedContainer(
                    duration: BrandDurations.quick,
                    width: i < shown ? 22 : 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: i < shown
                          ? BrandColors.pine
                          : BrandColors.pineSoft,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// سطح اللوحة الأبيض الذي يُعرض عليه الرمز.
class _ChartSurface extends StatelessWidget {
  const _ChartSurface({
    required this.optotypePx,
    required this.direction,
    required this.masking,
  });

  final double optotypePx;
  final EDirection direction;

  /// فترة التعمية بين رمزين: يُخفى الرمز تمامًا لا يُبهَت، فلا يبقى منه أثر
  /// يُقارَن به الرمز التالي.
  final bool masking;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        // لوحة بيضاء خالصة بأعلى تباين ممكن، تمامًا كلوحة العيادة.
        color: Colors.white,
        borderRadius: BorderRadius.circular(BrandRadii.large),
        // إطار ثابت اللون والسماكة: أي تغيّر فيه بعد الإجابة يكشف صحتها.
        border: Border.all(color: BrandColors.outlineSoft),
        boxShadow: [
          BoxShadow(
            color: BrandColors.pine.withValues(alpha: 0.07),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Center(
        child: AnimatedOpacity(
          opacity: masking ? 0 : 1,
          duration: const Duration(milliseconds: 110),
          child: TumblingE(
            key: const ValueKey('chart-optotype'),
            // يُرسم بحجمه الحقيقي دون أي تكبير — هذه هي دقة الفحص.
            size: math.max(optotypePx, 2),
            direction: direction,
          ),
        ),
      ),
    );
  }
}

/// لوحة الاتجاهات: أربعة أزرار كبيرة + دعم مفاتيح الأسهم لأجهزة التلفاز.
class _DirectionPad extends StatelessWidget {
  const _DirectionPad({
    required this.enabled,
    required this.band,
    required this.onAnswer,
    required this.onCannotSee,
  });

  final bool enabled;
  final ScreenBand band;
  final ValueChanged<EDirection> onAnswer;
  final VoidCallback onCannotSee;

  @override
  Widget build(BuildContext context) {
    final buttonSize = band.isCompact ? 64.0 : 78.0 * band.scale;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: const BoxDecoration(
        color: BrandColors.surface,
        border: Border(top: BorderSide(color: BrandColors.outlineSoft)),
      ),
      child: SafeArea(
        top: false,
        child: Focus(
          autofocus: true,
          onKeyEvent: (node, event) {
            if (!enabled || event is! KeyDownEvent) {
              return KeyEventResult.ignored;
            }
            final direction = switch (event.logicalKey) {
              LogicalKeyboardKey.arrowUp => EDirection.up,
              LogicalKeyboardKey.arrowDown => EDirection.down,
              LogicalKeyboardKey.arrowLeft => EDirection.left,
              LogicalKeyboardKey.arrowRight => EDirection.right,
              _ => null,
            };
            if (direction == null) return KeyEventResult.ignored;
            onAnswer(direction);
            return KeyEventResult.handled;
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // اتجاهات فيزيائية لا منطقية: لا تُعكس مع اتجاه الكتابة.
              Directionality(
                textDirection: TextDirection.ltr,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _PadButton(
                      icon: Icons.keyboard_arrow_up_rounded,
                      label: 'أعلى',
                      size: buttonSize,
                      enabled: enabled,
                      onTap: () => onAnswer(EDirection.up),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _PadButton(
                          icon: Icons.keyboard_arrow_left_rounded,
                          label: 'يسار',
                          size: buttonSize,
                          enabled: enabled,
                          onTap: () => onAnswer(EDirection.left),
                        ),
                        SizedBox(width: buttonSize * 0.9),
                        _PadButton(
                          icon: Icons.keyboard_arrow_right_rounded,
                          label: 'يمين',
                          size: buttonSize,
                          enabled: enabled,
                          onTap: () => onAnswer(EDirection.right),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _PadButton(
                      icon: Icons.keyboard_arrow_down_rounded,
                      label: 'أسفل',
                      size: buttonSize,
                      enabled: enabled,
                      onTap: () => onAnswer(EDirection.down),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              TextButton.icon(
                onPressed: enabled ? onCannotSee : null,
                icon: const Icon(Icons.visibility_off_outlined, size: 18),
                label: const Text('لا أستطيع التمييز'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PadButton extends StatelessWidget {
  const _PadButton({
    required this.icon,
    required this.label,
    required this.size,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final double size;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: enabled ? BrandColors.pine : BrandColors.ivoryDeep,
        borderRadius: BorderRadius.circular(BrandRadii.large),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(BrandRadii.large),
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(
              icon,
              size: size * 0.55,
              color: enabled ? BrandColors.goldGlow : BrandColors.inkMuted,
            ),
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ النتيجة

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result});

  final EyeResult result;

  @override
  Widget build(BuildContext context) {
    // `null` عندما لم يُجتَز أي سطر: النتيجة تحت اللوحة ولا مقام سنيلن لها.
    final line = acuityLineFor(result.acuity);
    final denominator = line?.snellenDenominator;
    final verdict = switch (denominator) {
      null => 'أضعف من أعلى سطر — راجع طبيب عيون',
      <= 25 => 'إبصار طبيعي',
      <= 40 => 'ضعف بسيط — يُنصح بمراجعة مختص',
      <= 70 => 'ضعف متوسط — راجع طبيب عيون',
      _ => 'ضعف واضح — راجع طبيب عيون',
    };
    final normal = denominator != null && denominator <= 25;

    // اجتاز كل سطر معروض ولوحةُ الشاشة مقتطعة: القياس محدود بالشاشة، وقد
    // يكون الإبصار الحقيقي أفضل من الرقم المكتوب.
    final atScreenLimit =
        result.cappedByScreen && result.passedLines == result.linesPresented;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: BrandColors.surface,
        borderRadius: BorderRadius.circular(BrandRadii.large),
        border: Border.all(color: BrandColors.outlineSoft),
        boxShadow: [
          BoxShadow(
            color: BrandColors.pine.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: BrandColors.pineMist,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.remove_red_eye_outlined,
                  size: 20,
                  color: BrandColors.pine,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  result.side.label,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: BrandColors.pine,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Scales down rather than overflowing when two cards share a row.
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  result.acuity.label,
                  maxLines: 1,
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        // SpaceMono لا يحمل حروفًا عربية، وتسمية «تحت اللوحة»
                        // عربية — فتُترك لخط الواجهة.
                        fontFamily: line != null ? 'SpaceMono' : null,
                        color: BrandColors.goldDeep,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                if (line != null) ...[
                  const SizedBox(width: 10),
                  Text(
                    '(${line.decimal.toStringAsFixed(2)})',
                    maxLines: 1,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: BrandColors.inkMuted,
                        ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            verdict,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: normal ? BrandColors.success : BrandColors.goldDeep,
                  fontWeight: FontWeight.w700,
                ),
          ),
          if (atScreenLimit) ...[
            const SizedBox(height: 6),
            Text(
              'توقفت اللوحة عند هذا السطر لحدود دقة الشاشة؛ قد يكون الإبصار '
              'أفضل مما يظهر.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: BrandColors.inkMuted,
                    height: 1.5,
                  ),
            ),
          ],
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _Metric(
                  label: 'أسطر مجتازة',
                  value: '${result.passedLines}/${result.linesPresented}',
                ),
              ),
              Expanded(
                child: _Metric(
                  label: 'دقة الإجابات',
                  value: '${(result.accuracy * 100).round()}%',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: BrandColors.inkMuted,
              ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: BrandColors.ink,
                fontFamily: 'SpaceMono',
              ),
        ),
      ],
    );
  }
}

class _MedicalDisclaimer extends StatelessWidget {
  const _MedicalDisclaimer();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: BrandColors.goldMist,
        borderRadius: BorderRadius.circular(BrandRadii.medium),
        border: Border.all(color: BrandColors.gold.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: BrandColors.goldDeep,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'فحص استرشادي لحدة الإبصار وحدها. يُعرض الرمز منفردًا بلا رموز '
              'مجاورة، فقد تأتي النتيجة أفضل قليلًا من لوحة العيادة، وهو لا '
              'يقيس حَوَل العين ولا عمى الألوان ولا ضغطها. لا يُغني عن فحص '
              'طبيب العيون.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: BrandColors.goldDeep,
                    height: 1.6,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            gradient: BrandGradients.pine,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, size: 20, color: BrandColors.goldGlow),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: BrandColors.pine,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
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
