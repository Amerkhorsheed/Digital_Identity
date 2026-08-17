import 'package:a_digital_id/features/registration/widgets/fingerprint_pad.dart';
import 'package:a_digital_id/services/touch_capture.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pumps the pad on its own and reports whatever capture it produces.
Future<TouchMetrics?> _runPad(
  WidgetTester tester, {
  required Duration hold,
  Offset drift = Offset.zero,
}) async {
  TouchMetrics? captured;

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: FingerprintPad(
            onCaptured: (metrics, _) => captured = metrics,
          ),
        ),
      ),
    ),
  );

  // Touch the plate itself: the leading 210px square of the pad column,
  // horizontally centred. The column's own centre sits in the caption below.
  final pad = find.byType(FingerprintPad);
  final plateCentre = Offset(
    tester.getCenter(pad).dx,
    tester.getTopLeft(pad).dy + 105,
  );

  final finger = await tester.startGesture(plateCentre);
  await tester.pump();

  if (drift != Offset.zero) {
    await finger.moveBy(drift);
    await tester.pump();
  }

  await tester.pump(hold);
  await finger.up();
  await tester.pumpAndSettle();

  return captured;
}

void main() {
  testWidgets('a brief, ordinary placement captures on lift', (tester) async {
    // The core fix: a finger lifted before the full read still succeeds,
    // the way a real sensor completes as soon as it has enough data.
    final metrics = await _runPad(
      tester,
      hold: const Duration(milliseconds: 700),
    );

    expect(metrics, isNotNull, reason: 'lifting past the minimum must capture');
    expect(metrics!.accepted, isTrue);
    expect(metrics.metMinimum, isTrue);
    expect(find.textContaining('اكتملت القراءة'), findsOneWidget);
  });

  testWidgets('holding for the full read also captures', (tester) async {
    final metrics = await _runPad(
      tester,
      hold: const Duration(milliseconds: 1400),
    );

    expect(metrics, isNotNull);
    expect(metrics!.dwell, 1.0);
    expect(find.textContaining('اكتملت القراءة'), findsOneWidget);
  });

  testWidgets('a tap too brief to read asks for another try', (tester) async {
    final metrics = await _runPad(
      tester,
      hold: const Duration(milliseconds: 150),
    );

    expect(metrics, isNull);
    expect(find.textContaining('لمسة قصيرة'), findsOneWidget);
  });

  testWidgets('a swipe is rejected, not mistaken for a placement',
      (tester) async {
    final metrics = await _runPad(
      tester,
      hold: const Duration(milliseconds: 1400),
      drift: const Offset(140, 0),
    );

    expect(metrics, isNull);
    expect(find.textContaining('مُرِّر الإصبع'), findsOneWidget);
  });

  testWidgets('a small wobble does not cost the applicant a retry',
      (tester) async {
    final metrics = await _runPad(
      tester,
      hold: const Duration(milliseconds: 900),
      drift: const Offset(18, 6),
    );

    expect(
      metrics,
      isNotNull,
      reason: 'a finger resting on glass always moves a little',
    );
    expect(metrics!.swiped, isFalse);
  });
}
