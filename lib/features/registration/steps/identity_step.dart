import 'package:flutter/material.dart';

import '../../../data/syria_places.dart';
import '../../../models/applicant.dart';
import '../../../shared/widgets/adaptive_layout.dart';
import '../../../shared/widgets/step_fields.dart';
import '../registration_page.dart';
import '../widgets/step_layout.dart';

/// Step 1 — personal identity: name, academic year, degree and place.
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
  late final TextEditingController _firstName;
  late final TextEditingController _lastName;
  late final TextEditingController _customDegree;
  late final TextEditingController _customCity;

  @override
  void initState() {
    super.initState();
    _firstName = TextEditingController(text: widget.draft.firstName);
    _lastName = TextEditingController(text: widget.draft.lastName);
    _customDegree =
        TextEditingController(text: widget.draft.customDegree ?? '');
    _customCity = TextEditingController(text: widget.draft.customCity ?? '');
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _customDegree.dispose();
    _customCity.dispose();
    super.dispose();
  }

  void _update(VoidCallback apply) {
    apply();
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final draft = widget.draft;
    final degree = draft.degree;
    final cityIsOther = draft.city == kOtherPlace;

    return StepLayout(
      hero: const StepHero(
        number: 1,
        icon: Icons.badge_outlined,
        title: 'الهوية الشخصية',
        subtitle: 'أخبرنا من أنت — الاسم، المرحلة الدراسية، التخصص والعنوان.',
      ),
      children: [
        FormGrid(
          children: [
            BrandTextField(
              label: 'الاسم الأول',
              controller: _firstName,
              icon: Icons.person_outline_rounded,
              error: widget.errors['firstName'],
              onChanged: (value) => _update(() => draft.firstName = value),
            ),
            BrandTextField(
              label: 'اسم العائلة',
              controller: _lastName,
              icon: Icons.person_pin_outlined,
              error: widget.errors['lastName'],
              onChanged: (value) => _update(() => draft.lastName = value),
            ),
            BrandDropdown<AcademicYear>(
              label: 'المرحلة الدراسية',
              value: draft.academicYear,
              items: AcademicYear.values,
              labelFor: (year) => year.label,
              icon: Icons.school_outlined,
              error: widget.errors['academicYear'],
              onChanged: (value) => _update(() => draft.academicYear = value),
            ),
            BrandDropdown<UndergraduateDegree>(
              label: 'الدرجة الجامعية',
              value: draft.degree,
              items: UndergraduateDegree.values,
              labelFor: (degree) => degree.label,
              icon: Icons.workspace_premium_outlined,
              error: widget.errors['degree'],
              onChanged: (value) => _update(() => draft.degree = value),
            ),
            if (degree == UndergraduateDegree.other)
              BrandTextField(
                label: 'تخصصك الدراسي',
                controller: _customDegree,
                icon: Icons.edit_note_rounded,
                error: widget.errors['customDegree'],
                onChanged: (value) =>
                    _update(() => draft.customDegree = value),
              ),
            BrandDropdown<String>(
              label: 'المحافظة',
              value: draft.governorate,
              items: kGovernorateNames,
              labelFor: (name) => name,
              icon: Icons.map_outlined,
              error: widget.errors['governorate'],
              onChanged: (value) => _update(() {
                draft.governorate = value;
                // اختيار محافظة جديدة يُعيد ضبط المدينة التابعة لها.
                draft.city = null;
                draft.customCity = null;
                _customCity.clear();
              }),
            ),
            BrandSearchPicker(
              label: 'المدينة / البلدة',
              value: draft.city,
              options: citiesOf(draft.governorate),
              icon: Icons.location_city_outlined,
              hint: draft.governorate == null
                  ? 'اختر المحافظة أولًا'
                  : 'اختر المدينة',
              searchHint: 'ابحث عن مدينة…',
              enabled: draft.governorate != null,
              error: widget.errors['city'],
              onSelected: (value) => _update(() {
                draft.city = value;
                if (value != kOtherPlace) {
                  draft.customCity = null;
                  _customCity.clear();
                }
              }),
            ),
            if (cityIsOther)
              BrandTextField(
                label: 'اسم المدينة أو البلدة',
                controller: _customCity,
                icon: Icons.location_on_outlined,
                error: widget.errors['customCity'],
                onChanged: (value) => _update(() => draft.customCity = value),
              ),
          ],
        ),
      ],
    );
  }
}
