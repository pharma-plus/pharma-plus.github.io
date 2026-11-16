import 'package:flutter/material.dart';

/// Responsive breakpoints pour tous les appareils.
/// API historique conservée (mobileBreak/tabletBreak/deskBreak, DeviceType)
/// + helpers centralisés additionnels (phases responsive smartphone/tablette).
///
/// Repères de référence (non rigides, à adapter au besoin réel) :
/// - 320–359 : très petit smartphone
/// - 360–430 : smartphone courant
/// - 431–599 : grand smartphone
/// - 600–767 : petite tablette
/// - 768–1023 : tablette
/// - 1024–1149 : grande tablette
/// - >=1150 : desktop (seuil shell/dashboard existant)
class ResponsiveHelper {
  ResponsiveHelper._();

  // --- Seuils historiques (compatibilité) ---
  static const mobileBreak = 600.0;
  static const tabletBreak = 1200.0;
  static const deskBreak = 1920.0;

  // --- Repères additionnels centralisés ---
  static const double verySmallPhoneMax = 359.0;
  static const double phoneMax = 430.0;
  static const double largePhoneMax = 599.0;
  static const double smallTabletMax = 767.0;
  static const double tabletMax = 1023.0;
  static const double largeTabletMax = 1149.0;
  static const double desktopMin = 1150.0;

  static const double touchTargetSize = 48.0;
  static const double compactTouchTargetSize = 44.0;

  static DeviceType getDeviceType(double width) {
    if (width < mobileBreak) return DeviceType.mobile;
    if (width < tabletBreak) return DeviceType.tablet;
    if (width < deskBreak) return DeviceType.desktop;
    return DeviceType.largeDesktop;
  }

  static bool isMobile(BuildContext context) =>
      MediaQuery.sizeOf(context).width < mobileBreak;
  static bool isTablet(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return w >= mobileBreak && w < tabletBreak;
  }

  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= tabletBreak;
  static bool isLargeDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= deskBreak;

  /// Seuil shell/navigation desktop historique du projet.
  static bool isDesktopShell(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= desktopMin;

  static bool isPortrait(BuildContext context) =>
      MediaQuery.orientationOf(context) == Orientation.portrait;
  static bool isLandscape(BuildContext context) =>
      MediaQuery.orientationOf(context) == Orientation.landscape;

  static bool isVerySmallPhone(BuildContext context) =>
      MediaQuery.sizeOf(context).width <= verySmallPhoneMax;
  static bool isStandardPhone(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return w >= 360 && w <= phoneMax;
  }

  static bool isLargePhone(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return w > phoneMax && w <= largePhoneMax;
  }

  static bool isSmallTablet(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return w >= mobileBreak && w <= smallTabletMax;
  }

  static bool isMediumTablet(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return w > smallTabletMax && w <= tabletMax;
  }

  static bool isLargeTablet(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return w > tabletMax && w <= largeTabletMax;
  }

  /// Zone sûre (encoches/barres système).
  static EdgeInsets safePadding(BuildContext context) =>
      MediaQuery.viewPaddingOf(context);

  /// Hauteur du clavier virtuel.
  static double keyboardInset(BuildContext context) =>
      MediaQuery.viewInsetsOf(context).bottom;

  static bool isKeyboardVisible(BuildContext context) =>
      keyboardInset(context) > 0;

  /// Padding adaptatif par appareil avec prise en compte SafeArea horizontale.
  static EdgeInsets pagePadding(BuildContext context) {
    final view = MediaQuery.viewPaddingOf(context);
    final base = getPadding(context);
    return base.copyWith(
      left: base.left + view.left,
      right: base.right + view.right,
      bottom: base.bottom + view.bottom,
    );
  }

  /// Largeur maximale de contenu lisible (utile tablette/desktop).
  static double contentMaxWidth(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    if (w < mobileBreak) return w;
    if (w <= largeTabletMax) return 1100;
    return 1320;
  }

  /// Espacement horizontal standard.
  static double horizontalGap(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    if (w <= verySmallPhoneMax) return 8;
    if (w < mobileBreak) return 12;
    if (w <= largeTabletMax) return 16;
    return 20;
  }

  /// Padding adapté par appareil (API historique).
  static EdgeInsets getPadding(BuildContext context) {
    if (isMobile(context)) return const EdgeInsets.all(12);
    if (isTablet(context)) return const EdgeInsets.all(16);
    return const EdgeInsets.all(20);
  }

  /// Taille de police adaptée
  static double getTitleFontSize(BuildContext context) {
    if (isMobile(context)) return 18;
    if (isTablet(context)) return 22;
    return 26;
  }

  static double getBodyFontSize(BuildContext context) {
    if (isMobile(context)) return 13;
    if (isTablet(context)) return 14;
    return 15;
  }
}

enum DeviceType { mobile, tablet, desktop, largeDesktop }
