import 'package:flutter/material.dart';
import '../../theme/design_tokens.dart';

/// Sélecteur de date standardisé PHARMA+
/// Remplace showDatePicker dans tous les formulaires
class AppDateField extends StatelessWidget {
  const AppDateField({
    super.key,
    this.controller,
    this.focusNode,
    this.label,
    this.hint,
    this.helperText,
    this.errorText,
    this.value,
    this.onChanged,
    this.validator,
    this.enabled = true,
    this.readOnly = false,
    this.firstDate,
    this.lastDate,
    this.initialDatePickerMode = DatePickerMode.day,
    this.selectableDayPredicate,
    this.fieldHintText,
    this.confirmText = 'Confirmer',
    this.cancelText = 'Annuler',
    this.helpText = 'Sélectionner une date',
    this.errorFormatText = 'Format de date invalide',
    this.errorInvalidText = 'Date hors plage autorisée',
    this.locale,
    this.prefixIcon,
    this.suffixIcon,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? label;
  final String? hint;
  final String? helperText;
  final String? errorText;
  final DateTime? value;
  final void Function(DateTime?)? onChanged;
  final String? Function(DateTime?)? validator;
  final bool enabled;
  final bool readOnly;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final DatePickerMode initialDatePickerMode;
  final SelectableDayPredicate? selectableDayPredicate;
  final String? fieldHintText;
  final String confirmText;
  final String cancelText;
  final String helpText;
  final String errorFormatText;
  final String errorInvalidText;
  final Locale? locale;
  final Widget? prefixIcon;
  final Widget? suffixIcon;

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    return '$day/$month/$year';
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final isDark = context.isDark;
    final hasError = errorText != null && errorText!.isNotEmpty;
    final displayValue = value != null ? _formatDate(value!) : '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Padding(
            padding: EdgeInsets.only(left: tokens.sp2, bottom: tokens.sp1),
            child: Text(label!, style: PharmaTokens.fieldLabel),
          ),
        ],
        InkWell(
          onTap: enabled && !readOnly
              ? () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: value ?? DateTime.now(),
                    firstDate: firstDate ?? DateTime(1900),
                    lastDate: lastDate ?? DateTime(2100),
                    initialDatePickerMode: initialDatePickerMode,
                    selectableDayPredicate: selectableDayPredicate,
                    confirmText: confirmText,
                    cancelText: cancelText,
                    helpText: helpText,
                    errorFormatText: errorFormatText,
                    errorInvalidText: errorInvalidText,
                    locale: locale,
                    builder: (context, child) => Theme(
                      data: Theme.of(context).copyWith(
                        colorScheme: ColorScheme.fromSeed(
                          seedColor: tokens.brandPrimary,
                          brightness:
                              isDark ? Brightness.dark : Brightness.light,
                          primary: tokens.brandPrimary,
                          onPrimary: Colors.white,
                          surface: isDark ? tokens.bgSurface : Colors.white,
                          onSurface: tokens.textPrimary,
                        ),
                        dialogTheme: DialogThemeData(
                          backgroundColor:
                              isDark ? tokens.bgSurface : Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(tokens.rDialog),
                          ),
                        ),
                        textButtonTheme: TextButtonThemeData(
                          style: TextButton.styleFrom(
                            foregroundColor: tokens.brandPrimary,
                          ),
                        ),
                      ),
                      child: child!,
                    ),
                  );
                  if (picked != null && picked != value) {
                    onChanged?.call(picked);
                    controller?.text = _formatDate(picked);
                  }
                }
              : null,
          borderRadius: BorderRadius.circular(tokens.rField),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: tokens.fieldPaddingHorizontal,
              vertical: tokens.fieldPaddingVertical,
            ),
            decoration: BoxDecoration(
              color: enabled
                  ? (isDark ? tokens.bgSurfaceRaised : Colors.white)
                  : (isDark ? tokens.bgSurface : Colors.grey[100]),
              borderRadius: BorderRadius.circular(tokens.rField),
              border: Border.all(
                color: hasError
                    ? tokens.danger
                    : (isDark ? tokens.borderDark : tokens.borderLight),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                if (prefixIcon != null) ...[
                  prefixIcon!,
                  SizedBox(width: tokens.sp2),
                ],
                Expanded(
                  child: Text(
                    displayValue.isEmpty ? (hint ?? '') : displayValue,
                    style: displayValue.isEmpty
                        ? tokens.fieldHelper
                        : tokens.fieldInput,
                  ),
                ),
                if (suffixIcon != null) ...[
                  SizedBox(width: tokens.sp2),
                  suffixIcon!,
                ] else ...[
                  Icon(
                    Icons.calendar_today_rounded,
                    size: tokens.fontSizeLg,
                    color: enabled
                        ? (isDark ? tokens.textTertiary : tokens.textDisabled)
                        : tokens.textDisabled,
                  ),
                ],
              ],
            ),
          ),
        ),
        if (hasError) ...[
          SizedBox(height: tokens.sp1),
          Padding(
            padding: EdgeInsets.only(left: tokens.sp2),
            child: Text(errorText!, style: tokens.fieldError),
          ),
        ],
        if (helperText != null && !hasError) ...[
          SizedBox(height: tokens.sp1),
          Padding(
            padding: EdgeInsets.only(left: tokens.sp2),
            child: Text(helperText!, style: tokens.fieldHelper),
          ),
        ],
      ],
    );
  }
}

/// Version avec contrôleur texte pour intégration Form
class AppDateFieldForm extends FormField<DateTime> {
  AppDateFieldForm({
    super.key,
    super.initialValue,
    super.onSaved,
    super.validator,
    super.autovalidateMode,
    this.label,
    this.hint,
    this.helperText,
    super.enabled = true,
    this.firstDate,
    this.lastDate,
    this.fieldHintText,
    this.prefixIcon,
  }) : super(
          builder: (state) {
            final context = state.context;
            final tokens = context.tokens;
            final isDark = context.isDark;
            final hasError = state.hasError;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (label != null) ...[
                  Padding(
                    padding: EdgeInsets.only(
                      left: tokens.sp2,
                      bottom: tokens.sp1,
                    ),
                    child: Text(label, style: tokens.fieldLabel),
                  ),
                ],
                InkWell(
                  onTap: enabled
                      ? () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: state.value ?? DateTime.now(),
                            firstDate: firstDate ?? DateTime(1900),
                            lastDate: lastDate ?? DateTime(2100),
                            builder: (context, child) => Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: ColorScheme.fromSeed(
                                  seedColor: tokens.brandPrimary,
                                  brightness: isDark
                                      ? Brightness.dark
                                      : Brightness.light,
                                  primary: tokens.brandPrimary,
                                  onPrimary: Colors.white,
                                  surface:
                                      isDark ? tokens.bgSurface : Colors.white,
                                  onSurface: tokens.textPrimary,
                                ),
                                dialogTheme: DialogThemeData(
                                  backgroundColor:
                                      isDark ? tokens.bgSurface : Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(tokens.rDialog),
                                  ),
                                ),
                              ),
                              child: child!,
                            ),
                          );
                          if (picked != null) {
                            state.didChange(picked);
                          }
                        }
                      : null,
                  borderRadius: BorderRadius.circular(tokens.rField),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: tokens.fieldPaddingHorizontal,
                      vertical: tokens.fieldPaddingVertical,
                    ),
                    decoration: BoxDecoration(
                      color: enabled
                          ? (isDark ? tokens.bgSurfaceRaised : Colors.white)
                          : (isDark ? tokens.bgSurface : Colors.grey[100]),
                      borderRadius: BorderRadius.circular(tokens.rField),
                      border: Border.all(
                        color: hasError
                            ? tokens.danger
                            : (isDark ? tokens.borderDark : tokens.borderLight),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        if (prefixIcon != null) ...[
                          prefixIcon,
                          SizedBox(width: tokens.sp2),
                        ],
                        Expanded(
                          child: Text(
                            state.value != null
                                ? _formatDate(state.value!)
                                : (hint ?? ''),
                            style: state.value != null
                                ? tokens.fieldInput
                                : tokens.fieldHelper,
                          ),
                        ),
                        Icon(
                          Icons.calendar_today_rounded,
                          size: tokens.fontSizeLg,
                          color: enabled
                              ? (isDark
                                  ? tokens.textTertiary
                                  : tokens.textDisabled)
                              : tokens.textDisabled,
                        ),
                      ],
                    ),
                  ),
                ),
                if (hasError) ...[
                  SizedBox(height: tokens.sp1),
                  Padding(
                    padding: EdgeInsets.only(left: tokens.sp2),
                    child: Text(
                      state.errorText ?? '',
                      style: tokens.fieldError,
                    ),
                  ),
                ],
                if (helperText != null && !hasError) ...[
                  SizedBox(height: tokens.sp1),
                  Padding(
                    padding: EdgeInsets.only(left: tokens.sp2),
                    child: Text(helperText, style: tokens.fieldHelper),
                  ),
                ],
              ],
            );
          },
        );

  final String? label;
  final String? hint;
  final String? helperText;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final String? fieldHintText;
  final Widget? prefixIcon;

  static String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    return '$day/$month/$year';
  }
}
