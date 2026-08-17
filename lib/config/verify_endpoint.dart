/// عنوان صفحة التحقق المستضافة — الرابط الذي يحمله رمز QR على كل بطاقة.
///
/// ## لماذا رابط https وليس رابط تطبيق
///
/// كاميرا الهاتف (iOS وأندرويد) مبنية حول روابط https: تفتحها فورًا، وتفتح
/// التطبيق نفسه إن كان مثبّتًا (Universal Links / App Links). أما مخطط
/// التطبيق الخاص `adigitalid://` فلا تعرضه الكاميرا بشكل موثوق، ولا يفعل
/// شيئًا إطلاقًا على أي هاتف لا يحمل التطبيق — وهو حال كل من يمسح البطاقة.
///
/// ## كيف تُفعّله
///
/// 1. ارفع مجلد `web/verify/` كما هو على أي استضافة ثابتة مجانية
///    (GitHub Pages أو Netlify أو Cloudflare Pages).
/// 2. ضع عنوانه هنا بدل القيمة الافتراضية، أو مرّره عند البناء:
///
/// ```bash
/// flutter build ipa --dart-define=VERIFY_URL=https://example.com/id
/// ```
///
/// ما دامت القيمة غير مضبوطة يعود الرمز تلقائيًا إلى رابط التطبيق، فلا
/// ينكسر شيء قبل الاستضافة.
///
/// ## الخصوصية
///
/// تُوضع بيانات البطاقة في **جزء التجزئة** من الرابط (بعد `#`)، وهذا الجزء
/// لا يُرسل إلى الخادم أبدًا وفق معيار HTTP — فالصفحة تفك الترميز محليًا في
/// المتصفح ولا تغادر بيانات الشخص جهازه.
library;

/// النطاق المحجوز `.invalid` لا يمكن أن يوجد فعليًا (RFC 2606)، فهو علامة
/// لا تلتبس على أن العنوان لم يُضبط بعد.
const String kUnsetVerifierBase = 'https://unset.invalid/id';

const String kVerifierBaseUrl = String.fromEnvironment(
  'VERIFY_URL',
  defaultValue: 'https://adigitalid-verify.pages.dev',
);

/// هل ضُبط عنوان صفحة تحقق حقيقي؟
bool get kHasHostedVerifier =>
    kVerifierBaseUrl.isNotEmpty &&
    !kVerifierBaseUrl.contains('unset.invalid') &&
    Uri.tryParse(kVerifierBaseUrl)?.hasScheme == true;
