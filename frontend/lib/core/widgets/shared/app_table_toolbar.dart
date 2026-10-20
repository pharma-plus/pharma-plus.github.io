import 'package:flutter/material.dart';
import '../../theme/design_tokens.dart';

/// Barre d'outils de tableau standardisée
class AppTableToolbar extends StatelessWidget {
  const AppTableToolbar({
    super.key,
    this.title,
    this.subtitle,
    this.counter,
    this.counterLabel,
    this.searchField,
    this.filterButton,
    this.actions = const [],
    this.primaryAction,
    this.secondaryActions = const [],
    this.leading,
    this.trailing,
    this.showDivider = true,
  });

  final String? title;
  final String? subtitle;
  final int? counter;
  final String? counterLabel;
  final Widget? searchField;
  final Widget? filterButton;
  final List<Widget> actions;
  final Widget? primaryAction;
  final List<Widget> secondaryActions;
  final Widget? leading;
  final Widget? trailing;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final isDark = context.isDark;

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: tokens.pagePadding,
            vertical: tokens.sp3,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (leading != null) ...[
                leading!,
                SizedBox(width: tokens.sp3),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (title != null)
                      Text(
                        title!,
                        style: tokens.displaySmall.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    if (subtitle != null) ...[
                      SizedBox(height: tokens.sp1),
                      Text(
                        subtitle!,
                        style: tokens.bodyMedium.copyWith(
                          color: isDark ? tokens.textTertiary : tokens.textDisabled,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (counter != null) ...[
                SizedBox(width: tokens.sp4),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: tokens.sp4,
                    vertical: tokens.sp2,
                  ),
                  decoration: BoxDecoration(
                    color: tokens.brandPrimary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(tokens.rFull),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$counter',
                        style: tokens.titleMedium.copyWith(
                          color: tokens.brandPrimary,
                          fontWeight: FontWeight.w800,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      if (counterLabel != null) ...[
                        SizedBox(width: tokens.sp2),
                        Text(
                          counterLabel!,
                          style: tokens.labelSmall.copyWith(
                            color: tokens.brandPrimary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              SizedBox(width: tokens.sp3),
              if (searchField != null)
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: 320),
                  child: searchField!,
                )
              else if (filterButton != null)
                filterButton!,
              ...actions.map((a) => Padding(
                padding: EdgeInsets.only(left: tokens.sp2),
                child: a,
              )),
              if (primaryAction != null) ...[
                SizedBox(width: tokens.sp3),
                primaryAction!,
              ],
              ...secondaryActions.map((a) => Padding(
                padding: EdgeInsets.only(left: tokens.sp2),
                child: a,
              )),
              if (trailing != null) ...[
                SizedBox(width: tokens.sp3),
                trailing!,
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
}

/// Bouton d'action principale standardisé
class AppPrimaryAction extends StatelessWidget {
  const AppPrimaryAction({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.iconOnly = false,
    this.loading = false,
    this.enabled = true,
    this.tooltip,
    this.size = AppButtonSize.medium,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool iconOnly;
  final bool loading;
  final bool enabled;
  final String? tooltip;
  final AppButtonSize size;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    final padding = _getPadding(size, tokens);
    final minSize = _getMinSize(size, tokens);
    final textStyle = _getTextStyle(tokens, size);
    final iconSize = _getIconSize(size, tokens);

    final button = FilledButton(
      onPressed: enabled && !loading ? onPressed : null,
      style: FilledButton.styleFrom(
        minimumSize: minSize,
        padding: padding,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.rButton),
        ),
        elevation: tokens.elevation2,
      ),
      child: loading
          ? SizedBox(
              width: iconSize,
              height: iconSize,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : iconOnly && icon != null
              ? Icon(icon, size: iconSize)
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: iconSize),
                      SizedBox(width: tokens.sp2),
                    ],
                    Flexible(
                      child: Text(
                        label,
                        style: textStyle,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
    );

    if (tooltip != null) {
      return Tooltip(
        message: tooltip!,
        child: button,
      );
    }

    return button;
  }

  EdgeInsets _getPadding(AppButtonSize size, PharmaTokensHelper tokens) {
    switch (size) {
      case AppButtonSize.small:
        return EdgeInsets.symmetric(
          horizontal: tokens.space3,
          vertical: tokens.space2,
        );
      case AppButtonSize.medium:
        return EdgeInsets.symmetric(
          horizontal: tokens.space5,
          vertical: tokens.space3,
        );
      case AppButtonSize.large:
        return EdgeInsets.symmetric(
          horizontal: tokens.space6,
          vertical: tokens.space4,
        );
    }
  }

  Size _getMinSize(AppButtonSize size, PharmaTokensHelper tokens) {
    switch (size) {
      case AppButtonSize.small:
        return Size(tokens.heightButton, tokens.heightButtonDense);
      case AppButtonSize.medium:
        return Size(tokens.heightButton, tokens.heightButton);
      case AppButtonSize.large:
        return Size(tokens.heightButtonLarge, tokens.heightButtonLarge);
    }
  }

  TextStyle _getTextStyle(PharmaTokensHelper tokens, AppButtonSize size) {
    switch (size) {
      case AppButtonSize.small:
        return tokens.labelSmall;
      case AppButtonSize.medium:
        return tokens.labelLarge;
      case AppButtonSize.large:
        return tokens.titleMedium.copyWith(fontWeight: FontWeight.w700);
    }
  }

  double _getIconSize(AppButtonSize size, PharmaTokensHelper tokens) {
    switch (size) {
      case AppButtonSize.small:
        return tokens.fontSizeSm;
      case AppButtonSize.medium:
        return tokens.fontSizeBase;
      case AppButtonSize.large:
        return tokens.fontSizeLg;
    }
  }
}

enum AppButtonSize {
  small,
  medium,
  large,
}

/// Groupe d'actions secondaires
class AppActionGroup extends StatelessWidget {
  const AppActionGroup({
    super.key,
    this.actions = const [],
    this.spacing = 8,
    this.direction = Axis.horizontal,
    this.alignment = MainAxisAlignment.end,
  });

  final List<Widget> actions;
  final double spacing;
  final Axis direction;
  final MainAxisAlignment alignment;

  @override
  Widget build(BuildContext context) {
    if (direction == Axis.horizontal) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: alignment,
        children: actions
            .expand((w) => [
                  w,
                  SizedBox(width: spacing),
                ])
            .take(actions.length * 2 - 1)
            .toList(),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: actions
          .expand((w) => [
                w,
                SizedBox(height: spacing),
              ])
          .take(actions.length * 2 - 1)
          .toList(),
    );
  }
}

/// Menu d'actions contextuelles (dropdown)
class AppActionMenu extends StatelessWidget {
  const AppActionMenu({
    super.key,
    required this.items,
    this.icon = Icons.more_vert_rounded,
    this.iconSize = 24,
    this.tooltip,
    this.offset,
    this.constraints,
    this.shape,
    this.elevation,
  });

  final List<AppActionMenuItem> items;
  final IconData icon;
  final double iconSize;
  final String? tooltip;
  final Offset? offset;
  final BoxConstraints? constraints;
  final ShapeBorder? shape;
  final double? elevation;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final isDark = context.isDark;

    return PopupMenuButton<AppActionMenuItem>(
      tooltip: tooltip,
      offset: offset ?? Offset(0, tokens.sp3),
      constraints: constraints ??
          BoxConstraints(
            minWidth: 180,
            maxWidth: 280,
          ),
      shape: shape ??
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(tokens.rMd),
            side: BorderSide(
              color: isDark ? tokens.borderDark : tokens.borderLight,
            ),
          ),
      elevation: elevation ?? tokens.elevation3,
      icon: Icon(
        icon,
        size: iconSize,
        color: isDark ? tokens.textTertiary : tokens.textDisabled,
      ),
      itemBuilder: (context) => items.map((item) => PopupMenuItem<AppActionMenuItem>(
            value: item,
            enabled: item.enabled,
            padding: EdgeInsets.symmetric(
              horizontal: tokens.sp3,
              vertical: tokens.sp1,
            ),
            child: Row(
              children: [
                if (item.icon != null) ...[
                  Icon(
                    item.icon,
                    size: tokens.fontSizeBase,
                    color: item.destructive
                        ? tokens.danger
                        : (isDark ? tokens.textSecondary : tokens.textSecondary),
                  ),
                  SizedBox(width: tokens.sp2),
                ],
                Flexible(
                  child: Text(
                    item.label,
                    style: tokens.bodyMedium.copyWith(
                      color: item.destructive
                          ? tokens.danger
                          : (isDark ? tokens.textPrimary : tokens.textPrimary),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (item.shortcut != null) ...[
                  SizedBox(width: tokens.sp2),
                  Text(
                    item.shortcut!,
                    style: tokens.labelSmall.copyWith(
                      color: isDark ? tokens.textTertiary : tokens.textDisabled,
                    ),
                  ),
                ],
              ],
            ),
          )).toList(),
      onSelected: (item) => item.onSelected?.call(),
    );
  }
}

class AppActionMenuItem {
  const AppActionMenuItem({
    required this.label,
    required this.onSelected,
    this.icon,
    this.destructive = false,
    this.enabled = true,
    this.shortcut,
  });

  final String label;
  final VoidCallback? onSelected;
  final IconData? icon;
  final bool destructive;
  final bool enabled;
  final String? shortcut;
}