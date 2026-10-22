import 'package:flutter/material.dart';
import '../../theme/design_tokens.dart';

/// Barre de filtres standardisée PHARMA+
class AppFilterBar extends StatelessWidget {
  const AppFilterBar({
    super.key,
    this.filters = const [],
    this.activeFilters = const {},
    this.onFilterChanged,
    this.onClearAll,
    this.showClearAll = true,
    this.clearAllLabel = 'Tout effacer',
    this.spacing = 8,
    this.runSpacing = 8,
    this.padding,
    this.backgroundColor,
    this.showDivider = true,
  });

  final List<AppFilterChip> filters;
  final Map<String, dynamic> activeFilters;
  final void Function(String, dynamic)? onFilterChanged;
  final VoidCallback? onClearAll;
  final bool showClearAll;
  final String clearAllLabel;
  final double spacing;
  final double runSpacing;
  final EdgeInsetsGeometry? padding;
  final Color? backgroundColor;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final isDark = context.isDark;
    final hasActiveFilters = activeFilters.isNotEmpty;

    if (filters.isEmpty && !hasActiveFilters) {
      return const SizedBox.shrink();
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: padding ?? EdgeInsets.all(tokens.sp3),
          decoration: BoxDecoration(
            color: backgroundColor ??
                (isDark ? tokens.bgSurfaceRaised : Colors.grey[50]),
            border: showDivider
                ? Border(
                    bottom: BorderSide(
                      color: isDark ? tokens.borderDark : tokens.borderLight,
                    ),
                  )
                : null,
          ),
          child: Wrap(
            spacing: spacing,
            runSpacing: runSpacing,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ...filters.map((filter) => _buildFilterChip(context, filter)),
              if (hasActiveFilters && showClearAll && onClearAll != null) ...[
                SizedBox(width: spacing),
                TextButton.icon(
                  onPressed: onClearAll,
                  icon: Icon(
                    Icons.clear_all_rounded,
                    size: tokens.fontSizeSm,
                  ),
                  label: Text(clearAllLabel, style: tokens.labelSmall),
                  style: TextButton.styleFrom(
                    foregroundColor: tokens.danger,
                    padding: EdgeInsets.symmetric(
                      horizontal: tokens.sp3,
                      vertical: tokens.sp1,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (showDivider)
          Divider(
            color: isDark ? tokens.borderDark : tokens.borderLight,
            height: 1,
            thickness: 1,
          ),
      ],
    );
  }

  Widget _buildFilterChip(BuildContext context, AppFilterChip filter) {
    final activeValue = activeFilters[filter.key];

    return filter.when(
      choice: (f) => _buildChoiceChip(context, f, activeValue),
      multi: (f) => _buildMultiChip(context, f, activeValue),
      range: (f) => _buildRangeChip(context, f, activeValue),
      date: (f) => _buildDateChip(context, f, activeValue),
      search: (f) => _buildSearchChip(context, f, activeValue),
    );
  }

  Widget _buildChoiceChip(
    BuildContext context,
    _ChoiceFilter f,
    dynamic activeValue,
  ) {
    final tokens = context.tokens;
    final isDark = context.isDark;
    final isActive = activeValue != null;

    return FilterChip(
      label: Text(f.label, style: tokens.labelSmall),
      selected: isActive,
      onSelected: (_) =>
          onFilterChanged?.call(f.key, isActive ? null : f.value),
      selectedColor: tokens.brandPrimary.withValues(alpha: 0.15),
      checkmarkColor: tokens.brandPrimary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.rFull),
        side: BorderSide(
          color: isActive
              ? tokens.brandPrimary
              : (isDark ? tokens.borderDark : tokens.borderLight),
        ),
      ),
      showCheckmark: false,
      labelStyle: tokens.labelSmall.copyWith(
        color: isActive
            ? tokens.brandPrimary
            : (isDark ? tokens.textSecondary : tokens.textSecondary),
      ),
      avatar: isActive
          ? CircleAvatar(
              radius: tokens.sp2,
              backgroundColor: tokens.brandPrimary,
              child: Icon(
                Icons.check_rounded,
                size: tokens.fontSizeXs,
                color: Colors.white,
              ),
            )
          : null,
      padding: EdgeInsets.symmetric(
        horizontal: tokens.sp3,
        vertical: tokens.sp1,
      ),
    );
  }

  Widget _buildMultiChip(
    BuildContext context,
    _MultiFilter f,
    dynamic activeValue,
  ) {
    final tokens = context.tokens;
    final isDark = context.isDark;
    final active = (activeValue as List?)?.cast<String>() ?? [];

    return PopupMenuButton<String>(
      child: FilterChip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(f.label, style: tokens.labelSmall),
            if (active.isNotEmpty) ...[
              SizedBox(width: tokens.sp1),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: tokens.sp2,
                  vertical: tokens.space0,
                ),
                decoration: BoxDecoration(
                  color: tokens.brandPrimary,
                  borderRadius: BorderRadius.circular(tokens.rFull),
                ),
                child: Text(
                  '${active.length}',
                  style: tokens.labelSmall.copyWith(
                    color: Colors.white,
                    fontSize: tokens.fontSizeXs,
                  ),
                ),
              ),
            ],
          ],
        ),
        selected: active.isNotEmpty,
        onSelected: null,
        showCheckmark: false,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.rFull),
          side: BorderSide(
            color: active.isNotEmpty
                ? tokens.brandPrimary
                : (isDark ? tokens.borderDark : tokens.borderLight),
          ),
        ),
        padding: EdgeInsets.symmetric(
          horizontal: tokens.sp3,
          vertical: tokens.sp1,
        ),
      ),
      itemBuilder: (context) => f.options.map((opt) {
        final isSelected = active.contains(opt.value);
        return CheckedPopupMenuItem<String>(
          value: opt.value,
          checked: isSelected,
          child: Text(opt.label, style: tokens.bodyMedium),
          onTap: () {
            final newActive = List<String>.from(active);
            if (isSelected) {
              newActive.remove(opt.value);
            } else {
              newActive.add(opt.value);
            }
            onFilterChanged?.call(f.key, newActive);
          },
        );
      }).toList(),
    );
  }

  Widget _buildRangeChip(
    BuildContext context,
    _RangeFilter f,
    dynamic activeValue,
  ) {
    final tokens = context.tokens;
    final isDark = context.isDark;
    final range = activeValue as Map<String, num>?;

    return PopupMenuButton<void>(
      child: FilterChip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(f.label, style: tokens.labelSmall),
            if (range != null) ...[
              SizedBox(width: tokens.sp1),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: tokens.sp2,
                  vertical: tokens.space0,
                ),
                decoration: BoxDecoration(
                  color: tokens.brandPrimary,
                  borderRadius: BorderRadius.circular(tokens.rFull),
                ),
                child: Text(
                  '${_formatNum(range['min'], decimals: f.decimals)}-${_formatNum(range['max'], decimals: f.decimals)}',
                  style: tokens.labelSmall.copyWith(
                    color: Colors.white,
                    fontSize: tokens.fontSizeXs,
                  ),
                ),
              ),
            ],
          ],
        ),
        selected: range != null,
        onSelected: null,
        showCheckmark: false,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.rFull),
          side: BorderSide(
            color: range != null
                ? tokens.brandPrimary
                : (isDark ? tokens.borderDark : tokens.borderLight),
          ),
        ),
        padding: EdgeInsets.symmetric(
          horizontal: tokens.sp3,
          vertical: tokens.sp1,
        ),
      ),
      itemBuilder: (context) => [
        PopupMenuItem<void>(
          enabled: false,
          height: 200,
          child: _RangePicker(
            filterKey: f.key,
            min: f.min,
            max: f.max,
            currentMin: range?['min']?.toDouble(),
            currentMax: range?['max']?.toDouble(),
            onChanged: (min, max) {
              if (min != null && max != null) {
                onFilterChanged?.call(f.key, {'min': min, 'max': max});
              } else {
                onFilterChanged?.call(f.key, null);
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDateChip(
    BuildContext context,
    _DateFilter f,
    dynamic activeValue,
  ) {
    final tokens = context.tokens;
    final isDark = context.isDark;
    final range = activeValue as Map<String, DateTime>?;

    return PopupMenuButton<void>(
      child: FilterChip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(f.label, style: tokens.labelSmall),
            if (range != null) ...[
              SizedBox(width: tokens.sp1),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: tokens.sp2,
                  vertical: tokens.space0,
                ),
                decoration: BoxDecoration(
                  color: tokens.brandPrimary,
                  borderRadius: BorderRadius.circular(tokens.rFull),
                ),
                child: Text(
                  '${_formatDate(range['start'])}-${_formatDate(range['end'])}',
                  style: tokens.labelSmall.copyWith(
                    color: Colors.white,
                    fontSize: tokens.fontSizeXs,
                  ),
                ),
              ),
            ],
          ],
        ),
        selected: range != null,
        onSelected: null,
        showCheckmark: false,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.rFull),
          side: BorderSide(
            color: range != null
                ? tokens.brandPrimary
                : (isDark ? tokens.borderDark : tokens.borderLight),
          ),
        ),
        padding: EdgeInsets.symmetric(
          horizontal: tokens.sp3,
          vertical: tokens.sp1,
        ),
      ),
      itemBuilder: (context) => [
        PopupMenuItem<void>(
          enabled: false,
          height: 320,
          child: _DateRangePicker(
            filterKey: f.key,
            currentStart: range?['start'],
            currentEnd: range?['end'],
            onChanged: (start, end) {
              if (start != null && end != null) {
                onFilterChanged?.call(f.key, {'start': start, 'end': end});
              } else {
                onFilterChanged?.call(f.key, null);
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSearchChip(
    BuildContext context,
    _SearchFilter f,
    dynamic activeValue,
  ) {
    final tokens = context.tokens;
    final isDark = context.isDark;
    final query = activeValue as String?;

    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.search_rounded,
            size: tokens.fontSizeSm,
            color: isDark ? tokens.textTertiary : tokens.textDisabled,
          ),
          SizedBox(width: tokens.sp1),
          Text(
            query?.isNotEmpty == true ? query! : f.placeholder,
            style: tokens.labelSmall.copyWith(
              color: query?.isNotEmpty == true
                  ? (isDark ? tokens.textPrimary : tokens.textPrimary)
                  : (isDark ? tokens.textTertiary : tokens.textDisabled),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
      selected: query?.isNotEmpty == true,
      onSelected: (_) => _showSearchDialog(context, f),
      showCheckmark: false,
      padding: EdgeInsets.symmetric(
        horizontal: tokens.sp3,
        vertical: tokens.sp1,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.rFull),
        side: BorderSide(
          color: query?.isNotEmpty == true
              ? tokens.brandPrimary
              : (isDark ? tokens.borderDark : tokens.borderLight),
        ),
      ),
    );
  }

  void _showSearchDialog(BuildContext context, _SearchFilter f) {
    final tokens = context.tokens;
    final controller =
        TextEditingController(text: activeFilters[f.key] as String? ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(f.label, style: tokens.headlineSmall),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: f.placeholder,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(tokens.rMd),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              onFilterChanged?.call(f.key, null);
              Navigator.pop(context);
            },
            child: Text('Effacer', style: tokens.labelMedium),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                onFilterChanged?.call(f.key, controller.text);
              }
              Navigator.pop(context);
            },
            child: Text('Appliquer', style: tokens.labelMedium),
          ),
        ],
      ),
    );
  }

  String _formatNum(num? n, {int? decimals}) =>
      n == null ? '∞' : n.toStringAsFixed(decimals ?? 0);

  String _formatDate(DateTime? d) => d == null
      ? '∞'
      : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

/// Définition des filtres (sealed class pattern via when)
sealed class AppFilterChip {
  const AppFilterChip();

  String get key;

  R when<R>({
    // ignore: library_private_types_in_public_api
    required R Function(_ChoiceFilter) choice,
    // ignore: library_private_types_in_public_api
    required R Function(_MultiFilter) multi,
    // ignore: library_private_types_in_public_api
    required R Function(_RangeFilter) range,
    // ignore: library_private_types_in_public_api
    required R Function(_DateFilter) date,
    // ignore: library_private_types_in_public_api
    required R Function(_SearchFilter) search,
  });
}

class _ChoiceFilter extends AppFilterChip {
  const _ChoiceFilter({
    required this.key,
    required this.label,
    required this.value,
  });

  @override
  final String key;
  final String label;
  final dynamic value;

  @override
  R when<R>({
    required R Function(_ChoiceFilter) choice,
    required R Function(_MultiFilter) multi,
    required R Function(_RangeFilter) range,
    required R Function(_DateFilter) date,
    required R Function(_SearchFilter) search,
  }) =>
      choice(this);
}

class _MultiFilter extends AppFilterChip {
  const _MultiFilter({
    required this.key,
    required this.label,
    required this.options,
  });

  @override
  final String key;
  final String label;
  final List<_FilterOption> options;

  @override
  R when<R>({
    required R Function(_ChoiceFilter) choice,
    required R Function(_MultiFilter) multi,
    required R Function(_RangeFilter) range,
    required R Function(_DateFilter) date,
    required R Function(_SearchFilter) search,
  }) =>
      multi(this);
}

class _RangeFilter extends AppFilterChip {
  const _RangeFilter({
    required this.key,
    required this.label,
    required this.min,
    required this.max,
    this.decimals,
  });

  @override
  final String key;
  final String label;
  final num min;
  final num max;
  final int? decimals;

  @override
  R when<R>({
    required R Function(_ChoiceFilter) choice,
    required R Function(_MultiFilter) multi,
    required R Function(_RangeFilter) range,
    required R Function(_DateFilter) date,
    required R Function(_SearchFilter) search,
  }) =>
      range(this);
}

class _DateFilter extends AppFilterChip {
  const _DateFilter({
    required this.key,
    required this.label,
  });

  @override
  final String key;
  final String label;

  @override
  R when<R>({
    required R Function(_ChoiceFilter) choice,
    required R Function(_MultiFilter) multi,
    required R Function(_RangeFilter) range,
    required R Function(_DateFilter) date,
    required R Function(_SearchFilter) search,
  }) =>
      date(this);
}

class _SearchFilter extends AppFilterChip {
  const _SearchFilter({
    required this.key,
    required this.label,
    required this.placeholder,
  });

  @override
  final String key;
  final String label;
  final String placeholder;

  @override
  R when<R>({
    required R Function(_ChoiceFilter) choice,
    required R Function(_MultiFilter) multi,
    required R Function(_RangeFilter) range,
    required R Function(_DateFilter) date,
    required R Function(_SearchFilter) search,
  }) =>
      search(this);
}

/// Factory methods
class AppFilters {
  static AppFilterChip choice({
    required String key,
    required String label,
    required dynamic value,
  }) {
    return _ChoiceFilter(key: key, label: label, value: value);
  }

  static AppFilterChip multi({
    required String key,
    required String label,
    required List<FilterOption> options,
  }) {
    return _MultiFilter(
      key: key,
      label: label,
      options: options.map((o) => _FilterOption(o.value, o.label)).toList(),
    );
  }

  static AppFilterChip range({
    required String key,
    required String label,
    required num min,
    required num max,
    int? decimals,
  }) {
    return _RangeFilter(
        key: key, label: label, min: min, max: max, decimals: decimals);
  }

  static AppFilterChip date({
    required String key,
    required String label,
  }) {
    return _DateFilter(key: key, label: label);
  }

  static AppFilterChip search({
    required String key,
    required String label,
    required String placeholder,
  }) {
    return _SearchFilter(key: key, label: label, placeholder: placeholder);
  }
}

class FilterOption {
  const FilterOption(this.value, this.label);
  final String value;
  final String label;
}

class _FilterOption {
  const _FilterOption(this.value, this.label);
  final String value;
  final String label;
}

/// Widgets internes pour les popups
class _RangePicker extends StatefulWidget {
  const _RangePicker({
    required this.filterKey,
    required this.min,
    required this.max,
    this.currentMin,
    this.currentMax,
    required this.onChanged,
  });

  final String filterKey;
  final num min;
  final num max;
  final double? currentMin;
  final double? currentMax;
  final void Function(double?, double?) onChanged;

  @override
  State<_RangePicker> createState() => _RangePickerState();
}

class _RangePickerState extends State<_RangePicker> {
  late TextEditingController _minCtrl;
  late TextEditingController _maxCtrl;

  @override
  void initState() {
    super.initState();
    _minCtrl = TextEditingController(text: widget.currentMin?.toString() ?? '');
    _maxCtrl = TextEditingController(text: widget.currentMax?.toString() ?? '');
  }

  @override
  void dispose() {
    _minCtrl.dispose();
    _maxCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Padding(
      padding: EdgeInsets.all(tokens.sp4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Plage de valeurs', style: tokens.titleMedium),
          SizedBox(height: tokens.sp3),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _minCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Min (${widget.min})',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(tokens.rMd),
                    ),
                  ),
                ),
              ),
              SizedBox(width: tokens.sp3),
              Expanded(
                child: TextField(
                  controller: _maxCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Max (${widget.max})',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(tokens.rMd),
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: tokens.sp3),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => widget.onChanged(null, null),
                  child: Text('Effacer', style: tokens.labelMedium),
                ),
              ),
              SizedBox(width: tokens.sp2),
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    final min = double.tryParse(_minCtrl.text);
                    final max = double.tryParse(_maxCtrl.text);
                    widget.onChanged(min, max);
                    Navigator.pop(context);
                  },
                  child: Text('Appliquer', style: tokens.labelMedium),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DateRangePicker extends StatefulWidget {
  const _DateRangePicker({
    required this.filterKey,
    this.currentStart,
    this.currentEnd,
    required this.onChanged,
  });

  final String filterKey;
  final DateTime? currentStart;
  final DateTime? currentEnd;
  final void Function(DateTime?, DateTime?) onChanged;

  @override
  State<_DateRangePicker> createState() => _DateRangePickerState();
}

class _DateRangePickerState extends State<_DateRangePicker> {
  DateTime? _start;
  DateTime? _end;

  @override
  void initState() {
    super.initState();
    _start = widget.currentStart;
    _end = widget.currentEnd;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Padding(
      padding: EdgeInsets.all(tokens.sp4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Plage de dates', style: tokens.titleMedium),
          SizedBox(height: tokens.sp3),
          Row(
            children: [
              Expanded(
                child: _DatePickerButton(
                  label: 'Début',
                  value: _start,
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _start ?? DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) setState(() => _start = picked);
                  },
                ),
              ),
              SizedBox(width: tokens.sp3),
              Expanded(
                child: _DatePickerButton(
                  label: 'Fin',
                  value: _end,
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _end ?? DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) setState(() => _end = picked);
                  },
                ),
              ),
            ],
          ),
          SizedBox(height: tokens.sp3),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => widget.onChanged(null, null),
                  child: Text('Effacer', style: tokens.labelMedium),
                ),
              ),
              SizedBox(width: tokens.sp2),
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    widget.onChanged(_start, _end);
                    Navigator.pop(context);
                  },
                  child: Text('Appliquer', style: tokens.labelMedium),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DatePickerButton extends StatelessWidget {
  const _DatePickerButton({
    required this.label,
    this.value,
    required this.onTap,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final isDark = context.isDark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(tokens.rMd),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: tokens.sp3,
          vertical: tokens.sp3,
        ),
        decoration: BoxDecoration(
          color: isDark ? tokens.bgSurfaceRaised : Colors.white,
          borderRadius: BorderRadius.circular(tokens.rMd),
          border: Border.all(
            color: isDark ? tokens.borderDark : tokens.borderLight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: tokens.labelSmall),
            SizedBox(height: tokens.sp1),
            Row(
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  size: tokens.fontSizeSm,
                  color: isDark ? tokens.textTertiary : tokens.textDisabled,
                ),
                SizedBox(width: tokens.sp2),
                Text(
                  value != null
                      ? '${value!.day}/${value!.month}/${value!.year}'
                      : 'Sélectionner',
                  style: value != null ? tokens.bodyMedium : tokens.fieldHelper,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
