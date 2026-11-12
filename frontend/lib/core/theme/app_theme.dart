import 'package:flutter/material.dart';
import 'colors.dart';

/// Thèmes PHARMA+ v4 — Nouvelle identité visuelle
/// Thème clair : marbre gris argent (silver) + texte foncé (inkDark)
/// Thème sombre : graphite + texte clair (porcelain)
/// Accents communs : vert sauge (sageGreen) + champagne
class AppTheme {
  AppTheme._();

  // Mémoïsation
  static final ThemeData _light = _base(Brightness.light);
  static final ThemeData _dark = _base(Brightness.dark);

  static ThemeData light() => _light;

  static ThemeData dark() => _dark;

  static ThemeData _base(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    // Couleurs de surface selon le thème
    final bgColor = isDark ? AppColors.graphite : AppColors.silver;
    final surfaceColor = isDark ? AppColors.surfaceDark : AppColors.silverLight;
    final textColor = isDark ? AppColors.porcelain : AppColors.inkDark;
    // Texte secondaire ATTÉNUÉ mais lisible dans les deux thèmes
    // (gris ardoise foncé sur surface claire, gris argent clair sur sombre).
    final mutedColor =
        isDark ? const Color(0xFFB9C2C9) : AppColors.inkDarkLight;

    // Accent : vert sauge dans les deux thèmes
    final accent = AppColors.sageGreen;
    final accentDark = AppColors.sageGreenDark;

    final scheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: brightness,
      primary: accent,
      secondary: AppColors.champagne,
      surface: surfaceColor,
      onPrimary: AppColors.inkDark, // Texte sur fond vert sauge : graphite foncé
      onSurface: textColor,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: bgColor,
      // Police officielle PHARMA+ : Times New Roman (« New Roman gras »),
      // titres en gras via textTheme ci-dessous.
      fontFamily: 'Times New Roman',
      fontFamilyFallback: const ['Georgia', 'Times', 'serif', 'Arial', 'Noto Sans Arabic'],
      textTheme: (isDark ? ThemeData.dark() : ThemeData.light())
          .textTheme
          .apply(
            fontFamily: 'Times New Roman',
            fontFamilyFallback: const ['Georgia', 'Times', 'serif'],
            bodyColor: textColor,
            displayColor: textColor,
          )
          .copyWith(
            // Écritures TOUJOURS lisibles : titres en gras, corps en w500.
            bodyMedium: TextStyle(
                color: textColor, fontWeight: FontWeight.w500),
            bodyLarge: TextStyle(
                color: textColor, fontWeight: FontWeight.w500),
            bodySmall: TextStyle(
                color: mutedColor, fontWeight: FontWeight.w500),
            titleLarge: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w700,
                fontSize: 22),
            titleMedium: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w700,
                fontSize: 16),
            titleSmall: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w700,
                fontSize: 14),
          ),
      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? AppColors.graphite : AppColors.silver,
        foregroundColor: textColor,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        elevation: 6,
        shadowColor: AppColors.shadowColor.withValues(alpha: isDark ? 0.35 : 0.12),
        surfaceTintColor: accent.withValues(alpha: isDark ? 0.06 : 0.04),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isDark ? AppColors.graphiteLight : AppColors.silverDark,
            width: 1,
          ),
        ),
        color: surfaceColor,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surfaceColor,
        indicatorColor: accent,
        elevation: 8,
      ),
      dividerTheme: DividerThemeData(
        color: isDark ? AppColors.graphiteLight : AppColors.silverDark,
        thickness: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? AppColors.surfaceDark : AppColors.silverLight,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        hintStyle: TextStyle(
          color: isDark ? const Color(0xFF8A95A0) : AppColors.inkDarkLight,
          fontSize: 14,
          fontWeight: FontWeight.w500,
          fontFamily: 'Times New Roman',
        ),
        labelStyle: TextStyle(
          color: isDark ? const Color(0xFFB9C2C9) : AppColors.inkDark,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          fontFamily: 'Times New Roman',
        ),
        prefixIconColor: isDark ? AppColors.silver : AppColors.inkDarkLight,
        suffixIconColor: isDark ? AppColors.silver : AppColors.inkDarkLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.silverDark, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.silverDark, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.sageGreen, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.danger, width: 2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: AppColors.inkDark,
          elevation: 4,
          shadowColor: accent.withValues(alpha: 0.5),
          minimumSize: const Size(48, 48),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: AppColors.inkDark,
          elevation: 4,
          shadowColor: accent.withValues(alpha: 0.5),
          minimumSize: const Size(48, 48),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: isDark ? AppColors.graphite : AppColors.silver,
        selectedIconTheme: IconThemeData(color: accent),
        selectedLabelTextStyle: TextStyle(
          color: AppColors.inkDark,
          fontWeight: FontWeight.w700,
        ),
        unselectedIconTheme: IconThemeData(
            color: isDark ? Colors.white60 : Colors.black54),
        unselectedLabelTextStyle: TextStyle(
            color: isDark ? Colors.white60 : Colors.black54),
        indicatorColor: accent.withValues(alpha: 0.18),
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: isDark ? AppColors.graphite : AppColors.silver,
        shape: const RoundedRectangleBorder(),
        scrimColor: Colors.black.withValues(alpha: 0.5),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surfaceColor,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: accent,
        selectionColor: accent.withValues(alpha: 0.3),
        selectionHandleColor: accent,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
        },
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: accent,
        linearTrackColor:
            isDark ? AppColors.graphiteLight : AppColors.silverDark,
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          // Pouces VISIBLES dans les deux thèmes (anciens white24/black26
          // pratiquement invisibles sur marbre et graphite).
          (states) => isDark
              ? const Color(0xFF9AA3AB)
              : const Color(0xFF6B7280),
        ),
        radius: const Radius.circular(8),
        thickness: WidgetStateProperty.all(7),
        crossAxisMargin: 2,
        mainAxisMargin: 4,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: isDark ? AppColors.graphite : AppColors.silver,
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: const TextStyle(color: AppColors.porcelain, fontSize: 12),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
      splashFactory: InkRipple.splashFactory,
    );
  }
}
