import 'package:flutter/material.dart';
import '../../theme/design_tokens.dart';

/// Sélecteur dropdown standardisé PHARMA+
/// Remplace DropdownButtonFormField dans tous les formulaires
class AppSelectField<T> extends StatelessWidget {
  const AppSelectField({
    super.key,
    this.focusNode,
    this.label,
    this.hint,
    this.helperText,
    this.errorText,
    required this.items,
    this.value,
    this.onChanged,
    this.validator,
    this.enabled = true,
    this.readOnly = false,
    this.prefixIcon,
    this.suffixIcon,
    this.itemBuilder,
    this.selectedItemBuilder,
    this.dropdownColor,
    this.menuMaxHeight,
    this.alignment,
    this.isExpanded = true,
    this.icon,
    this.iconSize,
    this.iconEnabledColor,
    this.iconDisabledColor,
    this.borderRadius,
    this.elevation,
    this.style,
    this.hintStyle,
    this.underline,
    this.autovalidateMode,
    this.onTap,
  });

  final FocusNode? focusNode;
  final String? label;
  final String? hint;
  final String? helperText;
  final String? errorText;
  final List<DropdownMenuItem<T>> items;
  final T? value;
  final void Function(T?)? onChanged;
  final String? Function(T?)? validator;
  final bool enabled;
  final bool readOnly;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final Widget Function(BuildContext, DropdownMenuItem<T>)? itemBuilder;
  final DropdownButtonBuilder? selectedItemBuilder;
  final Color? dropdownColor;
  final double? menuMaxHeight;
  final AlignmentGeometry? alignment;
  final bool isExpanded;
  final Widget? icon;
  final double? iconSize;
  final Color? iconEnabledColor;
  final Color? iconDisabledColor;
  final BorderRadius? borderRadius;
  final int? elevation;
  final TextStyle? style;
  final TextStyle? hintStyle;
  final Widget? underline;
  final AutovalidateMode? autovalidateMode;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final isDark = context.isDark;
    final hasError = errorText != null && errorText!.isNotEmpty;

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
        DropdownButtonFormField<T>(
          focusNode: focusNode,
          initialValue: value,
          items: items,
          onChanged: enabled && !readOnly ? onChanged : null,
          validator: validator,
          isExpanded: isExpanded,
          alignment: alignment ?? AlignmentDirectional.centerStart,
          style: style ??
              tokens.fieldInput.copyWith(
                color: enabled ? tokens.textPrimary : tokens.textDisabled,
              ),
          hint: hint != null
              ? Text(hint!, style: hintStyle ?? tokens.fieldHelper)
              : null,
          icon: icon ??
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: tokens.fontSizeLg,
                color: enabled
                    ? (isDark ? tokens.textTertiary : tokens.textDisabled)
                    : tokens.textDisabled,
              ),
          iconSize: iconSize ?? tokens.fontSizeLg,
          iconEnabledColor: iconEnabledColor,
          iconDisabledColor: iconDisabledColor,
          decoration: InputDecoration(
            helperText: hasError ? null : helperText,
            errorText: hasError ? errorText : null,
            prefixIcon: prefixIcon != null
                ? Padding(
                    padding:
                        EdgeInsets.only(left: tokens.sp4, right: tokens.sp2),
                    child: prefixIcon,
                  )
                : null,
            suffixIcon: suffixIcon != null
                ? Padding(
                    padding:
                        EdgeInsets.only(left: tokens.sp2, right: tokens.sp4),
                    child: suffixIcon,
                  )
                : null,
            filled: true,
            fillColor: enabled
                ? (isDark ? tokens.bgSurfaceRaised : Colors.white)
                : (isDark ? tokens.bgSurface : Colors.grey[100]),
            contentPadding: EdgeInsets.symmetric(
              horizontal: tokens.fieldPaddingHorizontal,
              vertical: tokens.fieldPaddingVertical,
            ),
            border: OutlineInputBorder(
              borderRadius:
                  borderRadius ?? BorderRadius.circular(tokens.rField),
              borderSide: BorderSide(
                color: isDark ? tokens.borderDark : tokens.borderLight,
                width: 1,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius:
                  borderRadius ?? BorderRadius.circular(tokens.rField),
              borderSide: BorderSide(
                color: hasError
                    ? tokens.danger
                    : (isDark ? tokens.borderDark : tokens.borderLight),
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius:
                  borderRadius ?? BorderRadius.circular(tokens.rField),
              borderSide: BorderSide(
                color: hasError ? tokens.danger : tokens.borderFocus,
                width: 1.6,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius:
                  borderRadius ?? BorderRadius.circular(tokens.rField),
              borderSide: BorderSide(color: tokens.danger, width: 1),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius:
                  borderRadius ?? BorderRadius.circular(tokens.rField),
              borderSide: BorderSide(color: tokens.danger, width: 2),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius:
                  borderRadius ?? BorderRadius.circular(tokens.rField),
              borderSide: BorderSide(
                color: isDark ? tokens.borderDark : tokens.borderLight,
                width: 1,
              ),
            ),
            errorStyle: tokens.fieldError,
            helperStyle: tokens.fieldHelper,
            labelStyle: tokens.fieldLabel,
            floatingLabelBehavior: FloatingLabelBehavior.auto,
          ),
          dropdownColor:
              dropdownColor ?? (isDark ? tokens.bgSurfaceRaised : Colors.white),
          menuMaxHeight: menuMaxHeight ?? 300,
          elevation: elevation ?? tokens.elevation3.toInt(),
          borderRadius: borderRadius ?? BorderRadius.circular(tokens.rMd),
          selectedItemBuilder: selectedItemBuilder,
          onTap: onTap,
        ),
      ],
    );
  }
}

/// Helper pour créer des items simples
class AppSelectItem<T> {
  const AppSelectItem({
    required this.value,
    required this.label,
    this.enabled = true,
    this.leading,
    this.trailing,
  });

  final T value;
  final String label;
  final bool enabled;
  final Widget? leading;
  final Widget? trailing;

  DropdownMenuItem<T> toMenuItem({
    Widget Function(BuildContext, AppSelectItem<T>)? itemBuilder,
  }) {
    return DropdownMenuItem<T>(
      value: value,
      enabled: enabled,
      child: itemBuilder != null
          ? Builder(
              builder: (context) => itemBuilder(context, this),
            )
          : Row(
              children: [
                if (leading != null) ...[
                  leading!,
                  const SizedBox(width: PharmaTokens.space2)
                ],
                Expanded(child: Text(label)),
                if (trailing != null) ...[
                  const SizedBox(width: PharmaTokens.space2),
                  trailing!
                ],
              ],
            ),
    );
  }
}

/// Variante avec recherche intégrée (pour listes longues)
class AppSearchableSelectField<T> extends StatefulWidget {
  const AppSearchableSelectField({
    super.key,
    this.label,
    this.hint,
    this.helperText,
    this.errorText,
    required this.items,
    this.value,
    this.onChanged,
    this.validator,
    this.enabled = true,
    this.searchHint = 'Rechercher…',
    this.emptyText = 'Aucun résultat',
    required this.getLabel,
    this.getSearchTerms,
  });

  final String? label;
  final String? hint;
  final String? helperText;
  final String? errorText;
  final List<T> items;
  final T? value;
  final void Function(T?)? onChanged;
  final String? Function(T?)? validator;
  final bool enabled;
  final String searchHint;
  final String emptyText;
  final String Function(T) getLabel;
  final List<String> Function(T)? getSearchTerms;

  @override
  State<AppSearchableSelectField<T>> createState() =>
      _AppSearchableSelectFieldState<T>();
}

class _AppSearchableSelectFieldState<T>
    extends State<AppSearchableSelectField<T>> {
  late List<T> _filteredItems;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  OverlayEntry? _overlayEntry;
  bool _isOpen = false;

  @override
  void initState() {
    super.initState();
    _filteredItems = widget.items;
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    _removeOverlay();
    super.dispose();
  }

  void _filter(String query) {
    if (query.isEmpty) {
      _filteredItems = widget.items;
    } else {
      final lowerQuery = query.toLowerCase();
      _filteredItems = widget.items.where((item) {
        final label = widget.getLabel(item).toLowerCase();
        final terms = widget.getSearchTerms?.call(item) ?? [];
        return label.contains(lowerQuery) ||
            terms.any((t) => t.toLowerCase().contains(lowerQuery));
      }).toList();
    }
    if (_isOpen) {
      setState(() {});
    }
  }

  void _toggleOverlay() {
    if (_isOpen) {
      _removeOverlay();
    } else {
      _showOverlay();
    }
  }

  void _showOverlay() {
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final size = renderBox.size;
    final offset = renderBox.localToGlobal(Offset.zero);

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        left: offset.dx,
        top: offset.dy + size.height + 4,
        width: size.width,
        child: Material(
          elevation: PharmaTokens.elevation4,
          borderRadius: BorderRadius.circular(PharmaTokens.radiusMd),
          color: context.isDark ? PharmaTokens.bgSurfaceRaised : Colors.white,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 320),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(PharmaTokens.space3),
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocus,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: widget.searchHint,
                      prefixIcon: const Icon(Icons.search,
                          size: PharmaTokens.fontSizeLg),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: PharmaTokens.space3,
                        vertical: PharmaTokens.space2,
                      ),
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(PharmaTokens.radiusMd),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: context.isDark
                          ? PharmaTokens.bgSurface
                          : Colors.grey[100],
                    ),
                    onChanged: _filter,
                  ),
                ),
                Divider(
                    height: 1,
                    color: context.isDark
                        ? PharmaTokens.borderDark
                        : PharmaTokens.borderLight),
                Expanded(
                  child: _filteredItems.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(PharmaTokens.space6),
                            child: Text(
                              widget.emptyText,
                              style: PharmaTokens.fieldHelper,
                            ),
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          itemCount: _filteredItems.length,
                          itemBuilder: (context, index) {
                            final item = _filteredItems[index];
                            final label = widget.getLabel(item);
                            final isSelected = item == widget.value;
                            return ListTile(
                              selected: isSelected,
                              selectedTileColor: context.isDark
                                  ? PharmaTokens.brandPrimary
                                      .withValues(alpha: 0.15)
                                  : PharmaTokens.brandPrimary
                                      .withValues(alpha: 0.08),
                              title:
                                  Text(label, style: PharmaTokens.bodyMedium),
                              onTap: () {
                                widget.onChanged?.call(item);
                                _removeOverlay();
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
    _isOpen = true;
    _searchFocus.requestFocus();
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    _isOpen = false;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final isDark = context.isDark;
    final hasError = widget.errorText != null && widget.errorText!.isNotEmpty;
    final label = widget.getLabel(widget.value as T);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.label != null) ...[
          Padding(
            padding: EdgeInsets.only(left: tokens.sp2, bottom: tokens.sp1),
            child: Text(widget.label!, style: PharmaTokens.fieldLabel),
          ),
        ],
        InkWell(
          onTap: widget.enabled ? _toggleOverlay : null,
          borderRadius: BorderRadius.circular(tokens.rField),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: tokens.fieldPaddingHorizontal,
              vertical: tokens.fieldPaddingVertical,
            ),
            decoration: BoxDecoration(
              color: widget.enabled
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
                Expanded(
                  child: Text(
                    widget.value != null ? label : (widget.hint ?? ''),
                    style: widget.value != null
                        ? tokens.fieldInput
                        : tokens.fieldHelper,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  _isOpen
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: tokens.fontSizeLg,
                  color: isDark ? tokens.textTertiary : tokens.textDisabled,
                ),
              ],
            ),
          ),
        ),
        if (hasError) ...[
          SizedBox(height: tokens.sp1),
          Padding(
            padding: EdgeInsets.only(left: tokens.sp2),
            child: Text(widget.errorText!, style: tokens.fieldError),
          ),
        ],
        if (widget.helperText != null && !hasError) ...[
          SizedBox(height: tokens.sp1),
          Padding(
            padding: EdgeInsets.only(left: tokens.sp2),
            child: Text(widget.helperText!, style: tokens.fieldHelper),
          ),
        ],
      ],
    );
  }
}
