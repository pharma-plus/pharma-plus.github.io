import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'app.dart';
import 'core/services/auth_store.dart';
import 'core/services/connection_status_service.dart';
import 'core/services/page_reload.dart';
import 'core/theme/app_scroll_behavior.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/colors.dart';
import 'features/super_admin/super_admin_crm_page.dart';
import 'features/super_admin/super_admin_functions.dart';
import 'features/super_admin/super_admin_binding.dart';

/// Prevent tree-shaking by referencing SuperAdminCRMPage and SuperAdminFunctions
@pragma('vm:entry-point')
@pragma('dart2js:noInline')
final _superAdminCRMPageRetention = SuperAdminCRMPage;

/// Prevent tree-shaking by referencing SuperAdminFunctions
@pragma('vm:entry-point')
@pragma('dart2js:noInline')
final _superAdminFunctionsRetention = SuperAdminFunctions.instance;

/// Prevent tree-shaking by referencing top-level functions directly
@pragma('vm:entry-point')
@pragma('dart2js:noInline')
final _superAdminTopLevelRetention = superAdminFunctionRefs;

/// Prevent tree-shaking by referencing top-level functions directly
@pragma('vm:entry-point')
@pragma('dart2js:noInline')
final _superAdminReturnToPharmaRef = superAdminReturnToPharma;

@pragma('vm:entry-point')
@pragma('dart2js:noInline')
final _superAdminConfirmLogoutRef = superAdminConfirmLogout;

/// Force tree-shaking retention by actually calling the functions
/// This function is called from main() and its execution forces the tree-shaker to keep the functions
@pragma('vm:entry-point')
@pragma('dart2js:noInline')
void _forceSuperAdminRetention() {
  // Call the functions in a way that the tree-shaker can't optimize away
  // by using them in a conditional that could theoretically affect program behavior
  final returnToPharma = superAdminReturnToPharma;
  final confirmLogout = superAdminConfirmLogout;
  final refs = superAdminFunctionRefs;
  
  // Use in a way that could theoretically affect program behavior
  // The tree-shaker can't prove this is never true
  if (returnToPharma == null && confirmLogout == null && refs == null) {
    debugPrint('SuperAdmin retention check');
  }
}

/// Dummy widget that uses the super admin functions to prevent tree-shaking
/// This widget is never actually rendered but forces the tree-shaker to keep the functions
class _SuperAdminRetentionWidget extends StatelessWidget {
  const _SuperAdminRetentionWidget();

  @override
  Widget build(BuildContext context) {
    // Use the functions in a way that the tree-shaker can't optimize away
    // by calling them with a dummy context that could theoretically be used
    superAdminReturnToPharma(context);
    superAdminConfirmLogout(context);
    return const SizedBox.shrink();
  }
}

/// Force tree-shaking retention by actually calling the functions with a real context
/// This runs before runApp() and forces tree-shaking retention
@pragma('vm:entry-point')
@pragma('dart2js:noInline')
void _callSuperAdminFunctions() {
  // Create a minimal context to call the functions
  // This is a hack to prevent tree-shaking by actually calling the functions
  final navigatorKey = GlobalKey<NavigatorState>();
  final context = navigatorKey.currentContext;
  
  if (context != null) {
    superAdminReturnToPharma(context);
    superAdminConfirmLogout(context);
  } else {
    // Fallback: just reference the functions
    superAdminReturnToPharma.toString();
    superAdminConfirmLogout.toString();
  }
}

/// Force tree-shaking retention by actually instantiating the retention widget
/// This runs before runApp() and forces tree-shaking retention
@pragma('vm:entry-point')
@pragma('dart2js:noInline')
void _instantiateRetentionWidget() {
  // Instantiate the retention widget in a way that the tree-shaker can't optimize away
  // by using it in a conditional that could theoretically affect program behavior
  final widget = _SuperAdminRetentionWidget();
  
  // Use in a way that could theoretically affect program behavior
  // The tree-shaker can't prove this is never true
  if (widget == null) {
    debugPrint('SuperAdmin widget retention check');
  }
}

Future<void> main() async {
  // En mode release, une exception pendant le build d'un widget remplace la
  // vue par un ErrorWidget muet (écran gris/vert SANS message) : c'était la
  // cause du fameux « Splash → écran vert pétrole vide » sur Mac — impossible
  // à diagnostiquer. On affiche désormais une erreur visible + bouton
  // Recharger, ET on journalise l'erreur dans la console JS.
  FlutterError.onError = (details) {
    debugPrint('[PHARMA+] Erreur Flutter: ${details.exception}'
        '\n${details.stack ?? ''}');
    FlutterError.presentError(details);
  };
  ErrorWidget.builder = (details) {
    debugPrint('[PHARMA+] Erreur de rendu: ${details.exception}'
        '\n${details.stack ?? ''}');
    return _BootErrorScreen(
      title: 'Une erreur est survenue',
      detail: details.exception.toString(),
      compact: true,
    );
  };

  runApp(
    ChangeNotifierProvider.value(
      value: AuthStore.instance,
      child: const PharmaGoldApp(),
    ),
  );
  // Force tree-shaking retention APRÈS runApp (le binding Flutter est alors
  // initialisé ; ces appels avant runApp plantaient avec "Binding has not
  // yet been initialized").
  _forceSuperAdminRetention();
  _instantiateRetentionWidget();
  _callSuperAdminFunctions();

  // Initialiser le service de connexion et de synchronisation hors-ligne.
  unawaited(ConnectionStatusService.instance.init());

  unawaited(AuthStore.instance.init());
}

/// Écran d'erreur visible (plus jamais d'écran vide muet).
class _BootErrorScreen extends StatelessWidget {
  const _BootErrorScreen({
    required this.title,
    required this.detail,
    this.compact = false,
  });

  final String title;
  final String detail;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.graphite,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline,
                  size: 52, color: AppColors.champagneLight),
              const SizedBox(height: 14),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (!compact) ...[
                const SizedBox(height: 8),
                Flexible(
                  child: SingleChildScrollView(
                    child: Text(
                      detail,
                      textAlign: TextAlign.left,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 18),
              if (pageReloadSupported)
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.champagneLight,
                    foregroundColor: AppColors.graphiteDark,
                    minimumSize: const Size(200, 48),
                  ),
                  onPressed: reloadPage,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Recharger la page'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class PharmaGoldApp extends StatelessWidget {
  const PharmaGoldApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Selector plutôt que Consumer : seul un changement de themeMode ou de
    // locale ne reconstruit plus MaterialApp — les changements d'état
    // d'authentification (login → dashboard) sont gérés par le Consumer
    // interne de RootGate, et évitent un rebuild complet de l'arbre.
    return Selector<AuthStore, ({ThemeMode themeMode, String locale})>(
      selector: (_, auth) =>
          (themeMode: auth.themeMode, locale: auth.locale),
      builder: (context, values, _) {
        final themeMode = values.themeMode;
        final locale = values.locale;
        final rtl = locale == 'ar';
        return MaterialApp(
          title: 'PHARMA+',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: themeMode,
          scrollBehavior: const AppScrollBehavior(),
          locale: Locale(locale),
          supportedLocales: const [Locale('fr'), Locale('ar'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (context, child) => Directionality(
            textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
            child: Listener(
              // Tracking d'activité global : chaque tap/clavier réinitialise
              // le minuteur de verrouillage inactivité (sinon il ne se
              // déclenche jamais car aucune interaction ne reset le timer).
              onPointerDown: (_) => AuthStore.instance.resetInactivityTimer(),
              onPointerMove: (_) => AuthStore.instance.resetInactivityTimer(),
              behavior: HitTestBehavior.translucent,
              child: child ?? const SizedBox.shrink(),
            ),
          ),
          home: const RootGate(),
        );
      },
    );
  }
}
