import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/services/auth_store.dart';
import 'features/auth/login_page.dart';
import 'features/shell/home_shell.dart';

/// Aiguillage : écran de connexion ou application principale.
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
        return auth.isAuthenticated ? const HomeShell() : const LoginPage();
      },
    );
  }
}
