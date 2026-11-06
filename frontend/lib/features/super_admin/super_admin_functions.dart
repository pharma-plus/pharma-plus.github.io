/// ============================================================
/// SUPER ADMIN — Functions (Tree-shaking Prevention)
/// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/strings.dart';
import '../../core/services/auth_store.dart';
import '../../core/theme/colors.dart';
import '../../features/shell/shell_nav.dart';

/// Top-level functions to prevent tree-shaking - these are directly referenced
/// and cannot be tree-shaken away because they're top-level constants
@pragma('vm:entry-point')
@pragma('dart2js:noInline')
void superAdminReturnToPharma(BuildContext context) {
  final authStore = context.read<AuthStore>();
  ShellNav.goHome();
  Navigator.of(context).popUntil((route) => route.isFirst);
}

/// Top-level function for logout
@pragma('vm:entry-point')
@pragma('dart2js:noInline')
Future<void> superAdminConfirmLogout(BuildContext context) async {
  final locale = context.read<AuthStore>().locale;
  final confirm = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(S.t('confirmLogout', locale)),
      content: Text(S.t('confirmLogoutMessage', locale)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(S.t('cancel', locale)),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
          onPressed: () async {
            Navigator.pop(ctx, true);
            await context.read<AuthStore>().signOut();
          },
          child: Text(S.t('logout', locale)),
        ),
      ],
    ),
  );
  if (confirm == true) {
    await context.read<AuthStore>().signOut();
  }
}

/// Service class that holds all Super Admin functions
class SuperAdminFunctions {
  SuperAdminFunctions._();

  /// Singleton instance - created at app startup
  static final SuperAdminFunctions instance = SuperAdminFunctions._();

  /// Retour à PHARMA+ : revient au dashboard PHARMA+ (HomeShell) en conservant la session
  @pragma('vm:entry-point')
  @pragma('dart2js:noInline')
  void returnToPharma(BuildContext context) {
    final authStore = context.read<AuthStore>();
    ShellNav.goHome();
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  /// Déconnexion complète
  @pragma('vm:entry-point')
  @pragma('dart2js:noInline')
  Future<void> confirmLogout(BuildContext context) async {
    final locale = context.read<AuthStore>().locale;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(S.t('confirmLogout', locale)),
        content: Text(S.t('confirmLogoutMessage', locale)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(S.t('cancel', locale)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () async {
              Navigator.pop(ctx, true);
              await context.read<AuthStore>().signOut();
            },
            child: Text(S.t('logout', locale)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await context.read<AuthStore>().signOut();
    }
  }
}

/// Prevent tree-shaking by referencing the instance
@pragma('vm:entry-point')
final _superAdminFunctionsInstance = SuperAdminFunctions.instance;

/// Function called at app startup to force tree-shaking retention
@pragma('vm:entry-point')
@pragma('dart2js:noInline')
void forceSuperAdminFunctionsRetention() {
  final instance = SuperAdminFunctions.instance;
  final method1 = instance.returnToPharma;
  final method2 = instance.confirmLogout;
  final hash = instance.hashCode;
  
  if (method1 == null && method2 == null && hash == 0) {
    debugPrint('SuperAdmin functions retention check');
  }
}

/// Top-level constants that directly reference the functions to prevent tree-shaking
/// These constants ensure the functions are never tree-shaken away
@pragma('vm:entry-point')
@pragma('dart2js:noInline')
const superAdminFunctionRefs = {
  'returnToPharma': superAdminReturnToPharma,
  'confirmLogout': superAdminConfirmLogout,
};

/// Global variables that directly reference the functions to prevent tree-shaking
/// These constants ensure the functions are never tree-shaken away
@pragma('vm:entry-point')
@pragma('dart2js:noInline')
final _superAdminReturnToPharmaRef = superAdminReturnToPharma;

@pragma('vm:entry-point')
@pragma('dart2js:noInline')
final _superAdminConfirmLogoutRef = superAdminConfirmLogout;