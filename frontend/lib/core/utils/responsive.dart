import 'package:flutter/material.dart';

/// Responsive breakpoints pour tous les appareils.
/// - Mobile: < 600dp (téléphone)
/// - Tablet: 600-1200dp (tablette)
/// - Desktop: >= 1200dp (écran large / caisse)
class ResponsiveHelper {
  static const mobileBreak = 600.0;
  static const tabletBreak = 1200.0;
  static const deskBreak = 1920.0;

  static DeviceType getDeviceType(double width) {
    if (width < mobileBreak) return DeviceType.mobile;
    if (width < tabletBreak) return DeviceType.tablet;
    if (width < deskBreak) return DeviceType.desktop;
    return DeviceType.largeDesktop;
  }

  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < mobileBreak;
  static bool isTablet(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return w >= mobileBreak && w < tabletBreak;
  }
  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= tabletBreak;
  static bool isLargeDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= deskBreak;

  /// Taille minimale pour les éléments tactiles (Material Design)
  static const touchTargetSize = 48.0;

  /// Padding adapté par appareil
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
