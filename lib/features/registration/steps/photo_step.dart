import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/theme/brand_colors.dart';
import '../../../services/biometric_service.dart';
import '../../../shared/widgets/adaptive_layout.dart';
import '../registration_page.dart';
import '../widgets/biometric_panel.dart';
import '../widgets/step_layout.dart';

/// Step 3 — portrait capture plus real biometric verification.
///
/// The biometric half is delegated to [BiometricPanel], which drives the
/// device's own fingerprint sensor through the platform biometric prompt.
class PhotoStep extends StatefulWidget {
  const PhotoStep({
    super.key,
    required this.draft,
    required this.errors,
    required this.onChanged,
    this.biometricService,
  });

  final ApplicantDraft draft;
  final Map<String, String> errors;
  final VoidCallback onChanged;
  final BiometricService? biometricService;

  @override
  State<PhotoStep> createState() => _PhotoStepState();
}

class _PhotoStepState extends State<PhotoStep> {
  final ImagePicker _picker = ImagePicker();
  bool _busy = false;

  Future<void> _capturePhoto() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final file = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1400,
        maxHeight: 1600,
        imageQuality: 92,
      );
      if (file != null) {
        widget.draft.photoPath = file.path;
        widget.onChanged();
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('الكاميرا غير متوفرة على هذا الجهاز.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasPhoto = widget.draft.hasPhoto;
    final photoError = widget.errors['photo'];
    final biometricError = widget.errors['biometric'];

    return StepLayout(
      hero: const StepHero(
        number: 4,
        icon: Icons.camera_alt_outlined,
        title: 'الصورة والبصمة',
        subtitle: 'التقط صورتك الشخصية ثم امسح بصمتك على مستشعر الجهاز.',
      ),
      children: [
        Column(
          children: [
            Center(
              child: _PhotoFrame(
                hasPhoto: hasPhoto,
                photoPath: widget.draft.photoPath,
                busy: _busy,
                onCamera: _capturePhoto,
              ),
            ),
            const SizedBox(height: 18),
            _GuidanceRow(hasPhoto: hasPhoto),
            if (photoError != null) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline_rounded,
                      size: 18, color: BrandColors.error),
                  const SizedBox(width: 8),
                  Text(
                    photoError,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: BrandColors.error,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 28),
            BiometricPanel(
              capture: widget.draft.biometric,
              error: biometricError,
              service: widget.biometricService,
              onChanged: (capture) {
                setState(() => widget.draft.biometric = capture);
                widget.onChanged();
              },
            ),
          ],
        ),
      ],
    );
  }
}

class _PhotoFrame extends StatelessWidget {
  const _PhotoFrame({
    required this.hasPhoto,
    required this.photoPath,
    required this.busy,
    required this.onCamera,
  });

  final bool hasPhoto;
  final String? photoPath;
  final bool busy;
  final VoidCallback onCamera;

  @override
  Widget build(BuildContext context) {
    const ringSize = 220.0;
    const photoSize = 196.0;

    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOutCubic,
          width: ringSize,
          height: ringSize,
          padding: const EdgeInsets.all((ringSize - photoSize) / 2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: hasPhoto
                ? BrandGradients.gold
                : const LinearGradient(
                    colors: [BrandColors.goldSoft, BrandColors.gold],
                  ),
            boxShadow: [
              BoxShadow(
                color: BrandColors.gold.withValues(alpha: 0.35),
                blurRadius: 28,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipOval(
            child: SizedBox(
              width: photoSize,
              height: photoSize,
              child: hasPhoto
                  ? Image.file(
                      File(photoPath!),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stack) =>
                          const _EmptyPortrait(),
                    )
                  : const _EmptyPortrait(),
            ),
          ),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: busy ? null : onCamera,
          style: FilledButton.styleFrom(
            backgroundColor: BrandColors.pine,
            minimumSize: const Size(200, 48),
            shape: const StadiumBorder(),
          ),
          icon: busy
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.camera_alt_outlined, size: 19),
          label: Text(hasPhoto ? 'إعادة الالتقاط' : 'التقاط صورة'),
        ),
      ],
    );
  }
}

class _EmptyPortrait extends StatelessWidget {
  const _EmptyPortrait();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: BrandColors.ivoryDeep,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.person_add_alt_1_outlined,
            size: 58,
            color: BrandColors.pine.withValues(alpha: 0.35),
          ),
          const SizedBox(height: 6),
          Text(
            'الصورة الشخصية',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: BrandColors.pine.withValues(alpha: 0.45),
                ),
          ),
        ],
      ),
    );
  }
}

class _GuidanceRow extends StatelessWidget {
  const _GuidanceRow({required this.hasPhoto});

  final bool hasPhoto;

  @override
  Widget build(BuildContext context) {
    const tips = [
      (Icons.light_mode_outlined, 'إضاءة واضحة ومباشرة'),
      (Icons.center_focus_strong_outlined, 'الوجه مستقيم في المنتصف'),
      (Icons.remove_circle_outline, 'خلفية محايدة بدون نظارات شمسية'),
    ];
    final band = Adaptive.bandOf(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: BrandColors.goldMist,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: BrandColors.gold.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                hasPhoto
                    ? Icons.check_circle_outline_rounded
                    : Icons.tips_and_updates_outlined,
                size: 17,
                color: hasPhoto ? BrandColors.success : BrandColors.goldDeep,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  hasPhoto
                      ? 'تم التقاط الصورة — تبدو رائعة ومكتملة!'
                      : 'إرشادات الصورة الشخصية',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: BrandColors.goldDeep,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ],
          ),
          if (!hasPhoto) ...[
            const SizedBox(height: 8),
            if (band.isCompact)
              Column(
                children: [
                  for (final tip in tips) _TipRow(tip: tip),
                ],
              )
            else
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 20,
                runSpacing: 6,
                children: [
                  for (final tip in tips) _TipRow(tip: tip),
                ],
              ),
          ],
        ],
      ),
    );
  }
}

class _TipRow extends StatelessWidget {
  const _TipRow({required this.tip});

  final (IconData, String) tip;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(tip.$1, size: 14, color: BrandColors.goldDeep),
          const SizedBox(width: 5),
          Text(
            tip.$2,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: BrandColors.inkMuted,
                ),
          ),
        ],
      ),
    );
  }
}
