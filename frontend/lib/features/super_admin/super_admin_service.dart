// Prevent tree-shaking by forcing all Super Admin functions to be retained
// This file is imported by main.dart and contains direct references to all functions

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/strings.dart';
import '../../core/services/auth_store.dart';
import '../../core/theme/colors.dart';
import '../../features/shell/shell_nav.dart';

/// Retour à PHARMA+ : revient au dashboard PHARMA+ (HomeShell) en conservant la session
@pragma('vm:entry-point')
@pragma('dart2js:noInline')
void superAdminReturnToPharma(BuildContext context) {
  final authStore = context.read<AuthStore>();
  ShellNav.goHome();
  Navigator.of(context).popUntil((route) => route.isFirst);
}

/// Déconnexion complète
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
}

/// Global list of function references to prevent tree-shaking
/// This is a top-level const that the tree-shaker cannot eliminate
@pragma('vm:entry-point')
@pragma('dart2js:noInline')
const List<Function> superAdminFunctionRefs = [
  superAdminReturnToPharma,
  superAdminConfirmLogout,
];

/// Class to force retention of the service
class SuperAdminService {
  const SuperAdminService._();

  static void returnToPharma(BuildContext context) => superAdminReturnToPharma(context);
  static Future<void> confirmLogout(BuildContext context) => superAdminConfirmLogout(context);
}

/// Global instance to prevent tree-shaking
@pragma('vm:entry-point')
final superAdminService = SuperAdminService._();