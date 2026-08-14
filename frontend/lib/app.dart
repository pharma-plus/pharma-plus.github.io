import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/services/auth_store.dart';
import 'features/auth/login_page.dart';
import 'features/shell/home_shell.dart';
import 'features/super_admin/super_admin_portal.dart';

/// Aiguillage : écran de connexion, portail Super Admin ou application.
class RootGate extends StatelessWidget {
  const RootGate({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthStore>(
      builder: (context, auth, _) {
        if (!auth.isInitialized) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        if (!auth.isAuthenticated) return const LoginPage();
        if (auth.user?.isSuperAdmin == true) return const SuperAdminPortal();
        return const HomeShell();
      },
    );
  }
}
