import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'package:pharma_maroc_gold/core/services/auth_store.dart';
import 'package:pharma_maroc_gold/core/theme/colors.dart';
import 'package:pharma_maroc_gold/features/dashboard/dashboard_page.dart';

/// Mission rénovation UI/UX — Dashboard :
///  1. les 8 cartes KPI illustrées rendent SANS débordement ;
///  2. chaque carte porte la couleur de SA catégorie (palette premium
///     centralisée dans AppColors — pas de KPI tout vert) ;
///  3. chaque KPI embarque son illustration 3D d'arrière-plan (webp maquette) ;
///  4. responsive : desktop large, fenêtre réduite, smartphone portrait.

const _kpiLabels = [
  'VENTES DU JOUR',
  'MÉDICAMENTS',
  'PRODUITS EN STOCK',
  'COMMANDES',
  'FOURNISSEURS',
  'CLIENTS',
  'EMPLOYÉS',
  'BÉNÉFICE MOIS',
];

HttpOverrides? _previousOverrides;

class _FakeHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => _FakeHttpClient();
}

(String, int) _responseFor(Uri url) {
  final path = url.path;
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
    return (
      jsonEncode({
        'data': <dynamic>[],
        'meta': {'unread': 0}
      }),
      200
    );
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
  // bufferSize n'est pas un membre de HttpClientRequest (champ local).
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

Future<void> _pumpDashboard(WidgetTester tester, Size size) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
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
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
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

  testWidgets(
      'Dashboard : 8 cartes KPI illustrées, couleur par catégorie, '
      'sans débordement (desktop)', (tester) async {
    await _pumpDashboard(tester, const Size(1440, 950));

    expect(tester.takeException(), isNull,
        reason: 'aucun débordement en 1440x950');

    // Les 8 cartes KPI rendent (données réelles vides → valeurs à 0).
    // Chaque carte est identifiée par sa clé de badge unique (pas de doublon
    // possible même si un libellé apparaît ailleurs dans le dashboard).
    for (var i = 0; i < _kpiLabels.length; i++) {
      expect(find.byKey(ValueKey('kpi-badge-${_kpiLabels[i]}')), findsOneWidget,
          reason: 'KPI ${_kpiLabels[i]} absente');
    }

    // Couleur de catégorie par carte (palette premium centralisée).
    Color badgeColorOf(String label) {
      final container =
          tester.widget<Container>(find.byKey(ValueKey('kpi-badge-$label')));
      return (container.decoration! as BoxDecoration).color!;
    }

    expect(badgeColorOf('VENTES DU JOUR'), AppColors.emeraldRich);
    expect(badgeColorOf('MÉDICAMENTS'), AppColors.cardBlue);
    expect(badgeColorOf('PRODUITS EN STOCK'), AppColors.cardAmber);
    expect(badgeColorOf('COMMANDES'), AppColors.cardPurple);
    expect(badgeColorOf('FOURNISSEURS'), AppColors.petroleumBlue);
    expect(badgeColorOf('CLIENTS'), AppColors.emeraldDeep);
    expect(badgeColorOf('EMPLOYÉS'), AppColors.emeraldInk);
    expect(badgeColorOf('BÉNÉFICE MOIS'), AppColors.champagneGold);

    // Illustrations 3D : chaque KPI utilise uniquement son fond illustré.
    expect(
      find.byWidgetPredicate((w) =>
          w is Image &&
          w.image is AssetImage &&
          (w.image as AssetImage)
              .assetName
              .startsWith('assets/images/kpi_bg_')),
      findsNWidgets(8),
      reason: '8 illustrations 3D d’arrière-plan attendues',
    );

    // Les illustrations remplissent la surface KPI sans sortir de la carte.
    final kpiImages = tester
        .widgetList<Image>(find.byWidgetPredicate((w) =>
            w is Image &&
            w.image is AssetImage &&
            (w.image as AssetImage)
                .assetName
                .startsWith('assets/images/kpi_bg_')))
        .toList();
    expect(kpiImages, hasLength(8));
    expect(kpiImages.every((image) => image.fit == BoxFit.cover), isTrue,
        reason: 'les 8 illustrations KPI doivent remplir leur carte');
  });

  testWidgets('Dashboard : responsive — fenêtre réduite et smartphone',
      (tester) async {
    await _pumpDashboard(tester, const Size(1024, 768));
    expect(tester.takeException(), isNull,
        reason: 'aucun débordement en 1024x768');
    for (var i = 0; i < _kpiLabels.length; i++) {
      expect(find.byKey(ValueKey('kpi-badge-${_kpiLabels[i]}')), findsOneWidget,
          reason: 'KPI ${_kpiLabels[i]} en 1024x768');
    }

    await _pumpDashboard(tester, const Size(390, 844));
    expect(tester.takeException(), isNull,
        reason: 'aucun débordement en 390x844 (smartphone portrait)');
    for (var i = 0; i < _kpiLabels.length; i++) {
      expect(find.byKey(ValueKey('kpi-badge-${_kpiLabels[i]}')), findsOneWidget,
          reason: 'KPI ${_kpiLabels[i]} en 390x844');
    }
  });
}
