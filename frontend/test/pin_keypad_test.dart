import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:pharma_maroc_gold/core/services/auth_store.dart';
import 'package:pharma_maroc_gold/core/theme/colors.dart';
import 'package:pharma_maroc_gold/features/security/lock_screen.dart';

/// Clavier PIN smartphone (320 → 430 px) :
///  - aucun débordement RenderFlex à toutes les largeurs ;
///  - chaque chiffre est CENTRÉ dans sa cellule (centre texte == centre
///    bouton, tolérance 0,5 px) — régression du décalage à 320 px ;
///  - hauteur tactile ≥ 48 px (ergonomie doigt) ;
///  - les taps enregistrent bien les chiffres (points PIN + 4e chiffre →
///    appel réseau simulé /auth/pin/verify).
///
/// Un HttpOverrides factice sert /auth/pin/verify (400 PIN_NOT_SET) pour
/// que le 4e chiffre ne débloque jamais l'écran ni ne fasse d'appel réel.

const _sizes = <(double, double)>[
  (320, 640),
  (360, 740),
  (375, 812),
  (390, 844),
  (430, 932),
];

HttpOverrides? _previousOverrides;
final List<String> _requestedPaths = [];

class _FakeHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => _FakeHttpClient();
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
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    _requestedPaths.add(url.path);
    return _FakeRequest(url);
  }

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

  @override
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
    // PIN non configuré côté factice : l'écran reste affiché (pas de
    // déblocage, pas de pop) et propose la création du code.
    const body = '{"error":{"code":"PIN_NOT_SET","message":"Aucun PIN"}}';
    return _FakeResponse(400, utf8.encode(body));
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

Future<void> _pumpLock(WidgetTester tester, Size size) async {
  await tester.binding.setSurfaceSize(size);
  await tester.pumpWidget(
    ChangeNotifierProvider<AuthStore>.value(
      value: AuthStore.instance,
      child: const MaterialApp(home: LockScreen()),
    ),
  );
  for (var i = 0; i < 4; i++) {
    await tester.pump();
  }
}

/// Points PIN remplis : Containers 16×16 dont la couleur (via
/// BoxDecoration) est l'or PHARMA+ — les vides sont gris.
int _filledDots(WidgetTester tester) {
  return tester
      .widgetList(
        find.byWidgetPredicate(
          (w) =>
              w is Container &&
              w.constraints?.maxWidth == 16 &&
              w.constraints?.maxHeight == 16 &&
              w.decoration is BoxDecoration &&
              (w.decoration as BoxDecoration).color == AppColors.pharmaGold,
        ),
      )
      .length;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    _requestedPaths.clear();
    _previousOverrides = HttpOverrides.current;
    HttpOverrides.global = _FakeHttpOverrides();
    AuthStore.instance.unlock();
  });

  tearDown(() {
    HttpOverrides.global = _previousOverrides;
    AuthStore.instance.unlock();
  });

  testWidgets('Clavier PIN : centrage + hauteur tactile de 320 à 430 px',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final (w, h) in _sizes) {
      await _pumpLock(tester, Size(w, h));
      expect(tester.takeException(), isNull, reason: 'débordement ${w}x$h');

      for (final label in ['1', '2', '3', '4', '5', '6', '7', '8', '9', '0']) {
        final text = find.text(label);
        final button = find.ancestor(
            of: text, matching: find.byType(ElevatedButton));
        expect(text, findsOneWidget, reason: 'chiffre $label ${w}x$h');
        expect(button, findsOneWidget, reason: 'bouton $label ${w}x$h');

        final textCenter = tester.getCenter(text);
        final buttonCenter = tester.getCenter(button);
        expect(
          (textCenter.dx - buttonCenter.dx).abs(),
          lessThan(0.5),
          reason: 'centrage horizontal $label ${w}x$h',
        );
        expect(
          (textCenter.dy - buttonCenter.dy).abs(),
          lessThan(0.5),
          reason: 'centrage vertical $label ${w}x$h',
        );

        final buttonSize = tester.getSize(button);
        expect(
          buttonSize.height,
          greaterThanOrEqualTo(48),
          reason: 'hauteur tactile $label ${w}x$h',
        );
      }
    }
  });

  testWidgets('Clavier PIN : taps enregistrent les chiffres (points + verify)',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pumpLock(tester, const Size(390, 844));

    await tester.tap(find.text('1'));
    await tester.tap(find.text('2'));
    await tester.tap(find.text('3'));
    await tester.pump();
    expect(_filledDots(tester), 3, reason: '3 points remplis après 3 taps');
    expect(_requestedPaths, isEmpty,
        reason: 'aucun appel réseau avant le 4e chiffre');

    // C → tout est effacé.
    await tester.tap(find.text('C'));
    await tester.pump();
    expect(_filledDots(tester), 0, reason: 'C efface les points');

    // 4 chiffres → vérification automatique simulée (400 PIN_NOT_SET).
    for (final d in ['1', '2', '3', '4']) {
      await tester.tap(find.text(d));
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();
    expect(
      _requestedPaths.where((p) => p.endsWith('/auth/pin/verify')).length,
      1,
      reason: '4e chiffre → un seul appel /auth/pin/verify',
    );
    expect(find.text('Aucun PIN configuré — définissez votre code.'),
        findsOneWidget);
  });
}
