import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../data/syria_places.dart';
import '../../../models/applicant.dart';
import '../../../shared/widgets/adaptive_layout.dart';
import '../../../shared/widgets/step_fields.dart';
import '../registration_page.dart';
import '../widgets/step_layout.dart';

/// Step 1 — personal identity: full name, birth year, academic stage, and governorate.
class IdentityStep extends StatefulWidget {
  const IdentityStep({
    super.key,
    required this.draft,
    required this.errors,
    required this.onChanged,
  });

  final ApplicantDraft draft;
  final Map<String, String> errors;
  final VoidCallback onChanged;

  @override
  State<IdentityStep> createState() => _IdentityStepState();
}

class _IdentityStepState extends State<IdentityStep> {
  late final TextEditingController _fullName;
  late final TextEditingController _birthYear;

  @override
  void initState() {
    super.initState();
    _fullName = TextEditingController(text: widget.draft.fullName);
    _birthYear = TextEditingController(
      text: widget.draft.birthYear?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _fullName.dispose();
    _birthYear.dispose();
    super.dispose();
  }

  void _update(VoidCallback apply) {
    apply();
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final draft = widget.draft;

    return StepLayout(
      hero: const StepHero(
        number: 1,
        icon: Icons.badge_outlined,
        title: 'الهوية الشخصية',
        subtitle: 'أدخل اسمك الثلاثي، سنة ميلادك، المرحلة الدراسية، ومحافظتك.',
      ),
      children: [
        FormGrid(
          children: [
            FormGridSpan(
              child: BrandTextField(
                label: 'الاسم الثلاثي',
                controller: _fullName,
                icon: Icons.person_outline_rounded,
                hint: 'مثال: أحمد محمد الحلبي',
                error: widget.errors['fullName'],
                onChanged: (value) => _update(() => draft.fullName = value),
              ),
            ),
            FormGridSpan(
              child: BrandTextField(
                label: 'سنة الميلاد',
                controller: _birthYear,
                icon: Icons.calendar_today_outlined,
                hint: 'مثال: 2001',
                maxLength: 4,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(4),
                ],
                textDirection: TextDirection.ltr,
                error: widget.errors['birthYear'],
                onChanged: (value) => _update(() {
                  draft.birthYear = int.tryParse(value.trim());
                }),
              ),
            ),
            FormGridSpan(
              child: BrandDropdown<AcademicYear>(
                label: 'المرحلة الدراسية',
                value: draft.academicYear,
                items: AcademicYear.values,
                labelFor: (year) => year.label,
                icon: Icons.school_outlined,
                error: widget.errors['academicYear'],
                onChanged: (value) => _update(() => draft.academicYear = value),
              ),
            ),
            FormGridSpan(
              child: BrandDropdown<String>(
                label: 'المحافظة',
                value: draft.governorate,
                items: kGovernorateNames,
                labelFor: (name) => name,
                icon: Icons.map_outlined,
                error: widget.errors['governorate'],
                onChanged: (value) => _update(() => draft.governorate = value),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
