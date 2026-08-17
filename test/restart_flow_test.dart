import 'dart:io';

import 'package:a_digital_id/app/app.dart';
import 'package:a_digital_id/features/idcard/id_result_page.dart';
import 'package:a_digital_id/services/id_record_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Hands the photo step a real file so the whole journey can be walked.
class _FakeImagePicker extends ImagePickerPlatform
    with MockPlatformInterfaceMixin {
  _FakeImagePicker(this.path);

  final String path;

  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions options = const ImagePickerOptions(),
  }) async {
    return XFile(path);
  }
}

Future<void> _selectDropdown(
  WidgetTester tester,
  String label,
  String option,
) async {
  final field = find.ancestor(
    of: find.text(label),
    matching: find.byType(Column),
  );
  final button = find.descendant(
    of: field.first,
    matching: find.byWidgetPredicate(
      (widget) => widget is DropdownButtonFormField<Object?>,
    ),
  );
  await tester.ensureVisible(button.first);
  await tester.pumpAndSettle();
  await tester.tap(button.first);
  await tester.pumpAndSettle();
  await tester.tap(find.text(option).last);
  await tester.pumpAndSettle();
}

Future<void> _enterText(WidgetTester tester, int index, String text) async {
  final field = find.byType(TextField).at(index);
  await tester.ensureVisible(field);
  await tester.pumpAndSettle();
  await tester.enterText(field, text);
  await tester.pumpAndSettle();
}

Future<void> _tapText(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.text(label).first);
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).first);
  await tester.pumpAndSettle();
}

void main() {
  late Directory tempDir;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    tempDir = Directory.systemTemp.createTempSync('a-id-restart');
    final photo = File('${tempDir.path}/portrait.png')
      // A 1×1 PNG is enough: the flow only needs a readable file on disk.
      ..writeAsBytesSync([
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
        0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
        0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
        0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
        0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
        0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
        0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
        0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
        0x42, 0x60, 0x82,
      ]);
    ImagePickerPlatform.instance = _FakeImagePicker(photo.path);
  });

  tearDownAll(() => tempDir.deleteSync(recursive: true));

  testWidgets('“بدء تسجيل جديد” clears the journey and returns to step one',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    final store = await tester.runAsync(() => IdRecordStore.open());
    await tester.pumpWidget(
      ADigitalIdApp(storeOpener: () async => store!, enableDeepLinks: false),
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 3400));
    await tester.pumpAndSettle();

    // Step 1
    await _enterText(tester, 0, 'سارة');
    await _enterText(tester, 1, 'الحلبي');
    await _selectDropdown(tester, 'المرحلة الدراسية', 'إجازة جامعية (بكالوريوس)');
    await _selectDropdown(tester, 'التخصص الدراسي', 'هندسة وتكنولوجيا');
    await _selectDropdown(tester, 'المحافظة', 'ريف دمشق');
    await _tapText(tester, 'اختر المدينة');
    await tester.tap(find.text('دوما').last);
    await tester.pumpAndSettle();
    await _tapText(tester, 'متابعة');

    // Step 2
    await _enterText(tester, 0, '165');
    await _enterText(tester, 1, '58.5');
    await _selectDropdown(tester, 'فصيلة الدم', 'O+');
    await _selectDropdown(tester, 'تصحيح الإبصار', 'نظارات');
    await _tapText(tester, 'لديّ تقرير طبي جاهز');
    await _selectDropdown(tester, 'العين اليمنى — حدة الإبصار', '20/20');
    await _selectDropdown(tester, 'العين اليسرى — حدة الإبصار', '20/30');
    await _tapText(tester, 'متابعة');

    // Step 3
    await _tapText(tester, 'التقاط صورة');
    expect(find.text('تم التقاط الصورة — تبدو رائعة!'), findsOneWidget);

    // From here on the result page pulses its success badge forever by
    // design, so the test pumps explicit frames instead of settling.
    await tester.ensureVisible(find.text('إصدار بطاقة الهوية'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('إصدار بطاقة الهوية'));
    await tester.pump();
    // Issuing hashes the ID and writes to SQLite — real async work that only
    // progresses outside the fake-async test zone.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 400)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
    expect(find.byType(IdResultPage), findsOneWidget);
    expect(find.text('بطاقة هويتك جاهزة'), findsOneWidget);

    await tester.ensureVisible(find.text('بدء تسجيل جديد'));
    await tester.pump();
    await tester.tap(find.text('بدء تسجيل جديد'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pumpAndSettle();

    // Back at a genuinely blank step one — not the filled form the old build
    // popped back to.
    expect(find.byType(IdResultPage), findsNothing);
    expect(find.text('الهوية الشخصية'), findsOneWidget);
    expect(find.text('سارة'), findsNothing);
    expect(find.text('الحلبي'), findsNothing);
    expect(find.text('دوما'), findsNothing);
    expect(find.text('اختر المدينة'), findsNothing);
    expect(find.text('اختر المحافظة أولًا'), findsOneWidget);
    expect(find.text('متابعة'), findsOneWidget);

    for (final field in tester.widgetList<TextField>(find.byType(TextField))) {
      expect(field.controller?.text ?? '', isEmpty);
    }
  });
}
