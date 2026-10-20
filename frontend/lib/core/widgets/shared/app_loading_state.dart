import 'package:flutter/material.dart';
import '../../theme/design_tokens.dart';

/// États de chargement standardisés PHARMA+
/// Remplace CircularProgressIndicator et shimmer custom
class AppLoadingState extends StatelessWidget {
  const AppLoadingState({
    super.key,
    this.type = AppLoadingType.spinner,
    this.size = AppLoadingSize.medium,
    this.color,
    this.message,
    this.centered = true,
  });

  final AppLoadingType type;
  final AppLoadingSize size;
  final Color? color;
  final String? message;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final isDark = context.isDark;
    final effectiveColor = color ?? tokens.brandEmerald;

    Widget content;

    switch (type) {
      case AppLoadingType.spinner:
        content = _buildSpinner(tokens, effectiveColor);
        break;
      case AppLoadingType.dots:
        content = _buildDots(tokens, effectiveColor);
        break;
      case AppLoadingType.pulse:
        content = _buildPulse(tokens, effectiveColor);
        break;
      case AppLoadingType.bar:
        content = _buildBar(tokens, effectiveColor);
        break;
      case AppLoadingType.skeleton:
        content = _buildSkeleton(tokens, isDark);
        break;
    }

    if (message != null) {
      content = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          content,
          SizedBox(height: tokens.sp3),
          Text(
            message!,
            style: tokens.bodySmall.copyWith(
              color: isDark ? tokens.textTertiary : tokens.textDisabled,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      );
    }

    if (centered) {
      return Center(child: content);
    }

    return content;
  }

  Widget _buildSpinner(PharmaTokensHelper tokens, Color color) {
    final diameter = _getDiameter(size);
    final strokeWidth = _getStrokeWidth(size);

    return SizedBox(
      width: diameter,
      height: diameter,
      child: CircularProgressIndicator(
        color: color,
        strokeWidth: strokeWidth,
        strokeCap: StrokeCap.round,
      ),
    );
  }

  Widget _buildDots(PharmaTokensHelper tokens, Color color) {
    final diameter = _getDotSize(size);
    return SizedBox(
      width: diameter * 3 + tokens.sp3 * 2,
      height: diameter,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(3, (index) => _AnimatedDot(
          index: index,
          size: diameter,
          color: color,
        )),
      ),
    );
  }

  Widget _buildPulse(PharmaTokensHelper tokens, Color color) {
    final diameter = _getDiameter(size);
    return SizedBox(
      width: diameter,
      height: diameter,
      child: _PulseIndicator(
        color: color,
        size: diameter,
      ),
    );
  }

  Widget _buildBar(PharmaTokensHelper tokens, Color color) {
    final width = _getBarWidth(size);
    final height = _getBarHeight(size);

    return SizedBox(
      width: width,
      height: height,
      child: LinearProgressIndicator(
        color: color,
        backgroundColor: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(tokens.rFull),
        minHeight: height,
      ),
    );
  }

  Widget _buildSkeleton(PharmaTokensHelper tokens, bool isDark) {
    return _SkeletonLoader(
      isDark: isDark,
      width: size == AppLoadingSize.large ? 300 : 200,
      height: tokens.tableRowHeight,
    );
  }

  double _getDiameter(AppLoadingSize size) {
    switch (size) {
      case AppLoadingSize.small:
        return 20;
      case AppLoadingSize.medium:
        return 28;
      case AppLoadingSize.large:
        return 40;
      case AppLoadingSize.xlarge:
        return 56;
    }
  }

  double _getStrokeWidth(AppLoadingSize size) {
    switch (size) {
      case AppLoadingSize.small:
        return 2;
      case AppLoadingSize.medium:
        return 3;
      case AppLoadingSize.large:
        return 4;
      case AppLoadingSize.xlarge:
        return 5;
    }
  }

  double _getDotSize(AppLoadingSize size) {
    switch (size) {
      case AppLoadingSize.small:
        return 6;
      case AppLoadingSize.medium:
        return 8;
      case AppLoadingSize.large:
        return 12;
      case AppLoadingSize.xlarge:
        return 16;
    }
  }

  double _getBarWidth(AppLoadingSize size) {
    switch (size) {
      case AppLoadingSize.small:
        return 80;
      case AppLoadingSize.medium:
        return 160;
      case AppLoadingSize.large:
        return 240;
      case AppLoadingSize.xlarge:
        return 320;
    }
  }

  double _getBarHeight(AppLoadingSize size) {
    switch (size) {
      case AppLoadingSize.small:
        return 3;
      case AppLoadingSize.medium:
        return 4;
      case AppLoadingSize.large:
        return 6;
      case AppLoadingSize.xlarge:
        return 8;
    }
  }
}

enum AppLoadingType {
  spinner,
  dots,
  pulse,
  bar,
  skeleton,
}

enum AppLoadingSize {
  small,
  medium,
  large,
  xlarge,
}

/// Indicateur à points animés
class _AnimatedDot extends StatefulWidget {
  const _AnimatedDot({
    required this.index,
    required this.size,
    required this.color,
  });

  final int index;
  final double size;
  final Color color;

  @override
  State<_AnimatedDot> createState() => _AnimatedDotState();
}

class _AnimatedDotState extends State<_AnimatedDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat();

    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(
          widget.index * 0.2,
          0.6 + widget.index * 0.2,
          curve: Curves.easeInOut,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.scale(
          scale: 0.5 + _animation.value * 0.5,
          child: Opacity(
            opacity: 0.3 + _animation.value * 0.7,
            child: Container(
              width: widget.size,
              height: widget.size,
              margin: EdgeInsets.symmetric(horizontal: PharmaTokens.space1),
              decoration: BoxDecoration(
                color: widget.color,
                shape: BoxShape.circle,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Indicateur de pulsation
class _PulseIndicator extends StatefulWidget {
  const _PulseIndicator({
    required this.color,
    required this.size,
  });

  final Color color;
  final double size;

  @override
  State<_PulseIndicator> createState() => _PulseIndicatorState();
}

class _PulseIndicatorState extends State<_PulseIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _opacityAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Opacity(
            opacity: _opacityAnimation.value,
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                color: widget.color,
                shape: BoxShape.circle,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Skeleton loader pour listes/tableaux
class _SkeletonLoader extends StatefulWidget {
  const _SkeletonLoader({
    required this.isDark,
    required this.width,
    required this.height,
  });

  final bool isDark;
  final double width;
  final double height;

  @override
  State<_SkeletonLoader> createState() => _SkeletonLoaderState();
}

class _SkeletonLoaderState extends State<_SkeletonLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();

    _animation = Tween<double>(begin: -1, end: 2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final baseColor = widget.isDark
        ? tokens.bgSurfaceRaised
        : Colors.grey[300]!;
    final highlightColor = widget.isDark
        ? tokens.bgSurface2
        : Colors.grey[100]!;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: baseColor,
            borderRadius: BorderRadius.circular(PharmaTokens.radiusMd),
            gradient: LinearGradient(
              begin: Alignment(_animation.value - 1, 0),
              end: Alignment(_animation.value, 0),
              colors: [
                baseColor,
                highlightColor,
                baseColor,
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        );
      },
    );
  }
}

/// Shimmer pour listes
class AppShimmerList extends StatelessWidget {
  const AppShimmerList({
    super.key,
    this.itemCount = 5,
    this.itemHeight = 72,
    this.itemBuilder,
    this.separator,
    this.padding,
  });

  final int itemCount;
  final double itemHeight;
  final Widget Function(BuildContext, int)? itemBuilder;
  final Widget? separator;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final isDark = context.isDark;

    return ListView.builder(
      padding: padding ?? EdgeInsets.all(tokens.sp4),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        final child = itemBuilder?.call(context, index) ?? _ShimmerItem(
          height: itemHeight,
          isDark: isDark,
        );

        if (separator != null && index < itemCount - 1) {
          return Column(
            children: [child, separator!],
          );
        }

        return child;
      },
    );
  }
}

class _ShimmerItem extends StatefulWidget {
  const _ShimmerItem({
    required this.height,
    required this.isDark,
  });

  final double height;
  final bool isDark;

  @override
  State<_ShimmerItem> createState() => _ShimmerItemState();
}

class _ShimmerItemState extends State<_ShimmerItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();

    _animation = Tween<double>(begin: -1, end: 2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final baseColor = widget.isDark
        ? tokens.bgSurfaceRaised
        : Colors.grey[300]!;
    final highlightColor = widget.isDark
        ? tokens.bgSurface2
        : Colors.grey[100]!;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          height: widget.height,
          margin: EdgeInsets.only(bottom: tokens.sp3),
          decoration: BoxDecoration(
            color: baseColor,
            borderRadius: BorderRadius.circular(tokens.rCard),
            gradient: LinearGradient(
              begin: Alignment(_animation.value - 1, 0),
              end: Alignment(_animation.value, 0),
              colors: [baseColor, highlightColor, baseColor],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        );
      },
    );
  }
}

/// Overlay de chargement pleine page
class AppLoadingOverlay extends StatelessWidget {
  const AppLoadingOverlay({
    super.key,
    required this.isLoading,
    required this.child,
    this.message,
    this.type = AppLoadingType.spinner,
    this.size = AppLoadingSize.large,
    this.barrierColor,
  });

  final bool isLoading;
  final Widget child;
  final String? message;
  final AppLoadingType type;
  final AppLoadingSize size;
  final Color? barrierColor;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final isDark = context.isDark;

    return Stack(
      children: [
        child,
        if (isLoading)
          ModalBarrier(
            color: barrierColor ??
                (isDark
                    ? Colors.black.withValues(alpha: 0.5)
                    : Colors.black.withValues(alpha: 0.3)),
            dismissible: false,
          ),
        if (isLoading)
          Center(
            child: Container(
              padding: EdgeInsets.all(tokens.sp6),
              decoration: BoxDecoration(
                color: isDark ? tokens.bgSurface : Colors.white,
                borderRadius: BorderRadius.circular(tokens.rDialog),
                boxShadow: tokens.shadowLevel(4, isDark: isDark),
              ),
              child: AppLoadingState(
                type: type,
                size: size,
                message: message,
                centered: true,
              ),
            ),
          ),
      ],
    );
  }
}