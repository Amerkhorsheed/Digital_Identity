import 'package:a_digital_id/app/app.dart';
import 'package:a_digital_id/app/theme/app_theme.dart';
import 'package:a_digital_id/features/idcard/id_result_page.dart';
import 'package:a_digital_id/models/applicant.dart';
import 'package:a_digital_id/models/biometric_capture.dart';
import 'package:a_digital_id/services/biometric_service.dart';
import 'package:a_digital_id/services/id_record_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

final _applicant = Applicant(
  turnNumber: 'A-001',
  fullName: 'سارة محمد المزيد',
  birthYear: 2001,
  academicYear: AcademicYear.university,
  governorate: 'دمشق',
  heightCm: 165,
  weightKg: 58.5,
  bloodType: BloodType.oPositive,
  rightEyeAcuity: VisualAcuity.twentyTwenty,
  leftEyeAcuity: VisualAcuity.twentyTwentyFive,
  biometric: BiometricCapture(
    method: BiometricMethod.fingerprint,
    capturedAtUtc: DateTime.utc(2026, 8, 16, 9, 25),
    sensorLabel: 'مستشعر بصمة الإصبع',
    attestation:
        '9f2a4c1b7e05d38a6c4b0f19d27e5a3c8b6104ff2d9e7a5c3b18604d7e2f9a1c',
  ),
);

Future<void> _selectDropdown(
  WidgetTester tester,
  String label,
  String option,
) async {
  final dropdown = find.ancestor(
    of: find.text(label),
    matching: find.byType(Column),
  );
  expect(dropdown, findsWidgets);
  final button = find.descendant(
    of: dropdown.first,
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

Future<void> _enterText(WidgetTester tester, int fieldIndex, String text) async {
  final field = find.byType(TextField).at(fieldIndex);
  await tester.ensureVisible(field);
  await tester.pumpAndSettle();
  await tester.enterText(field, text);
  await tester.pumpAndSettle();
}

/// A device whose fingerprint sensor is present, enrolled, and matches.
///
/// Standing in for `BiometricPrompt` / Touch ID lets the test drive the real
/// hardware branch of the panel — the branch that runs on a phone that has an
/// enrolled finger — without a platform channel.
class _EnrolledSensor extends BiometricService {
  @override
  Future<BiometricCapabilities> capabilities() async =>
      BiometricCapabilities(
        availability: BiometricAvailability.ready,
        enrolledTypes: const [BiometricType.fingerprint],
      );

  @override
  Future<BiometricAuthResult> authenticate({
    required BiometricCapabilities capabilities,
  }) async {
    return BiometricAuthResult.success(
      BiometricCapture(
        method: BiometricMethod.fingerprint,
        capturedAtUtc: DateTime.utc(2026, 8, 16, 9, 25),
        sensorLabel: 'مستشعر بصمة الإصبع',
        attestation:
            '4d1e8b7a3c05f29d6b8e1047c3a95f2e8d7b6041a9c3e5f7b2d840196ace7f3b',
      ),
    );
  }
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets('walks through all registration steps including turn reservation in Arabic',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    final store = await tester.runAsync(() => IdRecordStore.open());
    await tester.pumpWidget(
      ADigitalIdApp(
        storeOpener: () async => store!,
        enableDeepLinks: false,
        biometricService: _EnrolledSensor(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 3400));
    await tester.pumpAndSettle();

    // Step 0 — Turn Reservation
    expect(find.text('مرحلة قطع الدور'), findsOneWidget);
    expect(find.text('رقم دورك'), findsOneWidget);
    expect(find.text('A-001'), findsWidgets);
    await tester.tap(find.text('التالي'));
    await tester.pumpAndSettle();

    // Step 1 — identity
    expect(find.text('الهوية الشخصية'), findsOneWidget);
    await _enterText(tester, 0, 'سارة محمد المزيد');
    await _enterText(tester, 1, '2001');
    await _selectDropdown(tester, 'المرحلة الدراسية', 'جامعة');
    await _selectDropdown(tester, 'المحافظة', 'دمشق');

    await tester.tap(find.text('متابعة'));
    await tester.pumpAndSettle();

    // Step 2 — health
    expect(find.text('الملف الصحي'), findsOneWidget);
    await _selectDropdown(tester, 'فصيلة الدم', 'O+');

    // The eye test is required before the step can be completed.
    expect(find.text('بدء فحص النظر السريع الآن'), findsOneWidget);
    await tester.tap(find.text('متابعة'));
    await tester.pumpAndSettle();
    expect(
      find.text('أجرِ فحص النظر أو أدخل نتيجة تقريرك الطبي'),
      findsOneWidget,
    );

    // Manual entry satisfies it for users holding an optometrist's report.
    await tester.tap(find.text('لديّ تقرير طبي جاهز (إدخال يدوي)'));
    await tester.pumpAndSettle();
    await _selectDropdown(tester, 'العين اليمنى — حدة الإبصار', '20/20');
    await _selectDropdown(tester, 'العين اليسرى — حدة الإبصار', '20/25');

    await tester.tap(find.text('متابعة'));
    await tester.pumpAndSettle();

    // Step 3 — photo & biometric
    expect(find.text('الصورة والبصمة'), findsOneWidget);
    expect(find.text('التقاط صورة'), findsOneWidget);
    expect(find.text('اختيار من المكتبة'), findsNothing);
    expect(find.text('تسجيل البصمة'), findsOneWidget);

    // The device this test simulates has an enrolled sensor, so the signed
    // hardware match is offered alongside the pad.
    expect(
      find.text('مطابقة موقّعة عبر مستشعر بصمة الإصبع'),
      findsOneWidget,
    );

    final scanButton = find.text('مطابقة موقّعة عبر مستشعر بصمة الإصبع');
    await tester.ensureVisible(scanButton);
    await tester.pumpAndSettle();
    await tester.tap(scanButton);
    await tester.pumpAndSettle();

    // A successful match records its provenance, not just a boolean, and a
    // signed hardware match is labelled as verified.
    expect(find.text('موثقة'), findsOneWidget);
    expect(find.text('بصمة إصبع — مستشعر الجهاز'), findsOneWidget);
    expect(find.textContaining('4D1E-8B7A-3C05'), findsOneWidget);

    await tester.tap(find.text('إصدار بطاقة الهوية'));
    await tester.pumpAndSettle();
    expect(find.text('الصورة مطلوبة لإصدار بطاقة الهوية'), findsOneWidget);
  });

  testWidgets('result page renders the Arabic card and download actions',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: IdResultPage(
          applicant: _applicant,
          personalId: 'A-260816-TEST12',
          issuedAt: DateTime.utc(2026, 8, 16),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 1000));

    expect(find.text('بطاقة هويتك جاهزة'), findsOneWidget);
    expect(find.textContaining('A-260816-TEST12'), findsWidgets);
    expect(find.text('تنزيل صورة PNG'), findsNothing);
    expect(find.text('تنزيل مستند PDF'), findsNothing);
    expect(find.text('طباعة أو حفظ في الملفات'), findsNothing);
    expect(find.text('البيانات المضمنة في الرمز'), findsNothing);
    expect(find.text('بدء تسجيل جديد'), findsOneWidget);

    // Both faces are open at once: nothing flips, and the QR is on screen
    // from the first frame rather than hiding behind a back face.
    expect(find.text('إظهار ظهر البطاقة'), findsNothing);
    expect(find.text('إظهار وجه البطاقة'), findsNothing);
    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.text('بيانات الهوية'), findsOneWidget);
    expect(find.text('تكبير رمز التحقق'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.text('بيانات الهوية'), findsOneWidget);
  });

  testWidgets('“بدء تسجيل جديد” returns to an empty step one', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    bool? popped;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  popped = await Navigator.of(context).push<bool>(
                    MaterialPageRoute<bool>(
                      builder: (_) => IdResultPage(
                        applicant: _applicant,
                        personalId: 'A-260816-TEST12',
                        issuedAt: DateTime.utc(2026, 8, 16),
                      ),
                    ),
                  );
                },
                child: const Text('issue'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('issue'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));

    // The success badge pulses forever, so the page never settles — the scroll
    // has to be pumped out by hand rather than waited on.
    final restart = find.text('بدء تسجيل جديد');
    await tester.ensureVisible(restart);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(restart);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(popped, isTrue);
  });

  testWidgets('a scanned card is framed for viewing, not for re-issuing',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: IdResultPage(
          applicant: _applicant,
          personalId: 'A-260816-TEST12',
          issuedAt: DateTime.utc(2026, 8, 16),
          mode: IdResultMode.scanned,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 1000));

    expect(find.text('تمت قراءة البطاقة'), findsOneWidget);
    expect(find.text('تنزيل صورة PNG'), findsNothing);
    expect(find.text('تنزيل مستند PDF'), findsNothing);
    expect(find.text('مسح بطاقة أخرى'), findsOneWidget);
    expect(find.text('بدء تسجيل جديد'), findsNothing);
  });
}
