import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/design_tokens.dart';

/// Champ de texte standardisé PHARMA+
/// Remplace TextField / TextFormField dans tous les formulaires
class AppTextField extends StatelessWidget {
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
    this.suffix,
    this.obscureText = false,
    this.obscuringCharacter = '●',
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.readOnly = false,
    this.enabled = true,
    this.autofillHints,
    this.inputFormatters,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.maxLengthEnforcement,
    this.expands = false,
    this.initialValue,
    this.style,
    this.textAlign = TextAlign.start,
    this.textDirection,
    this.cursorColor,
    this.cursorWidth,
    this.cursorHeight,
    this.cursorRadius,
    this.selectionControls,
    this.scrollPadding = const EdgeInsets.all(20),
    this.enableInteractiveSelection = true,
    this.buildCounter,
    this.autofocus = false,
    this.restorationId,
    this.semanticLabel,
    this.onEditingComplete,
    this.contextMenuBuilder,
    this.magnifierConfiguration,
    this.spellCheckConfiguration,
    this.smartDashesType,
    this.smartQuotesType,
    this.contentInsertionConfiguration,
    this.contentPadding,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? label;
  final String? hint;
  final String? helperText;
  final String? errorText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final Widget? suffix;
  final bool obscureText;
  final String obscuringCharacter;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final void Function(String)? onSubmitted;
  final void Function()? onTap;
  final bool readOnly;
  final bool enabled;
  final Iterable<String>? autofillHints;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLines;
  final int? minLines;
  final int? maxLength;
  final MaxLengthEnforcement? maxLengthEnforcement;
  final bool expands;
  final String? initialValue;
  final TextStyle? style;
  final TextAlign textAlign;
  final TextDirection? textDirection;
  final Color? cursorColor;
  final double? cursorWidth;
  final double? cursorHeight;
  final Radius? cursorRadius;
  final TextSelectionControls? selectionControls;
  final EdgeInsets scrollPadding;
  final bool enableInteractiveSelection;
  final InputCounterWidgetBuilder? buildCounter;
  final bool autofocus;
  final String? restorationId;
  final String? semanticLabel;
  final VoidCallback? onEditingComplete;
  final EditableTextContextMenuBuilder? contextMenuBuilder;
  final TextMagnifierConfiguration? magnifierConfiguration;
  final SpellCheckConfiguration? spellCheckConfiguration;
  final SmartDashesType? smartDashesType;
  final SmartQuotesType? smartQuotesType;
  final ContentInsertionConfiguration? contentInsertionConfiguration;
  final EdgeInsetsGeometry? contentPadding;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final isDark = context.isDark;

    final effectiveError = errorText;
    final hasError = effectiveError != null && effectiveError.isNotEmpty;
    final effectiveHelper = helperText;

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
            child: Text(
              label!,
              style: PharmaTokens.fieldLabel,
            ),
          ),
        ],
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          initialValue: initialValue,
          obscureText: obscureText,
          obscuringCharacter: obscuringCharacter,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          textCapitalization: textCapitalization,
          validator: validator,
          onChanged: onChanged,
          onFieldSubmitted: onSubmitted,
          onTap: onTap,
          onEditingComplete: onEditingComplete,
          readOnly: readOnly,
          enabled: enabled,
          autofillHints: autofillHints,
          inputFormatters: inputFormatters,
          maxLines: maxLines,
          minLines: minLines,
          maxLength: maxLength,
          maxLengthEnforcement: maxLengthEnforcement,
          expands: expands,
          style: style ?? PharmaTokens.fieldInput,
          textAlign: textAlign,
          textDirection: textDirection,
          cursorColor: cursorColor ?? tokens.brandEmerald,
          cursorWidth: cursorWidth ?? 2.0,
          cursorHeight: cursorHeight,
          cursorRadius: cursorRadius,
          selectionControls: selectionControls,
          scrollPadding: scrollPadding,
          enableInteractiveSelection: enableInteractiveSelection,
          buildCounter: buildCounter,
          autofocus: autofocus,
          restorationId: restorationId,
          contextMenuBuilder: contextMenuBuilder,
          magnifierConfiguration: magnifierConfiguration,
          spellCheckConfiguration: spellCheckConfiguration,
          smartDashesType: smartDashesType,
          smartQuotesType: smartQuotesType,
          contentInsertionConfiguration: contentInsertionConfiguration,
          decoration: InputDecoration(
            hintText: hint,
            helperText: hasError ? null : effectiveHelper,
            errorText: hasError ? effectiveError : null,
            errorMaxLines: 3,
            prefixIcon: prefixIcon != null
                ? Padding(
                    padding: EdgeInsets.only(
                      left: tokens.sp4,
                      right: tokens.sp2,
                    ),
                    child: prefixIcon,
                  )
                : null,
            suffixIcon: suffixIcon != null
                ? Padding(
                    padding: EdgeInsets.only(
                      left: tokens.sp2,
                      right: tokens.sp4,
                    ),
                    child: suffixIcon,
                  )
                : null,
            suffix: suffix,
            filled: true,
            alignLabelWithHint: maxLines != 1,
            isDense: maxLines == 1,
            contentPadding: contentPadding ??
                EdgeInsets.symmetric(
                  horizontal: tokens.fieldPaddingHorizontal,
                  vertical: tokens.fieldPaddingVertical,
                ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(tokens.rField),
              borderSide: BorderSide(
                color: isDark ? tokens.borderDark : tokens.borderLight,
                width: 1,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(tokens.rField),
              borderSide: BorderSide(
                color: hasError
                    ? tokens.danger
                    : (isDark ? tokens.borderDark : tokens.borderLight),
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(tokens.rField),
              borderSide: BorderSide(
                color: hasError ? tokens.danger : tokens.borderFocus,
                width: 1.6,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(tokens.rField),
              borderSide: BorderSide(color: tokens.danger, width: 1),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(tokens.rField),
              borderSide: BorderSide(color: tokens.danger, width: 2),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(tokens.rField),
              borderSide: BorderSide(
                color: isDark ? tokens.borderDark : tokens.borderLight,
                width: 1,
              ),
            ),
            fillColor: enabled
                ? (isDark ? tokens.bgSurfaceRaised : Colors.white)
                : (isDark ? tokens.bgSurface : Colors.grey[100]),
            hoverColor: isDark
                ? tokens.bgSurfaceRaised.withValues(alpha: 0.8)
                : Colors.grey[50],
            focusColor: isDark ? tokens.bgSurfaceRaised : Colors.white,
            errorStyle: tokens.fieldError,
            helperStyle: tokens.fieldHelper,
            hintStyle: tokens.fieldHelper,
            labelStyle: tokens.fieldLabel,
            floatingLabelBehavior: FloatingLabelBehavior.auto,
            counterStyle: tokens.bodySmall.copyWith(
              color: isDark ? tokens.textTertiary : tokens.textDisabled,
            ),
          ),
        ),
      ],
    );
  }
}

/// Variante dense pour formulaires compacts
class AppTextFieldDense extends StatelessWidget {
  const AppTextFieldDense({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.helperText,
    this.errorText,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.keyboardType,
    this.validator,
    this.onChanged,
    this.enabled = true,
    this.readOnly = false,
    this.maxLines = 1,
    this.inputFormatters,
    this.onTap,
  });

  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final String? helperText;
  final String? errorText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final bool enabled;
  final bool readOnly;
  final int maxLines;
  final List<TextInputFormatter>? inputFormatters;
  final void Function()? onTap;

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      controller: controller,
      label: label,
      hint: hint,
      helperText: helperText,
      errorText: errorText,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      onChanged: onChanged,
      enabled: enabled,
      readOnly: readOnly,
      maxLines: maxLines,
      inputFormatters: inputFormatters,
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: PharmaTokens.space3,
        vertical: PharmaTokens.space2,
      ),
    );
  }
}
