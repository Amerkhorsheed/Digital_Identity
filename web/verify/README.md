# صفحة التحقق — `web/verify/`

صفحة ثابتة واحدة تفتح بطاقة الهوية من رمز QR وتنزّلها PNG أو PDF، بلا خادم
وبلا تثبيت التطبيق.

## الرفع (دقيقتان)

ارفع محتويات هذا المجلد كما هي على أي استضافة ثابتة:

- **GitHub Pages**: ادفع المجلد إلى مستودع، ثم Settings → Pages → فرع `main`.
- **Netlify / Cloudflare Pages**: اسحب المجلد وأفلته في لوحة التحكم.

ثم اضبط العنوان في التطبيق:

```bash
flutter build ipa --dart-define=VERIFY_URL=https://YOUR-HOST/id
flutter build apk --release --dart-define=VERIFY_URL=https://YOUR-HOST/id
```

أو غيّر `defaultValue` في `lib/config/verify_endpoint.dart` مرة واحدة.

> يجب أن يشير `VERIFY_URL` إلى المسار الذي يخدم `index.html` من هذا المجلد.

## فتح التطبيق مباشرة بدل الصفحة (اختياري)

إن أردت أن يفتح التطبيق نفسه عند مسح الرمز على جهاز يحمله:

1. **iOS** — أضف خاصية Associated Domains في Xcode بقيمة
   `applinks:YOUR-HOST`، ثم استبدل `TEAMID` في
   `.well-known/apple-app-site-association` بمعرّف فريق Apple لديك.
2. **أندرويد** — استبدل بصمة التوقيع في `.well-known/assetlinks.json`
   (تجدها بـ `keytool -list -v -keystore ...`)، وأضف في
   `android/app/src/main/AndroidManifest.xml` مرشّح نوايا مماثلًا للموجود
   لمخطط `adigitalid` لكن بـ `android:scheme="https"` و
   `android:host="YOUR-HOST"` و `android:autoVerify="true"`.

بدون هذه الخطوة تعمل الصفحة على كل الأجهزة — فقط لا يفتح التطبيق تلقائيًا.

## الاختبار محليًا

```bash
python3 -m http.server 8765 --directory web/verify
node web/verify/qr.test.mjs
```

ثم افتح `http://localhost:8765/#<payload>` حيث `<payload>` هو الجزء الذي يلي
`#` في أي رابط بطاقة.

## الملفات

| الملف | الدور |
| --- | --- |
| `index.html` | الواجهة وحالات التحميل والخطأ |
| `payload.js` | فك ترميز الحمولة والتحقق من CRC |
| `card.js` | رسم البطاقة على canvas وتصدير PNG و PDF |
| `qr.js` | مولّد رمز QR (بلا مكتبات) |
| `qr.test.mjs` | اختبار يثبّت مخرجات المولّد |
