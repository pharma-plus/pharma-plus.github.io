import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/l10n/strings.dart';
import 'core/services/auth_store.dart';
import 'core/theme/colors.dart';
import 'core/widgets/pharma_logo_medallion.dart';
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

class _SplashScreenState extends State<_SplashScreen>
    with SingleTickerProviderStateMixin {
  // Sécurité anti-blocage : si l'init n'a pas terminé au bout de 8 s,
  // on force l'avancement vers la page de connexion (jamais de chargement
  // infini). Sûr : on n'est pas authentifié, on ne crée aucune session.
  Timer? _timer;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );
  late final Animation<double> _fade = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOut,
  );
  late final Animation<double> _scale = Tween<double>(begin: 0.9, end: 1.0)
      .animate(CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutBack,
  ));

  @override
  void initState() {
    super.initState();
    _controller.forward();
    _timer = Timer(const Duration(seconds: 8), () {
      if (!mounted) return;
      final auth = context.read<AuthStore>();
      if (!auth.isInitialized) auth.forceProceedToLogin();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pharmaBg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Fond : image de pharmacie premium, légèrement assombrie.
          const PharmaBackground(
            overlayOpacity: 0.66,
            child: SizedBox.expand(),
          ),
          SafeArea(
            child: Center(
              child: FadeTransition(
                opacity: _fade,
                child: ScaleTransition(
                  scale: _scale,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const PharmaLogoMedallion(size: 138),
                      const SizedBox(height: 22),
                      const Text(
                        'PHARMA+',
                        style: TextStyle(
                          color: PharmaLogoMedallion.titleGold,
                          fontSize: 42,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -2,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Gestion intelligente de votre pharmacie',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: PharmaLogoMedallion.subtitleMint,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.4,
                        ),
                      ),
                      const SizedBox(height: 36),
                      const Text(
                        'Bienvenue',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'dans votre pharmacie',
                        style: TextStyle(
                          color: AppColors.textPrimary
                              .withValues(alpha: 0.65),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 32),
                      const _SplashProgressBar(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Barre de progression or champagne (anime en boucle).
class _SplashProgressBar extends StatefulWidget {
  const _SplashProgressBar();

  @override
  State<_SplashProgressBar> createState() => _SplashProgressBarState();
}

class _SplashProgressBarState extends State<_SplashProgressBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );

  @override
  void initState() {
    super.initState();
    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      height: 5,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(50),
        border: Border.all(color: AppColors.goldBorder, width: 1),
      ),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: 0.35 + 0.4 * _controller.value,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  AppColors.pharmaGold,
                  AppColors.pharmaGoldLight,
                ],
              ),
              borderRadius: BorderRadius.circular(50),
            ),
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
              const PharmaLogoMedallion(size: 110),
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
                  backgroundColor: PharmaLogoMedallion.goldBorder,
                  foregroundColor: const Color(0xFF07201B),
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
