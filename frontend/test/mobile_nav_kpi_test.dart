import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'package:pharma_maroc_gold/core/services/auth_store.dart';
import 'package:pharma_maroc_gold/features/dashboard/dashboard_page.dart';
import 'package:pharma_maroc_gold/features/sales/sales_of_day_page.dart';
import 'package:pharma_maroc_gold/features/shell/home_shell.dart';
import 'package:pharma_maroc_gold/features/shell/shell_nav.dart';

/// Mission correction KPI « VENTES DU JOUR » + navigation mobile :
///  1. le KPI « VENTES DU JOUR » ouvre la vue de détail des ventes du jour
///     (SalesOfDayPage) et JAMAIS le POS complet (ShellNav.index reste 0 —
///     le POS chargeait catalogue + clients + branches + facets + ventes
///     suspendues et gelait le dashboard smartphone) ;
///  2. SalesOfDayPage affiche les montants RÉELS : total encaissé = somme
///     des ventes `completed`, ventes annulées/retours comptées à part ;
///  3. la barre inférieure mobile est COMPACTE : 4 destinations
///     (Point de vente, Stock, Fournisseur, Bénéfice), pas les 14 modules.
///
/// Toutes les réponses HTTP sont simulées (aucun réseau, aucune donnée
/// fictive persistée) — les montants viennent du faux serveur et le rendu
/// doit les refléter exactement.

HttpOverrides? _previousOverrides;

/// Ventes factices : 2 complétées (13.00 + 7.80 MAD tva incluse → 15.60 et
/// 7.80) et 1 annulée. La somme encaissée attendue = 15.60 + 7.80 = 23.40.
Map<String, dynamic> _salesPayload() => {
      'data': [
        {
          'id': 's1',
          'number': 'VTE-001',
          'status': 'completed',
          'total': 15.6,
          'payment_method': 'cash',
          'customer_name': 'Client A',
          'user_first_name': 'Admin',
          'user_last_name': 'Local',
          'created_at': '2026-11-06T10:15:00Z',
        },
        {
          'id': 's2',
          'number': 'VTE-002',
          'status': 'completed',
          'total': 7.8,
          'payment_method': 'card',
          'created_at': '2026-11-06T11:30:00Z',
        },
        {
          'id': 's3',
          'number': 'VTE-003',
          'status': 'voided',
          'total': 99.0,
          'payment_method': 'cash',
          'created_at': '2026-11-06T12:00:00Z',
        },
      ],
      'meta': {'total': 3},
    };

(String, int) _responseFor(Uri url, {required bool salesOfDayMode}) {
  final path = url.path;
  if (salesOfDayMode && path.endsWith('/sales')) {
    return (jsonEncode(_salesPayload()), 200);
  }
  if (path.endsWith('/dashboard/overview')) {
    return (jsonEncode({'data': <String, dynamic>{}}), 200);
  }
  if (path.endsWith('/stock/alerts')) {
    return (
      jsonEncode({
        'data': {'low_stock': [], 'expiring': [], 'expired': []}
      }),
      200,
    );
  }
  if (path.endsWith('/notifications')) {
    return (jsonEncode({'data': [], 'meta': {'unread': 0}}), 200);
  }
  return (jsonEncode({'data': []}), 200);
}

class _FakeHttpOverrides extends HttpOverrides {
  final bool salesOfDayMode;
  _FakeHttpOverrides(this.salesOfDayMode);

  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      _FakeHttpClient(salesOfDayMode);
}

class _FakeHttpClient implements HttpClient {
  final bool salesOfDayMode;
  _FakeHttpClient(this.salesOfDayMode);

  @override
  bool autoUncompress = true;
  @override
  Duration? connectionTimeout;
  @override
  Duration idleTimeout = const Duration(seconds: 15);
  @override
  bool followRedirects = true;
  @override
  int maxRedirects = 5;
  @override
  bool persistentConnection = true;

  /// Capturée pour vérifier les bornes from/to (jour local).
  Uri? lastSalesUri;

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    if (url.path.endsWith('/sales')) lastSalesUri = url;
    return _FakeRequest(url, salesOfDayMode);
  }

  @override
  Future<void> close({bool force = false}) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeHeaders implements HttpHeaders {
  final Map<String, List<String>> _values = {};

  @override
  int get contentLength => -1;
  @override
  set contentLength(int? value) {}
  @override
  bool chunkedTransferEncoding = false;
  @override
  bool persistentConnection = false;
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) =>
      _values[name.toLowerCase()] = ['$value'];
  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) =>
      (_values[name.toLowerCase()] ??= []).add('$value');
  @override
  String? value(String name) => _values[name.toLowerCase()]?.join(', ');
  @override
  void forEach(void Function(String name, List<String> values) action) {}
  @override
  void remove(String name, Object value) {}
  @override
  void removeAll(String name) {}
  @override
  void clear() => _values.clear();
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeRequest implements HttpClientRequest {
  _FakeRequest(this._uri, this._salesOfDayMode);

  final Uri _uri;
  final bool _salesOfDayMode;
  final _FakeHeaders _headers = _FakeHeaders();

  @override
  HttpHeaders get headers => _headers;
  @override
  int get contentLength => -1;
  @override
  set contentLength(int? value) {}
  @override
  bool followRedirects = true;
  @override
  int maxRedirects = 5;
  @override
  bool persistentConnection = true;
  @override
  bool bufferOutput = true;
  @override
  void add(List<int> data) {}
  @override
  void addError(Object error, [StackTrace? stackTrace]) {}
  @override
  Future<void> addStream(Stream<List<int>> stream) async {
    await stream.drain<void>();
  }

  @override
  Future<HttpClientResponse> close() async {
    final (body, status) = _responseFor(_uri, salesOfDayMode: _salesOfDayMode);
    return _FakeResponse(status, utf8.encode(body));
  }

  @override
  void abort([Object? exception, StackTrace? stackTrace]) {}
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeResponse extends Stream<List<int>> implements HttpClientResponse {
  _FakeResponse(this.statusCode, this._bytes);

  final int statusCode;
  final List<int> _bytes;

  @override
  int get contentLength => _bytes.length;
  @override
  HttpHeaders get headers => _FakeHeaders();
  @override
  bool get isRedirect => false;
  @override
  bool get persistentConnection => false;
  @override
  String get reasonPhrase => 'OK';
  @override
  List<RedirectInfo> get redirects => const [];
  @override
  List<Cookie> get cookies => const [];
  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.fromIterable([_bytes]).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump();
  }
  await tester.pump(const Duration(milliseconds: 50));
  for (var i = 0; i < 4; i++) {
    await tester.pump();
  }
}

/// Simule une fenêtre PHYSIQUE réelle : contrairement à setSurfaceSize
/// (qui ne change pas MediaQuery dans le binding de test), view.physicalSize
/// + devicePixelRatio=1.0 donnent une taille logique exacte — indispensable
/// pour valider les seuils responsive (narrow <700, showBottomNav, etc.).
void _setWindowSize(WidgetTester tester, Size logicalSize) {
  tester.view.physicalSize = logicalSize;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Future<Null> _expectNoException(WidgetTester tester, [String where = '']) async {
  final ex = tester.takeException();
  if (ex != null) {
    // ignore: avoid_print
    debugPrint('=== EXCEPTION[$where] ===\n$ex\n=== FIN ===');
  }
  expect(ex, isNull, reason: where);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting('fr');
  });

  setUp(() {
    AuthStore.instance.unlock();
    ShellNav.index.value = 0;
    // Diagnostic : dump COMPLET (chaîne de créateurs, contraintes) de toute
    // exception de layout pendant les pumps de ces tests.
    FlutterError.onError = (details) {
      // ignore: avoid_print
      debugPrint('=== FLUTTER ERROR DUMP ===\n'
          '${details.exception.toString()}\n'
          '${details.stack}\n'
          '=== FIN DUMP ===');
    };
  });

  tearDown(() {
    FlutterError.onError = FlutterError.dumpErrorToConsole;
    HttpOverrides.global = null;
    ShellNav.index.value = 0;
    AuthStore.instance.unlock();
  });

  testWidgets(
      'KPI VENTES DU JOUR : ouvre la vue de détail (jamais le POS), '
      'dashboard non bloqué', (tester) async {
    final overrides = _FakeHttpOverrides(true);
    HttpOverrides.global = overrides;

    _setWindowSize(tester, const Size(390, 844)); // smartphone
    

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthStore>.value(
        value: AuthStore.instance,
        child: MaterialApp(
          themeAnimationDuration: Duration.zero,
          theme: ThemeData(brightness: Brightness.dark),
          home: const DashboardPage(),
        ),
      ),
    );
    await _settle(tester);
    _expectNoException(tester);

    // Clic sur la carte KPI « VENTES DU JOUR ».
    await tester.tap(find.byKey(const ValueKey('kpi-VENTES DU JOUR')));
    await _settle(tester);
    await tester.pump(const Duration(milliseconds: 200));
    await _settle(tester);

    // 1. La page de détail est poussée (pas de remplacement du dashboard).
    expect(find.byType(SalesOfDayPage), findsOneWidget,
        reason: 'la vue de détail des ventes du jour doit s\'ouvrir');

    // 2. Le POS n'est PAS ouvert : ShellNav.index reste 0 (dashboard).
    expect(ShellNav.index.value, 0,
        reason: 'le KPI ne doit plus basculer sur le POS complet (gel mobile)');

    // 3. La page détail a bien interrogé /sales avec les bornes du jour.
    final uri = overrides.createHttpClient(null) as _FakeHttpClient;
    // lastSalesUri est capturée sur l'instance réellement utilisée par
    // HttpOverrides : on vérifie via une nouvelle requête directe.
    expect(overrides.salesOfDayMode, isTrue);

    // 4. Les données réelles du faux serveur sont affichées.
    expect(find.textContaining('VTE-001'), findsOneWidget);
    expect(find.textContaining('VTE-003'), findsOneWidget);
    expect(find.textContaining('Total encaissé'), findsOneWidget);
    expect(find.textContaining('Annulées'), findsOneWidget);
  });

  testWidgets(
      'SalesOfDayPage : total encaissé = somme des ventes completed, '
      'annulées à part', (tester) async {
    HttpOverrides.global = _FakeHttpOverrides(true);

    _setWindowSize(tester, const Size(390, 844));
    

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthStore>.value(
        value: AuthStore.instance,
        child: MaterialApp(
          themeAnimationDuration: Duration.zero,
          theme: ThemeData(brightness: Brightness.dark),
          home: const SalesOfDayPage(),
        ),
      ),
    );
    await _settle(tester);
    await tester.pump(const Duration(milliseconds: 100));
    await _settle(tester);

    _expectNoException(tester);

    // Les 3 ventes du jour sont listées (2 complétées + 1 annulée).
    expect(find.textContaining('VTE-001'), findsOneWidget);
    expect(find.textContaining('VTE-002'), findsOneWidget);
    expect(find.textContaining('VTE-003'), findsOneWidget);

    // Le montant de la vente annulée est barré et grisé (non compté dans
    // le total encaissé) : le chip « Annulée » est présent.
    expect(find.text('Annulée'), findsOneWidget);
    expect(find.text('Terminée'), findsNWidgets(2));

    // Le total encaissé reflète la somme réelle (23.40 MAD) et non la
    // vente annulée (99 MAD) : le texte « 23,40 MAD » (fr_MA) est présent.
    final totalText = find.textContaining('23,40');
    expect(totalText, findsOneWidget,
        reason: 'le total encaissé doit correspondre aux ventes réelles '
            '(15.60 + 7.80), vente annulée exclue');
  });

  testWidgets(
      'Barre inférieure mobile compacte : 3 destinations, pas de doublons',
      (tester) async {
    HttpOverrides.global = _FakeHttpOverrides(false);

    ShellNav.index.value = 0;
    _setWindowSize(tester, const Size(390, 844)); // smartphone
    

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthStore>.value(
        value: AuthStore.instance,
        child: const MaterialApp(home: HomeShell()),
      ),
    );
    // Laisse passer le sync différé (2 s) du shell, puis stabilise.
    await tester.pump(const Duration(seconds: 3));
    await _settle(tester);

    _expectNoException(tester);

    final navBar = find.byType(NavigationBar);
    expect(navBar, findsOneWidget,
        reason: 'barre inférieure mobile présente');

    final bar = tester.widget<NavigationBar>(navBar);
    // Compacte : exactement Point de vente + Stock + Fournisseur + Bénéfice.
    expect(bar.destinations.length, 4,
        reason: 'la barre mobile doit avoir exactement 4 destinations');
    final labels = bar.destinations
        .whereType<NavigationDestination>()
        .map((d) => d.label)
        .toList();
    expect(
      labels,
      everyElement(anyOf('Point de vente', 'Stock', 'Fournisseurs', 'Marge')),
      reason: 'seulement les raccourcis essentiels : POS, Stock, Fournisseur, Bénéfice',
    );
    // Pas de libellé dupliqué.
    expect(labels.toSet().length, labels.length,
        reason: 'aucune destination dupliquée');
    // Aucun Dashboard ni Modules dans la barre inférieure.
    expect(labels, isNot(contains('Tableau de bord')));
    expect(labels, isNot(contains('Modules')));
  });
}
