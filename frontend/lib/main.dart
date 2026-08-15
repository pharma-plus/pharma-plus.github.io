import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'app.dart';
import 'core/services/auth_store.dart';
import 'core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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

class PharmaGoldApp extends StatelessWidget {
  const PharmaGoldApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthStore>(
      builder: (context, auth, _) {
        final rtl = auth.locale == 'ar';
        return MaterialApp(
          title: 'PHARMA+',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: auth.themeMode,
          locale: Locale(auth.locale),
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
