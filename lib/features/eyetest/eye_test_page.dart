import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/brand_colors.dart';
import '../../models/applicant.dart';
import '../../models/vision_test.dart';
import '../../shared/widgets/adaptive_layout.dart';
import '../../shared/widgets/brand_widgets.dart';
import 'tumbling_e.dart';

/// مراحل الفحص السريع
enum _TestStage { intro, testing, summary }

/// فحص حدة الإبصار التفاعلي الموحد للعينين معاً — ٥ فحوصات سريعة ودقيقة.
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
  static const int _totalChecks = 5;
  static const double _distanceCm = 40.0;

  /// المستويات الخمسة المتدرجة للفحص السريع
  static const List<(VisualAcuity, double)> _testLevels = [
    (VisualAcuity.twentySeventy, 110.0), // Check 1: Easy / Intro
    (VisualAcuity.twentyFifty, 85.0),   // Check 2: Intermediate
    (VisualAcuity.twentyForty, 65.0),   // Check 3: Standard
    (VisualAcuity.twentyThirty, 50.0),  // Check 4: Sharp
    (VisualAcuity.twentyTwenty, 38.0),  // Check 5: 20/20 Super sharp
  ];

  final math.Random _random = math.Random();

  _TestStage _stage = _TestStage.intro;
  int _currentIndex = 0;
  int _correctCount = 0;
  late EDirection _currentDirection;
  bool _masking = false;

  @override
  void initState() {
    super.initState();
    _currentDirection = _randomDirection();
  }

  EDirection _randomDirection() =>
      EDirection.values[_random.nextInt(EDirection.values.length)];

  void _startTest() {
    setState(() {
      _stage = _TestStage.testing;
      _currentIndex = 0;
      _correctCount = 0;
      _currentDirection = _randomDirection();
      _masking = false;
    });
  }

  void _handleAnswer(EDirection direction) {
    if (_masking || _stage != _TestStage.testing) return;

    final isCorrect = direction == _currentDirection;
    if (isCorrect) {
      _correctCount++;
      HapticFeedback.lightImpact();
    } else {
      HapticFeedback.mediumImpact();
    }

    if (_currentIndex + 1 >= _totalChecks) {
      // Finished all 5 checks
      setState(() {
        _stage = _TestStage.summary;
      });
      return;
    }

    // Move to next check with brief smooth mask. Five checks run back to back,
    // so every millisecond spent on the mask is paid five times over — it is
    // kept just long enough to stop the next letter appearing mid-blink.
    setState(() => _masking = true);
    Future.delayed(const Duration(milliseconds: 110), () {
      if (!mounted) return;
      setState(() {
        _currentIndex++;
        _currentDirection = _randomDirection();
        _masking = false;
      });
    });
  }

  VisualAcuity get _finalAcuity {
    switch (_correctCount) {
      case 5:
        return VisualAcuity.twentyTwenty;
      case 4:
        return VisualAcuity.twentyTwentyFive;
      case 3:
        return VisualAcuity.twentyThirty;
      case 2:
        return VisualAcuity.twentyForty;
      case 1:
        return VisualAcuity.twentyFifty;
      default:
        return VisualAcuity.twentySeventy;
    }
  }

  void _confirmResult() {
    final acuity = _finalAcuity;
    final report = VisionTestReport(
      right: EyeResult(
        side: EyeSide.right,
        acuity: acuity,
        correctAnswers: _correctCount,
        totalAnswers: _totalChecks,
        passedLines: _correctCount,
        linesPresented: _totalChecks,
      ),
      left: EyeResult(
        side: EyeSide.left,
        acuity: acuity,
        correctAnswers: _correctCount,
        totalAnswers: _totalChecks,
        passedLines: _correctCount,
        linesPresented: _totalChecks,
      ),
      distanceCm: _distanceCm,
      testedAtUtc: DateTime.now().toUtc(),
    );

    Navigator.of(context).pop(report);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BrandColors.ivory,
      appBar: AppBar(
        backgroundColor: BrandColors.pine,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text(
          'فحص حدة الإبصار التفاعلي',
          style: TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 160),
          child: switch (_stage) {
            _TestStage.intro => _buildIntro(),
            _TestStage.testing => _buildTesting(),
            _TestStage.summary => _buildSummary(),
          },
        ),
      ),
    );
  }

  // ------------------------------------------------------------- Intro Screen
  Widget _buildIntro() {
    final band = Adaptive.bandOf(context);

    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: band.gutter, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
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
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: BrandColors.goldMist,
                    shape: BoxShape.circle,
                    border: Border.all(color: BrandColors.goldSoft, width: 2),
                  ),
                  child: const Icon(
                    Icons.visibility_outlined,
                    size: 38,
                    color: BrandColors.pine,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'فحص النظر بالعينين معاً',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: BrandColors.pine,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'فحص سريع ومباشر (٥ محاولات فقط) لتحديد حدة الإبصار.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14.5,
                    color: BrandColors.inkMuted,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                // Instructions list
                _buildTipItem(
                  icon: Icons.remove_red_eye_rounded,
                  title: 'انظر بالعينين معاً',
                  desc: 'لا حاجة لتغطية أي عين أثناء الفحص.',
                ),
                const SizedBox(height: 12),
                _buildTipItem(
                  icon: Icons.phone_android_rounded,
                  title: 'مسافة الفحص الموصى بها',
                  desc: 'ثبّت الهاتف على مسافة مريحة من وجهك (~40 سم).',
                ),
                const SizedBox(height: 12),
                _buildTipItem(
                  icon: Icons.touch_app_rounded,
                  title: 'حدد اتجاه فتحة الحرف E',
                  desc: 'اضغط على السهم المطابق للاتجاه في ٥ محاولات متتالية.',
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: BrandButton(
                    label: 'بدء الفحص السريع الآن',
                    icon: Icons.play_arrow_rounded,
                    large: true,
                    onPressed: _startTest,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTipItem({
    required IconData icon,
    required String title,
    required String desc,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: BrandColors.goldMist,
        borderRadius: BorderRadius.circular(BrandRadii.medium),
      ),
      child: Row(
        children: [
          Icon(icon, size: 22, color: BrandColors.goldDeep),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: BrandColors.pine,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: BrandColors.inkMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------- Testing Screen
  Widget _buildTesting() {
    final currentLevel = _testLevels[_currentIndex];
    final optotypeSize = currentLevel.$2;

    return Column(
      children: [
        // Top progress indicator
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'الفحص ${_currentIndex + 1} من $_totalChecks',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: BrandColors.pine,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: BrandColors.goldMist,
                      borderRadius: BorderRadius.circular(BrandRadii.pill),
                      border: Border.all(color: BrandColors.goldSoft),
                    ),
                    child: const Text(
                      'بالعينين معاً',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: BrandColors.goldDeep,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(BrandRadii.pill),
                child: LinearProgressIndicator(
                  value: (_currentIndex + 1) / _totalChecks,
                  minHeight: 6,
                  backgroundColor: BrandColors.outlineSoft,
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(BrandColors.goldDeep),
                ),
              ),
            ],
          ),
        ),
        // Central E Optotype Box
        Expanded(
          child: Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(BrandRadii.large),
                border: Border.all(color: BrandColors.outlineSoft),
                boxShadow: [
                  BoxShadow(
                    color: BrandColors.pine.withValues(alpha: 0.04),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 90),
                opacity: _masking ? 0.0 : 1.0,
                child: TumblingE(
                  size: optotypeSize,
                  direction: _currentDirection,
                  color: BrandColors.pineDeep,
                ),
              ),
            ),
          ),
        ),
        // Directional Controls Pad
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            children: [
              const Text(
                'أين تتجه فتحة الحرف E؟',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: BrandColors.ink,
                ),
              ),
              const SizedBox(height: 18),
              // The four keys sit on a recessed ivory plate, which is what
              // makes them read as one pad rather than four loose buttons. The
              // keys keep their true screen positions — the left key is on the
              // left — so the answer maps to the gap the eye just saw, which is
              // why the plate is laid out ignoring the page's RTL direction.
              Directionality(
                textDirection: TextDirection.ltr,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: BrandColors.goldMist,
                    borderRadius: BorderRadius.circular(BrandRadii.extraLarge),
                    border: Border.all(color: BrandColors.goldSoft, width: 1.2),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildDirectionButton(
                        direction: EDirection.up,
                        icon: Icons.keyboard_arrow_up_rounded,
                        label: 'أعلى',
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildDirectionButton(
                            direction: EDirection.left,
                            icon: Icons.keyboard_arrow_left_rounded,
                            label: 'يسار',
                          ),
                          const SizedBox(width: 12),
                          // The dead centre of the pad, left empty so the four
                          // arms read as a compass rose.
                          Container(
                            width: 78,
                            height: 78,
                            alignment: Alignment.center,
                            child: Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color:
                                    BrandColors.gold.withValues(alpha: 0.45),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          _buildDirectionButton(
                            direction: EDirection.right,
                            icon: Icons.keyboard_arrow_right_rounded,
                            label: 'يمين',
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildDirectionButton(
                        direction: EDirection.down,
                        icon: Icons.keyboard_arrow_down_rounded,
                        label: 'أسفل',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// One arm of the direction pad.
  ///
  /// The four keys read as a single pine control rather than four separate
  /// cards: a round, solid key with the arrow set large in gold. At this point
  /// the person is squinting at a letter, so the target is big, the contrast is
  /// high, and the word under it is there for confirmation rather than for
  /// reading. The [label] stays in the tree — the pad has to be usable by touch
  /// and by screen reader alike.
  Widget _buildDirectionButton({
    required EDirection direction,
    required IconData icon,
    required String label,
  }) {
    const size = 78.0;

    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: BrandGradients.pine,
            border: Border.all(
              color: BrandColors.gold.withValues(alpha: 0.55),
              width: 1.4,
            ),
            boxShadow: [
              BoxShadow(
                color: BrandColors.pine.withValues(alpha: 0.28),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: InkWell(
            onTap: () => _handleAnswer(direction),
            customBorder: const CircleBorder(),
            splashColor: BrandColors.gold.withValues(alpha: 0.30),
            highlightColor: BrandColors.gold.withValues(alpha: 0.14),
            child: SizedBox.square(
              dimension: size,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 38, color: BrandColors.goldGlow),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ----------------------------------------------------------- Summary Screen
  Widget _buildSummary() {
    final band = Adaptive.bandOf(context);
    final acuity = _finalAcuity;

    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: band.gutter, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(BrandRadii.large),
              border: Border.all(color: BrandColors.goldSoft, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: BrandColors.gold.withValues(alpha: 0.18),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    gradient: BrandGradients.gold,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: BrandColors.gold.withValues(alpha: 0.35),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.check_rounded,
                      size: 44,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'اكتمل فحص النظر بنجاح!',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: BrandColors.pine,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'تم قياس حدة الإبصار بالعينين معاً عبر ٥ فحوصات معيارية.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13.5,
                    color: BrandColors.inkMuted,
                  ),
                ),
                const SizedBox(height: 28),
                // Acuity Badge
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: BrandColors.goldMist,
                    borderRadius: BorderRadius.circular(BrandRadii.medium),
                    border: Border.all(color: BrandColors.goldSoft),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'حدة الإبصار المقاسة (للعينين معاً)',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: BrandColors.pine,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        acuity.label,
                        style: const TextStyle(
                          fontSize: 42,
                          fontWeight: FontWeight.w900,
                          color: BrandColors.pine,
                          fontFamily: 'SpaceMono',
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'إجابات صحيحة: $_correctCount من $_totalChecks',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: BrandColors.goldDeep,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: BrandButton(
                    label: 'اعتماد النتيجة والمتابعة',
                    icon: Icons.check_circle_outline_rounded,
                    large: true,
                    onPressed: _confirmResult,
                  ),
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: _startTest,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('إعادة إجراء الفحص'),
                  style: TextButton.styleFrom(
                    foregroundColor: BrandColors.ink,
                    textStyle: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
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
