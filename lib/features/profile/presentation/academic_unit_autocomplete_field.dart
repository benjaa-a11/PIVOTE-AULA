import 'package:flutter/material.dart';
import '../../../core/design_system/app_colors.dart';
import '../../../core/design_system/components/app_text_field.dart';
import '../domain/academic_unit_catalog.dart';

class AcademicUnitAutocompleteField extends StatelessWidget {
  const AcademicUnitAutocompleteField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    this.errorText,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final String? errorText;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return RawAutocomplete<AcademicUnit>(
      textEditingController: controller,
      displayStringForOption: (unit) => unit.selectionLabel,
      optionsBuilder: (value) {
        final query = value.text.trim();
        if (query.length < 2) return const Iterable<AcademicUnit>.empty();
        final results = searchAcademicUnits(query, limit: 8);
        final normalized = normalizeAcademicText(query);
        final exact = results.any(
          (unit) => normalizeAcademicText(unit.selectionLabel) == normalized,
        );
        return exact
            ? results
            : <AcademicUnit>[...results, AcademicUnit.custom(query)];
      },
      onSelected: (unit) => onChanged?.call(unit.selectionLabel),
      fieldViewBuilder: (context, textController, focusNode, onFieldSubmitted) {
        return AppTextField(
          controller: textController,
          focusNode: focusNode,
          label: label,
          hint: hint,
          errorText: errorText,
          prefixIcon: const Icon(Icons.account_balance_outlined),
          textInputAction: TextInputAction.search,
          onChanged: onChanged,
          onSubmitted: (_) => onFieldSubmitted(),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        final items = options.toList(growable: false);
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 8,
            color: AppColors.surfaceElevated(context),
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: AppColors.border(context)),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280, maxWidth: 480),
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 6),
                shrinkWrap: true,
                itemCount: items.length,
                separatorBuilder: (_, __) => Divider(
                  height: 1,
                  indent: 56,
                  color: AppColors.borderSubtle(context),
                ),
                itemBuilder: (context, index) {
                  final unit = items[index];
                  final icon = switch (unit.type) {
                    AcademicUnitType.university =>
                      Icons.account_balance_rounded,
                    AcademicUnitType.faculty => Icons.school_rounded,
                    AcademicUnitType.institute => Icons.science_rounded,
                    AcademicUnitType.department => Icons.hub_rounded,
                    AcademicUnitType.school => Icons.menu_book_rounded,
                    AcademicUnitType.custom => Icons.edit_outlined,
                  };
                  return ListTile(
                    minVerticalPadding: 8,
                    leading: CircleAvatar(
                      radius: 18,
                      backgroundColor:
                          theme.colorScheme.primary.withValues(alpha: 0.12),
                      child: Icon(
                        icon,
                        size: 18,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    title: Text(
                      unit.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: AppColors.textPrimary(context),
                      ),
                    ),
                    subtitle: Text(
                      unit.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary(context),
                      ),
                    ),
                    trailing: Icon(
                      Icons.north_west_rounded,
                      size: 16,
                      color: AppColors.textTertiary(context),
                    ),
                    onTap: () => onSelected(unit),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
