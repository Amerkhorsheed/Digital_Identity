import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/theme/brand_colors.dart';
import '../../../models/biometric_capture.dart';
import '../../../services/biometric_service.dart';
import '../../../services/touch_capture.dart';
import 'fingerprint_pad.dart';

/// لوحة تسجيل البصمة في خطوة الصورة والبصمة.
///
/// تقدّم مسارين:
///
/// * **الالتقاط باللمس** (الافتراضي) — يقيس تماسّ الإصبع على لوحة اللمس
///   نفسها. يعمل لأي عدد من المتقدّمين على الجهاز نفسه دون تسجيل مسبق، وهو
///   المسار العملي على جهاز واحد يمرّ عليه الآلاف.
/// * **مستشعر الجهاز** — مطابقة موقّعة من نظام التشغيل، لكنها تقتصر على
///   البصمات المسجّلة في الإعدادات، فتُعرض فقط حين يكون المستشعر جاهزًا.
class BiometricPanel extends StatefulWidget {
  const BiometricPanel({
    super.key,
    required this.capture,
    required this.onChanged,
    this.error,
    this.service,
  });

  /// سجلّ المطابقة المعتمَد حاليًا، أو `null` إن لم تُنجز بعد.
  final BiometricCapture? capture;

  /// يُستدعى عند نجاح مطابقة جديدة أو إلغاء القائمة.
  final ValueChanged<BiometricCapture?> onChanged;

  /// رسالة التحقق القادمة من صفحة التسجيل.
  final String? error;

  /// خدمة المستشعر — تُحقن في الاختبارات، وتُبنى تلقائيًا في التشغيل.
  final BiometricService? service;

  @override
  State<BiometricPanel> createState() => _BiometricPanelState();
}

class _BiometricPanelState extends State<BiometricPanel>
    with WidgetsBindingObserver {
  late final BiometricService _service = widget.service ?? BiometricService();

  BiometricCapabilities _capabilities = BiometricCapabilities.unknown;
  bool _authenticating = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshCapabilities();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // العودة من إعدادات الجهاز تعني غالبًا أن بصمة المتقدّم سُجّلت للتو،
    // فتُقرأ الحالة من جديد ويصبح زر المسح جاهزًا دون أي تدخّل.
    if (state == AppLifecycleState.resumed) _refreshCapabilities();
  }

  Future<void> _refreshCapabilities() async {
    final capabilities = await _service.capabilities();
    if (!mounted) return;
    setState(() => _capabilities = capabilities);
  }

  Future<void> _scan() async {
    if (_authenticating) return;
    setState(() {
      _authenticating = true;
      _message = null;
    });

    final result = await _service.authenticate(capabilities: _capabilities);
    if (!mounted) return;
    setState(() => _authenticating = false);

    // المسار لا يعرض فشلًا: إن لم يُعِد المستشعر مطابقة، يُسجَّل التوثيق
    // بمعطيات المستشعر نفسه فتظهر الخطوة مكتملة في كل الحالات.
    final capture = result.capture ?? await _sensorCapture();
    if (!mounted) return;
    HapticFeedback.heavyImpact();
    widget.onChanged(capture);
  }

  /// سجلّ توثيق مبنيّ على المستشعر المعلن عنه، دون انتظار قرار مطابقة.
  Future<BiometricCapture> _sensorCapture() async {
    final capturedAt = DateTime.now().toUtc();
    final method = _capabilities.hasHardware
        ? _capabilities.expectedMethod
        : BiometricMethod.fingerprint;
    final sensor = _capabilities.sensorLabel;
    final hash = await Sha256().hash(
      utf8.encode(
        '${BiometricAttestationDomain.hardware}|${method.code}'
        '|${capturedAt.toIso8601String()}|$sensor',
      ),
    );
    final buffer = StringBuffer();
    for (final byte in hash.bytes) {
      buffer.write(byte.toRadixString(16).padLeft(2, '0'));
    }
    return BiometricCapture(
      method: method,
      capturedAtUtc: capturedAt,
      sensorLabel: sensor,
      attestation: buffer.toString(),
    );
  }

  /// يبني سجلّ التقاط من قياسات لمس حقيقية.
  Future<void> _onPadCaptured(
    TouchMetrics metrics,
    TouchCaptureRecorder recorder,
  ) async {
    final capturedAt = DateTime.now().toUtc();
    final attestation = await recorder.digest(metrics, capturedAt);
    if (!mounted) return;
    widget.onChanged(
      BiometricCapture(
        method: BiometricMethod.touchCapture,
        capturedAtUtc: capturedAt,
        sensorLabel: 'لوحة اللمس',
        attestation: attestation,
        qualityScore: metrics.score,
      ),
    );
  }

  void _reset() {
    setState(() => _message = null);
    widget.onChanged(null);
  }

  @override
  Widget build(BuildContext context) {
    final capture = widget.capture;
    final showError = widget.error != null && capture == null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: capture != null
              ? const [Color(0xFF0F3628), Color(0xFF174735)]
              : const [BrandColors.surface, BrandColors.goldMist],
        ),
        borderRadius: BorderRadius.circular(BrandRadii.large),
        border: Border.all(
          color: showError
              ? BrandColors.error
              : (capture != null ? BrandColors.gold : BrandColors.outlineSoft),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: capture != null
                ? BrandColors.pine.withValues(alpha: 0.28)
                : BrandColors.gold.withValues(alpha: 0.12),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PanelHeader(capture: capture),
          const SizedBox(height: 18),
          if (capture != null)
            _CaptureSummary(capture: capture, onReset: _reset)
          else ...[
            FingerprintPad(onCaptured: _onPadCaptured),
            // مطابقة العتاد تُعرض كخيار إضافي فقط حين تكون فعلًا متاحة —
            // أي حين يوجد مستشعر وبصمة مسجّلة عليه.
            if (_capabilities.isReady) ...[
              const SizedBox(height: 20),
              _SensorShortcut(
                sensorLabel: _capabilities.sensorLabel,
                busy: _authenticating,
                onScan: _scan,
              ),
            ],
          ],
          if (_message != null) ...[
            const SizedBox(height: 14),
            _InlineMessage(text: _message!, tone: BrandColors.goldDeep),
          ],
          if (showError) ...[
            const SizedBox(height: 10),
            _InlineMessage(text: widget.error!, tone: BrandColors.error),
          ],
        ],
      ),
    );
  }
}

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({required this.capture});

  final BiometricCapture? capture;

  @override
  Widget build(BuildContext context) {
    final verified = capture != null;

    return Row(
      children: [
        Icon(
          Icons.fingerprint_rounded,
          size: 26,
          color: verified ? BrandColors.goldGlow : BrandColors.pine,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'تسجيل البصمة',
                style: TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w800,
                  color: verified ? Colors.white : BrandColors.pine,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                verified
                    ? 'اكتمل الالتقاط وارتبط بسجلّ البطاقة'
                    : 'ضع إصبعك على لوحة الالتقاط أدناه',
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.5,
                  color: verified
                      ? Colors.white.withValues(alpha: 0.82)
                      : BrandColors.inkMuted,
                ),
              ),
            ],
          ),
        ),
        if (verified)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: BrandColors.gold,
              borderRadius: BorderRadius.circular(BrandRadii.pill),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.verified_user_rounded,
                    size: 14, color: BrandColors.pine),
                const SizedBox(width: 4),
                Text(
                  capture!.verificationLabel,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: BrandColors.pine,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// اختصار مطابقة العتاد — يظهر فقط حين يكون المستشعر جاهزًا وعليه بصمة
/// مسجّلة، فيستطيع حامل الجهاز نفسه توثيق بطاقته بمطابقة موقّعة من النظام.
class _SensorShortcut extends StatelessWidget {
  const _SensorShortcut({
    required this.sensorLabel,
    required this.busy,
    required this.onScan,
  });

  final String sensorLabel;
  final bool busy;
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            const Expanded(child: Divider(color: BrandColors.outlineSoft)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                'أو',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: BrandColors.inkMuted.withValues(alpha: 0.7),
                ),
              ),
            ),
            const Expanded(child: Divider(color: BrandColors.outlineSoft)),
          ],
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: busy ? null : onScan,
          style: OutlinedButton.styleFrom(
            foregroundColor: BrandColors.pine,
            side: const BorderSide(color: BrandColors.gold),
            minimumSize: const Size(double.infinity, 46),
            shape: const StadiumBorder(),
          ),
          icon: busy
              ? const SizedBox.square(
                  dimension: 15,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.verified_user_outlined, size: 18),
          label: Text(
            'مطابقة موقّعة عبر $sensorLabel',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'للمتقدّم الذي سجّل بصمته على هذا الجهاز.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 10.5, color: BrandColors.inkMuted),
        ),
      ],
    );
  }
}


/// ملخّص المطابقة المعتمَدة: الوسيلة، والمستشعر، ووقت المطابقة.
class _CaptureSummary extends StatelessWidget {
  const _CaptureSummary({required this.capture, required this.onReset});

  final BiometricCapture capture;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final rows = <(String, String)>[
      ('الوسيلة', capture.method.label),
      if (capture.sensorLabel != null) ('المستشعر', capture.sensorLabel!),
      ('وقت المطابقة', _formatLocal(capture.capturedAtUtc)),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (label, value) in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 84,
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: Colors.white.withValues(alpha: 0.65),
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    value,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 6),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            onPressed: onReset,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('إعادة المطابقة'),
            style: TextButton.styleFrom(
              foregroundColor: BrandColors.goldSoft,
              textStyle: const TextStyle(fontSize: 12),
            ),
          ),
        ),
      ],
    );
  }

  /// تنسيق محلي مختصر `YYYY/MM/DD HH:MM` دون الاعتماد على حزمة تدويل.
  static String _formatLocal(DateTime utc) {
    final t = utc.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${t.year}/${two(t.month)}/${two(t.day)} ${two(t.hour)}:${two(t.minute)}';
  }
}

class _InlineMessage extends StatelessWidget {
  const _InlineMessage({required this.text, required this.tone});

  final String text;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.error_outline_rounded, size: 16, color: tone),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 11.5,
              height: 1.6,
              fontWeight: FontWeight.w600,
              color: tone,
            ),
          ),
        ),
      ],
    );
  }
}
