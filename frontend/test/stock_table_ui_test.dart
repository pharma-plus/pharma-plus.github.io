import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'package:pharma_maroc_gold/core/services/auth_store.dart';
import 'package:pharma_maroc_gold/core/theme/colors.dart';
import 'package:pharma_maroc_gold/features/shell/app_side_menu.dart';
import 'package:pharma_maroc_gold/features/shell/home_shell.dart';
import 'package:pharma_maroc_gold/features/shell/shell_nav.dart';
import 'package:pharma_maroc_gold/features/stock/stock_page.dart';

/// Phase 5 — régressions visuelles corrigées :
///  1. tableau Stock 100 % opaque : zone, en-tête et lignes (alpha 255,
///     aucune ligne `Colors.transparent`) dans les deux thèmes ;
///  2. en-tête et contrôles FIXES : le défilement vertical ne déplace que
///     les lignes (en-tête + filtres + totaux immobiles) ;
///  3. menu latéral FIXE sur desktop (≥1150 px) : rendu par le shell,
///     immobile pendant le défilement du contenu, absent en dessous.

const _rowCount = 30;

HttpOverrides? _previousOverrides;

class _FakeHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => _FakeHttpClient();
}

String _balancesJson() {
  final rows = <Map<String, dynamic>>[];
  for (var i = 1; i <= _rowCount; i++) {
    rows.add({
      'id': 'b$i',
      'medication_id': 'm$i',
      'branch_id': 'br1',
      'lot_id': 'l$i',
      'quantity': 100 + i,
      'reserved_quantity': 0,
    });
  }
  return jsonEncode({'data': rows});
}

String _lotsJson() {
  final rows = <Map<String, dynamic>>[];
  for (var i = 1; i <= _rowCount; i++) {
    rows.add({
      'id': 'l$i',
      'medication_id': 'm$i',
      'lot_number': 'LOT-$i',
      'expiry_date': '2027-06-30',
    });
  }
  return jsonEncode({'data': rows});
}

String _medsJson() {
  final rows = <Map<String, dynamic>>[];
  for (var i = 1; i <= _rowCount; i++) {
    final n = i.toString().padLeft(2, '0');
    rows.add({
      'id': 'm$i',
      'name': 'Med $n',
      'dosage': '500 mg',
      'form': 'Comprimé',
      'laboratory_name': 'Labo $n',
      'price_sale': 10.0 + i,
      'reorder_level': 5,
      'barcode_ean13': '61112345678${i % 10}',
    });
  }
  return jsonEncode({'data': rows});
}

(String, int) _responseFor(Uri url) {
  final path = url.path;
  if (path.endsWith('/stock/balances')) return (_balancesJson(), 200);
  if (path.endsWith('/stock/lots')) return (_lotsJson(), 200);
  if (path.endsWith('/catalog/medications')) return (_medsJson(), 200);
  if (path.endsWith('/dashboard/overview')) {
    return (jsonEncode({'data': <String, dynamic>{}}), 200);
  }
  if (path.endsWith('/stock/alerts')) {
    return (
      jsonEncode({
        'data': {
          'low_stock': <dynamic>[],
          'expiring': <dynamic>[],
          'expired': <dynamic>[],
        },
      }),
      200,
    );
  }
  if (path.endsWith('/notifications')) {
    return (jsonEncode({'data': <dynamic>[], 'meta': {'unread': 0}}), 200);
  }
  if (path.contains('/sync/pull/')) {
    return (jsonEncode({'data': {'maxRevision': 0, 'rows': []}}), 200);
  }
  return (jsonEncode({'data': <dynamic>[]}), 200);
}

class _FakeHttpClient implements HttpClient {
  @override
  bool autoUncompress = true;
  @override
  Duration? connectionTimeout;
  bool followRedirects = true;
  int maxRedirects = 5;
  bool persistentConnection = true;
  @override
  Duration idleTimeout = const Duration(seconds: 15);

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async =>
      _FakeRequest(url);

  @override
  Future<void> close({bool force = false}) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeHeaders implements HttpHeaders {
  final Map<String, List<String>> _values = {};
  int _contentLength = -1;

  @override
  int get contentLength => _contentLength;

  @override
  set contentLength(int? value) => _contentLength = value ?? -1;

  @override
  bool chunkedTransferEncoding = false;

  @override
  bool persistentConnection = false;

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {
    _values[name.toLowerCase()] = ['$value'];
  }

  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {
    (_values[name.toLowerCase()] ??= []).add('$value');
  }

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
  _FakeRequest(this._uri);

  final Uri _uri;
  final _FakeHeaders _headers = _FakeHeaders();

  @override
  HttpHeaders get headers => _headers;

  int _contentLength = -1;

  @override
  int get contentLength => _contentLength;

  @override
  set contentLength(int? value) => _contentLength = value ?? -1;

  @override
  bool followRedirects = true;

  @override
  int maxRedirects = 5;

  @override
  bool persistentConnection = true;

  @override
  bool bufferOutput = true;

  int bufferSize = 8192;

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
    final (body, status) = _responseFor(_uri);
    return _FakeResponse(status, utf8.encode(body));
  }

  @override
  void abort([Object? exception, StackTrace? stackTrace]) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeResponse extends Stream<List<int>> implements HttpClientResponse {
  _FakeResponse(this.statusCode, this._bytes);

  @override
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

Future<void> _pumpStock(WidgetTester tester, Size size,
    {Brightness brightness = Brightness.dark}) async {
  await tester.binding.setSurfaceSize(size);
  await tester.pumpWidget(
    ChangeNotifierProvider<AuthStore>.value(
      value: AuthStore.instance,
      child: MaterialApp(
        // AnimatedTheme interpole les changements de thème (200 ms) :
        // on coupe l'animation pour que Theme.of soit immédiatement exact.
        themeAnimationDuration: Duration.zero,
        theme: ThemeData(brightness: brightness),
        home: const StockPage(),
      ),
    ),
  );
  await _settle(tester);
}

Future<void> _setWindowSize(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.binding.setSurfaceSize(size);
}

Finder _verticalScroll() => find.descendant(
      of: find.byType(StockPage),
      matching: find.byWidgetPredicate(
        (w) => w is SingleChildScrollView && w.scrollDirection == Axis.vertical,
      ),
    );

Finder _horizontalScroll() => find.descendant(
      of: find.byType(StockPage),
      matching: find.byWidgetPredicate(
        (w) => w is SingleChildScrollView && w.scrollDirection == Axis.horizontal,
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // StockPage formate les dates de péremption via Fmt.shortDate (DateFormat)
    // → locale intl nécessaire en environnement de test.
    await initializeDateFormatting('fr');
  });

  setUp(() {
    AuthStore.instance.unlock();
    _previousOverrides = HttpOverrides.current;
    HttpOverrides.global = _FakeHttpOverrides();
  });

  tearDown(() {
    HttpOverrides.global = _previousOverrides;
    AuthStore.instance.unlock();
  });

  testWidgets('Tableau Stock : zone, en-tête et lignes opaques (2 thèmes)',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));

    for (final brightness in [Brightness.dark, Brightness.light]) {
      await _pumpStock(tester, const Size(1024, 768), brightness: brightness);
      final label = '${brightness.name} 1024x768';
      expect(tester.takeException(), isNull, reason: 'débordement $label');

      // En-tête : conteneur vert pétrole SOLIDE (aucun alpha).
      final header = tester.widget<Container>(
        find.byKey(const ValueKey('stock_table_header')),
      );
      expect(header.color, AppColors.primary, reason: 'en-tête $label');
      expect(header.color!.a, 1.0, reason: 'en-tête opaque $label');

      // Zone du tableau : fond SOLIDE sous et entre les lignes.
      final zone = tester.widget<Container>(
        find.byKey(const ValueKey('stock_table_zone')),
      );
      expect(zone.color, isNotNull, reason: 'zone $label');
      expect(zone.color!.a, 1.0, reason: 'zone alpha 255 $label');
      expect(
        brightness == Brightness.dark
            ? AppColors.pharmaSurface
            : Colors.white,
        zone.color,
        reason: 'couleur de zone attendue $label',
      );

      // Lignes : Material alternés, TOUS opaques, jamais transparents.
      final stripes = <Color>{};
      for (final name in ['Med 01', 'Med 02', 'Med 03', 'Med 04']) {
        final rowMaterial = find
            .ancestor(of: find.text(name), matching: find.byType(Material))
            .first;
        final color = tester.widget<Material>(rowMaterial).color;
        expect(color, isNotNull, reason: 'couleur de ligne $name $label');
        expect(color!.a, 1.0, reason: 'ligne opaque $name $label');
        stripes.add(color);
      }
      expect(stripes, isNot(contains(Colors.transparent)),
          reason: 'aucune ligne transparente $label');
      expect(stripes.length, 2, reason: 'alternance de 2 couleurs $label');
    }
  });

  testWidgets('Tableau Stock : en-tête et contrôles fixes pendant le défilement',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pumpStock(tester, const Size(1024, 768));

    final headerBefore = tester.getTopLeft(find.text('Médicament'));
    final chipBefore = tester.getTopLeft(find.text('Tous'));
    final firstRowBefore = tester.getTopLeft(find.text('Med 01'));

    // Défilement vertical DANS le tableau (les lignes bougent).
    await tester.drag(_verticalScroll(), const Offset(0, -320));
    await tester.pump();

    final v = tester.widget<SingleChildScrollView>(_verticalScroll());
    expect(v.controller!.offset, greaterThan(0),
        reason: 'les lignes ont bien défilé');

    // En-tête et contrôles immobiles ; seule la première ligne a bougé.
    expect(tester.getTopLeft(find.text('Médicament')), headerBefore,
        reason: 'en-tête fixe');
    expect(tester.getTopLeft(find.text('Tous')), chipBefore,
        reason: 'filtres fixes');
    expect(tester.getTopLeft(find.text('Med 01')).dy,
        lessThan(firstRowBefore.dy),
        reason: 'les lignes défilent sous l\'en-tête fixe');

    // Défilement horizontal : l'en-tête suit les colonnes (même scroll).
    final h = tester.widget<SingleChildScrollView>(_horizontalScroll());
    await tester.drag(_horizontalScroll(), const Offset(-200, 0));
    await tester.pump();
    expect(h.controller!.offset, greaterThan(0),
        reason: 'défilement horizontal actif');
  });

  testWidgets(
      'Shell desktop ≥1150 : menu latéral FIXE, contenu Stock défile à droite',
      (tester) async {
    ShellNav.index.value = 0;
    await _setWindowSize(tester, const Size(1920, 1080));
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthStore>.value(
        value: AuthStore.instance,
        child: const MaterialApp(home: HomeShell()),
      ),
    );
    // Laisse passer le sync différé (2 s) du shell, puis stabilise.
    await tester.pump(const Duration(seconds: 3));
    await _settle(tester);

    expect(tester.takeException(), isNull);
    expect(find.byType(AppSideMenu), findsOneWidget,
        reason: 'menu fixe rendu par le shell à 1920 px');
    final menuRect = tester.getRect(find.byType(AppSideMenu));

    // Navigation par le menu → onglet Stock du shell.
    await tester.tap(find.descendant(
      of: find.byType(AppSideMenu),
      matching: find.text('Stock'),
    ));
    await _settle(tester);
    await tester.pump(const Duration(milliseconds: 100));
    await _settle(tester);

    expect(find.descendant(
      of: find.byType(StockPage),
      matching: find.text('Médicament'),
    ), findsOneWidget);

    // Le menu reste strictement immobile pendant le défilement du tableau.
    final before = tester.getRect(find.byType(AppSideMenu));
    final headerBefore = tester.getTopLeft(find.descendant(
      of: find.byType(StockPage),
      matching: find.text('Médicament'),
    ));
    await tester.drag(
      find.descendant(
        of: find.byType(StockPage),
        matching: find.byWidgetPredicate((w) =>
            w is SingleChildScrollView && w.scrollDirection == Axis.vertical),
      ),
      const Offset(0, -300),
    );
    await tester.pump();
    final after = tester.getRect(find.byType(AppSideMenu));
    expect(after, before, reason: 'menu fixe pendant le scroll du contenu');
    expect(
      tester.getTopLeft(find.descendant(
        of: find.byType(StockPage),
        matching: find.text('Médicament'),
      )),
      headerBefore,
      reason: 'en-tête du tableau fixe sous le menu',
    );

    // Le menu est bien à GAUCHE du contenu (pas superposé).
    final stockRect = tester.getRect(find.byType(StockPage));
    expect(menuRect.right, lessThanOrEqualTo(stockRect.left + 1),
        reason: 'menu et contenu côte à côte');
    expect(after.width, inInclusiveRange(63, 233),
        reason: 'largeur rail 64 / ouvert 232');

    // Dispose explicite (timer 30 s du menu) avant la fin du test.
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Shell <1150 : menu fixe absent (hamburger conservé)',
      (tester) async {
    ShellNav.index.value = 0;
    await _setWindowSize(tester, const Size(1024, 768));
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthStore>.value(
        value: AuthStore.instance,
        child: const MaterialApp(home: HomeShell()),
      ),
    );
    await tester.pump(const Duration(seconds: 3));
    await _settle(tester);

    expect(tester.takeException(), isNull);
    expect(find.byType(AppSideMenu), findsNothing,
        reason: 'pas de menu fixe sous 1150 px');

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Menu : onglet actif suit ShellNav.index et tap navigue',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    AppSideNavItem? tapped;
    ShellNav.index.value = 0;
    final auth = AuthStore.instance;
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthStore>.value(
        value: auth,
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 232,
              height: 900,
              child: AppSideMenu(
                onNavigate: (item) => tapped = item,
                onLogout: () {},
                onMoreModules: () {},
                onToggleCollapse: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    // "Point de vente" (POS) est visible dans l'environnement de test
    // (l'utilisateur de test a les permissions sales:view).
    // Vérifie que le callback reçoit le bon shellIndex.
    await tester.tap(find.text('Point de vente'));
    await tester.pump();
    expect(tapped?.shellIndex, 2);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('StockPage.openWith : filtre poussé + onglet 4', (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pumpStock(tester, const Size(1024, 768));

    StockPage.openWith(filter: 'low');
    expect(ShellNav.index.value, 4);
    await _settle(tester);

    // Le filtre est consommé (remis à null) et appliqué à la page montée :
    // aucune ligne mock n'est en stock faible → tableau vidé.
    expect(StockPage.pendingFilter.value, isNull);
    expect(find.text('Med 01'), findsNothing,
        reason: 'aucune ligne hors filtre « stock faible »');

    StockPage.openWith();
    expect(StockPage.pendingFilter.value, isNull);
    await _settle(tester);
    expect(find.text('Med 01'), findsWidgets,
        reason: 'filtre réinitialisé : lignes de retour');
    expect(tester.takeException(), isNull);
  });
}
