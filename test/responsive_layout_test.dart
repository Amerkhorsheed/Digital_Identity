import 'package:a_digital_id/app/app.dart';
import 'package:a_digital_id/features/registration/registration_page.dart';
import 'package:a_digital_id/features/registration/widgets/flow_header.dart';
import 'package:a_digital_id/services/id_record_store.dart';
import 'package:a_digital_id/shared/widgets/adaptive_layout.dart';
import 'package:a_digital_id/shared/widgets/animations.dart';
import 'package:a_digital_id/shared/widgets/brand_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Boots the app straight into registration at a given logical size.
Future<void> _pumpRegistration(
  WidgetTester tester, {
  required Size logicalSize,
  double devicePixelRatio = 2.0,
  double topPadding = 0,
}) async {
  tester.view.devicePixelRatio = devicePixelRatio;
  tester.view.physicalSize = logicalSize * devicePixelRatio;
  if (topPadding > 0) {
    tester.view.padding =
        FakeViewPadding(top: topPadding * devicePixelRatio);
    tester.view.viewPadding =
        FakeViewPadding(top: topPadding * devicePixelRatio);
  }
  addTearDown(tester.view.reset);

  final store = await tester.runAsync(() => IdRecordStore.open());
  await tester.pumpWidget(ADigitalIdApp(storeOpener: () async => store!, enableDeepLinks: false));
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 3400));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Adaptive bands', () {
    test('map widths to phone, tablet, desktop and TV', () {
      expect(Adaptive.bandForWidth(390), ScreenBand.compact);
      expect(Adaptive.bandForWidth(599), ScreenBand.compact);
      expect(Adaptive.bandForWidth(600), ScreenBand.medium);
      expect(Adaptive.bandForWidth(834), ScreenBand.medium);
      expect(Adaptive.bandForWidth(1024), ScreenBand.expanded);
      expect(Adaptive.bandForWidth(1920), ScreenBand.television);
    });

    test('phones use one form column, everything else uses two', () {
      expect(ScreenBand.compact.formColumns, 1);
      expect(ScreenBand.medium.formColumns, 2);
      expect(ScreenBand.television.formColumns, 2);
    });

    test('scale grows with viewing distance', () {
      expect(ScreenBand.compact.scale, 1.0);
      expect(
        ScreenBand.television.scale,
        greaterThan(ScreenBand.expanded.scale),
      );
    });
  });

  testWidgets('the header clears the status bar instead of sliding under it',
      (tester) async {
    const topInset = 54.0;
    await _pumpRegistration(
      tester,
      logicalSize: const Size(400, 900),
      topPadding: topInset,
    );

    final header = find.byType(FlowHeader);
    expect(header, findsOneWidget);

    // The pine block itself starts at the very top of the screen…
    expect(tester.getTopLeft(header).dy, 0);

    // …but nothing inside it is drawn under the notch.
    final logo = tester.getTopLeft(find.byType(BrandLogo));
    expect(logo.dy, greaterThanOrEqualTo(topInset));
  });

  testWidgets('step content is visible immediately, without a tap',
      (tester) async {
    await _pumpRegistration(tester, logicalSize: const Size(400, 900));

    // Regression: entrance animations used to build from a controller they
    // never listened to, leaving every screen at opacity 0 until an unrelated
    // rebuild — usually a stray tap — happened to repaint it.
    final opacities = tester
        .widgetList<Opacity>(
          find.descendant(
            of: find.byType(Entrance),
            matching: find.byType(Opacity),
          ),
        )
        .toList();

    expect(opacities, isNotEmpty);
    for (final opacity in opacities) {
      expect(opacity.opacity, 1.0);
    }
    expect(find.text('الهوية الشخصية'), findsOneWidget);
  });

  testWidgets('phones show a single form column', (tester) async {
    await _pumpRegistration(tester, logicalSize: const Size(390, 844));

    expect(find.byType(RegistrationPage), findsOneWidget);
    // The trust badge is tablet-and-up chrome.
    expect(find.text('آمن · مشفّر · موثّق'), findsNothing);

    final first = tester.getRect(find.text('الاسم الأول'));
    final second = tester.getRect(find.text('اسم العائلة'));
    expect(second.top, greaterThan(first.bottom));
  });

  testWidgets('tablets show two form columns and the trust badge',
      (tester) async {
    await _pumpRegistration(tester, logicalSize: const Size(1024, 1366));

    expect(find.text('آمن · مشفّر · موثّق'), findsOneWidget);

    final first = tester.getRect(find.text('الاسم الأول'));
    final second = tester.getRect(find.text('اسم العائلة'));
    // Side by side on the same row.
    expect((first.center.dy - second.center.dy).abs(), lessThan(2));
  });

  testWidgets('short screens fold the brand row away to protect the form',
      (tester) async {
    await _pumpRegistration(tester, logicalSize: const Size(844, 390));

    // The wordmark row is dropped; the stepper stays.
    expect(find.text('مركز التسجيل والإصدار'), findsNothing);
    expect(find.text('الهوية'), findsOneWidget);
    expect(find.text('الاسم الأول'), findsOneWidget);
  });

  testWidgets('TV-sized screens keep the content in a readable column',
      (tester) async {
    await _pumpRegistration(tester, logicalSize: const Size(1920, 1080));

    final card = tester.getRect(find.byType(SectionCard).first);
    expect(card.width, lessThanOrEqualTo(ScreenBand.television.contentWidth));
    // …and centred rather than pinned to one edge.
    expect((card.center.dx - 960).abs(), lessThan(2));
  });
}
