import 'dart:io';

import 'package:a_digital_id/app/app.dart';
import 'package:a_digital_id/features/idcard/id_result_page.dart';
import 'package:a_digital_id/features/registration/widgets/fingerprint_pad.dart';
import 'package:a_digital_id/services/biometric_service.dart';
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

/// A tablet with no enrolled fingerprint — the realistic shared-device case,
/// where every applicant uses the on-screen capture pad.
class _NoEnrolledSensor extends BiometricService {
  @override
  Future<BiometricCapabilities> capabilities() async =>
      const BiometricCapabilities(
        availability: BiometricAvailability.notEnrolled,
      );
}

/// Holds a finger steady on the capture pad until the read completes.
Future<void> _captureFingerprint(WidgetTester tester) async {
  final pad = find.byType(FingerprintPad);
  await tester.ensureVisible(pad);
  await tester.pumpAndSettle();

  final finger = await tester.startGesture(tester.getCenter(pad));
  await tester.pump();
  // Lifting early aborts the read, so the finger must stay down for the
  // whole dwell — exactly as an applicant has to.
  await tester.pump(const Duration(milliseconds: 2600));
  await finger.up();
  await tester.pumpAndSettle();
}

void main() {
  late Directory tempDir;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    tempDir = Directory.systemTemp.createTempSync('a-id-restart');
    final photo = File('${tempDir.path}/portrait.png')
      ..writeAsBytesSync([
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
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

  testWidgets('“بدء تسجيل جديد” clears the journey and returns to step zero (Turn reservation)',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    final store = await tester.runAsync(() => IdRecordStore.open());
    await tester.pumpWidget(
      ADigitalIdApp(
        storeOpener: () async => store!,
        enableDeepLinks: false,
        biometricService: _NoEnrolledSensor(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 3400));
    await tester.pumpAndSettle();

    // Step 0 — Turn Reservation
    expect(find.text('مرحلة قطع الدور'), findsOneWidget);
    expect(find.text('A-001'), findsWidgets);
    await _tapText(tester, 'التالي');

    // Step 1 — Identity
    await _enterText(tester, 0, 'سارة محمد الحلبي');
    await _enterText(tester, 1, '2001');
    await _selectDropdown(tester, 'المرحلة الدراسية', 'جامعة');
    await _selectDropdown(tester, 'المحافظة', 'ريف دمشق');
    await _tapText(tester, 'متابعة');

    // Step 2 — Health
    await _selectDropdown(tester, 'فصيلة الدم', 'O+');
    await _tapText(tester, 'لديّ تقرير طبي جاهز (إدخال يدوي)');
    await _selectDropdown(tester, 'العين اليمنى — حدة الإبصار', '20/20');
    await _selectDropdown(tester, 'العين اليسرى — حدة الإبصار', '20/30');
    await _tapText(tester, 'متابعة');

    // Step 3 — Photo & Biometric
    await _tapText(tester, 'التقاط صورة');
    expect(find.text('تم التقاط الصورة — تبدو رائعة ومكتملة!'), findsOneWidget);

    // A real match on the device's own fingerprint sensor.
    await _captureFingerprint(tester);
    // A touch capture is recorded as captured, not as a signed hardware match.
    expect(find.text('مُلتقطة'), findsOneWidget);
    expect(find.text('التقاط بصمة — لوحة اللمس'), findsOneWidget);

    await tester.ensureVisible(find.text('إصدار بطاقة الهوية'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('إصدار بطاقة الهوية'));
    await tester.pump();
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

    expect(find.byType(IdResultPage), findsNothing);
    expect(find.text('مرحلة قطع الدور'), findsOneWidget);
    expect(find.text('رقم دورك'), findsOneWidget);
    expect(find.text('A-002'), findsWidgets);
    expect(find.text('التالي'), findsOneWidget);
  });
}
