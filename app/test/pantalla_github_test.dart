import 'dart:async';
import 'dart:io';

import 'package:duo_desktop/src/config.dart';
import 'package:duo_desktop/src/pantallas/pantalla_github.dart';
import 'package:duo_desktop/src/tema/paleta.dart';
import 'package:duo_desktop/src/tema/tema.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'soporte/http_falso.dart';

/// Lo que devolvería `GET /github` con el repo en marcha: una rama por agente y
/// dos PR abiertos.
const _respuesta = {
  'branches': [
    {'name': 'cc/t-015-tests', 'agent': 'cc'},
    {'name': 'codex/t-011-endpoints', 'agent': 'codex'},
    {'name': 'chat/t-002-contrato', 'agent': 'chat'},
  ],
  'pullRequests': [
    {
      'number': 42,
      'title': 'tests de widget de las cuatro vistas',
      'state': 'open',
      'head': 'cc/t-015-tests',
    },
    {
      'number': 41,
      'title': 'endpoints que faltaban',
      'state': 'merged',
      'head': 'codex/t-011-endpoints',
    },
  ],
};

/// Una ventana de escritorio de verdad: los dos paneles reparten por ancho.
Future<void> _pinta(WidgetTester tester, {Size tamano = const Size(1600, 1200)}) async {
  tester.view.physicalSize = tamano;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: TemaDuo.oscuro(),
      home: const Scaffold(body: PantallaGitHub()),
    ),
  );
  // La pantalla pide `/github` en `initState`: hasta que vuelve hay spinner.
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('mientras se pide /github se ve que está cargando', (tester) async {
    final espera = Completer<RespuestaFalsa>();
    HttpFalso.instala((_) => espera.future, addTearDown);

    await tester.pumpWidget(
      MaterialApp(
        theme: TemaDuo.oscuro(),
        home: const Scaffold(body: PantallaGitHub()),
      ),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('RAMAS POR AGENTE'), findsNothing);
    // El botón de actualizar no se puede pulsar dos veces encima.
    expect(
      tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
      isNull,
    );

    espera.complete(const RespuestaFalsa(codigo: 200, cuerpo: '{}'));
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('ramas y pull requests se pintan con su recuento', (tester) async {
    HttpFalso.conJson(_respuesta, addTearDown);

    await _pinta(tester);

    expect(find.text('GitHub'), findsOneWidget);
    expect(find.text('GET /github'), findsOneWidget);
    expect(find.text('RAMAS POR AGENTE'), findsOneWidget);
    expect(find.text('PULL REQUESTS'), findsOneWidget);
    // Los sufijos de cada tarjeta son los recuentos: tres ramas, dos PR.
    expect(find.text('3'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);

    expect(find.text('cc/t-015-tests'), findsNWidgets(2)); // rama y PR
    expect(find.text('codex/t-011-endpoints'), findsNWidgets(2));
    expect(find.text('chat/t-002-contrato'), findsOneWidget);

    expect(find.text('#42'), findsOneWidget);
    expect(find.text('tests de widget de las cuatro vistas'), findsOneWidget);
    expect(find.text('open'), findsOneWidget);
    expect(find.text('#41'), findsOneWidget);
    expect(find.text('merged'), findsOneWidget);

    // Con datos no hay aviso: el aviso es solo para lo que no se pudo mostrar.
    expect(find.textContaining('no hay ramas ni pull requests'), findsNothing);
  });

  testWidgets('cada rama lleva el color de su agente', (tester) async {
    HttpFalso.conJson(_respuesta, addTearDown);

    await _pinta(tester);

    // El alias va en texto (`Mono`); el color es solo el refuerzo.
    for (final alias in ['cc', 'codex', 'chat']) {
      expect(find.text(alias), findsOneWidget, reason: 'falta el alias $alias');
    }

    // El punto de color de cada fila, en el orden en que llegaron las ramas.
    final puntos = tester
        .widgetList<Container>(
          find.byWidgetPredicate(
            (w) =>
                w is Container &&
                w.constraints == const BoxConstraints.tightFor(width: 8, height: 8),
          ),
        )
        .map((c) => c.color)
        .toList();

    // El color sigue al agente, no a su puesto en la lista: `chat` llega
    // último y aun así se queda con su slot.
    expect(puntos, [
      PaletaDatos.oscuro.serieDe('cc'),
      PaletaDatos.oscuro.serieDe('codex'),
      PaletaDatos.oscuro.serieDe('chat'),
    ]);
  });

  testWidgets('las claves alternativas del contrato también se entienden', (tester) async {
    // El contrato admite `pull_requests`/`prs` y `branch`/`owner`: si el
    // servicio usa la variante en snake_case la pantalla no se queda en blanco.
    HttpFalso.conJson({
      'branches': [
        {'branch': 'cc/t-015-tests'},
        {'branch': 'rama-sin-dueno'},
      ],
      'pull_requests': [
        {'id': 7, 'branch': 'cc/t-015-tests', 'status': 'draft'},
      ],
    }, addTearDown);

    await _pinta(tester);

    // Sin `agent`, el dueño se deduce del prefijo de la rama.
    expect(find.text('cc'), findsOneWidget);
    // Y si no hay prefijo conocido no se inventa un agente.
    expect(find.text('—'), findsOneWidget);
    expect(find.text('#7'), findsOneWidget);
    expect(find.text('Pull request sin título'), findsOneWidget);
    expect(find.text('draft'), findsOneWidget);
  });

  testWidgets('una respuesta vacía se dice, no se pinta como si no hubiera nada', (
    tester,
  ) async {
    HttpFalso.conJson({'branches': <Object>[], 'pullRequests': <Object>[]}, addTearDown);

    await _pinta(tester);

    expect(
      find.text(
        'El endpoint respondió correctamente, pero no hay ramas ni pull requests para mostrar.',
      ),
      findsOneWidget,
    );
    // Los dos paneles siguen en pantalla, cada uno diciendo que está a cero.
    expect(find.text('No hay ramas devueltas por GET /github.'), findsOneWidget);
    expect(find.text('No hay pull requests devueltos por GET /github.'), findsOneWidget);
    expect(find.text('0'), findsNWidgets(2));
  });

  testWidgets('un endpoint que todavía no existe se distingue de un error', (tester) async {
    HttpFalso.instala(
      (_) async => const RespuestaFalsa(codigo: 404, cuerpo: 'Not Found'),
      addTearDown,
    );

    await _pinta(tester);

    expect(
      find.text('GET /github todavía no está disponible en el servicio local.'),
      findsOneWidget,
    );
    expect(find.text('RAMAS POR AGENTE'), findsOneWidget);
  });

  testWidgets('un 501 se lee igual que un 404: falta por implementar', (tester) async {
    HttpFalso.instala(
      (_) async => const RespuestaFalsa(codigo: 501, cuerpo: ''),
      addTearDown,
    );

    await _pinta(tester);

    expect(
      find.text('GET /github todavía no está disponible en el servicio local.'),
      findsOneWidget,
    );
  });

  testWidgets('cualquier otro código HTTP se muestra con su número', (tester) async {
    HttpFalso.instala(
      (_) async => const RespuestaFalsa(codigo: 500, cuerpo: 'boom'),
      addTearDown,
    );

    await _pinta(tester);

    expect(
      find.text('El servicio respondió HTTP 500 al consultar /github.'),
      findsOneWidget,
    );
  });

  testWidgets('sin servicio local se dice eso, no un error genérico', (tester) async {
    HttpFalso.instala(
      (_) async => throw const SocketException('connection refused'),
      addTearDown,
    );

    await _pinta(tester);

    expect(find.text('El servicio local no está disponible.'), findsOneWidget);
    expect(find.text('No hay ramas devueltas por GET /github.'), findsOneWidget);
  });

  testWidgets('una respuesta que no es un objeto JSON se explica', (tester) async {
    HttpFalso.instala(
      (_) async => const RespuestaFalsa(codigo: 200, cuerpo: '[1, 2, 3]'),
      addTearDown,
    );

    await _pinta(tester);

    expect(
      find.textContaining('no tiene el formato esperado: respuesta no es un objeto JSON'),
      findsOneWidget,
    );
  });

  testWidgets('se pide al puerto del servicio local, no a GitHub', (tester) async {
    final falso = HttpFalso.conJson(_respuesta, addTearDown);

    await _pinta(tester);

    expect(falso.pedidas, hasLength(1));
    expect(falso.pedidas.single.host, '127.0.0.1');
    expect(falso.pedidas.single.port, ConfigDuo.desdeEntorno.puerto);
    expect(falso.pedidas.single.path, '/github');
  });

  testWidgets('Actualizar vuelve a preguntar y recoge lo nuevo', (tester) async {
    var primera = true;
    final falso = HttpFalso.instala((_) async {
      if (primera) {
        primera = false;
        return const RespuestaFalsa(codigo: 503, cuerpo: '');
      }
      return const RespuestaFalsa(
        codigo: 200,
        cuerpo: '{"branches":[{"name":"cc/t-015-tests","agent":"cc"}],"pullRequests":[]}',
      );
    }, addTearDown);

    await _pinta(tester);
    expect(find.text('El servicio respondió HTTP 503 al consultar /github.'), findsOneWidget);

    await tester.tap(find.text('Actualizar'));
    await tester.pumpAndSettle();

    expect(falso.pedidas, hasLength(2));
    expect(find.text('cc/t-015-tests'), findsOneWidget);
    expect(find.textContaining('HTTP 503'), findsNothing);
  });

  testWidgets('en una ventana estrecha los dos paneles se apilan sin romperse', (
    tester,
  ) async {
    HttpFalso.conJson(_respuesta, addTearDown);

    // `pumpWidget` ya fallaría con un desborde de layout.
    await _pinta(tester, tamano: const Size(820, 1200));

    expect(find.text('RAMAS POR AGENTE'), findsOneWidget);
    expect(find.text('PULL REQUESTS'), findsOneWidget);
  });
}
