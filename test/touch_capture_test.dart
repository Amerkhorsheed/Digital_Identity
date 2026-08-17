import 'package:a_digital_id/services/touch_capture.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';

const Duration _dwell = Duration(milliseconds: 1100);
const Duration _minimum = Duration(milliseconds: 550);

TouchCaptureRecorder _recorder() => TouchCaptureRecorder(
      requiredDwell: _dwell,
      minimumDwell: _minimum,
    );

PointerDownEvent _down(
  Offset at, {
  double pressure = 0.5,
  double radiusMajor = 18,
}) =>
    PointerDownEvent(
      position: at,
      pressure: pressure,
      radiusMajor: radiusMajor,
      radiusMinor: radiusMajor * 0.8,
    );

PointerMoveEvent _move(
  Offset at, {
  double pressure = 0.5,
  double radiusMajor = 18,
}) =>
    PointerMoveEvent(
      position: at,
      pressure: pressure,
      radiusMajor: radiusMajor,
      radiusMinor: radiusMajor * 0.8,
    );

/// Drives a recorder through a hold, returning its final metrics.
TouchMetrics _hold(
  TouchCaptureRecorder recorder, {
  Offset origin = const Offset(200, 300),
  double jitter = 3,
  Duration held = _dwell,
  double pressure = 0.5,
  double radiusMajor = 18,
}) {
  recorder.begin(_down(origin, pressure: pressure, radiusMajor: radiusMajor));
  // A panel that does not support pressure reports a constant 1.0; one that
  // does shows small variation as the finger settles.
  final supportsPressure = pressure < 1.0;
  for (var i = 1; i <= 12; i++) {
    final t = Duration(microseconds: held.inMicroseconds * i ~/ 12);
    recorder.update(
      _move(
        origin + Offset(i.isEven ? jitter : -jitter, jitter / 2),
        pressure: supportsPressure
            ? pressure + (i.isEven ? 0.01 : -0.01)
            : pressure,
        radiusMajor: radiusMajor,
      ),
      t,
    );
  }
  recorder.tick(held);
  return recorder.metrics();
}

void main() {
  group('a normal finger placement is accepted', () {
    late TouchMetrics metrics;

    setUp(() => metrics = _hold(_recorder()));

    test('passes without needing a retry', () {
      expect(
        metrics.accepted,
        isTrue,
        reason: 'rejected with "${metrics.failureReason}" — $metrics',
      );
      expect(metrics.score, greaterThanOrEqualTo(TouchMetrics.acceptThreshold));
    });

    test('records the contact the touchscreen actually reported', () {
      expect(metrics.contactReported, isTrue);
      expect(metrics.meanRadiusPx, closeTo(18, 0.5));
      expect(metrics.sampleCount, greaterThan(10));
    });
  });

  group('reads complete like a real sensor, not on a fixed timer', () {
    test('lifting after the minimum still succeeds', () {
      // The behaviour that made the old pad frustrating: a finger lifted at
      // 70% threw the whole read away. A real sensor has already captured.
      final metrics = _hold(
        _recorder(),
        held: const Duration(milliseconds: 700),
      );

      expect(metrics.metMinimum, isTrue);
      expect(metrics.dwell, lessThan(1.0));
      expect(
        metrics.accepted,
        isTrue,
        reason: 'an early lift past the minimum must not fail — $metrics',
      );
    });

    test('a full hold scores higher than a minimal one', () {
      final quick = _hold(
        _recorder(),
        held: const Duration(milliseconds: 600),
      );
      final full = _hold(_recorder(), held: _dwell);

      expect(quick.accepted, isTrue);
      expect(full.accepted, isTrue);
      expect(full.score, greaterThan(quick.score));
    });

    test('ordinary wobble does not cost a retry', () {
      // 20px of drift is normal for a finger resting on glass.
      final metrics = _hold(_recorder(), jitter: 20);

      expect(metrics.swiped, isFalse);
      expect(
        metrics.accepted,
        isTrue,
        reason: 'a steady-enough finger must not be rejected — $metrics',
      );
    });
  });

  group('only a genuinely unreadable placement is rejected', () {
    test('a tap too brief to read', () {
      final metrics = _hold(
        _recorder(),
        held: const Duration(milliseconds: 200),
      );

      expect(metrics.metMinimum, isFalse);
      expect(metrics.accepted, isFalse);
      expect(metrics.failureReason, contains('لمسة قصيرة'));
    });

    test('a swipe across the pad', () {
      final recorder = _recorder();
      const origin = Offset(200, 300);
      recorder.begin(_down(origin));

      final withinTolerance = recorder.update(
        _move(origin + const Offset(140, 0)),
        const Duration(milliseconds: 300),
      );
      expect(withinTolerance, isFalse);

      recorder.tick(_dwell);
      final metrics = recorder.metrics();
      expect(metrics.swiped, isTrue);
      expect(metrics.accepted, isFalse);
      expect(metrics.failureReason, contains('مُرِّر الإصبع'));
    });

    test('a fingernail tip rather than the pad of the finger', () {
      final metrics = _hold(_recorder(), radiusMajor: 1);

      expect(metrics.contactReported, isTrue);
      expect(metrics.accepted, isFalse);
      expect(metrics.failureReason, contains('منطقة تماسّ'));
    });

    test('no contact at all scores zero', () {
      final metrics = _recorder().metrics();
      expect(metrics, same(TouchMetrics.empty));
      expect(metrics.score, 0);
      expect(metrics.accepted, isFalse);
    });
  });

  group('scoring adapts to what the hardware reports', () {
    test('a panel with no pressure support still passes', () {
      // Android panels commonly report a constant 1.0 pressure, meaning
      // "unsupported". Scoring that as zero firmness would fail every capture.
      final metrics = _hold(_recorder(), pressure: 1.0);

      expect(metrics.pressureReported, isFalse);
      expect(metrics.firmness, 0.0);
      expect(metrics.accepted, isTrue, reason: '$metrics');
    });

    test('a panel reporting no contact area still passes', () {
      final metrics = _hold(_recorder(), radiusMajor: 0);

      expect(metrics.contactReported, isFalse);
      expect(metrics.accepted, isTrue, reason: '$metrics');
    });
  });

  group('attestation digest', () {
    test('is a full SHA-256 tied to the measurements', () async {
      final recorder = _recorder();
      final metrics = _hold(recorder);
      final at = DateTime.utc(2026, 8, 17, 10, 30);

      final digest = await recorder.digest(metrics, at);

      expect(digest, hasLength(64));
      expect(digest, matches(RegExp(r'^[0-9a-f]{64}$')));
      expect(await recorder.digest(metrics, at), digest);
    });

    test('differs when the capture instant differs', () async {
      final recorder = _recorder();
      final metrics = _hold(recorder);

      expect(
        await recorder.digest(metrics, DateTime.utc(2026, 8, 17, 10, 30)),
        isNot(await recorder.digest(metrics, DateTime.utc(2026, 8, 17, 10, 31))),
      );
    });

    test('differs when the finger travelled a different path', () async {
      final a = _recorder();
      final b = _recorder();
      final at = DateTime.utc(2026, 8, 17, 10, 30);

      final metricsA = _hold(a, jitter: 2);
      final metricsB = _hold(b, jitter: 9);

      expect(
        await a.digest(metricsA, at),
        isNot(await b.digest(metricsB, at)),
      );
    });
  });
}
