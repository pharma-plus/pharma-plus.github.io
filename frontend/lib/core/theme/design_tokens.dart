import 'package:flutter/material.dart';
import 'colors.dart';

/// Design Tokens PHARMA+ — Source unique de vérité pour l'UI
/// Utilisés par les composants partagés (AppDataTable, AppTextField, etc.)
abstract final class PharmaTokens {
  PharmaTokens._();

  // =========================================================================
  // COULEURS SÉMANTIQUES (mapping vers AppColors)
  // =========================================================================

  // Arrière-plans
  static const Color bgPrimary = AppColors.pharmaBg;
  static const Color bgSecondary = AppColors.pharmaBg2;
  static const Color bgSurface = AppColors.pharmaSurface;
  static const Color bgSurfaceRaised = AppColors.pharmaSurface2;
  static const Color bgPanel = AppColors.surfacePanel;
  static const Color bgSidebar = AppColors.surfaceSidebar;
  static const Color bgCard = AppColors.surfaceCard;
  static const Color bgSurface2 = AppColors.pharmaSurface2;

  // Texte
  static const Color textPrimary = AppColors.textPrimary;
  static const Color textSecondary = AppColors.textSecondary;
  static const Color textTertiary = AppColors.textTertiary;
  static const Color textDisabled = AppColors.textDisabled;
  static const Color textOnPrimary = Colors.white;
  static const Color textOnSurface = AppColors.textPrimary;

  // Marque / Primaire
  static const Color brandPrimary = AppColors.primary; // #006B43
  static const Color brandPrimaryLight = AppColors.primaryLight;
  static const Color brandEmerald = AppColors.emerald; // #00C96B
  static const Color brandGold = AppColors.brandGold; // #D6A84F
  static const Color brandGoldLight = AppColors.pharmaGoldLight;

  // États
  static const Color success = AppColors.success;
  static const Color warning = AppColors.warning;
  static const Color danger = AppColors.danger;
  static const Color info = AppColors.info;

  // Domaines métier (pour KPI, graphiques, badges)
  static const Color domainRevenue = AppColors.emerald;
  static const Color domainStock = AppColors.warnAmber;
  static const Color domainOrders = AppColors.purple;
  static const Color domainSuppliers = AppColors.cyan;
  static const Color domainCustomers = AppColors.pink;
  static const Color domainEmployees = AppColors.olive;
  static const Color domainAI = AppColors.purple;
  static const Color domainAnalytics = AppColors.info;

  // Bordures
  static const Color borderLight = AppColors.dividerLight;
  static const Color borderDark = AppColors.dividerDark;
  static const Color borderGold = AppColors.goldBorder;
  static const Color borderGoldStrong = AppColors.goldBorderStrong;
  static const Color borderFocus = AppColors.brandGold;

  // =========================================================================
  // TYPOGRAPHIE
  // =========================================================================

  static const String fontFamily = 'Inter';
  static const String fontFamilyFallback = 'Noto Sans Arabic';

  // Échelle de tailles (rem-based, 1rem = 16px)
  static const double fontSizeXs = 11; // 0.6875rem
  static const double fontSizeSm = 12; // 0.75rem
  static const double fontSizeBase = 14; // 0.875rem
  static const double fontSizeMd = 15; // 0.9375rem
  static const double fontSizeLg = 16; // 1rem
  static const double fontSizeXl = 18; // 1.125rem
  static const double fontSize2xl = 20; // 1.25rem
  static const double fontSize3xl = 24; // 1.5rem
  static const double fontSize4xl = 30; // 1.875rem
  static const double fontSize5xl = 36; // 2.25rem

  // Poids
  static const FontWeight weightLight = FontWeight.w300;
  static const FontWeight weightRegular = FontWeight.w400;
  static const FontWeight weightMedium = FontWeight.w500;
  static const FontWeight weightSemiBold = FontWeight.w600;
  static const FontWeight weightBold = FontWeight.w700;

  // Hauteurs de ligne
  static const double lineHeightTight = 1.2;
  static const double lineHeightNormal = 1.5;
  static const double lineHeightRelaxed = 1.625;

  // Styles de texte prédéfinis
  static TextStyle get displayLarge => const TextStyle(
        fontSize: fontSize5xl,
        fontWeight: weightBold,
        height: lineHeightTight,
        color: textPrimary,
        fontFamily: fontFamily,
      );

  static TextStyle get displayMedium => const TextStyle(
        fontSize: fontSize4xl,
        fontWeight: weightBold,
        height: lineHeightTight,
        color: textPrimary,
        fontFamily: fontFamily,
      );

  static TextStyle get displaySmall => const TextStyle(
        fontSize: fontSize3xl,
        fontWeight: weightSemiBold,
        height: lineHeightTight,
        color: textPrimary,
        fontFamily: fontFamily,
      );

  static TextStyle get headlineLarge => const TextStyle(
        fontSize: fontSize2xl,
        fontWeight: weightSemiBold,
        height: lineHeightNormal,
        color: textPrimary,
        fontFamily: fontFamily,
      );

  static TextStyle get headlineMedium => const TextStyle(
        fontSize: fontSizeXl,
        fontWeight: weightSemiBold,
        height: lineHeightNormal,
        color: textPrimary,
        fontFamily: fontFamily,
      );

  static TextStyle get headlineSmall => const TextStyle(
        fontSize: fontSizeLg,
        fontWeight: weightSemiBold,
        height: lineHeightNormal,
        color: textPrimary,
        fontFamily: fontFamily,
      );

  static TextStyle get titleLarge => const TextStyle(
        fontSize: fontSizeLg,
        fontWeight: weightMedium,
        height: lineHeightNormal,
        color: textPrimary,
        fontFamily: fontFamily,
      );

  static TextStyle get titleMedium => const TextStyle(
        fontSize: fontSizeBase,
        fontWeight: weightMedium,
        height: lineHeightNormal,
        color: textPrimary,
        fontFamily: fontFamily,
      );

  static TextStyle get titleSmall => const TextStyle(
        fontSize: fontSizeSm,
        fontWeight: weightMedium,
        height: lineHeightNormal,
        color: textPrimary,
        fontFamily: fontFamily,
      );

  static TextStyle get bodyLarge => const TextStyle(
        fontSize: fontSizeLg,
        fontWeight: weightRegular,
        height: lineHeightRelaxed,
        color: textPrimary,
        fontFamily: fontFamily,
      );

  static TextStyle get bodyMedium => const TextStyle(
        fontSize: fontSizeBase,
        fontWeight: weightRegular,
        height: lineHeightRelaxed,
        color: textPrimary,
        fontFamily: fontFamily,
      );

  static TextStyle get bodySmall => const TextStyle(
        fontSize: fontSizeSm,
        fontWeight: weightRegular,
        height: lineHeightRelaxed,
        color: textSecondary,
        fontFamily: fontFamily,
      );

  static TextStyle get labelLarge => const TextStyle(
        fontSize: fontSizeBase,
        fontWeight: weightMedium,
        height: lineHeightNormal,
        color: textPrimary,
        fontFamily: fontFamily,
      );

  static TextStyle get labelMedium => const TextStyle(
        fontSize: fontSizeSm,
        fontWeight: weightMedium,
        height: lineHeightNormal,
        color: textPrimary,
        fontFamily: fontFamily,
      );

  static TextStyle get labelSmall => const TextStyle(
        fontSize: fontSizeXs,
        fontWeight: weightMedium,
        height: lineHeightNormal,
        color: textSecondary,
        fontFamily: fontFamily,
      );

  // Styles pour composants spécifiques
  static TextStyle get fieldLabel => labelMedium.copyWith(color: textSecondary);
  static TextStyle get fieldInput => bodyMedium;
  static TextStyle get fieldHelper => bodySmall;
  static TextStyle get fieldError => bodySmall.copyWith(color: danger);
  static TextStyle get tableHeader =>
      labelMedium.copyWith(color: textSecondary);
  static TextStyle get tableCell => bodyMedium;
  static TextStyle get tableCellNumeric => bodyMedium.copyWith(
        fontFeatures: const [FontFeature.tabularFigures()],
        fontFamily: 'Roboto Mono',
      );
  static TextStyle get badge => labelSmall.copyWith(
        fontWeight: weightSemiBold,
        letterSpacing: 0.5,
      );

  // =========================================================================
  // ESPACEMENTS (base 4px = 0.25rem)
  // =========================================================================

  static const double space0 = 0;
  static const double space1 = 4; // 0.25rem
  static const double space2 = 8; // 0.5rem
  static const double space3 = 12; // 0.75rem
  static const double space4 = 16; // 1rem
  static const double space5 = 20; // 1.25rem
  static const double space6 = 24; // 1.5rem
  static const double space8 = 32; // 2rem
  static const double space10 = 40; // 2.5rem
  static const double space12 = 48; // 3rem
  static const double space16 = 64; // 4rem
  static const double space20 = 80; // 5rem
  static const double space24 = 96; // 6rem

  // Espacements composants
  static const double fieldPaddingHorizontal = space4; // 16
  static const double fieldPaddingVertical = space3; // 12
  static const double fieldGap = space2; // 8
  static const double sectionGap = space6; // 24
  static const double cardPadding = space4; // 16
  static const double cardGap = space4; // 16
  static const double pagePadding = space4; // 16
  static const double pagePaddingDesktop = space6; // 24
  static const double toolbarGap = space3; // 12
  static const double tableCellPadding = space3; // 12
  static const double dialogPadding = space6; // 24

  // =========================================================================
  // RAYONS DE BORDURE
  // =========================================================================

  static const double radiusXs = 4;
  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 16;
  static const double radiusXl = 20;
  static const double radius2xl = 24;
  static const double radiusFull = 9999;

  // Rayons composants
  static const double radiusField = radiusLg; // 16
  static const double radiusCard = radiusXl; // 20
  static const double radiusDialog = radius2xl; // 24
  static const double radiusButton = radiusLg; // 16
  static const double radiusBadge = radiusFull; // 9999
  static const double radiusTooltip = radiusSm; // 8

  // =========================================================================
  // OMBRES / ELEVATION
  // =========================================================================

  static const double elevation0 = 0;
  static const double elevation1 = 1;
  static const double elevation2 = 3;
  static const double elevation3 = 6;
  static const double elevation4 = 10;
  static const double elevation5 = 15;

  static List<BoxShadow> shadowLevel(int level, {bool isDark = true}) {
    final color = isDark ? AppColors.shadowColor : Colors.black;
    final opacity = isDark ? 0.35 : 0.12;
    switch (level) {
      case 0:
        return [];
      case 1:
        return [
          BoxShadow(
            color: color.withValues(alpha: opacity * 0.3),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ];
      case 2:
        return [
          BoxShadow(
            color: color.withValues(alpha: opacity * 0.4),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
          BoxShadow(
            color: color.withValues(alpha: opacity * 0.2),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ];
      case 3:
        return [
          BoxShadow(
            color: color.withValues(alpha: opacity * 0.45),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: color.withValues(alpha: opacity * 0.25),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ];
      case 4:
        return [
          BoxShadow(
            color: color.withValues(alpha: opacity * 0.5),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: color.withValues(alpha: opacity * 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ];
      case 5:
        return [
          BoxShadow(
            color: color.withValues(alpha: opacity * 0.55),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: color.withValues(alpha: opacity * 0.35),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ];
      default:
        return shadowLevel(3, isDark: isDark);
    }
  }

  // Ombres colorées (glow) pour KPI/domaines
  static List<BoxShadow> glowShadow(Color color, {double intensity = 0.4}) => [
        BoxShadow(
          color: color.withValues(alpha: intensity * 0.6),
          blurRadius: 24,
          spreadRadius: -4,
          offset: const Offset(0, 8),
        ),
        BoxShadow(
          color: color.withValues(alpha: intensity * 0.3),
          blurRadius: 12,
          spreadRadius: -2,
          offset: const Offset(0, 4),
        ),
      ];

  // =========================================================================
  // HAUTEURS COMPOSANTS
  // =========================================================================

  static const double heightField = 52; // Input fields
  static const double heightFieldDense = 44; // Dense fields
  static const double heightButton = 48; // Min button height
  static const double heightButtonLarge = 56; // Large buttons
  static const double heightAppBar = 64; // AppBar
  static const double heightBottomNav = 72; // NavigationBar
  static const double heightTableRow = 52; // DataTable row
  static const double heightTableRowCompact = 44; // Compact row
  static const double heightTableHeader = 48; // Table header
  static const double heightDialogTitle = 56; // Dialog title bar
  static const double heightAvatarSm = 32;
  static const double heightAvatarMd = 40;
  static const double heightAvatarLg = 56;
  static const double heightAvatarXl = 80;

  // =========================================================================
  // BREAKPOINTS RESPONSIVE
  // =========================================================================

  static const double breakpointMobile = 600;
  static const double breakpointTablet = 900;
  static const double breakpointDesktop = 1200;
  static const double breakpointLargeDesktop = 1600;
  static const double breakpointXLarge = 1920;

  static bool isMobile(double width) => width < breakpointMobile;
  static bool isTablet(double width) =>
      width >= breakpointMobile && width < breakpointDesktop;
  static bool isDesktop(double width) =>
      width >= breakpointDesktop && width < breakpointLargeDesktop;
  static bool isLargeDesktop(double width) => width >= breakpointLargeDesktop;

  // Colonnes grille responsive
  static int gridColumns(double width) {
    if (width >= breakpointXLarge) return 6;
    if (width >= breakpointLargeDesktop) return 5;
    if (width >= breakpointDesktop) return 4;
    if (width >= breakpointTablet) return 3;
    if (width >= 480) return 2;
    return 1;
  }

  // =========================================================================
  // DURÉES ANIMATION
  // =========================================================================

  static const Duration durationFast = Duration(milliseconds: 150);
  static const Duration durationNormal = Duration(milliseconds: 250);
  static const Duration durationSlow = Duration(milliseconds: 350);
  static const Duration durationPageTransition = Duration(milliseconds: 300);

  static const Curve curveStandard = Curves.easeInOutCubic;
  static const Curve curveEmphasized = Curves.easeOutCubic;
  static const Curve curveDecelerate = Curves.decelerate;

  // =========================================================================
  // Z-INDEX / COUCHES
  // =========================================================================

  static const int zIndexDropdown = 100;
  static const int zIndexSticky = 200;
  static const int zIndexModal = 300;
  static const int zIndexTooltip = 400;
  static const int zIndexToast = 500;
  static const int zIndexLoading = 1000;

  // =========================================================================
  // MOTION / REDUCED MOTION
  // =========================================================================

  static Duration getDuration(bool reduceMotion) =>
      reduceMotion ? Duration.zero : durationNormal;

  static Curve getCurve(bool reduceMotion) =>
      reduceMotion ? Curves.linear : curveStandard;
}

/// Helper pour accéder aux tokens depuis BuildContext
extension PharmaTokensExtension on BuildContext {
  PharmaTokensHelper get tokens => PharmaTokensHelper(this);

  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  ColorScheme get scheme => Theme.of(this).colorScheme;
}

/// Helper public qui délègue aux static members de PharmaTokens
class PharmaTokensHelper {
  final BuildContext _context;
  const PharmaTokensHelper(this._context);

  // Couleurs
  Color get bgPrimary => PharmaTokens.bgPrimary;
  Color get bgSurface => PharmaTokens.bgSurface;
  Color get bgSurfaceRaised => PharmaTokens.bgSurfaceRaised;
  Color get bgPanel => PharmaTokens.bgPanel;
  Color get bgSidebar => PharmaTokens.bgSidebar;
  Color get textPrimary => PharmaTokens.textPrimary;
  Color get textSecondary => PharmaTokens.textSecondary;
  Color get textTertiary => PharmaTokens.textTertiary;
  Color get textDisabled => PharmaTokens.textDisabled;
  Color get brandPrimary => PharmaTokens.brandPrimary;
  Color get brandEmerald => PharmaTokens.brandEmerald;
  Color get brandGold => PharmaTokens.brandGold;
  Color get brandGoldLight => PharmaTokens.brandGoldLight;
  Color get success => PharmaTokens.success;
  Color get warning => PharmaTokens.warning;
  Color get danger => PharmaTokens.danger;
  Color get info => PharmaTokens.info;
  Color get borderLight => PharmaTokens.borderLight;
  Color get borderDark => PharmaTokens.borderDark;
  Color get borderGold => PharmaTokens.borderGold;
  Color get borderGoldStrong => PharmaTokens.borderGoldStrong;
  Color get borderFocus => PharmaTokens.borderFocus;

  // Domaines métier
  Color get domainRevenue => PharmaTokens.domainRevenue;
  Color get domainStock => PharmaTokens.domainStock;
  Color get domainOrders => PharmaTokens.domainOrders;
  Color get domainSuppliers => PharmaTokens.domainSuppliers;
  Color get domainCustomers => PharmaTokens.domainCustomers;
  Color get domainEmployees => PharmaTokens.domainEmployees;
  Color get domainAI => PharmaTokens.domainAI;
  Color get domainAnalytics => PharmaTokens.domainAnalytics;

  // Spacing
  double get space0 => PharmaTokens.space0;
  double get sp0 => PharmaTokens.space0;
  double get sp1 => PharmaTokens.space1;
  double get space1 => PharmaTokens.space1;
  double get sp2 => PharmaTokens.space2;
  double get space2 => PharmaTokens.space2;
  double get sp3 => PharmaTokens.space3;
  double get space3 => PharmaTokens.space3;
  double get sp4 => PharmaTokens.space4;
  double get space4 => PharmaTokens.space4;
  double get sp5 => PharmaTokens.space5;
  double get space5 => PharmaTokens.space5;
  double get sp6 => PharmaTokens.space6;
  double get space6 => PharmaTokens.space6;
  double get sp8 => PharmaTokens.space8;
  double get space8 => PharmaTokens.space8;
  double get sp10 => PharmaTokens.space10;
  double get sp12 => PharmaTokens.space12;
  double get sp16 => PharmaTokens.space16;
  double get sp20 => PharmaTokens.space20;
  double get sp24 => PharmaTokens.space24;
  double get fieldPaddingHorizontal => PharmaTokens.fieldPaddingHorizontal;
  double get fieldPaddingVertical => PharmaTokens.fieldPaddingVertical;
  double get fieldGap => PharmaTokens.fieldGap;
  double get sectionGap => PharmaTokens.sectionGap;
  double get cardPadding => PharmaTokens.cardPadding;
  double get cardGap => PharmaTokens.cardGap;
  double get pagePadding => PharmaTokens.pagePadding;
  double get pagePaddingDesktop => PharmaTokens.pagePaddingDesktop;
  double get toolbarGap => PharmaTokens.toolbarGap;
  double get tableCellPadding => PharmaTokens.tableCellPadding;
  double get dialogPadding => PharmaTokens.dialogPadding;

  // Radius
  double get rXs => PharmaTokens.radiusXs;
  double get rSm => PharmaTokens.radiusSm;
  double get rMd => PharmaTokens.radiusMd;
  double get rLg => PharmaTokens.radiusLg;
  double get rXl => PharmaTokens.radiusXl;
  double get r2xl => PharmaTokens.radius2xl;
  double get rFull => PharmaTokens.radiusFull;
  double get rField => PharmaTokens.radiusField;
  double get rCard => PharmaTokens.radiusCard;
  double get rDialog => PharmaTokens.radiusDialog;
  double get rButton => PharmaTokens.radiusButton;
  double get rBadge => PharmaTokens.radiusBadge;
  double get rTooltip => PharmaTokens.radiusTooltip;

  // Tailles
  double get fieldHeight => PharmaTokens.heightField;
  double get fieldHeightDense => PharmaTokens.heightFieldDense;
  double get buttonHeight => PharmaTokens.heightButton;
  double get buttonHeightLarge => PharmaTokens.heightButtonLarge;
  double get heightButton => PharmaTokens.heightButton;
  double get heightButtonLarge => PharmaTokens.heightButtonLarge;
  double get heightButtonDense => PharmaTokens.heightFieldDense;
  double get tableRowHeight => PharmaTokens.heightTableRow;
  double get tableRowHeightCompact => PharmaTokens.heightTableRowCompact;
  double get tableHeaderHeight => PharmaTokens.heightTableHeader;
  double get appBarHeight => PharmaTokens.heightAppBar;
  double get bottomNavHeight => PharmaTokens.heightBottomNav;

  // Ombres / Elevation
  double get elevation1 => PharmaTokens.elevation1;
  double get elevation2 => PharmaTokens.elevation2;
  double get elevation3 => PharmaTokens.elevation3;
  double get elevation4 => PharmaTokens.elevation4;

  // Couleurs supplémentaires
  Color get bgSurface2 => PharmaTokens.bgSurface2;

  // Typographie
  double get fontSizeXs => PharmaTokens.fontSizeXs;
  double get fontSizeSm => PharmaTokens.fontSizeSm;
  double get fontSizeBase => PharmaTokens.fontSizeBase;
  double get fontSizeMd => PharmaTokens.fontSizeMd;
  double get fontSizeLg => PharmaTokens.fontSizeLg;
  double get fontSizeXl => PharmaTokens.fontSizeXl;
  double get fontSize2xl => PharmaTokens.fontSize2xl;
  double get fontSize3xl => PharmaTokens.fontSize3xl;
  double get fontSize4xl => PharmaTokens.fontSize4xl;
  double get fontSize5xl => PharmaTokens.fontSize5xl;

  // Styles
  TextStyle get displayLarge => PharmaTokens.displayLarge;
  TextStyle get displayMedium => PharmaTokens.displayMedium;
  TextStyle get displaySmall => PharmaTokens.displaySmall;
  TextStyle get headlineLarge => PharmaTokens.headlineLarge;
  TextStyle get headlineMedium => PharmaTokens.headlineMedium;
  TextStyle get headlineSmall => PharmaTokens.headlineSmall;
  TextStyle get titleLarge => PharmaTokens.titleLarge;
  TextStyle get titleMedium => PharmaTokens.titleMedium;
  TextStyle get titleSmall => PharmaTokens.titleSmall;
  TextStyle get bodyLarge => PharmaTokens.bodyLarge;
  TextStyle get bodyMedium => PharmaTokens.bodyMedium;
  TextStyle get bodySmall => PharmaTokens.bodySmall;
  TextStyle get labelLarge => PharmaTokens.labelLarge;
  TextStyle get labelMedium => PharmaTokens.labelMedium;
  TextStyle get labelSmall => PharmaTokens.labelSmall;
  TextStyle get fieldLabel => PharmaTokens.fieldLabel;
  TextStyle get fieldInput => PharmaTokens.fieldInput;
  TextStyle get fieldHelper => PharmaTokens.fieldHelper;
  TextStyle get fieldError => PharmaTokens.fieldError;
  TextStyle get tableHeader => PharmaTokens.tableHeader;
  TextStyle get tableCell => PharmaTokens.tableCell;
  TextStyle get tableCellNumeric => PharmaTokens.tableCellNumeric;
  TextStyle get badge => PharmaTokens.badge;

  // Ombres
  List<BoxShadow> shadowLevel(int level, {bool? isDark}) =>
      PharmaTokens.shadowLevel(level, isDark: isDark ?? _context.isDark);
  List<BoxShadow> glowShadow(Color color, {double intensity = 0.4}) =>
      PharmaTokens.glowShadow(color, intensity: intensity);

  // Responsive
  bool get isMobile =>
      PharmaTokens.isMobile(MediaQuery.of(_context).size.width);
  bool get isTablet =>
      PharmaTokens.isTablet(MediaQuery.of(_context).size.width);
  bool get isDesktop =>
      PharmaTokens.isDesktop(MediaQuery.of(_context).size.width);
  bool get isLargeDesktop =>
      PharmaTokens.isLargeDesktop(MediaQuery.of(_context).size.width);
  int gridColumns() =>
      PharmaTokens.gridColumns(MediaQuery.of(_context).size.width);

  // Durées
  Duration get durationFast => PharmaTokens.durationFast;
  Duration get durationNormal => PharmaTokens.durationNormal;
  Duration get durationSlow => PharmaTokens.durationSlow;
  Duration get durationPageTransition => PharmaTokens.durationPageTransition;

  // Z-index
  int get zIndexDropdown => PharmaTokens.zIndexDropdown;
  int get zIndexSticky => PharmaTokens.zIndexSticky;
  int get zIndexModal => PharmaTokens.zIndexModal;
  int get zIndexTooltip => PharmaTokens.zIndexTooltip;
  int get zIndexToast => PharmaTokens.zIndexToast;
  int get zIndexLoading => PharmaTokens.zIndexLoading;
}
