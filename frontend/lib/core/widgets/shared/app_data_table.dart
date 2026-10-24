import 'package:flutter/material.dart';
import '../../theme/design_tokens.dart';
import 'app_empty_state.dart';
import 'app_loading_state.dart';

/// Colonne de tableau typée
class AppDataColumn<T> {
  const AppDataColumn({
    required this.key,
    required this.label,
    this.width,
    this.minWidth,
    this.maxWidth,
    this.flex,
    this.alignment = TextAlign.start,
    this.numeric = false,
    this.sortable = true,
    this.filterable = false,
    this.filterOptions,
    this.cellBuilder,
    this.headerBuilder,
    this.tooltip,
    this.visible = true,
    this.pinned = false,
  });

  final String key;
  final String label;
  final double? width;
  final double? minWidth;
  final double? maxWidth;
  final int? flex;
  final TextAlign alignment;
  final bool numeric;
  final bool sortable;
  final bool filterable;
  final List<String>? filterOptions;
  final Widget Function(BuildContext, T, int)? cellBuilder;
  final Widget Function(BuildContext)? headerBuilder;
  final String? tooltip;
  final bool visible;
  final bool pinned;

  DataColumn toDataColumn(
    BuildContext context, {
    required int columnIndex,
    required bool sortedAscending,
    required String? sortColumnKey,
    required void Function(String?, bool)? onSort,
  }) {
    final isSorted = sortColumnKey == key;

    return DataColumn(
      label: headerBuilder?.call(context) ??
          _SortableHeader(
            label: label,
            sortable: sortable,
            isSorted: isSorted,
            sortedAscending: sortedAscending,
            columnKey: key,
            onSort: onSort,
          ),
      numeric: numeric,
      tooltip: tooltip,
    );
  }
}

class _SortableHeader extends StatelessWidget {
  const _SortableHeader({
    required this.label,
    required this.sortable,
    required this.isSorted,
    required this.sortedAscending,
    required this.columnKey,
    this.onSort,
  });

  final String label;
  final bool sortable;
  final bool isSorted;
  final bool sortedAscending;
  final String columnKey;
  final void Function(String?, bool)? onSort;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    if (!sortable) {
      return Text(
        label,
        style: tokens.tableHeader,
        overflow: TextOverflow.ellipsis,
      );
    }

    return InkWell(
      onTap: onSort == null
          ? null
          : () => onSort!(columnKey, isSorted ? !sortedAscending : true),
      borderRadius: BorderRadius.circular(tokens.rSm),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: tokens.sp1,
          vertical: tokens.sp1,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                label,
                style: tokens.tableHeader.copyWith(
                  color: isSorted ? tokens.brandPrimary : null,
                  fontWeight: isSorted ? FontWeight.w700 : FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isSorted) ...[
              SizedBox(width: tokens.sp1),
              Icon(
                sortedAscending
                    ? Icons.arrow_upward_rounded
                    : Icons.arrow_downward_rounded,
                size: tokens.fontSizeSm,
                color: tokens.brandPrimary,
              ),
            ] else ...[
              SizedBox(width: tokens.sp1),
              Icon(
                Icons.unfold_more_rounded,
                size: tokens.fontSizeXs,
                color: tokens.textTertiary,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Configuration du tableau
class AppDataTableConfig {
  const AppDataTableConfig({
    this.showCheckboxColumn = false,
    this.checkboxColumnWidth = 48,
    this.rowHeight = 52,
    this.headerHeight = 48,
    this.columnSpacing = 24,
    this.horizontalMargin = 16,
    this.showVerticalLines = false,
    this.showHorizontalLines = true,
    this.dividerColor,
    this.striped = true,
    this.hoverColor,
    this.selectionColor,
    this.fixedLeftColumns = 0,
    this.fixedRightColumns = 0,
    this.minColumnWidth = 80,
    this.maxColumnWidth = 400,
    this.defaultColumnWidth = 150,
  });

  final bool showCheckboxColumn;
  final double checkboxColumnWidth;
  final double rowHeight;
  final double headerHeight;
  final double columnSpacing;
  final double horizontalMargin;
  final bool showVerticalLines;
  final bool showHorizontalLines;
  final Color? dividerColor;
  final bool striped;
  final Color? hoverColor;
  final Color? selectionColor;
  final int fixedLeftColumns;
  final int fixedRightColumns;
  final double minColumnWidth;
  final double maxColumnWidth;
  final double defaultColumnWidth;
}

/// Ligne de tableau avec sélection
class AppDataRow<T> extends StatelessWidget {
  const AppDataRow({
    super.key,
    required this.item,
    required this.index,
    required this.columns,
    required this.config,
    this.selected = false,
    this.onSelect,
    this.onTap,
    this.onLongPress,
    this.onDoubleTap,
    this.hovered = false,
    this.showDivider = true,
  });

  final T item;
  final int index;
  final List<AppDataColumn<T>> columns;
  final AppDataTableConfig config;
  final bool selected;
  final void Function(bool?)? onSelect;
  final void Function(T)? onTap;
  final void Function(T)? onLongPress;
  final void Function(T)? onDoubleTap;
  final bool hovered;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final isDark = context.isDark;
    final visibleColumns = columns.where((c) => c.visible).toList();

    final rowColor = selected
        ? (config.selectionColor ??
            (isDark
                ? tokens.brandPrimary.withValues(alpha: 0.12)
                : tokens.brandPrimary.withValues(alpha: 0.06)))
        : hovered
            ? (config.hoverColor ??
                (isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.grey.withValues(alpha: 0.08)))
            : (config.striped && index.isOdd
                ? (isDark
                    ? Colors.white.withValues(alpha: 0.15)
                    : Colors.grey.withValues(alpha: 0.1))
                : (isDark ? const Color(0xFF0F2520) : Colors.white));

    return Container(
      color: rowColor,
      child: InkWell(
        onTap: () => onTap?.call(item),
        onLongPress: () => onLongPress?.call(item),
        onDoubleTap: () => onDoubleTap?.call(item),
        child: Row(
          children: [
            if (config.showCheckboxColumn)
              SizedBox(
                width: config.checkboxColumnWidth,
                child: Center(
                  child: Checkbox(
                    value: selected,
                    onChanged: onSelect,
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ),
            Expanded(
              child: Row(
                children: visibleColumns.asMap().entries.map((entry) {
                  final colIndex = entry.key;
                  final column = entry.value;
                  final isLast = colIndex == visibleColumns.length - 1;
                  final width = column.width ??
                      (column.flex != null
                          ? null
                          : column.minWidth ?? config.defaultColumnWidth);

                  return _buildCell(
                    context,
                    column,
                    colIndex,
                    isLast,
                    width,
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCell(
    BuildContext context,
    AppDataColumn<T> column,
    int colIndex,
    bool isLast,
    double? width,
  ) {
    final tokens = context.tokens;
    final isDark = context.isDark;

    final cell = column.cellBuilder?.call(context, item, index) ??
        _buildDefaultCell(context, column, item);

    final paddedCell = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.tableCellPadding,
        vertical: tokens.sp1,
      ),
      child: Align(
        alignment: _getAlignment(column.alignment),
        child: cell,
      ),
    );

    Widget result = width != null
        ? SizedBox(width: width, child: paddedCell)
        : column.flex != null
            ? Flexible(flex: column.flex!, child: paddedCell)
            : ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: column.minWidth ?? config.minColumnWidth,
                  maxWidth: column.maxWidth ?? config.maxColumnWidth,
                ),
                child: paddedCell,
              );

    if (!isLast && config.showVerticalLines) {
      result = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          result,
          VerticalDivider(
            width: 1,
            thickness: 1,
            color: config.dividerColor ??
                (isDark ? tokens.borderDark : tokens.borderLight),
            indent: tokens.sp1,
            endIndent: tokens.sp1,
          ),
        ],
      );
    }

    return result;
  }

  Widget _buildDefaultCell(
      BuildContext context, AppDataColumn<T> column, T item) {
    final tokens = context.tokens;
    final isNumeric = column.numeric;

    // Essaie d'accéder à la propriété par clé via réflexion (pour Map)
    dynamic value;
    if (item is Map) {
      value = item[column.key];
    } else {
      // Pour les objets, essaie d'accéder via getter
      try {
        value = (item as dynamic)[column.key];
      } catch (_) {
        value = null;
      }
    }

    if (value == null) {
      return Text(
        '—',
        style: tokens.tableCell.copyWith(
          color: isNumeric ? tokens.textTertiary : tokens.textDisabled,
        ),
      );
    }

    final textStyle = isNumeric ? tokens.tableCellNumeric : tokens.tableCell;

    return Text(
      value.toString(),
      style: textStyle,
      overflow: TextOverflow.ellipsis,
      maxLines: 1,
    );
  }

  Alignment _getAlignment(TextAlign align) {
    switch (align) {
      case TextAlign.left:
        return Alignment.centerLeft;
      case TextAlign.right:
        return Alignment.centerRight;
      case TextAlign.center:
        return Alignment.center;
      case TextAlign.justify:
        return Alignment.centerLeft;
      case TextAlign.start:
        return Alignment.centerLeft;
      case TextAlign.end:
        return Alignment.centerRight;
    }
  }
}

/// Tableau de données complet avec toutes les fonctionnalités
class AppDataTable<T> extends StatefulWidget {
  const AppDataTable({
    super.key,
    required this.columns,
    required this.data,
    this.config = const AppDataTableConfig(),
    this.sortColumnKey,
    this.sortAscending = true,
    this.onSort,
    this.onRowTap,
    this.onRowLongPress,
    this.onRowDoubleTap,
    this.onSelectionChanged,
    this.selectedItems = const [],
    this.emptyState,
    this.loading = false,
    this.loadingMessage,
    this.pagination = false,
    this.pageSize = 25,
    this.currentPage = 0,
    this.onPageChanged,
    this.totalRows,
    this.showRowNumbers = false,
    this.rowNumberColumnWidth = 48,
    this.rowNumberLabel = 'N°',
    this.fixedHeader = false,
    this.scrollController,
    this.columnResizeMode = ColumnResizeMode.none,
    this.onColumnResize,
    this.rowBuilder,
  });

  final List<AppDataColumn<T>> columns;
  final List<T> data;
  final AppDataTableConfig config;
  final String? sortColumnKey;
  final bool sortAscending;
  final void Function(String?, bool)? onSort;
  final void Function(T)? onRowTap;
  final void Function(T)? onRowLongPress;
  final void Function(T)? onRowDoubleTap;
  final void Function(List<T>)? onSelectionChanged;
  final List<T> selectedItems;
  final Widget? emptyState;
  final bool loading;
  final String? loadingMessage;
  final bool pagination;
  final int pageSize;
  final int currentPage;
  final void Function(int)? onPageChanged;
  final int? totalRows;
  final bool showRowNumbers;
  final double rowNumberColumnWidth;
  final String rowNumberLabel;
  final bool fixedHeader;
  final ScrollController? scrollController;
  final ColumnResizeMode columnResizeMode;
  final void Function(String, double)? onColumnResize;
  final Widget Function(BuildContext, T, int)? rowBuilder;

  @override
  State<AppDataTable<T>> createState() => _AppDataTableState<T>();
}

class _AppDataTableState<T> extends State<AppDataTable<T>> {
  final ScrollController _internalVerticalController = ScrollController();
  final ScrollController _internalHorizontalController = ScrollController();
  late List<T> _selectedItems;
  late int _currentPage;
  late int _pageSize;
  late String? _sortColumnKey;
  late bool _sortAscending;

  @override
  void initState() {
    super.initState();
    _selectedItems = List.from(widget.selectedItems);
    _currentPage = widget.currentPage;
    _pageSize = widget.pageSize;
    _sortColumnKey = widget.sortColumnKey;
    _sortAscending = widget.sortAscending;
  }

  @override
  void didUpdateWidget(covariant AppDataTable<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedItems != oldWidget.selectedItems) {
      _selectedItems = List.from(widget.selectedItems);
    }
    if (widget.currentPage != oldWidget.currentPage) {
      _currentPage = widget.currentPage;
    }
    if (widget.pageSize != oldWidget.pageSize) {
      _pageSize = widget.pageSize;
    }
    if (widget.sortColumnKey != oldWidget.sortColumnKey) {
      _sortColumnKey = widget.sortColumnKey;
    }
    if (widget.sortAscending != oldWidget.sortAscending) {
      _sortAscending = widget.sortAscending;
    }
  }

  List<T> get _displayData {
    if (!widget.pagination) return widget.data;
    final start = _currentPage * _pageSize;
    final end = start + _pageSize;
    return widget.data.sublist(
      start.clamp(0, widget.data.length),
      end.clamp(0, widget.data.length),
    );
  }

  void _handleSort(String? columnKey, bool ascending) {
    setState(() {
      _sortColumnKey = columnKey;
      _sortAscending = ascending;
    });
    widget.onSort?.call(columnKey, ascending);
  }

  void _handleSelectAll(bool? value) {
    if (value == true) {
      setState(() => _selectedItems = List.from(_displayData));
    } else {
      setState(() => _selectedItems.clear());
    }
    widget.onSelectionChanged?.call(_selectedItems);
  }

  void _handleSelectItem(T item, bool? selected) {
    setState(() {
      if (selected == true) {
        _selectedItems.add(item);
      } else {
        _selectedItems.remove(item);
      }
    });
    widget.onSelectionChanged?.call(_selectedItems);
  }

  bool _isSelected(T item) => _selectedItems.contains(item);

  @override
  Widget build(BuildContext context) {
    final visibleColumns = widget.columns.where((c) => c.visible).toList();
    final hasSelection =
        widget.config.showCheckboxColumn || widget.onSelectionChanged != null;

    if (widget.loading) {
      return _buildLoading(context);
    }

    if (_displayData.isEmpty) {
      return _buildEmpty(context);
    }

    return Column(
      children: [
        if (widget.pagination || widget.totalRows != null)
          _buildPaginationInfo(context),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // En-tête FIXE (sticky) : hors du défilement vertical,
              // partage le même défilement horizontal que les lignes.
              if (widget.fixedHeader) {
                return _buildStickyHeaderTable(
                    context, constraints, visibleColumns, hasSelection);
              }
              return SingleChildScrollView(
                controller: widget.scrollController,
                scrollDirection: Axis.vertical,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minWidth: constraints.maxWidth,
                    ),
                    child: _buildTable(context, visibleColumns, hasSelection),
                  ),
                ),
              );
            },
          ),
        ),
        if (widget.pagination) _buildPagination(context),
      ],
    );
  }

  /// En-tête FIXE + lignes défilantes, sur le pattern éprouvé du module
  /// Stock : un SEUL défilement horizontal (SizedBox à largeur totale
  /// bornée — aucun Stack), largeurs de colonnes EXPLICITES identiques
  /// pour l'en-tête et les lignes : alignement garanti même en défilement,
  /// ce que deux DataTable séparés ne peuvent pas assurer.
  Widget _buildStickyHeaderTable(
    BuildContext context,
    BoxConstraints constraints,
    List<AppDataColumn<T>> visibleColumns,
    bool hasSelection,
  ) {
    final tokens = context.tokens;
    final isDark = context.isDark;

    // Largeur explicite par colonne — identique en-tête / lignes.
    final widths = <double>[
      ...visibleColumns.map((c) => c.width ?? widget.config.defaultColumnWidth),
    ];
    final rowNumberW =
        widget.showRowNumbers ? widget.rowNumberColumnWidth : 0.0;
    final checkboxW = (widget.config.showCheckboxColumn || hasSelection)
        ? widget.config.checkboxColumnWidth
        : 0.0;
    final contentW =
        rowNumberW + checkboxW + widths.fold(0.0, (a, b) => a + b);
    // Marges internes (horizontalMargin × 2) s'ajoutent aux colonnes :
    // sans elles, le Row déborderait exactement de cette valeur.
    final minTotalW = contentW + 2 * widget.config.horizontalMargin;
    // Largeur totale : au minimum l'espace disponible ; le défilement
    // horizontal ne s'active que si les colonnes dépassent cet espace.
    final totalW = constraints.maxWidth.isFinite
        ? (minTotalW > constraints.maxWidth ? minTotalW : constraints.maxWidth)
        : minTotalW;
    final verticalController =
        widget.scrollController ?? _internalVerticalController;
    final headerColor =
        isDark ? const Color(0xFF0F2520) : const Color(0xFF006B43);
    final divider = widget.config.dividerColor ??
        (isDark ? tokens.borderDark : tokens.borderLight);

    Widget cell(double w, Widget child, {TextAlign align = TextAlign.left}) {
      return SizedBox(
        width: w,
        child: Padding(
          padding: EdgeInsets.only(right: widget.config.columnSpacing),
          child: Align(
            alignment: align == TextAlign.right
                ? Alignment.centerRight
                : align == TextAlign.center
                    ? Alignment.center
                    : Alignment.centerLeft,
            child: child,
          ),
        ),
      );
    }

    // ---- En-tête FIXE (hors du défilement vertical) ----
    final header = Container(
      key: const ValueKey('app_table_sticky_header'),
      height: widget.config.headerHeight,
      color: headerColor,
      padding: EdgeInsets.symmetric(horizontal: widget.config.horizontalMargin),
      child: Row(children: [
        if (checkboxW > 0)
          SizedBox(
            width: checkboxW,
            child: hasSelection
                ? Center(
                    child: Checkbox(
                      value: _displayData.isNotEmpty &&
                          _selectedItems.length == _displayData.length,
                      onChanged: (v) => _handleSelectAll(v),
                    ),
                  )
                : null,
          ),
        if (widget.showRowNumbers)
          cell(rowNumberW,
              Text(widget.rowNumberLabel, style: tokens.tableHeader),
              align: TextAlign.right),
        ...visibleColumns.asMap().entries.map(
              (e) => cell(
                widths[e.key],
                _SortableHeader(
                  label: e.value.label,
                  sortable: e.value.sortable,
                  isSorted: _sortColumnKey == e.value.key,
                  sortedAscending: _sortAscending,
                  columnKey: e.value.key,
                  onSort: _handleSort,
                ),
                align: e.value.alignment,
              ),
            ),
      ]),
    );

    // ---- Lignes défilantes verticalement (fond opaque garanti) ----
    Widget buildRow(int index) {
      final item = _displayData[index];
      final globalIndex =
          widget.pagination ? _currentPage * _pageSize + index : index;
      final rowColor = _isSelected(item)
          ? (isDark ? const Color(0xFF0A2E22) : const Color(0xFFE3F2EC))
          : (widget.config.striped && index.isOdd)
              ? (isDark ? const Color(0xFF16362C) : const Color(0xFFF2F5F3))
              : (isDark ? const Color(0xFF0F2520) : Colors.white);
      return Material(
        color: rowColor,
        child: InkWell(
          onTap: widget.onRowTap != null ? () => widget.onRowTap!(item) : null,
          onLongPress: widget.onRowLongPress != null
              ? () => widget.onRowLongPress!(item)
              : null,
          onDoubleTap: widget.onRowDoubleTap != null
              ? () => widget.onRowDoubleTap!(item)
              : null,
          child: Container(
            constraints: BoxConstraints(minHeight: widget.config.rowHeight),
            decoration: BoxDecoration(
              border: widget.config.showHorizontalLines
                  ? Border(bottom: BorderSide(color: divider, width: 1))
                  : null,
            ),
            padding: EdgeInsets.symmetric(
                horizontal: widget.config.horizontalMargin),
            child: Row(children: [
              if (checkboxW > 0)
                SizedBox(
                  width: checkboxW,
                  child: hasSelection
                      ? Center(
                          child: Checkbox(
                            value: _isSelected(item),
                            onChanged: (v) => _handleSelectItem(item, v),
                          ),
                        )
                      : null,
                ),
              if (widget.showRowNumbers)
                cell(
                  rowNumberW,
                  Text('${globalIndex + 1}', style: tokens.tableCellNumeric),
                  align: TextAlign.right,
                ),
              ...visibleColumns.asMap().entries.map(
                    (e) => cell(
                      widths[e.key],
                      widget.rowBuilder?.call(context, item, index) ??
                          _buildDefaultCell(context, e.value, item),
                      align: e.value.alignment,
                    ),
                  ),
            ]),
          ),
        ),
      );
    }

    return Scrollbar(
      controller: _internalHorizontalController,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _internalHorizontalController,
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: totalW,
          height: constraints.maxHeight,
          child: Column(children: [
            header,
            Expanded(
              child: Scrollbar(
                controller: verticalController,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  controller: verticalController,
                  child: Column(
                    children: [
                      for (var i = 0; i < _displayData.length; i++) buildRow(i),
                    ],
                  ),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _internalVerticalController.dispose();
    _internalHorizontalController.dispose();
    super.dispose();
  }

  Widget _buildLoading(BuildContext context) {
    return Center(
      child: AppLoadingState(
        type: AppLoadingType.skeleton,
        size: AppLoadingSize.large,
        message: widget.loadingMessage ?? 'Chargement…',
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return widget.emptyState ??
        AppEmptyStates.noData(
          message: 'Aucune donnée à afficher',
        );
  }

  Widget _buildPaginationInfo(BuildContext context) {
    final tokens = context.tokens;
    final total = widget.totalRows ?? widget.data.length;
    final start = widget.pagination ? _currentPage * _pageSize + 1 : 1;
    final end =
        widget.pagination ? (_currentPage + 1) * _pageSize : widget.data.length;
    final pageSizes = <int>{10, 25, 50, 100, _pageSize}.toList()..sort();

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.pagePadding,
        vertical: tokens.sp2,
      ),
      child: Row(
        children: [
          Text(
            'Affichage $start–${end.clamp(0, total)} sur $total',
            style: tokens.bodySmall,
          ),
          const Spacer(),
          if (widget.pagination)
            DropdownButton<int>(
              value: _pageSize,
              items: pageSizes
                  .map((e) => DropdownMenuItem(
                        value: e,
                        child: Text('$e par page'),
                      ))
                  .toList(),
              onChanged: (v) {
                if (v == null) return;
                setState(() {
                  _pageSize = v;
                  _currentPage = 0;
                });
                widget.onPageChanged?.call(0);
              },
              underline: const SizedBox(),
            ),
        ],
      ),
    );
  }

  Widget _buildTable(
    BuildContext context,
    List<AppDataColumn<T>> visibleColumns,
    bool hasSelection,
  ) {
    final tokens = context.tokens;
    final isDark = context.isDark;

    /* DataTable indexe ses colonnes dans `columns` (la colonne « N° »
       comprise) : sans cet offset, l'indicateur de tri atterrissait sur
       la mauvaise colonne quand showRowNumbers était actif. */
    final rawSortIndex = _sortColumnKey == null
        ? -1
        : visibleColumns.indexWhere((c) => c.key == _sortColumnKey);
    final effectiveSortIndex = rawSortIndex < 0
        ? null
        : rawSortIndex + (widget.showRowNumbers ? 1 : 0);

    return DataTable(
      headingRowColor: WidgetStateProperty.resolveWith((states) =>
          isDark ? const Color(0xFF0F2520) : const Color(0xFF006B43)),
      headingRowHeight: widget.config.headerHeight,
      dataRowMinHeight: widget.config.rowHeight,
      dataRowMaxHeight: widget.config.rowHeight * 2,
      columnSpacing: widget.config.columnSpacing,
      horizontalMargin: widget.config.horizontalMargin,
      showCheckboxColumn: widget.config.showCheckboxColumn,
      checkboxHorizontalMargin: tokens.sp3,
      sortColumnIndex: effectiveSortIndex,
      sortAscending: _sortAscending,
      onSelectAll: hasSelection ? _handleSelectAll : null,
      dividerThickness: widget.config.showHorizontalLines ? 1 : 0,
      border: widget.config.showVerticalLines
          ? TableBorder(
              verticalInside: BorderSide(
                color: widget.config.dividerColor ??
                    (isDark ? tokens.borderDark : tokens.borderLight),
                width: 1,
              ),
              horizontalInside: BorderSide(
                color: widget.config.dividerColor ??
                    (isDark ? tokens.borderDark : tokens.borderLight),
                width: widget.config.showHorizontalLines ? 1 : 0,
              ),
            )
          : null,
      columns: [
        if (widget.showRowNumbers)
          DataColumn(
            label: Text(
              widget.rowNumberLabel,
              style: tokens.tableHeader,
            ),
            numeric: true,
          ),
        ...visibleColumns.map((col) => col.toDataColumn(
              context,
              columnIndex: visibleColumns.indexOf(col),
              sortedAscending: _sortAscending,
              sortColumnKey: _sortColumnKey,
              onSort: _handleSort,
            )),
      ],
      rows: _displayData.asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;
        final globalIndex =
            widget.pagination ? _currentPage * _pageSize + index : index;

        return DataRow(
          selected: _isSelected(item),
          onSelectChanged:
              hasSelection ? (v) => _handleSelectItem(item, v) : null,
          color: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return isDark ? const Color(0xFF0A2E22) : const Color(0xFFE3F2EC);
            }
            if (states.contains(WidgetState.hovered)) {
              return isDark ? const Color(0xFF16362C) : const Color(0xFFEAF2EE);
            }
            return (widget.config.striped && index.isOdd)
                ? (isDark ? const Color(0xFF16362C) : const Color(0xFFF2F5F3))
                : (isDark ? const Color(0xFF0F2520) : Colors.white);
          }),
          cells: [
            if (widget.showRowNumbers)
              DataCell(
                Center(
                  child: Text(
                    '${globalIndex + 1}',
                    style: tokens.tableCellNumeric,
                  ),
                ),
              ),
            ...visibleColumns.map((col) => DataCell(
                  widget.rowBuilder?.call(context, item, index) ??
                      _buildDefaultCell(context, col, item),
                )),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildDefaultCell(
    BuildContext context,
    AppDataColumn<T> col,
    T item,
  ) {
    final tokens = context.tokens;
    final isNumeric = col.numeric;

    dynamic value;
    if (item is Map) {
      value = item[col.key];
    } else {
      try {
        value = (item as dynamic)[col.key];
      } catch (_) {
        value = null;
      }
    }

    if (value == null) {
      return Text(
        '—',
        style: tokens.tableCell.copyWith(
          color: tokens.textDisabled,
        ),
      );
    }

    return Align(
      alignment: col.alignment == TextAlign.right
          ? Alignment.centerRight
          : col.alignment == TextAlign.center
              ? Alignment.center
              : Alignment.centerLeft,
      child: Text(
        value.toString(),
        style: isNumeric ? tokens.tableCellNumeric : tokens.tableCell,
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
    );
  }

  Widget _buildPagination(BuildContext context) {
    final tokens = context.tokens;
    final isDark = context.isDark;
    final totalPages = widget.totalRows != null
        ? (widget.totalRows! / _pageSize).ceil()
        : (widget.data.length / _pageSize).ceil();

    if (totalPages <= 1) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.all(tokens.sp4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: Icon(Icons.chevron_left_rounded, size: tokens.fontSizeXl),
            onPressed: _currentPage > 0
                ? () => widget.onPageChanged?.call(_currentPage - 1)
                : null,
            tooltip: 'Page précédente',
          ),
          ...List.generate(totalPages.clamp(0, 5), (index) {
            final pageIndex = totalPages > 5 && _currentPage > 2
                ? _currentPage - 2 + index
                : index;
            if (pageIndex >= totalPages) return const SizedBox.shrink();

            return Padding(
              padding: EdgeInsets.symmetric(horizontal: tokens.sp1),
              child: FilterChip(
                label: Text('${pageIndex + 1}', style: tokens.labelSmall),
                selected: pageIndex == _currentPage,
                onSelected: (_) => widget.onPageChanged?.call(pageIndex),
                selectedColor: tokens.brandPrimary.withValues(alpha: 0.15),
                checkmarkColor: tokens.brandPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(tokens.rFull),
                  side: BorderSide(
                    color: pageIndex == _currentPage
                        ? tokens.brandPrimary
                        : (isDark ? tokens.borderDark : tokens.borderLight),
                  ),
                ),
              ),
            );
          }),
          IconButton(
            icon: Icon(Icons.chevron_right_rounded, size: tokens.fontSizeXl),
            onPressed: _currentPage < totalPages - 1
                ? () => widget.onPageChanged?.call(_currentPage + 1)
                : null,
            tooltip: 'Page suivante',
          ),
        ],
      ),
    );
  }
}

enum ColumnResizeMode {
  none,
  hover,
  drag,
}
