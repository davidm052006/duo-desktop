import 'dart:convert';

import 'package:duo_desktop/src/config.dart';
import 'package:duo_desktop/src/datos/cliente_duo.dart';
import 'package:duo_desktop/src/estado/estado_tablero.dart';
import 'package:duo_desktop/src/modelos/tablero.dart';
import 'package:duo_desktop/src/pantallas/pantalla_visualizaciones.dart';
import 'package:duo_desktop/src/tema/tema.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

const _config = ConfigDuo(puerto: 5132, token: 'secreto');

/// Un tablero con las tres situaciones que las gráficas tienen que distinguir:
/// un agente con tarea viva, uno con entrega pendiente de revisión, y uno con
/// trabajo ya integrado. Dos días distintos, para que la línea tenga pendiente.
final _json = jsonEncode({
  'project': {'name': 'duo-desktop', 'repo': '/home/david/dev/duo-desktop', 'board': '/pizarra'},
  'board': {
    'tasks': [
      {
        'id': 'T-012',
        'title': 'visualizaciones',
        'owner': 'cc',
        'branch': 'cc/t-012-visualizaciones',
        'status': 'abierta',
        'opened': '2026-10-01',
      },
      {
        'id': 'T-009',
        'title': 'pantalla de preguntas',
        'owner': 'cc',
        'branch': 'cc/t-009-preguntas',
        'status': 'entregada',
        'opened': '2026-09-30',
      },
      {
        'id': 'T-004',
        'title': 'migración de la tabla de sesiones',
        'owner': 'codex',
        'branch': 'codex/t-004-sesiones',
        'status': 'esperando',
        'opened': '2026-09-29',
      },
      {
        'id': 'T-002',
        'title': 'contrato de la API',
        'owner': 'chat',
        'branch': 'chat/t-002-contrato',
        'status': 'integrada',
        'opened': '2026-09-29',
      },
    ],
  },
  'ledger': {
    'agents': [
      {'agent': 'chat', 'points': 2, 'tasks': 2, 'last': '2026-09-30'},
      {'agent': 'codex', 'points': 1, 'tasks': 1, 'last': '2026-09-30'},
      {'agent': 'cc', 'points': 0, 'tasks': 0, 'last': null},
    ],
  },
});

/// Sin sondeo: un `Timer.periodic` dejaría relojes pendientes al acabar.
Future<EstadoTablero> _estadoCon(String cuerpo, {int codigo = 200}) async {
  final estado = EstadoTablero(
    cliente: ClienteDuo(
      config: _config,
      transporte: MockClient((_) async => http.Response(cuerpo, codigo)),
    ),
  );
  await estado.refresca();
  return estado;
}

/// Una ventana de escritorio de verdad: las gráficas reparten por ancho.
Future<void> _pinta(WidgetTester tester, EstadoTablero estado) async {
  tester.view.physicalSize = const Size(1600, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: estado,
      child: MaterialApp(
        theme: TemaDuo.oscuro(),
        home: const PantallaVisualizaciones(),
      ),
    ),
  );
}

void main() {
  group('lo que se deduce de /board', () {
    DatosGraficas datosDe(String cuerpo) => DatosGraficas.desde(
      Tablero.desdeJson(jsonDecode(cuerpo) as Map<String, dynamic>),
    );

    test('el reparto separa tareas vivas de integradas', () {
      final datos = datosDe(_json);

      // El orden es el del ledger, no el de aparición en el tablero.
      expect([for (final r in datos.reparto) r.alias], ['chat', 'codex', 'cc']);

      final cc = datos.reparto.firstWhere((r) => r.alias == 'cc');
      expect(cc.vivas, 2);
      expect(cc.integradas, 0);

      final chat = datos.reparto.firstWhere((r) => r.alias == 'chat');
      expect(chat.vivas, 0);
      expect(chat.integradas, 1);
      expect(chat.total, 1);
    });

    test('la línea de tiempo rellena los días sin tareas', () {
      final datos = datosDe(_json);

      // Del 29 al 1 hay tres días; el 30 de septiembre no queda fuera aunque
      // solo tenga una tarea.
      expect(datos.dias.length, 3);
      expect([for (final d in datos.dias) d.total], [2, 1, 1]);
      expect(fechaIso(datos.dias.first.fecha), '2026-09-29');
      expect(datos.diasRecortados, 0);
    });

    test('solo cuenta como revisión lo entregado o integrado', () {
      final datos = datosDe(_json);

      // codex está esperando una decisión: no ha entregado nada.
      expect([for (final r in datos.revisiones) r.autor], ['chat', 'cc']);
      expect(datos.revisiones.every((r) => r.revisor == 'David'), isTrue);
      expect(datos.entregadasTotales, 2);
    });

    test('un rango largo se recorta a los días más recientes y lo dice', () {
      final datos = datosDe(
        jsonEncode({
          'board': {
            'tasks': [
              for (var dia = 1; dia <= 30; dia++)
                {
                  'id': 'T-${dia.toString().padLeft(3, '0')}',
                  'title': 'tarea $dia',
                  'owner': 'cc',
                  'branch': 'cc/t-$dia',
                  'status': 'abierta',
                  'opened': '2026-09-${dia.toString().padLeft(2, '0')}',
                },
            ],
          },
          'ledger': {
            'agents': [
              {'agent': 'cc', 'points': 0, 'tasks': 0, 'last': null},
            ],
          },
        }),
      );

      expect(datos.dias.length, DatosGraficas.maximoDias);
      expect(datos.diasRecortados, 30 - DatosGraficas.maximoDias);
      // Se queda el final del rango, no el principio.
      expect(fechaIso(datos.dias.last.fecha), '2026-09-30');
    });

    test('un tablero vacío no inventa series ni fechas', () {
      final datos = datosDe(
        jsonEncode({
          'board': {'tasks': []},
          'ledger': {'agents': []},
        }),
      );

      expect(datos.vacio, isTrue);
      expect(datos.dias, isEmpty);
      expect(datos.revisiones, isEmpty);
    });
  });

  group('la pantalla', () {
    testWidgets('las tres gráficas están, cada una con su título', (tester) async {
      await _pinta(tester, await _estadoCon(_json));

      expect(find.text('Visualizaciones'), findsOneWidget);
      expect(find.text('REPARTO POR AGENTE'), findsOneWidget);
      expect(find.text('TAREAS POR DÍA'), findsOneWidget);
      expect(find.text('QUIÉN REVISÓ A QUIÉN'), findsOneWidget);
    });

    testWidgets('cada gráfica se pinta con su propio CustomPainter', (tester) async {
      await _pinta(tester, await _estadoCon(_json));

      Finder pintor<T extends CustomPainter>() => find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is T,
      );

      expect(pintor<PintorBarras>(), findsOneWidget);
      expect(pintor<PintorLinea>(), findsOneWidget);
      expect(pintor<PintorGrafo>(), findsOneWidget);
    });

    testWidgets('las cifras van en texto, no solo en la altura de la barra', (
      tester,
    ) async {
      await _pinta(tester, await _estadoCon(_json));

      expect(find.text('2 total · 2 viva(s) · 0 integrada(s)'), findsOneWidget);
      expect(find.text('1 total · 0 viva(s) · 1 integrada(s)'), findsOneWidget);
      expect(find.textContaining('Pico: 2 tarea(s) el 2026-09-29'), findsOneWidget);
    });

    testWidgets('el grafo dice que el revisor no sale del tablero', (tester) async {
      await _pinta(tester, await _estadoCon(_json));

      expect(find.text('2 entrega(s)'), findsOneWidget);
      expect(find.textContaining('no el revisor'), findsOneWidget);
      // La atribución agente→agente llega con los PR de GitHub.
      expect(find.text('Fase 4'), findsOneWidget);
      expect(find.text('David'), findsNWidgets(2));
    });

    testWidgets('las gráficas son legibles para un lector de pantalla', (tester) async {
      final handle = tester.ensureSemantics();
      await _pinta(tester, await _estadoCon(_json));

      expect(
        find.bySemanticsLabel(RegExp('cc: 2 tareas, 2 vivas y 0 integradas')),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(RegExp('cc entregó 1 tarea')),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('en una ventana estrecha las gráficas se apilan sin romperse', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(820, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: await _estadoCon(_json),
          child: MaterialApp(
            theme: TemaDuo.claro(),
            home: const PantallaVisualizaciones(),
          ),
        ),
      );

      // `pumpWidget` ya habría fallado con un desborde de layout; aquí solo se
      // comprueba que las tres siguen estando en la columna única.
      expect(find.text('REPARTO POR AGENTE'), findsOneWidget);
      expect(find.text('TAREAS POR DÍA'), findsOneWidget);
      expect(find.text('QUIÉN REVISÓ A QUIÉN'), findsOneWidget);
    });

    testWidgets('un tablero vacío se dice, no se dibuja vacío', (tester) async {
      await _pinta(
        tester,
        await _estadoCon(
          jsonEncode({
            'board': {'tasks': []},
            'ledger': {'agents': []},
          }),
        ),
      );

      expect(find.text('El tablero está vacío: nada que repartir.'), findsOneWidget);
      expect(find.text('Ninguna tarea tiene fecha que situar.'), findsOneWidget);
      expect(
        find.byWidgetPredicate((w) => w is CustomPaint && w.painter is PintorBarras),
        findsNothing,
      );
    });

    testWidgets('sin servicio se ve el fallo, no gráficas a cero', (tester) async {
      await _pinta(
        tester,
        await _estadoCon(
          jsonEncode({
            'error': {'code': 'unauthorized', 'message': 'Token local ausente o inválido.'},
          }),
          codigo: 401,
        ),
      );

      expect(find.text('unauthorized'), findsOneWidget);
      expect(find.text('REPARTO POR AGENTE'), findsNothing);
    });
  });
}
