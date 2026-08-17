import 'package:a_digital_id/app/app.dart';
import 'package:a_digital_id/app/theme/app_theme.dart';
import 'package:a_digital_id/features/idcard/id_result_page.dart';
import 'package:a_digital_id/models/applicant.dart';
import 'package:a_digital_id/services/id_record_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _applicant = Applicant(
  turnNumber: 'A-001',
  fullName: 'سارة محمد المزيد',
  birthYear: 2001,
  academicYear: AcademicYear.bachelor,
  governorate: 'دمشق',
  heightCm: 165,
  weightKg: 58.5,
  bloodType: BloodType.oPositive,
  rightEyeAcuity: VisualAcuity.twentyTwenty,
  leftEyeAcuity: VisualAcuity.twentyTwentyFive,
  hasBiometric: true,
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
    await tester.pumpWidget(ADigitalIdApp(storeOpener: () async => store!, enableDeepLinks: false));
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
    await _selectDropdown(tester, 'المرحلة الدراسية', 'إجازة جامعية (بكالوريوس)');
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
    expect(find.text('الصورة والبصمة البيومترية'), findsOneWidget);
    expect(find.text('التقاط صورة'), findsOneWidget);
    expect(find.text('اختيار من المكتبة'), findsNothing);
    expect(find.text('المسح والتوثيق البيومتري الحقيقي'), findsOneWidget);

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

    // The card opens on its front face and holds there — no endless spin.
    expect(find.text('إظهار ظهر البطاقة'), findsOneWidget);
    expect(find.byType(QrImageView), findsNothing);

    await tester.tap(find.text('إظهار ظهر البطاقة'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.text('إظهار وجه البطاقة'), findsOneWidget);
    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.text('بيانات الهوية'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    expect(find.text('إظهار وجه البطاقة'), findsOneWidget);
    expect(find.byType(QrImageView), findsOneWidget);
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

    await tester.tap(find.text('بدء تسجيل جديد'));
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
