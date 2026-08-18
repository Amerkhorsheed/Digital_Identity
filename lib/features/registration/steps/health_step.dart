import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/theme/brand_colors.dart';
import '../../../models/applicant.dart';
import '../../../shared/widgets/adaptive_layout.dart';
import '../registration_page.dart';
import '../widgets/step_layout.dart';

/// Step 3 — health profile: body measurements and blood group.
///
/// The sight check used to live here too; it now has its own page, which
/// leaves this one to the three things a clerk can read straight off a scale
/// and a chart.
class HealthStep extends StatefulWidget {
  const HealthStep({
    super.key,
    required this.draft,
    required this.errors,
    required this.onChanged,
  });

  final ApplicantDraft draft;
  final Map<String, String> errors;
  final VoidCallback onChanged;

  @override
  State<HealthStep> createState() => _HealthStepState();
}

class _HealthStepState extends State<HealthStep> {
  void _update(VoidCallback apply) {
    apply();
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final draft = widget.draft;

    final currentHeight = draft.heightCm ?? 172;
    final currentWeight = draft.weightKg ?? 68.0;

    return StepLayout(
      hero: const StepHero(
        number: 2,
        icon: Icons.favorite_outline_rounded,
        title: 'الملف الصحي',
        subtitle: 'حدد قياساتك الجسمية وفصيلة دمك.',
      ),
      children: [
        FormGrid(
          children: [
            FormGridSpan(
              child: _MeasurementSlider(
                label: 'الطول',
                unit: 'سم',
                icon: Icons.height_rounded,
                value: currentHeight.toDouble(),
                min: 120,
                max: 220,
                divisions: 100,
                formattedValue: '$currentHeight سم',
                error: widget.errors['height'],
                onChanged: (val) => _update(() => draft.heightCm = val.round()),
              ),
            ),
            FormGridSpan(
              child: _MeasurementSlider(
                label: 'الوزن',
                unit: 'كجم',
                icon: Icons.monitor_weight_outlined,
                value: currentWeight,
                min: 40.0,
                max: 160.0,
                divisions: 240,
                formattedValue: '${currentWeight.toStringAsFixed(1)} كجم',
                error: widget.errors['weight'],
                onChanged: (val) => _update(() {
                  // Round to 1 decimal place.
                  draft.weightKg = (val * 2).round() / 2.0;
                }),
              ),
            ),
            FormGridSpan(
              child: _BloodTypePicker(
                value: draft.bloodType,
                error: widget.errors['bloodType'],
                onChanged: (value) => _update(() => draft.bloodType = value),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// A luxury interactive slider with live badge and quick adjustment buttons.
class _MeasurementSlider extends StatelessWidget {
  const _MeasurementSlider({
    required this.label,
    required this.unit,
    required this.icon,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.formattedValue,
    required this.onChanged,
    this.error,
  });

  final String label;
  final String unit;
  final IconData icon;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String formattedValue;
  final ValueChanged<double> onChanged;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final clamped = value.clamp(min, max);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: BrandColors.surface,
        borderRadius: BorderRadius.circular(BrandRadii.medium),
        border: Border.all(
          color: error != null ? BrandColors.error : BrandColors.outlineSoft,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: BrandColors.pine.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 22, color: BrandColors.pine),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: BrandColors.ink,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  gradient: BrandGradients.gold,
                  borderRadius: BorderRadius.circular(BrandRadii.pill),
                  boxShadow: [
                    BoxShadow(
                      color: BrandColors.gold.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  formattedValue,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(
                  Icons.remove_circle_outline_rounded,
                  color: BrandColors.pine,
                ),
                onPressed: clamped > min
                    ? () {
                        final step = (max - min) / divisions;
                        onChanged((clamped - step).clamp(min, max));
                      }
                    : null,
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: BrandColors.pine,
                    inactiveTrackColor: BrandColors.outlineSoft,
                    thumbColor: BrandColors.goldDeep,
                    overlayColor: BrandColors.gold.withValues(alpha: 0.15),
                    trackHeight: 6.0,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 11.0,
                      elevation: 3,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 22.0,
                    ),
                  ),
                  child: Slider(
                    value: clamped,
                    min: min,
                    max: max,
                    divisions: divisions,
                    onChanged: onChanged,
                  ),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(
                  Icons.add_circle_outline_rounded,
                  color: BrandColors.pine,
                ),
                onPressed: clamped < max
                    ? () {
                        final step = (max - min) / divisions;
                        onChanged((clamped + step).clamp(min, max));
                      }
                    : null,
              ),
            ],
          ),
          if (error != null) ...[
            const SizedBox(height: 4),
            Text(
              error!,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: BrandColors.error,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Blood group, picked from the eight groups laid out at once.
///
/// A dropdown hid all eight behind a tap and a scroll, which is the wrong
/// shape for a set this small and this fixed. Laid out as a grid the whole
/// answer space is visible, the selection is one tap, and the group letters —
/// the part a medic actually reads — are set large in the mono face with the
/// Rh sign carried as a separate mark rather than buried in the string.
class _BloodTypePicker extends StatelessWidget {
  const _BloodTypePicker({
    required this.value,
    required this.onChanged,
    this.error,
  });

  final BloodType? value;
  final ValueChanged<BloodType> onChanged;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        color: BrandColors.surface,
        borderRadius: BorderRadius.circular(BrandRadii.medium),
        border: Border.all(
          color: error != null ? BrandColors.error : BrandColors.outlineSoft,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: BrandColors.pine.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.bloodtype_outlined,
                size: 22,
                color: BrandColors.pine,
              ),
              const SizedBox(width: 8),
              const Text(
                'فصيلة الدم',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: BrandColors.ink,
                ),
              ),
              const Spacer(),
              AnimatedSwitcher(
                duration: BrandDurations.quick,
                child: value == null
                    ? const SizedBox.shrink()
                    : Container(
                        key: ValueKey(value),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          gradient: BrandGradients.gold,
                          borderRadius: BorderRadius.circular(BrandRadii.pill),
                        ),
                        // '+O' is what RTL makes of 'O+', so the chip is set
                        // left to right like the tiles it summarises.
                        child: Directionality(
                          textDirection: TextDirection.ltr,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.water_drop_rounded,
                                size: 14,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                value!.label,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  fontFamily: 'SpaceMono',
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              // Four across on anything phone-width or wider, so the eight
              // groups land as two clean rows of A / B / AB / O.
              const gap = 10.0;
              final columns = constraints.maxWidth >= 260 ? 4 : 2;
              final tile =
                  (constraints.maxWidth - gap * (columns - 1)) / columns;

              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final type in BloodType.values)
                    SizedBox(
                      key: ValueKey(type),
                      width: tile,
                      child: _BloodTile(
                        type: type,
                        selected: type == value,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          onChanged(type);
                        },
                      ),
                    ),
                ],
              );
            },
          ),
          if (error != null) ...[
            const SizedBox(height: 10),
            Text(
              error!,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: BrandColors.error,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BloodTile extends StatelessWidget {
  const _BloodTile({
    required this.type,
    required this.selected,
    required this.onTap,
  });

  final BloodType type;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // 'AB−' → group 'AB', sign '−'. The sign is the part that gets missed at a
    // glance, so it is drawn as its own mark instead of a trailing character.
    final label = type.label;
    final group = label.substring(0, label.length - 1);
    final sign = label.substring(label.length - 1);

    return Semantics(
      button: true,
      selected: selected,
      label: 'فصيلة الدم $label',
      child: AnimatedContainer(
        duration: BrandDurations.quick,
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          gradient: selected ? BrandGradients.pine : null,
          color: selected ? null : BrandColors.goldMist,
          borderRadius: BorderRadius.circular(BrandRadii.medium),
          border: Border.all(
            color: selected ? BrandColors.gold : BrandColors.outlineSoft,
            width: selected ? 1.6 : 1.2,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: BrandColors.pine.withValues(alpha: 0.28),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(BrandRadii.medium),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(BrandRadii.medium),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // The drop names what the tile is about before the letters
                  // are read, and fills in when the group is the chosen one.
                  Icon(
                    selected
                        ? Icons.water_drop_rounded
                        : Icons.water_drop_outlined,
                    size: 17,
                    color: selected
                        ? BrandColors.goldGlow
                        : BrandColors.goldDeep.withValues(alpha: 0.75),
                  ),
                  const SizedBox(height: 6),
                  // Blood groups are written left to right the world over —
                  // under the page's RTL direction the sign would jump ahead of
                  // the letter and read as '+A'.
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          group,
                          style: TextStyle(
                            fontSize: 20,
                            height: 1,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'SpaceMono',
                            color: selected ? Colors.white : BrandColors.pine,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Text(
                          sign,
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.05,
                            fontWeight: FontWeight.w800,
                            color: selected
                                ? BrandColors.goldGlow
                                : BrandColors.goldDeep,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
