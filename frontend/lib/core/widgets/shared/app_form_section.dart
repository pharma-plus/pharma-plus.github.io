import 'package:flutter/material.dart';
import '../../theme/design_tokens.dart';

/// Section de formulaire standardisée PHARMA+
/// Regroupe des champs liés avec titre, description, aide
class AppFormSection extends StatelessWidget {
  const AppFormSection({
    super.key,
    required this.title,
    this.description,
    this.icon,
    this.children = const [],
    this.footer,
    this.collapsible = false,
    this.initiallyExpanded = true,
    this.expansionCallback,
    this.padding,
    this.margin,
    this.backgroundColor,
    this.borderColor,
    this.showDivider = true,
    this.crossAxisAlignment = CrossAxisAlignment.stretch,
    this.spacing = 16,
  });

  final String title;
  final String? description;
  final IconData? icon;
  final List<Widget> children;
  final Widget? footer;
  final bool collapsible;
  final bool initiallyExpanded;
  final void Function(bool)? expansionCallback;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? backgroundColor;
  final Color? borderColor;
  final bool showDivider;
  final CrossAxisAlignment crossAxisAlignment;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final isDark = context.isDark;

    if (collapsible) {
      return _CollapsibleSection(
        title: title,
        description: description,
        icon: icon,
        footer: footer,
        initiallyExpanded: initiallyExpanded,
        expansionCallback: expansionCallback,
        padding: padding,
        margin: margin,
        backgroundColor: backgroundColor,
        borderColor: borderColor,
        showDivider: showDivider,
        crossAxisAlignment: crossAxisAlignment,
        spacing: spacing,
        children: children,
      );
    }

    return Container(
      margin: margin ?? EdgeInsets.symmetric(vertical: tokens.sp2),
      padding: padding ?? EdgeInsets.all(tokens.sp4),
      decoration: BoxDecoration(
        color:
            backgroundColor ?? (isDark ? tokens.bgSurfaceRaised : Colors.white),
        borderRadius: BorderRadius.circular(tokens.rCard),
        border: Border.all(
          color:
              borderColor ?? (isDark ? tokens.borderDark : tokens.borderLight),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: crossAxisAlignment,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(tokens, isDark),
          if (description != null) ...[
            SizedBox(height: tokens.sp1),
            Text(
              description!,
              style: tokens.bodySmall.copyWith(
                color: isDark ? tokens.textTertiary : tokens.textDisabled,
              ),
            ),
          ],
          SizedBox(height: spacing),
          ...children
              .expand((widget) => [widget, SizedBox(height: spacing)])
              .take(children.length * 2 - 1),
          if (footer != null) ...[
            SizedBox(height: spacing),
            footer!,
          ],
        ],
      ),
    );
  }

  Widget _buildHeader(PharmaTokensHelper tokens, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (icon != null) ...[
          Container(
            padding: EdgeInsets.all(tokens.sp2),
            decoration: BoxDecoration(
              color: tokens.brandPrimary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(tokens.rMd),
            ),
            child: Icon(
              icon,
              size: tokens.fontSizeLg,
              color: tokens.brandPrimary,
            ),
          ),
          SizedBox(width: tokens.sp3),
        ],
        Expanded(
          child: Text(
            title,
            style: tokens.titleMedium.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _CollapsibleSection extends StatefulWidget {
  const _CollapsibleSection({
    required this.title,
    this.description,
    this.icon,
    required this.children,
    this.footer,
    required this.initiallyExpanded,
    this.expansionCallback,
    this.padding,
    this.margin,
    this.backgroundColor,
    this.borderColor,
    required this.showDivider,
    required this.crossAxisAlignment,
    required this.spacing,
  });

  final String title;
  final String? description;
  final IconData? icon;
  final List<Widget> children;
  final Widget? footer;
  final bool initiallyExpanded;
  final void Function(bool)? expansionCallback;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? backgroundColor;
  final Color? borderColor;
  final bool showDivider;
  final CrossAxisAlignment crossAxisAlignment;
  final double spacing;

  @override
  State<_CollapsibleSection> createState() => _CollapsibleSectionState();
}

class _CollapsibleSectionState extends State<_CollapsibleSection>
    with SingleTickerProviderStateMixin {
  late bool _expanded;
  late AnimationController _controller;
  late Animation<double> _heightAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _heightAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
    _opacityAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
    );

    if (_expanded) {
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _expanded = !_expanded;
      if (_expanded) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
      widget.expansionCallback?.call(_expanded);
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final isDark = context.isDark;

    return Container(
      margin: widget.margin ?? EdgeInsets.symmetric(vertical: tokens.sp2),
      decoration: BoxDecoration(
        color: widget.backgroundColor ??
            (isDark ? tokens.bgSurfaceRaised : Colors.white),
        borderRadius: BorderRadius.circular(tokens.rCard),
        border: Border.all(
          color: widget.borderColor ??
              (isDark ? tokens.borderDark : tokens.borderLight),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: _toggle,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(tokens.rCard),
              bottom: _expanded ? Radius.zero : Radius.circular(tokens.rCard),
            ),
            child: Padding(
              padding: widget.padding ?? EdgeInsets.all(tokens.sp4),
              child: Row(
                children: [
                  if (widget.icon != null) ...[
                    Container(
                      padding: EdgeInsets.all(tokens.sp2),
                      decoration: BoxDecoration(
                        color: tokens.brandPrimary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(tokens.rMd),
                      ),
                      child: Icon(
                        widget.icon,
                        size: tokens.fontSizeLg,
                        color: tokens.brandPrimary,
                      ),
                    ),
                    SizedBox(width: tokens.sp3),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: tokens.titleMedium.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (widget.description != null) ...[
                          SizedBox(height: tokens.sp1),
                          Text(
                            widget.description!,
                            style: tokens.bodySmall.copyWith(
                              color: isDark
                                  ? tokens.textTertiary
                                  : tokens.textDisabled,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 300),
                    child: Icon(
                      Icons.expand_more_rounded,
                      size: tokens.fontSizeXl,
                      color: isDark ? tokens.textTertiary : tokens.textDisabled,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return ClipRect(
                child: Align(
                  heightFactor: _heightAnimation.value,
                  child: Opacity(
                    opacity: _opacityAnimation.value,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        tokens.sp4,
                        0,
                        tokens.sp4,
                        tokens.sp4,
                      ),
                      child: Column(
                        crossAxisAlignment: widget.crossAxisAlignment,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (widget.showDivider) ...[
                            Divider(
                              color: isDark
                                  ? tokens.borderDark
                                  : tokens.borderLight,
                              height: tokens.sp3,
                            ),
                            SizedBox(height: tokens.sp1),
                          ],
                          ...widget.children
                              .expand(
                                  (w) => [w, SizedBox(height: widget.spacing)])
                              .take(widget.children.length * 2 - 1),
                          if (widget.footer != null) ...[
                            SizedBox(height: widget.spacing),
                            widget.footer!,
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Groupe de champs inline (sur une ligne si espace)
class AppFormFieldGroup extends StatelessWidget {
  const AppFormFieldGroup({
    super.key,
    required this.children,
    this.spacing = 16,
    this.runSpacing = 16,
    this.crossAxisAlignment = WrapCrossAlignment.start,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.wrapAlignment = WrapAlignment.start,
  });

  final List<Widget> children;
  final double spacing;
  final double runSpacing;
  final WrapCrossAlignment crossAxisAlignment;
  final MainAxisAlignment mainAxisAlignment;
  final WrapAlignment wrapAlignment;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: spacing,
      runSpacing: runSpacing,
      crossAxisAlignment: crossAxisAlignment,
      alignment: wrapAlignment,
      direction: Axis.horizontal,
      children: children.map((child) => Flexible(child: child)).toList(),
    );
  }
}

/// Titre de page standardisé
class AppPageHeader extends StatelessWidget {
  const AppPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.actions = const [],
    this.counter,
    this.counterLabel,
    this.showDivider = true,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final List<Widget> actions;
  final int? counter;
  final String? counterLabel;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final isDark = context.isDark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (icon != null) ...[
              Container(
                padding: EdgeInsets.all(tokens.sp3),
                decoration: BoxDecoration(
                  color: tokens.brandPrimary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(tokens.rMd),
                ),
                child: Icon(
                  icon,
                  size: tokens.fontSize2xl,
                  color: tokens.brandPrimary,
                ),
              ),
              SizedBox(width: tokens.sp4),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: tokens.displaySmall.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (subtitle != null) ...[
                    SizedBox(height: tokens.sp1),
                    Text(
                      subtitle!,
                      style: tokens.bodyMedium.copyWith(
                        color:
                            isDark ? tokens.textTertiary : tokens.textDisabled,
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
            ...actions.map((a) => Padding(
                  padding: EdgeInsets.only(left: tokens.sp2),
                  child: a,
                )),
          ],
        ),
        if (showDivider) ...[
          SizedBox(height: tokens.sp3),
          Divider(
            color: isDark ? tokens.borderDark : tokens.borderLight,
            height: 1,
            thickness: 1,
          ),
        ],
      ],
    );
  }
}
