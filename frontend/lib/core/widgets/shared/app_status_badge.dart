import 'package:flutter/material.dart';
import '../../theme/design_tokens.dart';

/// Badge de statut standardisé PHARMA+
/// Remplace StatusChip et badges custom dans toutes les pages
class AppStatusBadge extends StatelessWidget {
  const AppStatusBadge({
    super.key,
    required this.label,
    this.type = AppStatusType.info,
    this.size = AppStatusSize.medium,
    this.showIcon = false,
    this.icon,
    this.onTap,
    this.tooltip,
    this.customColor,
    this.customTextColor,
    this.customBorderColor,
    this.padding,
  });

  final String label;
  final AppStatusType type;
  final AppStatusSize size;
  final bool showIcon;
  final IconData? icon;
  final VoidCallback? onTap;
  final String? tooltip;
  final Color? customColor;
  final Color? customTextColor;
  final Color? customBorderColor;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    final config = _getConfig(context);
    final bgColor = customColor ?? config.bgColor;
    final textColor = customTextColor ?? config.textColor;
    final borderColor = customBorderColor ?? config.borderColor;
    final iconData = icon ?? config.icon;
    final labelStyle = _getLabelStyle(context, size);
    final horizontalPadding = padding?.horizontal ?? _getHorizontalPadding(size);
    final verticalPadding = padding?.vertical ?? _getVerticalPadding(size);
    final radius = _getRadius(size);
    final iconSize = _getIconSize(size);

    final badge = Container(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: verticalPadding,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showIcon || icon != null) ...[
            Icon(iconData, size: iconSize, color: textColor),
            SizedBox(width: tokens.sp1),
          ],
          Text(
            label,
            style: labelStyle.copyWith(color: textColor),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: badge,
      );
    }

    if (tooltip != null) {
      return Tooltip(
        message: tooltip!,
        child: badge,
      );
    }

    return badge;
  }

  _StatusConfig _getConfig(BuildContext context) {
    final tokens = context.tokens;
    final isDark = context.isDark;

    switch (type) {
      case AppStatusType.success:
        return _StatusConfig(
          bgColor: isDark
              ? tokens.success.withValues(alpha: 0.15)
              : tokens.success.withValues(alpha: 0.1),
          textColor: tokens.success,
          borderColor: tokens.success.withValues(alpha: 0.3),
          icon: Icons.check_circle_rounded,
        );
      case AppStatusType.warning:
        return _StatusConfig(
          bgColor: isDark
              ? tokens.warning.withValues(alpha: 0.15)
              : tokens.warning.withValues(alpha: 0.1),
          textColor: tokens.warning,
          borderColor: tokens.warning.withValues(alpha: 0.3),
          icon: Icons.warning_amber_rounded,
        );
      case AppStatusType.danger:
      case AppStatusType.error:
        return _StatusConfig(
          bgColor: isDark
              ? tokens.danger.withValues(alpha: 0.15)
              : tokens.danger.withValues(alpha: 0.1),
          textColor: tokens.danger,
          borderColor: tokens.danger.withValues(alpha: 0.3),
          icon: Icons.error_rounded,
        );
      case AppStatusType.info:
        return _StatusConfig(
          bgColor: isDark
              ? tokens.info.withValues(alpha: 0.15)
              : tokens.info.withValues(alpha: 0.1),
          textColor: tokens.info,
          borderColor: tokens.info.withValues(alpha: 0.3),
          icon: Icons.info_rounded,
        );
      case AppStatusType.neutral:
        return _StatusConfig(
          bgColor: isDark ? tokens.bgSurfaceRaised : Colors.grey[100]!,
          textColor: isDark ? tokens.textSecondary : tokens.textTertiary,
          borderColor: isDark ? tokens.borderDark : tokens.borderLight,
          icon: Icons.remove_circle_outline_rounded,
        );
      case AppStatusType.pending:
        return _StatusConfig(
          bgColor: isDark
              ? tokens.info.withValues(alpha: 0.15)
              : tokens.info.withValues(alpha: 0.1),
          textColor: tokens.info,
          borderColor: tokens.info.withValues(alpha: 0.3),
          icon: Icons.schedule_rounded,
        );
      case AppStatusType.custom:
        return _StatusConfig(
          bgColor: customColor ??
              (isDark
                  ? tokens.brandPrimary.withValues(alpha: 0.15)
                  : tokens.brandPrimary.withValues(alpha: 0.1)),
          textColor: customTextColor ?? tokens.brandPrimary,
          borderColor: customBorderColor ?? tokens.brandPrimary.withValues(alpha: 0.3),
          icon: icon ?? Icons.label_rounded,
        );
    }
  }

  TextStyle _getLabelStyle(BuildContext context, AppStatusSize size) {
    final tokens = context.tokens;
    switch (size) {
      case AppStatusSize.small:
        return tokens.labelSmall.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        );
      case AppStatusSize.medium:
        return tokens.labelMedium.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
        );
      case AppStatusSize.large:
        return tokens.labelLarge.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        );
    }
  }

  double _getHorizontalPadding(AppStatusSize size) {
    switch (size) {
      case AppStatusSize.small:
        return PharmaTokens.space2;
      case AppStatusSize.medium:
        return PharmaTokens.space3;
      case AppStatusSize.large:
        return PharmaTokens.space4;
    }
  }

  double _getVerticalPadding(AppStatusSize size) {
    switch (size) {
      case AppStatusSize.small:
        return PharmaTokens.space0;
      case AppStatusSize.medium:
        return PharmaTokens.space1;
      case AppStatusSize.large:
        return PharmaTokens.space2;
    }
  }

  double _getRadius(AppStatusSize size) {
    switch (size) {
      case AppStatusSize.small:
        return PharmaTokens.radiusFull;
      case AppStatusSize.medium:
        return PharmaTokens.radiusFull;
      case AppStatusSize.large:
        return PharmaTokens.radiusFull;
    }
  }

  double _getIconSize(AppStatusSize size) {
    switch (size) {
      case AppStatusSize.small:
        return PharmaTokens.fontSizeXs;
      case AppStatusSize.medium:
        return PharmaTokens.fontSizeSm;
      case AppStatusSize.large:
        return PharmaTokens.fontSizeBase;
    }
  }
}

/// Types de statut
enum AppStatusType {
  success,
  warning,
  danger,
  error,
  info,
  neutral,
  pending,
  custom,
}

/// Tailles de badge
enum AppStatusSize {
  small,
  medium,
  large,
}

/// Configuration interne
class _StatusConfig {
  const _StatusConfig({
    required this.bgColor,
    required this.textColor,
    required this.borderColor,
    required this.icon,
  });

  final Color bgColor;
  final Color textColor;
  final Color borderColor;
  final IconData icon;
}

/// Badges prédéfinis pour domaines métier
class AppDomainBadge extends StatelessWidget {
  const AppDomainBadge({
    super.key,
    required this.domain,
    required this.label,
    this.size = AppStatusSize.medium,
    this.showIcon = true,
  });

  final AppDomain domain;
  final String label;
  final AppStatusSize size;
  final bool showIcon;

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;

    final config = _getDomainConfig(context, domain);

    return AppStatusBadge(
      label: label,
      type: AppStatusType.custom,
      size: size,
      showIcon: showIcon,
      customColor: isDark
          ? config.color.withValues(alpha: 0.15)
          : config.color.withValues(alpha: 0.1),
      customTextColor: config.color,
      customBorderColor: config.color.withValues(alpha: 0.3),
      icon: config.icon,
    );
  }

  _DomainConfig _getDomainConfig(BuildContext context, AppDomain domain) {
    final tokens = context.tokens;
    switch (domain) {
      case AppDomain.revenue:
        return _DomainConfig(tokens.domainRevenue, Icons.attach_money_rounded);
      case AppDomain.stock:
        return _DomainConfig(tokens.domainStock, Icons.inventory_2_rounded);
      case AppDomain.orders:
        return _DomainConfig(tokens.domainOrders, Icons.shopping_cart_rounded);
      case AppDomain.suppliers:
        return _DomainConfig(tokens.domainSuppliers, Icons.local_shipping_rounded);
      case AppDomain.customers:
        return _DomainConfig(tokens.domainCustomers, Icons.people_rounded);
      case AppDomain.employees:
        return _DomainConfig(tokens.domainEmployees, Icons.badge_rounded);
      case AppDomain.ai:
        return _DomainConfig(tokens.domainAI, Icons.psychology_rounded);
      case AppDomain.analytics:
        return _DomainConfig(tokens.domainAnalytics, Icons.analytics_rounded);
    }
  }
}

enum AppDomain {
  revenue,
  stock,
  orders,
  suppliers,
  customers,
  employees,
  ai,
  analytics,
}

class _DomainConfig {
  const _DomainConfig(this.color, this.icon);
  final Color color;
  final IconData icon;
}