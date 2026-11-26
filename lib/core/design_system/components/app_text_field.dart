import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app_colors.dart';
import '../app_radius.dart';
import '../app_spacing.dart';
import '../app_typography.dart';

class AppTextField extends StatefulWidget {
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? label;
  final String? hint;
  final String? helperText;
  final String? errorText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onTap;
  final int maxLines;
  final int? minLines;
  final bool autofocus;
  final bool enabled;
  final bool readOnly;

  const AppTextField({
    super.key,
    this.controller,
    this.focusNode,
    this.label,
    this.hint,
    this.helperText,
    this.errorText,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.maxLines = 1,
    this.minLines,
    this.autofocus = false,
    this.enabled = true,
    this.readOnly = false,
  });

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late FocusNode _effectiveFocusNode;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _effectiveFocusNode = widget.focusNode ?? FocusNode();
    _effectiveFocusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(covariant AppTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusNode != oldWidget.focusNode) {
      if (oldWidget.focusNode == null) {
        _effectiveFocusNode.removeListener(_onFocusChange);
        _effectiveFocusNode.dispose();
      } else {
        oldWidget.focusNode?.removeListener(_onFocusChange);
      }
      _effectiveFocusNode = widget.focusNode ?? FocusNode();
      _effectiveFocusNode.addListener(_onFocusChange);
    }
  }

  @override
  void dispose() {
    _effectiveFocusNode.removeListener(_onFocusChange);
    if (widget.focusNode == null) {
      _effectiveFocusNode.dispose();
    }
    super.dispose();
  }

  void _onFocusChange() {
    if (_effectiveFocusNode.hasFocus != _isFocused && mounted) {
      setState(() => _isFocused = _effectiveFocusNode.hasFocus);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;

    final hasError = widget.errorText != null && widget.errorText!.isNotEmpty;
    final borderColor = hasError
        ? AppColors.errFg(context)
        : _isFocused
            ? primary
            : (isDark ? AppColors.darkBorder : AppColors.lightBorder);

    final fillColor = isDark
        ? (_isFocused ? AppColors.darkSurfaceElevated : AppColors.darkSurfaceSubtle)
        : (_isFocused ? Colors.white : AppColors.lightSurfaceSubtle);

    final iconColor = _isFocused
        ? primary
        : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.label != null) ...[
          Text(
            widget.label!,
            style: AppTypography.titleSmall.copyWith(
              color: AppColors.textPrimary(context),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
        ],
        AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: ShapeDecoration(
            color: fillColor,
            shape: AppRadius.continuousMd(
              side: BorderSide(
                color: borderColor,
                width: hasError || _isFocused ? 1.5 : 1.0,
              ),
            ),
            shadows: _isFocused && !hasError
                ? [
                    BoxShadow(
                      color: primary.withValues(alpha: isDark ? 0.22 : 0.12),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ]
                : const [],
          ),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Row(
            crossAxisAlignment: widget.maxLines > 1
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.center,
            children: [
              if (widget.prefixIcon != null) ...[
                Padding(
                  padding: EdgeInsets.only(
                    top: widget.maxLines > 1 ? 13 : 0,
                    right: AppSpacing.sm,
                  ),
                  child: IconTheme(
                    data: IconThemeData(color: iconColor, size: 19),
                    child: widget.prefixIcon!,
                  ),
                ),
              ],
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  focusNode: _effectiveFocusNode,
                  obscureText: widget.obscureText,
                  keyboardType: widget.keyboardType,
                  textInputAction: widget.textInputAction,
                  textCapitalization: widget.textCapitalization,
                  inputFormatters: widget.inputFormatters,
                  onChanged: widget.onChanged,
                  onSubmitted: widget.onSubmitted,
                  onTap: widget.onTap,
                  maxLines: widget.obscureText ? 1 : widget.maxLines,
                  minLines: widget.minLines,
                  scrollPadding: const EdgeInsets.fromLTRB(0, 24, 0, 120),
                  autofocus: widget.autofocus,
                  enabled: widget.enabled,
                  readOnly: widget.readOnly,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textPrimary(context),
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    focusedErrorBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 13),
                    hintText: widget.hint,
                    hintStyle: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textTertiary(context),
                    ),
                  ),
                ),
              ),
              if (widget.suffixIcon != null) ...[
                Padding(
                  padding: EdgeInsets.only(
                    top: widget.maxLines > 1 ? 10 : 0,
                    left: AppSpacing.xs,
                  ),
                  child: IconTheme(
                    data: IconThemeData(color: iconColor, size: 19),
                    child: widget.suffixIcon!,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 5),
          Row(
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 13,
                color: AppColors.errFg(context),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  widget.errorText!,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.errFg(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ] else if (widget.helperText != null) ...[
          const SizedBox(height: 5),
          Text(
            widget.helperText!,
            style: AppTypography.caption.copyWith(
              color: AppColors.textTertiary(context),
            ),
          ),
        ],
      ],
    );
  }
}

/// Barra de búsqueda unificada sin bordes duplicados.
class AppSearchBar extends StatelessWidget {
  final TextEditingController? controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;
  final bool autofocus;
  final String currentQuery;

  const AppSearchBar({
    super.key,
    this.controller,
    required this.hintText,
    this.onChanged,
    this.onClear,
    this.autofocus = false,
    this.currentQuery = '',
  });

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      controller: controller,
      autofocus: autofocus,
      hint: hintText,
      prefixIcon: const Icon(Icons.search_rounded, size: 20),
      suffixIcon: currentQuery.isNotEmpty
          ? GestureDetector(
              onTap: onClear,
              child: const Icon(Icons.close_rounded, size: 18),
            )
          : null,
      onChanged: onChanged,
    );
  }
}

/// Selector desplegable estilizado de forma consistente con [AppTextField].
class AppSelectField<T> extends StatelessWidget {
  final String? label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final String? hint;
  final String? errorText;

  const AppSelectField({
    super.key,
    this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.hint,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasError = errorText != null && errorText!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: AppTypography.titleSmall.copyWith(
              color: AppColors.textPrimary(context),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
        ],
        Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          decoration: ShapeDecoration(
            color: isDark
                ? AppColors.darkSurfaceSubtle
                : AppColors.lightSurfaceSubtle,
            shape: AppRadius.continuousMd(
              side: BorderSide(
                color: hasError
                    ? AppColors.errFg(context)
                    : AppColors.border(context),
                width: hasError ? 1.5 : 1.0,
              ),
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              isExpanded: true,
              hint: hint != null
                  ? Text(
                      hint!,
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textTertiary(context),
                      ),
                    )
                  : null,
              icon: Icon(
                Icons.keyboard_arrow_down_rounded,
                color: AppColors.textSecondary(context),
              ),
              dropdownColor:
                  isDark ? AppColors.darkSurfaceElevated : Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.md),
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textPrimary(context),
                fontWeight: FontWeight.w500,
              ),
              items: items,
              onChanged: onChanged,
            ),
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 5),
          Text(
            errorText!,
            style: AppTypography.caption.copyWith(
              color: AppColors.errFg(context),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}
