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
import 'features/super_admin/super_admin_functions.dart'
    as super_admin_functions;

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

class _SplashScreenState extends State<_SplashScreen>
    with TickerProviderStateMixin {
  // Sécurité anti-blocage : si l'init n'a pas terminé au bout de 8 s,
  // on force l'avancement vers la page de connexion (jamais de chargement
  // infini). Sûr : on n'est pas authentifié, on ne crée aucune session.
  // (Partie L) Ce garde-fou est une sécurité, pas une animation : conservé.
  Timer? _timer;

  // Barre de progression du splash (maquettes portrait + paysage) :
  // remplissage or / vert avec pourcentage affiché en paysage.
  late final AnimationController _progress;

  @override
  void initState() {
    super.initState();
    _progress = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..forward();
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
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Splash visuel conforme aux maquettes (portrait + paysage) : fond
    // scène pharmacie, badge circulaire PHARMA+ avec lueur or, séparateur
    // feuille, « Bienvenue dans votre pharmacie », progression or et
    // « Chargement en cours… ». En paysage (tablette / desktop), la barre
    // de progression affiche le pourcentage et une rangée d'atouts
    // (Sécurisé, Performant, Tactile, Cloud, Fiable) est ancrée en bas.
    // Aucun deuxième splash n'est affiché : celui du HTML (#pmg-loading
    // dans web/index.html) est retiré à l'événement flutter-first-frame,
    // puis ce widget prend le relais pour une transition sans saut visuel.
    final size = MediaQuery.sizeOf(context);
    final w = size.width;
    final h = size.height;
    final isLandscape = w > h;

    return Scaffold(
      backgroundColor: AppColors.pharmaBg,
      body: PharmaBackground(
        overlayOpacity: 0.66,
        child: SafeArea(
          child: Stack(
            alignment: Alignment.center,
            children: [
              isLandscape ? _buildLandscape(w) : _buildPortrait(w),
              if (isLandscape && w >= 700 && h >= 400)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 6,
                  child: _buildFeatureChips(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Maquette PORTRAIT : badge circulaire, séparateur feuille, « Bienvenue /
  /// dans votre pharmacie » sur deux lignes, fine ligne or de progression,
  /// « Chargement en cours… ».
  Widget _buildPortrait(double w) {
    // Taille du badge : petit écran -> plus compact, desktop -> plus grand.
    final logoSize = (w < 360
            ? w * 0.62
            : w < 600
                ? 210.0
                : w < 1024
                    ? 260.0
                    : 300.0)
        .clamp(170.0, 320.0);
    // FittedBox : rétrécit le contenu si l'écran est très bas ou si le
    // texte est agrandi (accessibilité) — le splash ne déborde jamais.
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildBadge(logoSize),
          const SizedBox(height: 26),
          _buildLeafDivider(110),
          const SizedBox(height: 22),
          const Text(
            'Bienvenue',
            style: TextStyle(
              color: AppColors.champagne,
              fontSize: 30,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'dans votre pharmacie',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 34),
          _buildThinProgress(w < 600 ? 170 : 230),
          const SizedBox(height: 42),
          const Text(
            'Chargement en cours…',
            style: TextStyle(
              color: Colors.white38,
              fontSize: 12,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }

  /// Maquette PAYSAGE : badge, séparateur feuille, « Bienvenue dans votre
  /// pharmacie » sur une ligne, barre de progression avec pourcentage,
  /// « Chargement en cours… ». Rangée d'atouts ancrée en bas (maquette).
  Widget _buildLandscape(double w) {
    final badgeSize = (w < 900 ? 150.0 : 185.0).clamp(140.0, 200.0);
    final barWidth = (w * 0.42).clamp(240.0, 460.0);
    // FittedBox : rétrécit le contenu si l'écran (paysage smartphone) est
    // très bas ou si le texte est agrandi — jamais de débordement.
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildBadge(badgeSize),
          const SizedBox(height: 18),
          _buildLeafDivider(90),
          const SizedBox(height: 14),
          RichText(
            text: const TextSpan(
              children: [
                TextSpan(
                  text: 'Bienvenue ',
                  style: TextStyle(
                    color: AppColors.champagne,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                TextSpan(
                  text: 'dans votre pharmacie',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          _buildProgressBar(barWidth),
          const SizedBox(height: 14),
          const Text(
            'Chargement en cours…',
            style: TextStyle(
              color: Colors.white38,
              fontSize: 12,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }

  /// Badge circulaire PHARMA+ avec lueur or (identique aux 2 maquettes).
  Widget _buildBadge(double logoSize) {
    final innerLogo = (logoSize * 0.42).clamp(58.0, 120.0);
    return Container(
      width: logoSize,
      height: logoSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.champagne.withValues(alpha: 0.55),
          width: 3,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.champagne.withValues(alpha: 0.40),
            blurRadius: 44,
            spreadRadius: 10,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.65),
            blurRadius: 32,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Center(
        // FittedBox : le contenu se rétrécit si nécessaire (petit badge,
        // texte agrandi en accessibilité) — jamais de débordement.
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              PharmaPlusLogo(size: innerLogo),
              const SizedBox(height: 12),
              const Text(
                'PHARMA+',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'GESTION INTELLIGENTE',
                style: TextStyle(
                  color: AppColors.champagne,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.6,
                ),
              ),
              const Text(
                'DE VOTRE PHARMACIE',
                style: TextStyle(
                  color: AppColors.champagne,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Séparateur feuille dorée entre deux fines lignes (les 2 maquettes).
  Widget _buildLeafDivider(double halfWidth) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: halfWidth,
          height: 1,
          color: AppColors.champagne.withValues(alpha: 0.45),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 10),
          child: Icon(Icons.eco, size: 15, color: AppColors.champagne),
        ),
        Container(
          width: halfWidth,
          height: 1,
          color: AppColors.champagne.withValues(alpha: 0.45),
        ),
      ],
    );
  }

  /// Fine ligne or de progression (maquette portrait, sans pourcentage).
  Widget _buildThinProgress(double width) {
    return AnimatedBuilder(
      animation: _progress,
      builder: (context, _) {
        final v = Curves.easeOut.transform(_progress.value);
        return Container(
          width: width,
          height: 4,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: Colors.white.withValues(alpha: 0.12),
            border: Border.all(
              color: AppColors.champagne.withValues(alpha: 0.45),
              width: 1,
            ),
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: v.clamp(0.02, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  gradient: const LinearGradient(
                    colors: [AppColors.champagne, Color(0xFFF1D58A)],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Barre de progression avec pourcentage (maquette paysage : 75 %).
  Widget _buildProgressBar(double width) {
    return AnimatedBuilder(
      animation: _progress,
      builder: (context, _) {
        final v = _progress.value;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: width,
              height: 8,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.white.withValues(alpha: 0.12),
                border: Border.all(
                  color: AppColors.champagne.withValues(alpha: 0.50),
                  width: 1,
                ),
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: v.clamp(0.02, 1.0),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      gradient: const LinearGradient(
                        colors: [AppColors.sageGreen, Color(0xFF4CA97A)],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 44,
              child: Text(
                '${(v * 100).round()}%',
                textAlign: TextAlign.right,
                style: const TextStyle(
                  color: AppColors.champagne,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Rangée d'atouts (maquette paysage) : Sécurisé, Performant, Tactile,
  /// Cloud, Fiable. Défilement horizontal si l'écran est trop étroit.
  Widget _buildFeatureChips() {
    const features = <(IconData, String, String)>[
      (Icons.verified_user_outlined, 'SÉCURISÉ', 'Vos données sont protégées'),
      (Icons.insert_chart_outlined, 'PERFORMANT', 'Gestion rapide et efficace'),
      (
        Icons.touch_app_outlined,
        'TACTILE',
        'Interface adaptée à tous vos écrans'
      ),
      (Icons.cloud_outlined, 'CLOUD', 'Disponible partout et à tout moment'),
      (
        Icons.settings_outlined,
        'FIABLE',
        'Conçu pour accompagner votre croissance'
      ),
    ];
    return Center(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (icon, title, subtitle) in features)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.champagne.withValues(alpha: 0.55),
                          width: 1.2,
                        ),
                      ),
                      child: Icon(icon, size: 20, color: AppColors.champagne),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: AppColors.champagne,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.55),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
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
