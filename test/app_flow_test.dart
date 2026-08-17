import 'package:a_digital_id/app/app.dart';
import 'package:a_digital_id/services/id_record_store.dart';
import 'package:a_digital_id/app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets('splash shows the brand mark, then hands off to registration',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    final store = await tester.runAsync(() => IdRecordStore.open());

    await tester.pumpWidget(
      ADigitalIdApp(storeOpener: () async => store!, enableDeepLinks: false),
    );
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('الهوية الرقمية'), findsWidgets);

    await tester.pump(const Duration(milliseconds: 3600));
    await tester.pumpAndSettle();

    expect(find.text('الهوية الشخصية'), findsOneWidget);
    expect(find.text('الاسم الأول'), findsOneWidget);
  });

  test('theme uses the brand palette', () {
    final theme = AppTheme.light;
    expect(theme.colorScheme.primary, const Color(0xFF17352F));
    expect(theme.colorScheme.secondary, const Color(0xFF8A7443));
    expect(theme.scaffoldBackgroundColor, const Color(0xFFFAF7EF));
  });
}
