import 'package:a_digital_id/features/eyetest/eye_test_page.dart';
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

/// Answers one optotype, either correctly or with a deliberate miss.
Future<void> _answer(WidgetTester tester, {required bool correct}) async {
  final shown = _shown(tester);
  final answer = correct
      ? shown
      : EDirection.values.firstWhere((d) => d != shown);
  await tester.tap(find.byIcon(_iconFor(answer)));
  await tester.pump();
  // The chart holds a short confirmation flash, then advances — settle fully
  // so the next optotype (or the next eye's brief) is the only thing on screen.
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();
}

Future<void> _startEye(WidgetTester tester) async {
  await tester.tap(find.text('أنا جاهز — ابدأ'));
  await tester.pumpAndSettle();
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

    test('scales larger lines by their Snellen ratio', () {
      final twentyTwenty = kAcuityLines.last.optotypeHeightMm(40);
      final twentyTwoHundred = kAcuityLines.first.optotypeHeightMm(40);
      expect(twentyTwoHundred / twentyTwenty, closeTo(10, 0.001));
    });

    test('runs five lines from 20/200 down to 20/20', () {
      expect(kAcuityLines, hasLength(5));
      expect(kAcuityLines.first.snellenDenominator, 200);
      expect(kAcuityLines.last.snellenDenominator, 20);
      final denominators = [
        for (final line in kAcuityLines) line.snellenDenominator,
      ];
      expect(denominators, [200, 100, 50, 30, 20]);
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
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    VisionTestReport? report;
    await tester.pumpWidget(_harness(onDone: (r) => report = r));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('ابدأ فحص العين اليمنى'));
    await tester.pumpAndSettle();

    for (var eye = 0; eye < 2; eye++) {
      await _startEye(tester);
      // Two correct answers clear a line, so five lines take ten optotypes.
      var answered = 0;
      while (_optotype.evaluate().isNotEmpty && answered < 30) {
        await _answer(tester, correct: true);
        answered++;
      }
      expect(answered, kAcuityLines.length * kCorrectToPass);
    }

    await tester.pumpAndSettle();
    expect(find.text('اكتمل فحص النظر'), findsOneWidget);
    expect(find.text('20/20'), findsNWidgets(2));

    await tester.tap(find.text('اعتماد النتيجة'));
    await tester.pumpAndSettle();

    expect(report, isNotNull);
    expect(report!.right.acuity, VisualAcuity.twentyTwenty);
    expect(report!.left.acuity, VisualAcuity.twentyTwenty);
    expect(report!.right.passedLines, kAcuityLines.length);
    expect(report!.distanceCm, 40);
    expect(report!.methodLabel, contains('40 سم'));
  });

  testWidgets('failing the first line floors the score at 20/200',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    VisionTestReport? report;
    await tester.pumpWidget(_harness(onDone: (r) => report = r));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ابدأ فحص العين اليمنى'));
    await tester.pumpAndSettle();

    for (var eye = 0; eye < 2; eye++) {
      await _startEye(tester);
      var answered = 0;
      while (_optotype.evaluate().isNotEmpty && answered < 10) {
        await _answer(tester, correct: false);
        answered++;
      }
      // Two misses end the line — and with the largest line failed, the eye.
      expect(answered, 2);
    }

    await tester.pumpAndSettle();
    expect(find.text('20/200'), findsNWidgets(2));

    await tester.tap(find.text('اعتماد النتيجة'));
    await tester.pumpAndSettle();

    expect(report!.right.acuity, VisualAcuity.twentyTwoHundred);
    expect(report!.right.passedLines, 0);
  });

  testWidgets('“cannot tell” counts as a miss and ends the line',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_harness());
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ابدأ فحص العين اليمنى'));
    await tester.pumpAndSettle();
    await _startEye(tester);

    expect(find.text('السطر 1 من 5 · 20/200'), findsOneWidget);

    for (var i = 0; i < 2; i++) {
      await tester.tap(find.text('لا أستطيع التمييز'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
    }
    await tester.pumpAndSettle();

    // The right eye is done; the app moves straight on to the left eye.
    expect(find.text('الآن نفحص العين اليسرى'), findsOneWidget);
  });
}
