// PMG-SPLASH-TUNING

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/l10n/strings.dart';
import 'core/models/user.dart';
import 'core/services/auth_store.dart';
import 'core/theme/colors.dart';
import 'core/widgets/pharma_logo.dart';
import 'core/widgets/pharma_background.dart';
import 'features/auth/login_page.dart';
import 'core/services/app_guards.dart';
import 'core/services/system_back_guard.dart';
import 'features/audit/employee_space_page.dart';
import 'features/security/lock_screen.dart';
import 'features/shell/home_shell.dart';
import 'features/shell/shell_nav.dart';
import 'features/super_admin/super_admin_crm_page.dart';
import 'features/super_admin/super_admin_shell.dart';
import 'features/super_admin/super_admin_functions.dart' as super_admin_functions;

/// Force tree-shaking retention by making the super admin check dynamic
/// This prevents the tree-shaker from proving the condition is never true
@pragma('vm:entry-point')
@pragma('dart2js:noInline')
bool _shouldShowSuperAdmin(AuthStore auth) {
  // Use a function call that the tree-shaker can't optimize away
  // The tree-shaker can't prove this function always returns false
  return auth.user?.isSuperAdmin == true;
}

/// Force tree-shaking retention by creating SuperAdminShell in a function
/// This prevents the tree-shaker from proving this branch is unreachable
@pragma('vm:entry-point')
@pragma('dart2js:noInline')
Widget _createSuperAdminPage() => const SuperAdminShell();

/// Force tree-shaking retention by referencing the functions directly
/// This ensures the functions are kept in the compiled output
@pragma('vm:entry-point')
@pragma('dart2js:noInline')
void _retainSuperAdminFunctions() {
  // Reference the top-level functions to prevent tree-shaking
  super_admin_functions.superAdminReturnToPharma.toString();
  super_admin_functions.superAdminConfirmLogout.toString();
  super_admin_functions.SuperAdminFunctions.instance.returnToPharma.toString();
  super_admin_functions.SuperAdminFunctions.instance.confirmLogout.toString();
  
  // Call the functions in a way that the tree-shaker can't optimize away
  // by using them in a conditional that could theoretically affect program behavior
  if (super_admin_functions.superAdminReturnToPharma == null && 
      super_admin_functions.superAdminConfirmLogout == null) {
    debugPrint('SuperAdmin retention check');
  }
}

class RootGate extends StatelessWidget {
  const RootGate({super.key});

  @override
  Widget build(BuildContext context) {
    // Bouton retour système (smartphone / tablette) : armé dès le démarrage.
    systemBackInit(onBackAtRoot: confirmQuitApp);
    return Consumer<AuthStore>(
      builder: (context, auth, _) {
        if (!auth.isInitialized) {
          return _withPopScope(const _SplashScreen());
        }
        if (auth.initError) {
          return _withPopScope(_InitErrorScreen(
            onRetry: auth.retryInit,
            onContinue: auth.continueToLogin,
          ));
        }
        if (!auth.isAuthenticated) return _withPopScope(const LoginPage());

        // PROTECTION PIN : si la session est verrouillée (inactivité ou
        // manuelle), l'écran PIN s'affiche AVANT tout accès au dashboard,
        // quelle que soit le rôle (client, admin pharmacie, Super Admin).
        if (auth.isLocked) {
          return _withPopScope(const LockScreen());
        }

        if (_shouldShowSuperAdmin(auth)) {
      // Force retention of SuperAdminCRMPage by using it in a way tree-shaker can't eliminate
      return _withPopScope(_createSuperAdminPage());
    }
        // Bouton retour système (smartphone) — TOUTES les pages :
        // 1) dialogue / formulaire / sous-page poussée → pop (reste sur la page) ;
        // 2) onglet shell ≠ Dashboard → Dashboard ;
        // 3) Dashboard → dialogue « Voulez-vous quitter PHARMA+ ? ».
        // Jamais de fermeture sans confirmation.
        systemBackAttachContext(context);
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) async {
            if (didPop) return;
            final nav = Navigator.of(context, rootNavigator: true);
            // Si nav.canPop() == true, un PopScope interne (formulaire, dialogue)
            // a déjà eu la main et a DÉCIDÉ de ne pas popper (unsaved changes).
            // On NE DOIT PAS appeler nav.pop() ici -> double-pop.
            if (nav.canPop()) return;
            if (ShellNav.index.value != 0) {
              ShellNav.goHome();
              return;
            }
            await confirmQuitApp(context);
          },
          child: _isPrivilegedUser(auth.user)
              ? const HomeShell()
              : const EmployeeSpacePage(),
        );
      },
    );
  }
}

/// Enveloppe toute page racine avec PopScope : dialogue d'abord,
/// sinon confirmation de quitter (splash / login / erreur / super-admin).
Widget _withPopScope(Widget child) {
  return Builder(
    builder: (context) {
      systemBackAttachContext(context);
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) async {
          if (didPop) return;
          final nav = Navigator.of(context, rootNavigator: true);
          // Même règle : si une route interne peut popper, c'est qu'un
          // PopScope interne a déjà géré le retour (ou va le faire).
          if (nav.canPop()) return;
          await confirmQuitApp(context);
        },
        child: child,
      );
    },
  );
}

/// Personnel de direction : pharmacien / admin / gestionnaire (permissions
/// de gestion) -> shell complet. Employes, caissiers et assistants ->
/// Espace Employe (interface simplifiee selon leurs permissions).
bool _isPrivilegedUser(User? user) =>
    user != null &&
    (user.hasPermission('employees:view') ||
        user.hasPermission('users:view') ||
        user.hasPermission('purchases:edit') ||
        user.hasPermission('accounting:view') ||
        user.hasPermission('settings:view'));

class _SplashScreen extends StatefulWidget {
  const _SplashScreen();

  @override
  State<_SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<_SplashScreen> {
  // Sécurité anti-blocage : si l'init n'a pas terminé au bout de 8 s,
  // on force l'avancement vers la page de connexion (jamais de chargement
  // infini). Sûr : on n'est pas authentifié, on ne crée aucune session.
  // (Partie L) Ce garde-fou est une sécurité, pas une animation : conservé.
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Sonde du splash (plus aucun Timer artificiel qui masque l'init) :
    // toutes les secondes, AuthStore.splashProbe() décide s'il faut
    // débloquer la page de connexion. S'il y a une session à restaurer,
    // le splash reste affiché jusqu'à la fin de _doInit (bornée 12 s) —
    // eliminates le "double splash" ET la bascule erronée entre les
    // espaces Client / Super Admin pendant l'initialisation.
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        _timer?.cancel();
        return;
      }
      final auth = context.read<AuthStore>();
      if (auth.isInitialized) {
        _timer?.cancel();
        return;
      }
      auth.splashProbe();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Un seul splash visuel : celui du HTML (#pmg-loading dans web/index.html),
    // retiré à l'événement flutter-first-frame. Aucun deuxième splash Flutter
    // n'est affiché ici : pas de logo, pas de barre de progression, pas
    // d'indicateur. Juste le fond identique au splash HTML pour une transition
    // sans saut visuel. Dès qu'AuthStore est initialisé, RootGate bascule
    // vers la page de connexion ou le dashboard.
    return Scaffold(
      backgroundColor: AppColors.pharmaBg,
      body: PharmaBackground(
        overlayOpacity: 0.66,
        child: SizedBox.expand(),
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
              const PharmaFullLogo(width: 230),
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
                  backgroundColor: AppColors.brandGold,
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
