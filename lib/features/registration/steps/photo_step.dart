import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/theme/brand_colors.dart';
import '../../../shared/widgets/adaptive_layout.dart';
import '../registration_page.dart';
import '../widgets/step_layout.dart';

/// Step 3 — portrait capture. The photo is cropped to a perfect circle for
/// the identity card with retake support.
class PhotoStep extends StatefulWidget {
  const PhotoStep({
    super.key,
    required this.draft,
    required this.errors,
    required this.onChanged,
  });

  final ApplicantDraft draft;
  final Map<String, String> errors;
  final VoidCallback onChanged;

  @override
  State<PhotoStep> createState() => _PhotoStepState();
}

class _PhotoStepState extends State<PhotoStep> {
  final ImagePicker _picker = ImagePicker();
  bool _busy = false;

  Future<void> _pick(ImageSource source) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final file = await _picker.pickImage(
        source: source,
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
        SnackBar(
          content: Text(
            source == ImageSource.camera
                ? 'الكاميرا غير متوفرة على هذا الجهاز.'
                : 'تعذّر فتح مكتبة الصور.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasPhoto = widget.draft.hasPhoto;
    final error = widget.errors['photo'];

    return StepLayout(
      hero: const StepHero(
        number: 3,
        icon: Icons.camera_alt_outlined,
        title: 'الصورة الشخصية',
        subtitle: 'التقط صورة واضحة وجيدة الإضاءة لبطاقة الهوية الخاصة بك.',
      ),
      children: [
        Column(
          children: [
            Center(
              child: _PhotoFrame(
                hasPhoto: hasPhoto,
                photoPath: widget.draft.photoPath,
                busy: _busy,
                onCamera: () => _pick(ImageSource.camera),
                onGallery: () => _pick(ImageSource.gallery),
              ),
            ),
            const SizedBox(height: 20),
            _GuidanceRow(hasPhoto: hasPhoto),
            if (error != null) ...[
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline_rounded,
                      size: 18, color: BrandColors.error),
                  const SizedBox(width: 8),
                  Text(
                    error,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: BrandColors.error,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
            ],
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
    required this.onGallery,
  });

  final bool hasPhoto;
  final String? photoPath;
  final bool busy;
  final VoidCallback onCamera;
  final VoidCallback onGallery;

  @override
  Widget build(BuildContext context) {
    const ringSize = 236.0;
    const photoSize = 208.0;

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
                blurRadius: 30,
                offset: const Offset(0, 10),
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
        const SizedBox(height: 24),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 14,
          runSpacing: 12,
          children: [
            FilledButton.icon(
              onPressed: busy ? null : onCamera,
              style: FilledButton.styleFrom(
                backgroundColor: BrandColors.pine,
                minimumSize: const Size(190, 54),
                shape: const StadiumBorder(),
              ),
              icon: busy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.camera_alt_outlined),
              label: Text(hasPhoto ? 'إعادة الالتقاط' : 'التقاط صورة'),
            ),
            OutlinedButton.icon(
              onPressed: busy ? null : onGallery,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(190, 54),
                side: const BorderSide(color: BrandColors.pine, width: 1.4),
                shape: const StadiumBorder(),
              ),
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('اختيار من المكتبة'),
            ),
          ],
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
            size: 64,
            color: BrandColors.pine.withValues(alpha: 0.35),
          ),
          const SizedBox(height: 8),
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
      (Icons.light_mode_outlined, 'وجّه وجهك نحو مصدر الضوء'),
      (Icons.center_focus_strong_outlined, 'الوجه في المنتصف ومستقيم'),
      (Icons.remove_circle_outline, 'بدون نظارات أو غطاء رأس'),
    ];
    final band = Adaptive.bandOf(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: BrandColors.goldMist,
        borderRadius: BorderRadius.circular(16),
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
                size: 18,
                color: hasPhoto ? BrandColors.success : BrandColors.goldDeep,
              ),
              const SizedBox(width: 8),
              Text(
                hasPhoto
                    ? 'تم التقاط الصورة — تبدو رائعة!'
                    : 'إرشادات الصورة',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: BrandColors.goldDeep,
                    ),
              ),
            ],
          ),
          if (!hasPhoto) ...[
            const SizedBox(height: 10),
            if (band.isCompact)
              Column(
                children: [
                  for (final tip in tips) _TipRow(tip: tip),
                ],
              )
            else
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 24,
                runSpacing: 8,
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
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(tip.$1, size: 14, color: BrandColors.goldDeep),
          const SizedBox(width: 6),
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
