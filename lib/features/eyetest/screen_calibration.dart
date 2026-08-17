/// معايرة الشاشة: كم بكسل منطقي يقابل مليمترًا واحدًا على هذا الجهاز.
///
/// لا يوفّر النظام قياس الشاشة الفيزيائي لتطبيقات فلاتر، لذا يُعاير المستخدم
/// الشاشة مرة واحدة بمطابقة بطاقة قياسية (85.6 × 53.98 مم) — وهي الطريقة
/// المعتمدة في اختبارات الإبصار الرقمية — فتصبح أحجام الرموز دقيقة فعليًا.
abstract final class ScreenCalibration {
  /// العرض القياسي لبطاقة ISO/IEC 7810 ID-1 بالمليمتر.
  static const double cardLongSideMm = 85.60;
  static const double cardShortSideMm = 53.98;

  /// قيمة افتراضية معقولة قبل المعايرة (متوسط الهواتف واللوحيات الحديثة).
  static const double defaultPxPerMm = 5.7;

  static double _pxPerMm = defaultPxPerMm;
  static bool _calibrated = false;

  static double get pxPerMm => _pxPerMm;
  static bool get isCalibrated => _calibrated;

  static void set(double value) {
    _pxPerMm = value.clamp(2.0, 20.0);
    _calibrated = true;
  }

  static void reset() {
    _pxPerMm = defaultPxPerMm;
    _calibrated = false;
  }

  /// نقطة البداية للمعايرة: القيمة المعايرة إن وُجدت، وإلا الافتراضية.
  static double initialGuess() => _calibrated ? _pxPerMm : defaultPxPerMm;
}
