import 'dart:async';

import 'package:flutter/material.dart';
import '../../theme/design_tokens.dart';

/// Champ de recherche standardisé PHARMA+
class AppSearchField extends StatefulWidget {
  const AppSearchField({
    super.key,
    this.controller,
    this.focusNode,
    this.hint = 'Rechercher…',
    this.placeholder = 'Rechercher…',
    this.onChanged,
    this.onSubmitted,
    this.onClear,
    this.onFilterTap,
    this.filterLabel = 'Filtres',
    this.filterIcon = Icons.filter_list_rounded,
    this.showFilterButton = true,
    this.debounceDuration = const Duration(milliseconds: 300),
    this.enabled = true,
    this.readOnly = false,
    this.autofocus = false,
    this.prefixIcon,
    this.suffixIcon,
    this.caseSensitive = false,
    this.minCharsForSearch = 0,
    this.showClearButton = true,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String hint;
  final String placeholder;
  final void Function(String)? onChanged;
  final void Function(String)? onSubmitted;
  final VoidCallback? onClear;
  final VoidCallback? onFilterTap;
  final String filterLabel;
  final IconData filterIcon;
  final bool showFilterButton;
  final Duration debounceDuration;
  final bool enabled;
  final bool readOnly;
  final bool autofocus;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final bool caseSensitive;
  final int minCharsForSearch;
  final bool showClearButton;

  @override
  State<AppSearchField> createState() => _AppSearchFieldState();
}

class _AppSearchFieldState extends State<AppSearchField> {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  Timer? _debounceTimer;
  String _lastQuery = '';

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
    _focusNode = widget.focusNode ?? FocusNode();
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _controller.removeListener(_onTextChanged);
    if (widget.controller == null) _controller.dispose();
    if (widget.focusNode == null) _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final query = _controller.text;
    if (query == _lastQuery) return;
    _lastQuery = query;

    _debounceTimer?.cancel();
    if (widget.debounceDuration > Duration.zero) {
      _debounceTimer = Timer(widget.debounceDuration, () {
        _performSearch(query);
      });
    } else {
      _performSearch(query);
    }
  }

  void _performSearch(String query) {
    if (!widget.enabled) return;
    if (query.length < widget.minCharsForSearch) return;
    widget.onChanged?.call(query);
  }

  void _clear() {
    _controller.clear();
    widget.onClear?.call();
    widget.onChanged?.call('');
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final isDark = context.isDark;
    final hasText = _controller.text.isNotEmpty;

    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            focusNode: _focusNode,
            enabled: widget.enabled,
            readOnly: widget.readOnly,
            autofocus: widget.autofocus,
            onSubmitted: widget.onSubmitted,
            onTapOutside: (_) => _focusNode.unfocus(),
            style: tokens.fieldInput,
            decoration: InputDecoration(
              hintText: widget.hint,
              prefixIcon: widget.prefixIcon ??
                  Padding(
                    padding: EdgeInsets.only(
                      left: tokens.sp4,
                      right: tokens.sp2,
                    ),
                    child: Icon(
                      Icons.search_rounded,
                      size: tokens.fontSizeLg,
                      color: isDark ? tokens.textTertiary : tokens.textDisabled,
                    ),
                  ),
              suffixIcon: hasText && widget.showClearButton
                  ? IconButton(
                      icon: Icon(
                        Icons.clear_rounded,
                        size: tokens.fontSizeLg,
                        color: isDark ? tokens.textTertiary : tokens.textDisabled,
                      ),
                      onPressed: _clear,
                      tooltip: 'Effacer',
                      splashRadius: 20,
                    )
                  : widget.suffixIcon != null
                      ? Padding(
                          padding: EdgeInsets.only(
                            left: tokens.sp2,
                            right: tokens.sp4,
                          ),
                          child: widget.suffixIcon,
                        )
                      : null,
              filled: true,
              fillColor: widget.enabled
                  ? (isDark ? tokens.bgSurfaceRaised : Colors.white)
                  : (isDark ? tokens.bgSurface : Colors.grey[100]),
              contentPadding: EdgeInsets.symmetric(
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
                  color: isDark ? tokens.borderDark : tokens.borderLight,
                  width: 1,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(tokens.rField),
                borderSide: BorderSide(
                  color: tokens.borderFocus,
                  width: 1.6,
                ),
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(tokens.rField),
                borderSide: BorderSide(
                  color: isDark ? tokens.borderDark : tokens.borderLight,
                  width: 1,
                ),
              ),
            ),
          ),
        ),
        if (widget.showFilterButton && widget.onFilterTap != null) ...[
          SizedBox(width: tokens.sp2),
          OutlinedButton.icon(
            onPressed: widget.enabled ? widget.onFilterTap : null,
            icon: Icon(
              widget.filterIcon,
              size: tokens.fontSizeBase,
            ),
            label: Text(widget.filterLabel, style: tokens.labelMedium),
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.symmetric(
                horizontal: tokens.sp4,
                vertical: tokens.sp3,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(tokens.rButton),
              ),
              side: BorderSide(
                color: isDark ? tokens.borderGold : tokens.brandPrimary,
                width: 1.5,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Recherche avec suggestions (autocomplete)
class AppSearchAutocomplete<T> extends StatefulWidget {
  const AppSearchAutocomplete({
    super.key,
    required this.suggestions,
    required this.getLabel,
    this.getSearchTerms,
    this.onSelected,
    this.onChanged,
    this.controller,
    this.hint = 'Rechercher…',
    this.emptyText = 'Aucune suggestion',
    this.loading = false,
    this.maxSuggestions = 10,
    this.debounceDuration = const Duration(milliseconds: 200),
  });

  final List<T> suggestions;
  final String Function(T) getLabel;
  final List<String> Function(T)? getSearchTerms;
  final void Function(T)? onSelected;
  final void Function(String)? onChanged;
  final TextEditingController? controller;
  final String hint;
  final String emptyText;
  final bool loading;
  final int maxSuggestions;
  final Duration debounceDuration;

  @override
  State<AppSearchAutocomplete<T>> createState() =>
      _AppSearchAutocompleteState<T>();
}

class _AppSearchAutocompleteState<T> extends State<AppSearchAutocomplete<T>> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  OverlayEntry? _overlayEntry;
  Timer? _debounceTimer;
  List<T> _filtered = [];
  bool _showOverlay = false;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _controller.text = widget.controller!.text;
    }
    _controller.addListener(_onTextChanged);
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _controller.removeListener(_onTextChanged);
    _focusNode.removeListener(_onFocusChange);
    _controller.dispose();
    _focusNode.dispose();
    _removeOverlay();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus) {
      Future.delayed(Duration(milliseconds: 100), _removeOverlay);
    } else if (_controller.text.isNotEmpty) {
      _filter(_controller.text);
      _showOverlayIfNeeded();
    }
  }

  void _onTextChanged() {
    widget.onChanged?.call(_controller.text);
    _debounceTimer?.cancel();
    _debounceTimer = Timer(widget.debounceDuration, () {
      _filter(_controller.text);
      if (_focusNode.hasFocus) _showOverlayIfNeeded();
    });
  }

  void _filter(String query) {
    if (query.isEmpty) {
      _filtered = [];
    } else {
      final lowerQuery = query.toLowerCase();
      _filtered = widget.suggestions.where((item) {
        final label = widget.getLabel(item).toLowerCase();
        final terms = widget.getSearchTerms?.call(item) ?? [];
        return label.contains(lowerQuery) ||
            terms.any((t) => t.toLowerCase().contains(lowerQuery));
      }).take(widget.maxSuggestions).toList();
    }
    if (_showOverlay) setState(() {});
  }

  void _showOverlayIfNeeded() {
    if (_showOverlay) return;
    _showOverlay = true;
    _renderOverlay();
  }

  void _removeOverlay() {
    _showOverlay = false;
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _renderOverlay() {
    final tokens = context.tokens;
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
          elevation: tokens.elevation4,
          borderRadius: BorderRadius.circular(tokens.rMd),
          color: context.isDark
              ? tokens.bgSurfaceRaised
              : Colors.white,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: 300),
            child: _filtered.isEmpty
                ? _buildEmpty()
                : _buildList(),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  Widget _buildEmpty() {
    final tokens = context.tokens;
    return Padding(
      padding: EdgeInsets.all(tokens.sp4),
      child: Center(
        child: Text(
          widget.emptyText,
          style: tokens.fieldHelper,
        ),
      ),
    );
  }

  Widget _buildList() {
    final tokens = context.tokens;
    return ListView.builder(
      shrinkWrap: true,
      itemCount: _filtered.length,
      itemBuilder: (context, index) {
        final item = _filtered[index];
        final label = widget.getLabel(item);
        return ListTile(
          dense: true,
          title: Text(label, style: tokens.bodyMedium),
          onTap: () {
            _controller.text = label;
            widget.onSelected?.call(item);
            _removeOverlay();
            _focusNode.unfocus();
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final isDark = context.isDark;

    return TextField(
      controller: _controller,
      focusNode: _focusNode,
      onSubmitted: (_) => _removeOverlay(),
      style: tokens.fieldInput,
      decoration: InputDecoration(
        hintText: widget.hint,
        prefixIcon: Padding(
          padding: EdgeInsets.only(left: tokens.sp4, right: tokens.sp2),
          child: Icon(
            Icons.search_rounded,
            size: tokens.fontSizeLg,
            color: isDark ? tokens.textTertiary : tokens.textDisabled,
          ),
        ),
        suffixIcon: widget.loading
            ? Padding(
                padding: EdgeInsets.all(tokens.sp3),
                child: SizedBox(
                  width: tokens.sp4,
                  height: tokens.sp4,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: tokens.brandPrimary,
                  ),
                ),
              )
            : _controller.text.isNotEmpty
                ? IconButton(
                    icon: Icon(
                      Icons.clear_rounded,
                      size: tokens.fontSizeLg,
                    ),
                    onPressed: () {
                      _controller.clear();
                      widget.onChanged?.call('');
                      _filter('');
                    },
                  )
                : null,
        filled: true,
        fillColor: isDark ? tokens.bgSurfaceRaised : Colors.white,
        contentPadding: EdgeInsets.symmetric(
          horizontal: tokens.fieldPaddingHorizontal,
          vertical: tokens.fieldPaddingVertical,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(tokens.rField),
          borderSide: BorderSide(
            color: isDark ? tokens.borderDark : tokens.borderLight,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(tokens.rField),
          borderSide: BorderSide(
            color: isDark ? tokens.borderDark : tokens.borderLight,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(tokens.rField),
          borderSide: BorderSide(color: tokens.borderFocus, width: 1.6),
        ),
      ),
    );
  }
}