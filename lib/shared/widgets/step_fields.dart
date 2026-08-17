import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/brand_colors.dart';
import 'adaptive_layout.dart';

/// Field label row with optional error state.
class FieldLabel extends StatelessWidget {
  const FieldLabel({super.key, required this.text, this.error});

  final String text;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodySmall?.copyWith(
                color: BrandColors.inkMuted,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
          ),
          if (error != null) ...[
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                error!,
                style: textTheme.bodySmall?.copyWith(
                  color: BrandColors.error,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.left,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Branded dropdown with gold accent and validation error.
class BrandDropdown<T> extends StatelessWidget {
  const BrandDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.labelFor,
    required this.onChanged,
    this.error,
    this.hint = 'اختر',
    this.icon,
    this.enabled = true,
  });

  final String label;
  final T? value;
  final List<T> items;
  final String Function(T) labelFor;
  final ValueChanged<T?> onChanged;
  final String? error;
  final String hint;
  final IconData? icon;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        FieldLabel(text: label, error: error),
        DropdownButtonFormField<T>(
          initialValue: value,
          isExpanded: true,
          isDense: false,
          hint: Text(
            hint,
            style: textTheme.bodyMedium?.copyWith(color: BrandColors.inkMuted),
          ),
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: BrandColors.goldDeep,
          ),
          style: textTheme.bodyMedium?.copyWith(color: BrandColors.ink),
          dropdownColor: BrandColors.surface,
          borderRadius: BorderRadius.circular(16),
          menuMaxHeight: 420,
          items: [
            for (final item in items)
              DropdownMenuItem(
                value: item,
                child: Text(labelFor(item), overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: enabled ? onChanged : null,
          decoration: InputDecoration(
            prefixIcon: icon == null ? null : Icon(icon, size: 20),
            enabled: enabled,
            errorText: error == null ? null : ' ',
            errorStyle: const TextStyle(height: 0.4),
          ),
        ),
      ],
    );
  }
}

/// Numeric input (height / weight) with unit suffix.
class BrandNumberField extends StatelessWidget {
  const BrandNumberField({
    super.key,
    required this.label,
    required this.controller,
    required this.unit,
    required this.onChanged,
    this.error,
    this.allowDecimal = false,
    this.icon,
  });

  final String label;
  final TextEditingController controller;
  final String unit;
  final ValueChanged<String> onChanged;
  final String? error;
  final bool allowDecimal;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        FieldLabel(text: label, error: error),
        TextField(
          controller: controller,
          keyboardType: TextInputType.numberWithOptions(decimal: allowDecimal),
          textInputAction: TextInputAction.next,
          textDirection: TextDirection.ltr,
          inputFormatters: [
            FilteringTextInputFormatter.allow(
              allowDecimal
                  ? RegExp(r'^\d{0,3}(\.\d{0,1})?')
                  : RegExp(r'^\d{0,3}'),
            ),
          ],
          maxLength: allowDecimal ? 5 : 3,
          onChanged: onChanged,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
          decoration: InputDecoration(
            counterText: '',
            prefixIcon: icon == null ? null : Icon(icon, size: 20),
            suffixText: unit,
            suffixStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: BrandColors.goldDeep,
                  fontWeight: FontWeight.w700,
                ),
            errorText: error == null ? null : ' ',
            errorStyle: const TextStyle(height: 0.4),
          ),
        ),
      ],
    );
  }
}

/// Text input for names and free-text places.
class BrandTextField extends StatelessWidget {
  const BrandTextField({
    super.key,
    required this.label,
    required this.controller,
    required this.onChanged,
    this.hint,
    this.error,
    this.icon,
    this.keyboardType,
    this.inputFormatters,
    this.textDirection,
    this.textCapitalization = TextCapitalization.words,
    this.maxLength,
  });

  final String label;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String? hint;
  final String? error;
  final IconData? icon;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final TextDirection? textDirection;
  final TextCapitalization textCapitalization;
  final int? maxLength;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        FieldLabel(text: label, error: error),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          textDirection: textDirection,
          textCapitalization: textCapitalization,
          textInputAction: TextInputAction.next,
          maxLength: maxLength,
          onChanged: onChanged,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w500,
              ),
          decoration: InputDecoration(
            counterText: '',
            hintText: hint,
            hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: BrandColors.inkMuted,
                ),
            prefixIcon: icon == null ? null : Icon(icon, size: 20),
            errorText: error == null ? null : ' ',
            errorStyle: const TextStyle(height: 0.4),
          ),
        ),
      ],
    );
  }
}

/// A field that opens a searchable list — used for long option sets such as
/// Syrian cities, where a plain dropdown would be a wall of scrolling.
///
/// Presents as a bottom sheet on phones and as a centred dialog from tablet
/// up, so the picker feels native on every screen size.
class BrandSearchPicker extends StatelessWidget {
  const BrandSearchPicker({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onSelected,
    this.error,
    this.icon,
    this.hint = 'اختر',
    this.searchHint = 'ابحث…',
    this.enabled = true,
    this.emptyMessage = 'لا توجد نتائج مطابقة',
  });

  final String label;
  final String? value;
  final List<String> options;
  final ValueChanged<String> onSelected;
  final String? error;
  final IconData? icon;
  final String hint;
  final String searchHint;
  final bool enabled;
  final String emptyMessage;

  Future<void> _open(BuildContext context) async {
    final band = Adaptive.bandOf(context);
    final picker = _PickerBody(
      title: label,
      options: options,
      selected: value,
      searchHint: searchHint,
      emptyMessage: emptyMessage,
    );

    final result = band.isCompact
        ? await showModalBottomSheet<String>(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            backgroundColor: BrandColors.surface,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(BrandRadii.extraLarge),
              ),
            ),
            builder: (context) => FractionallySizedBox(
              heightFactor: 0.86,
              child: picker,
            ),
          )
        : await showDialog<String>(
            context: context,
            builder: (context) => Dialog(
              backgroundColor: BrandColors.surface,
              insetPadding: const EdgeInsets.all(40),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(BrandRadii.extraLarge),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560, maxHeight: 640),
                child: picker,
              ),
            ),
          );

    if (result != null) onSelected(result);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final hasValue = value != null && value!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        FieldLabel(text: label, error: error),
        Material(
          color: enabled ? BrandColors.surface : BrandColors.ivoryDeep,
          borderRadius: BorderRadius.circular(BrandRadii.medium),
          child: InkWell(
            onTap: enabled ? () => _open(context) : null,
            borderRadius: BorderRadius.circular(BrandRadii.medium),
            child: Container(
              constraints: const BoxConstraints(minHeight: 56),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(BrandRadii.medium),
                border: Border.all(
                  color: error != null
                      ? BrandColors.error
                      : BrandColors.outlineSoft,
                  width: error != null ? 1.4 : 1,
                ),
              ),
              child: Row(
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 20, color: BrandColors.goldDeep),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Text(
                      hasValue ? value! : hint,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodyMedium?.copyWith(
                        color: hasValue
                            ? BrandColors.ink
                            : BrandColors.inkMuted,
                        fontWeight:
                            hasValue ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.search_rounded,
                    size: 20,
                    color: BrandColors.goldDeep,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PickerBody extends StatefulWidget {
  const _PickerBody({
    required this.title,
    required this.options,
    required this.selected,
    required this.searchHint,
    required this.emptyMessage,
  });

  final String title;
  final List<String> options;
  final String? selected;
  final String searchHint;
  final String emptyMessage;

  @override
  State<_PickerBody> createState() => _PickerBodyState();
}

class _PickerBodyState extends State<_PickerBody> {
  final TextEditingController _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  List<String> get _filtered {
    final q = _normalize(_query.text);
    if (q.isEmpty) return widget.options;
    return [
      for (final option in widget.options)
        if (_normalize(option).contains(q)) option,
    ];
  }

  /// Arabic search that ignores diacritics and alef/ya/ta-marbuta variants,
  /// so "حماه" finds "حماة" and "ادلب" finds "إدلب".
  static String _normalize(String input) {
    final buffer = StringBuffer();
    for (final rune in input.trim().runes) {
      final char = String.fromCharCode(rune);
      switch (char) {
        case 'أ' || 'إ' || 'آ' || 'ٱ':
          buffer.write('ا');
        case 'ى':
          buffer.write('ي');
        case 'ة':
          buffer.write('ه');
        case 'ؤ':
          buffer.write('و');
        case 'ئ':
          buffer.write('ي');
        default:
          // Skip Arabic diacritics (harakat) entirely.
          if (rune >= 0x064B && rune <= 0x0652) continue;
          buffer.write(char.toLowerCase());
      }
    }
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    final results = _filtered;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: textTheme.titleMedium?.copyWith(
                      color: BrandColors.pine,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: 'إغلاق',
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _query,
              autofocus: false,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: widget.searchHint,
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _query.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () => setState(_query.clear),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Flexible(
            child: results.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      widget.emptyMessage,
                      style: textTheme.bodyMedium?.copyWith(
                        color: BrandColors.inkMuted,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 20),
                    itemCount: results.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final option = results[index];
                      final selected = option == widget.selected;
                      return ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(BrandRadii.medium),
                        ),
                        selected: selected,
                        selectedTileColor: BrandColors.goldMist,
                        title: Text(
                          option,
                          style: textTheme.bodyLarge?.copyWith(
                            fontWeight:
                                selected ? FontWeight.w700 : FontWeight.w400,
                            color: selected
                                ? BrandColors.goldDeep
                                : BrandColors.ink,
                          ),
                        ),
                        trailing: selected
                            ? const Icon(
                                Icons.check_circle_rounded,
                                color: BrandColors.goldDeep,
                              )
                            : null,
                        onTap: () => Navigator.of(context).pop(option),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
