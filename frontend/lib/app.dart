import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/l10n/strings.dart';
import 'core/services/auth_store.dart';
import 'core/theme/colors.dart';
import 'core/widgets/pharma_logo.dart';
import 'core/widgets/pharma_background.dart';
import 'features/auth/login_page.dart';
import 'features/shell/home_shell.dart';
import 'features/super_admin/super_admin_portal.dart';

/// Aiguillage : Splash → Connexion / Dashboard / Erreur d'init.
class RootGate extends StatelessWidget {
  const RootGate({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthStore>(
      builder: (context, auth, _) {
        if (!auth.isInitialized) {
          return const _SplashScreen();
        }
        if (auth.initError) {
          return _InitErrorScreen(
            onRetry: auth.retryInit,
            onContinue: auth.continueToLogin,
          );
        }
        if (!auth.isAuthenticated) return const LoginPage();
        if (auth.user?.isSuperAdmin == true) return const SuperAdminPortal();
        return const HomeShell();
      },
    );
  }
}

class _SplashScreen extends StatefulWidget {
  const _SplashScreen();

  @override
  State<_SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<_SplashScreen> {
  // Sécurité anti-blocage : si l'init n'a pas terminé au bout de 8 s,
  // on force l'avancement vers la page de connexion (jamais de chargement
  // infini). Sûr : on n'est pas authentifié, on ne crée aucune session.
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(seconds: 8), () {
      if (!mounted) return;
      final auth = context.read<AuthStore>();
      if (!auth.isInitialized) auth.forceProceedToLogin();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.menu,
      body: PharmaBackground(
        child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PharmaPlusLogo(size: 96),
            SizedBox(height: 24),
            SizedBox(
              width: 34,
              height: 34,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: AppColors.turquoise,
              ),
            ),
            SizedBox(height: 16),
            Text(
              'PHARMA+',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
                letterSpacing: 4,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }
}

class _InitErrorScreen extends StatelessWidget {
  final VoidCallback onRetry;
  final VoidCallback onContinue;
  const _InitErrorScreen({required this.onRetry, required this.onContinue});

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AuthStore>().locale;
    return Scaffold(
      backgroundColor: AppColors.menu,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const PharmaPlusLogo(size: 80),
              const SizedBox(height: 28),
              const Icon(Icons.error_outline,
                  size: 56, color: AppColors.danger),
              const SizedBox(height: 16),
              const Text(
                "Impossible d'initialiser PHARMA+.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Veuillez réessayer ou continuer vers la connexion.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  minimumSize: const Size(220, 52),
                ),
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Réessayer'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: onContinue,
                child: Text(
                  S.t('continueToLogin', locale),
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
