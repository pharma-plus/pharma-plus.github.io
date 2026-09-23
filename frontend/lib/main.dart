import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'app.dart';
import 'core/services/auth_store.dart';
import 'core/services/page_reload.dart';
import 'core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ---- Diagnostic global (web release inclus) ----
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

  // On affiche immédiatement le Splash (RootGate) au lieu de bloquer le
  // lancement sur une initialisation qui pourrait ne jamais se terminer.
  runApp(
    ChangeNotifierProvider.value(
      value: AuthStore.instance,
      child: const PharmaGoldApp(),
    ),
  );
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
      color: const Color(0xFF03100D),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline,
                  size: 52, color: Color(0xFFE9C873)),
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
                    backgroundColor: const Color(0xFFE9C873),
                    foregroundColor: const Color(0xFF07201B),
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
          locale: Locale(locale),
          supportedLocales: const [Locale('fr'), Locale('ar'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (context, child) => Directionality(
            textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
            child: child ?? const SizedBox.shrink(),
          ),
          home: const RootGate(),
        );
      },
    );
  }
}
