import 'package:a_digital_id/app/theme/brand_colors.dart';
import 'package:a_digital_id/features/eyetest/eye_test_page.dart';
import 'package:a_digital_id/features/eyetest/screen_calibration.dart';
import 'package:a_digital_id/features/eyetest/tumbling_e.dart';
import 'package:a_digital_id/models/applicant.dart';
import 'package:a_digital_id/models/vision_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

IconData _iconFor(EDirection direction) => switch (direction) {
      EDirection.up => Icons.keyboard_arrow_up_rounded,
      EDirection.down => Icons.keyboard_arrow_down_rounded,
      EDirection.left => Icons.keyboard_arrow_left_rounded,
      EDirection.right => Icons.keyboard_arrow_right_rounded,
    };

/// The optotype currently on the chart (the brief screen shows samples too).
final Finder _optotype = find.byKey(const ValueKey('chart-optotype'));

/// The direction of the optotype currently on the chart.
EDirection _shown(WidgetTester tester) =>
    tester.widget<TumblingE>(_optotype).direction;

/// Answers one optotype, either correctly or with a deliberate miss, and
/// reports the direction that was on the chart.
Future<EDirection> _answer(
  WidgetTester tester, {
  required bool correct,
}) async {
  final shown = _shown(tester);
  final answer =
      correct ? shown : EDirection.values.firstWhere((d) => d != shown);
  await tester.tap(find.byIcon(_iconFor(answer)));
  await tester.pump();
  // The chart blanks briefly, then advances — settle fully so the next
  // optotype (or the next eye's brief) is the only thing on screen.
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pumpAndSettle();
  return shown;
}

/// Scrolls a button into view before tapping it.
///
/// The setup, brief and summary screens all scroll, and on a short viewport
/// their primary button sits below the fold.
Future<void> _tapButton(WidgetTester tester, String label) async {
  final finder = find.text(label);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _startEye(WidgetTester tester) =>
    _tapButton(tester, 'أنا جاهز — ابدأ');

/// Runs one eye to completion, returning every direction that was presented.
Future<List<EDirection>> _runEye(
  WidgetTester tester, {
  required bool correct,
  int limit = 60,
}) async {
  await _startEye(tester);
  final shown = <EDirection>[];
  while (_optotype.evaluate().isNotEmpty && shown.length < limit) {
    shown.add(await _answer(tester, correct: correct));
  }
  return shown;
}

/// Every border colour currently painted by a [Container] in the tree.
///
/// The chart must never recolour its frame after an answer: a green or red
/// border tells the examinee whether they were right, which lets them learn
/// the pattern instead of reading the optotype.
Iterable<Color> _borderColours(WidgetTester tester) {
  return tester.widgetList<Container>(find.byType(Container)).expand((box) {
    final decoration = box.decoration;
    if (decoration is! BoxDecoration) return const <Color>[];
    final border = decoration.border;
    if (border is! Border) return const <Color>[];
    return [
      border.top.color,
      border.bottom.color,
      border.left.color,
      border.right.color,
    ];
  });
}

/// The opacity the chart is painting the optotype at right now.
double _optotypeOpacity(WidgetTester tester) {
  return tester
      .widgetList<AnimatedOpacity>(
        find.ancestor(of: _optotype, matching: find.byType(AnimatedOpacity)),
      )
      .first
      .opacity;
}

Widget _harness({ValueChanged<VisionTestReport?>? onDone}) {
  return MaterialApp(
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async {
                final report = await EyeTestPage.show(context);
                onDone?.call(report);
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Opens the chart and clears the setup screen with the default calibration.
///
/// A 2.0 device pixel ratio is enough for the 20/20 line at 40 cm, so the full
/// eight-line chart is presented.
Future<void> _openAndStart(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.reset);
  addTearDown(ScreenCalibration.reset);

  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  await _tapButton(tester, 'ابدأ فحص العين اليمنى');
}

void main() {
  group('AcuityLine', () {
    test('sizes the 20/20 optotype to five arc-minutes', () {
      const line = AcuityLine(
        acuity: VisualAcuity.twentyTwenty,
        snellenDenominator: 20,
      );
      // 5 arc-minutes at 40 cm ≈ 0.58 mm; at 6 m ≈ 8.7 mm.
      expect(line.optotypeHeightMm(40), closeTo(0.582, 0.005));
      expect(line.optotypeHeightMm(600), closeTo(8.727, 0.01));
      expect(line.decimal, 1.0);
      expect(line.label, '20/20');
    });

    test('strokes one fifth of the optotype height', () {
      final line = kAcuityLines.last;
      expect(line.strokeWidthMm(40), closeTo(line.optotypeHeightMm(40) / 5, 1e-9));
      expect(line.strokeWidthMm(40), closeTo(0.1164, 0.001));
    });

    test('scales larger lines by their Snellen ratio', () {
      final twentyTwenty = kAcuityLines.last.optotypeHeightMm(40);
      final twentyTwoHundred = kAcuityLines.first.optotypeHeightMm(40);
      expect(twentyTwoHundred / twentyTwenty, closeTo(10, 0.001));
    });

    test('runs the full Snellen progression from 20/200 down to 20/20', () {
      final denominators = [
        for (final line in kAcuityLines) line.snellenDenominator,
      ];
      expect(denominators, [200, 100, 70, 50, 40, 30, 25, 20]);
      // Monotonically finer, so the renderable subset is always a prefix.
      expect(
        denominators,
        orderedEquals(denominators.toList()..sort((a, b) => b.compareTo(a))),
      );
    });

    test('maps an acuity back to its line, and below-chart to null', () {
      expect(acuityLineFor(VisualAcuity.twentyForty)?.snellenDenominator, 40);
      expect(acuityLineFor(VisualAcuity.worseThanTwentyTwoHundred), isNull);
      // 20/10 is a real reading but not a line this chart presents.
      expect(acuityLineFor(VisualAcuity.twentyTen), isNull);
    });
  });

  group('protocol', () {
    test('needs three of four correct, and two misses end the line', () {
      expect(kOptotypesPerLine, 4);
      expect(kCorrectToPass, 3);
      expect(kWrongToFail, 2);
      // A line can never need more presentations than it holds.
      expect(kCorrectToPass + kWrongToFail - 1, kOptotypesPerLine);
    });

    test('blind guessing clears a line only 5.1% of the time', () {
      // Four orientations, so p = 0.25 per optotype. A guesser passes by
      // scoring at least kCorrectToPass before kWrongToFail misses.
      const p = 0.25;
      // Exactly 3 of 3, or 3 of 4 with the miss anywhere in the first three.
      final threeStraight = p * p * p;
      final oneMissThenThree = 3 * (1 - p) * p * p * p;
      expect(threeStraight + oneMissThenThree, closeTo(0.0508, 0.0005));
    });
  });

  group('renderableAcuityLines', () {
    test('keeps every line when the screen can draw a 20/20 stroke', () {
      final lines = renderableAcuityLines(
        pxPerMm: ScreenCalibration.defaultPxPerMm,
        distanceCm: 40,
        devicePixelRatio: 3.0,
      );
      expect(lines, hasLength(kAcuityLines.length));
      expect(lines.last.snellenDenominator, 20);
    });

    test('truncates the lines a low-density screen would smear', () {
      // At 40 cm and 1× density the 20/30 stroke is 0.995 device px — below
      // the one-pixel floor — so the chart stops at 20/40.
      final lines = renderableAcuityLines(
        pxPerMm: ScreenCalibration.defaultPxPerMm,
        distanceCm: 40,
        devicePixelRatio: 1.0,
      );
      expect(
        [for (final line in lines) line.snellenDenominator],
        [200, 100, 70, 50, 40],
      );
    });

    test('recovers the finer lines as the distance grows', () {
      final near = renderableAcuityLines(
        pxPerMm: ScreenCalibration.defaultPxPerMm,
        distanceCm: 40,
        devicePixelRatio: 1.0,
      );
      final far = renderableAcuityLines(
        pxPerMm: ScreenCalibration.defaultPxPerMm,
        distanceCm: 300,
        devicePixelRatio: 1.0,
      );
      expect(far.length, greaterThan(near.length));
      expect(far, hasLength(kAcuityLines.length));
    });

    test('never returns an empty chart', () {
      final lines = renderableAcuityLines(
        pxPerMm: 0.01,
        distanceCm: 40,
        devicePixelRatio: 1.0,
      );
      expect(lines, [kAcuityLines.first]);
    });
  });

  group('EyeResult', () {
    test('flags a below-chart score only when lines were actually shown', () {
      const measured = EyeResult(
        side: EyeSide.right,
        acuity: VisualAcuity.worseThanTwentyTwoHundred,
        correctAnswers: 1,
        totalAnswers: 2,
        passedLines: 0,
        linesPresented: 8,
      );
      expect(measured.belowChart, isTrue);
      expect(measured.cappedByScreen, isFalse);

      // A report rebuilt from a QR code carries no answer detail at all, and
      // must not be mistaken for a below-chart measurement.
      final decoded = VisionTestReport.decoded(
        right: VisualAcuity.twentyTwenty,
        left: VisualAcuity.twentyTwenty,
        distanceCm: 40,
        testedAtUtc: DateTime.utc(2026),
      );
      expect(decoded.right.belowChart, isFalse);
      expect(decoded.right.cappedByScreen, isFalse);
    });

    test('flags a chart the screen cut short', () {
      const capped = EyeResult(
        side: EyeSide.left,
        acuity: VisualAcuity.twentyForty,
        correctAnswers: 15,
        totalAnswers: 15,
        passedLines: 5,
        linesPresented: 5,
      );
      expect(capped.cappedByScreen, isTrue);
      expect(capped.accuracy, 1.0);
    });
  });

  group('EDirection', () {
    test('covers the four tumbling-E orientations', () {
      expect(EDirection.values, hasLength(4));
      expect(EDirection.right.radians, 0);
      expect(EDirection.down.quarterTurns, 1);
    });
  });

  testWidgets('a flawless run scores 20/20 in both eyes', (tester) async {
    VisionTestReport? report;
    await tester.pumpWidget(_harness(onDone: (r) => report = r));
    await _openAndStart(tester);

    final shown = <EDirection>[];
    for (var eye = 0; eye < 2; eye++) {
      final directions = await _runEye(tester, correct: true);
      // Three correct answers clear a line, so eight lines take 24 optotypes.
      expect(directions, hasLength(kAcuityLines.length * kCorrectToPass));
      shown.addAll(directions);
    }

    await tester.pumpAndSettle();
    expect(find.text('اكتمل فحص النظر'), findsOneWidget);
    expect(find.text('20/20'), findsNWidgets(2));

    // Orientations are drawn uniformly from all four, so a repeat is all but
    // certain over 48 presentations — the old chart excluded the previous
    // orientation, which handed a guesser one-in-three instead of one-in-four.
    var repeats = 0;
    for (var i = 1; i < shown.length; i++) {
      if (shown[i] == shown[i - 1]) repeats++;
    }
    expect(repeats, greaterThan(0));

    await _tapButton(tester, 'اعتماد النتيجة');

    expect(report, isNotNull);
    expect(report!.right.acuity, VisualAcuity.twentyTwenty);
    expect(report!.left.acuity, VisualAcuity.twentyTwenty);
    expect(report!.right.passedLines, kAcuityLines.length);
    expect(report!.right.linesPresented, kAcuityLines.length);
    expect(report!.right.belowChart, isFalse);
    expect(report!.right.cappedByScreen, isFalse);
    expect(report!.distanceCm, 40);
    expect(report!.methodLabel, contains('40 سم'));
  });

  testWidgets('failing the top line records a below-chart score, not 20/200',
      (tester) async {
    VisionTestReport? report;
    await tester.pumpWidget(_harness(onDone: (r) => report = r));
    await _openAndStart(tester);

    for (var eye = 0; eye < 2; eye++) {
      // Two misses end the line — and with the largest line failed, the eye.
      expect(await _runEye(tester, correct: false), hasLength(kWrongToFail));
    }

    await tester.pumpAndSettle();
    // Crediting an unread line to the examinee is the bug this guards.
    expect(find.text('20/200'), findsNothing);
    expect(find.text('أسوأ من 20/200'), findsNWidgets(2));

    await _tapButton(tester, 'اعتماد النتيجة');

    expect(report!.right.acuity, VisualAcuity.worseThanTwentyTwoHundred);
    expect(report!.right.passedLines, 0);
    expect(report!.right.belowChart, isTrue);
  });

  testWidgets('never reveals whether an answer was right', (tester) async {
    await tester.pumpWidget(_harness());
    await _openAndStart(tester);
    await _startEye(tester);

    for (final correct in [true, false]) {
      final shown = _shown(tester);
      final answer = correct
          ? shown
          : EDirection.values.firstWhere((d) => d != shown);
      await tester.tap(find.byIcon(_iconFor(answer)));
      await tester.pump();
      // Mid-blank: exactly where the old chart flashed a green or red frame.
      await tester.pump(const Duration(milliseconds: 150));

      expect(_borderColours(tester), isNot(contains(BrandColors.success)));
      expect(_borderColours(tester), isNot(contains(BrandColors.error)));
      // The optotype is hidden outright, leaving no afterimage to compare
      // the next one against.
      expect(_optotypeOpacity(tester), 0);

      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
    }
  });

  testWidgets('presents the whole eight-line chart', (tester) async {
    await tester.pumpWidget(_harness());
    await _openAndStart(tester);
    await _startEye(tester);

    expect(find.text('السطر 1 من 8 · 20/200'), findsOneWidget);

    // Clear the first line and the header advances to the next acuity.
    for (var i = 0; i < kCorrectToPass; i++) {
      await _answer(tester, correct: true);
    }
    expect(find.text('السطر 2 من 8 · 20/100'), findsOneWidget);
  });

  testWidgets('“cannot tell” counts as a miss and ends the line',
      (tester) async {
    await tester.pumpWidget(_harness());
    await _openAndStart(tester);
    await _startEye(tester);

    expect(find.text('السطر 1 من 8 · 20/200'), findsOneWidget);

    for (var i = 0; i < kWrongToFail; i++) {
      await tester.tap(find.text('لا أستطيع التمييز'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
    }
    await tester.pumpAndSettle();

    // The right eye is done; the app moves straight on to the left eye.
    expect(find.text('الآن نفحص العين اليسرى'), findsOneWidget);
  });
}
