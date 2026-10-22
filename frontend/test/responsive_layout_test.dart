import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'package:pharma_maroc_gold/core/services/auth_store.dart';
import 'package:pharma_maroc_gold/core/widgets/gradient_button.dart';
import 'package:pharma_maroc_gold/core/widgets/shared/app_confirm_dialog.dart';
import 'package:pharma_maroc_gold/core/widgets/shared/app_data_table.dart';
import 'package:pharma_maroc_gold/features/catalog/catalog_page.dart';
import 'package:pharma_maroc_gold/features/stock/stock_page.dart';
import 'package:pharma_maroc_gold/features/suppliers/suppliers_page.dart';
import 'package:pharma_maroc_gold/features/super_admin/super_admin_portal.dart';
import 'package:pharma_maroc_gold/features/super_admin/users_management_page.dart';

/// Tests responsive (étape 6) : 360 / 390 / 768 / 1024 / 1366 / 1920 via
/// setSurfaceSize. Un débordement RenderFlex apparaît comme exception de
/// test : chaque taille assert takeException() == null.
/// Un HttpOverrides interne sert des données factices aux pages (sinon le
/// mock flutter_test répond 400 et les branches cartes/tableau, qui
/// n'existent qu'avec des lignes, ne sont jamais rendues).

const _sizes = <(double, double)>[
  (360, 800),
  (390, 844),
  (768, 1024),
  (1024, 768),
  (1366, 768),
  (1920, 1080),
];

HttpOverrides? _previousOverrides;

class _FakeHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => _FakeHttpClient();
}

(String, int) _responseFor(Uri url) {
  final path = url.path;
  if (path.endsWith('/suppliers')) {
    return (
      jsonEncode({
        'data': [
          {
            'id': 's1',
            'name': 'Distri Pharma',
            'city': 'Casablanca',
            'contact_name': 'Ali Bennani',
            'phone': '0661000111',
            'rating': 4.6,
            'nb_orders': 24,
          },
          {
            'id': 's2',
            'name': 'MediFourn',
            'city': 'Rabat',
            'contact_name': 'Sara Idrissi',
            'phone': '0537000222',
            'rating': 3.9,
            'nb_orders': 11,
          },
          {
            'id': 's3',
            'name': 'Grossiste Atlas',
            'city': 'Fès',
            'contact_name': 'Omar Alami',
            'phone': '0535000333',
            'rating': 4.2,
            'nb_orders': 7,
          },
        ],
      }),
      200,
    );
  }
  if (path.endsWith('/catalog/medications/facets')) {
    return (
      jsonEncode({
        'data': {
          'laboratories': [],
          'forms': [],
          'dosages': [],
          'statuses': [],
          'indications_total': 0,
        },
      }),
      200,
    );
  }
  if (path.endsWith('/catalog/medications/stock-ids')) {
    return ('{"data":[]}', 200);
  }
  if (path.endsWith('/stock/balances')) {
    return (
      jsonEncode({
        'data': [
          {
            'id': 'b1',
            'medication_id': 'm1',
            'branch_id': 'br1',
            'lot_id': 'l1',
            'quantity': 120,
            'reserved_quantity': 0,
          },
          {
            'id': 'b2',
            'medication_id': 'm2',
            'branch_id': 'br1',
            'lot_id': 'l2',
            'quantity': 3,
            'reserved_quantity': 0,
          },
          {
            'id': 'b3',
            'medication_id': 'm3',
            'branch_id': 'br1',
            'lot_id': 'l3',
            'quantity': 0,
            'reserved_quantity': 0,
          },
        ],
      }),
      200,
    );
  }
  if (path.endsWith('/stock/lots')) {
    return (
      jsonEncode({
        'data': [
          {
            'id': 'l1',
            'medication_id': 'm1',
            'lot_number': 'LOT-A1',
            'expiry_date': '2027-06-30',
          },
          {
            'id': 'l2',
            'medication_id': 'm2',
            'lot_number': 'LOT-B2',
            'expiry_date': '2026-11-15',
          },
          {
            'id': 'l3',
            'medication_id': 'm3',
            'lot_number': 'LOT-C3',
            'expiry_date': '2025-01-01',
          },
        ],
      }),
      200,
    );
  }
  if (path.endsWith('/catalog/medications')) {
    return (
      jsonEncode({
        'data': [
          {
            'id': 'm1',
            'name': 'Doliprane',
            'dci': 'Paracétamol',
            'dosage': '1000 mg',
            'form': 'Comprimé',
            'presentation': 'Boîte de 8',
            'price_purchase': 12.5,
            'price_sale': 18.9,
            'min_stock': 10,
            'status': 'available',
            'stock_quantity': 120,
            'laboratory_name': 'Sanofi',
          },
          {
            'id': 'm2',
            'name': 'Amoxicilline Mylan',
            'dci': 'Amoxicilline',
            'dosage': '500 mg',
            'form': 'Gélule',
            'price_purchase': 22.0,
            'price_sale': 34.5,
            'min_stock': 5,
            'status': 'available',
            'stock_quantity': 40,
            'laboratory_name': 'Mylan',
          },
          {
            'id': 'm3',
            'name': 'Spasfon',
            'dci': 'Phloroglucinol',
            'dosage': '80 mg',
            'form': 'Comprimé',
            'price_purchase': 19.9,
            'price_sale': 29.9,
            'min_stock': 8,
            'status': 'available',
            'stock_quantity': 0,
            'laboratory_name': 'Teriak',
          },
        ],
      }),
      200,
    );
  }
  return ('{"error":{"code":"MOCK_400","message":"mock 400"}}', 400);
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

  List<int> _body = const [];

  @override
  void add(List<int> data) {
    _body = [..._body, ...data];
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}

  @override
  Future<void> addStream(Stream<List<int>> stream) async {
    _body = await stream.fold<List<int>>(<int>[], (acc, chunk) {
      acc.addAll(chunk);
      return acc;
    });
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
  for (var i = 0; i < 6; i++) {
    await tester.pump();
  }
}

void main() {
  setUpAll(() async {
    // StockPage formate les dates de péremption via Fmt.shortDate (DateFormat)
    // → données de locale intl nécessaires en environnement de test.
    await initializeDateFormatting('fr');
  });

  setUp(() {
    _previousOverrides = HttpOverrides.current;
    HttpOverrides.global = _FakeHttpOverrides();
  });

  tearDown(() {
    HttpOverrides.global = _previousOverrides;
  });

  testWidgets(
      'SuppliersPage : 6 tailles sans débordement — cartes <600, AppDataTable >=600',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final (w, h) in _sizes) {
      await tester.binding.setSurfaceSize(Size(w, h));
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: AuthStore.instance,
          child: const MaterialApp(home: SuppliersPage()),
        ),
      );
      await _settle(tester);

      expect(tester.takeException(), isNull, reason: 'SuppliersPage ${w}x$h');
      final desktop = w >= 600;
      expect(
        find.byType(AppDataTable<Map<String, dynamic>>),
        desktop ? findsOneWidget : findsNothing,
        reason: 'mode tableau/cartes ${w}x$h',
      );
      expect(find.text('Distri Pharma'), findsWidgets,
          reason: 'données rendues ${w}x$h');
    }
  });

  testWidgets('CatalogPage : 6 tailles sans débordement', (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final (w, h) in _sizes) {
      await tester.binding.setSurfaceSize(Size(w, h));
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: AuthStore.instance,
          child: const MaterialApp(home: CatalogPage()),
        ),
      );
      await _settle(tester);

      expect(tester.takeException(), isNull, reason: 'CatalogPage ${w}x$h');
      expect(find.text('Doliprane'), findsWidgets,
          reason: 'données rendues ${w}x$h');
    }
  });

  testWidgets(
      'StockPage : 6 tailles sans débordement — tableau >=600, cartes <600',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final (w, h) in _sizes) {
      await tester.binding.setSurfaceSize(Size(w, h));
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: AuthStore.instance,
          child: const MaterialApp(home: StockPage()),
        ),
      );
      await _settle(tester);
      await tester.pump(const Duration(milliseconds: 100));
      await _settle(tester);

      expect(tester.takeException(), isNull, reason: 'StockPage ${w}x$h');
      expect(find.text('Doliprane'), findsWidgets,
          reason: 'données rendues ${w}x$h');
      // En-tête collant « Péremption » : tableau uniquement (>=600).
      expect(
        find.text('Péremption'),
        w >= 600 ? findsOneWidget : findsNothing,
        reason: 'mode tableau/cartes ${w}x$h',
      );
    }
  });

  testWidgets('UserFormDialog : 6 tailles sans débordement', (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final (w, h) in _sizes) {
      await tester.binding.setSurfaceSize(Size(w, h));
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: AuthStore.instance,
          child: const MaterialApp(
            home: Scaffold(
              body: UserFormDialog(roles: [
                {'id': 'r1', 'name': 'Admin'}
              ]),
            ),
          ),
        ),
      );
      await _settle(tester);

      expect(tester.takeException(), isNull, reason: 'UserFormDialog ${w}x$h');
      expect(find.byType(FilledButton), findsOneWidget);
    }
  });

  testWidgets('PharmacyForm : 6 tailles sans débordement', (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final (w, h) in _sizes) {
      await tester.binding.setSurfaceSize(Size(w, h));
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: AuthStore.instance,
          child: const MaterialApp(
            home: Scaffold(body: SingleChildScrollView(child: PharmacyForm())),
          ),
        ),
      );
      await _settle(tester);

      expect(tester.takeException(), isNull, reason: 'PharmacyForm ${w}x$h');
      expect(find.byType(GradientButton), findsOneWidget);
    }
  });

  testWidgets('AppConfirmDialog : 6 tailles — dialogue et boutons visibles',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final (w, h) in _sizes) {
      await tester.binding.setSurfaceSize(Size(w, h));
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () {
                    AppConfirmDialog.show(
                      context: context,
                      title: 'Supprimer la caméra',
                      message: 'Caméra 1',
                      isDestructive: true,
                      type: AppConfirmType.danger,
                    );
                  },
                  child: const Text('ouvrir'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('ouvrir'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull,
          reason: 'AppConfirmDialog ${w}x$h');
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Confirmer'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Annuler'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Annuler'));
      await tester.pumpAndSettle();
    }
  });
}
