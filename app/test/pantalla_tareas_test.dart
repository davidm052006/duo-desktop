import 'dart:convert';

import 'package:duo_desktop/src/config.dart';
import 'package:duo_desktop/src/datos/cliente_duo.dart';
import 'package:duo_desktop/src/estado/estado_tablero.dart';
import 'package:duo_desktop/src/pantallas/marco_app.dart';
import 'package:duo_desktop/src/pantallas/pantalla_tareas.dart';
import 'package:duo_desktop/src/tema/tema.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

const _config = ConfigDuo(puerto: 5132, token: 'secreto');

final _json = jsonEncode({
  'project': {'name': 'duo-desktop', 'repo': '/repo', 'board': '/pizarra'},
  'board': {
    'tasks': [
      {
        'id': 'T-009',
        'title': 'vistas de tareas y agentes',
        'owner': 'cc',
        'branch': 'cc/t-009-vistas',
        'status': 'abierta',
        'opened': '2026-10-01',
      },
      {
        'id': 'T-006',
        'title': 'primera vista: inicio',
        'owner': 'cc',
        'branch': 'cc/t-006-inicio',
        'status': 'integrada',
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
        'status': 'entregada',
        'opened': '2026-09-28',
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

/// Una ventana de escritorio de verdad: la tabla reparte sus columnas por ancho.
Future<void> _pinta(WidgetTester tester, EstadoTablero estado) async {
  tester.view.physicalSize = const Size(1600, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: estado,
      child: MaterialApp(theme: TemaDuo.oscuro(), home: const Scaffold(body: PantallaTareas())),
    ),
  );
}

void main() {
  testWidgets('lista todas las tareas del tablero, también las integradas', (tester) async {
    await _pinta(tester, await _estadoCon(_json));

    expect(find.text('Tareas'), findsOneWidget);
    expect(find.text('vistas de tareas y agentes'), findsOneWidget);
    expect(find.text('primera vista: inicio'), findsOneWidget);
    expect(find.text('migración de la tabla de sesiones'), findsOneWidget);
    expect(find.text('contrato de la API'), findsOneWidget);
    expect(find.text('4 total'), findsOneWidget);
  });

  testWidgets('respeta el orden de la pizarra, no reordena', (tester) async {
    await _pinta(tester, await _estadoCon(_json));

    double y(String t) => tester.getTopLeft(find.text(t)).dy;
    expect(y('T-009'), lessThan(y('T-006')));
    expect(y('T-006'), lessThan(y('T-004')));
    expect(y('T-004'), lessThan(y('T-002')));
  });

  testWidgets('filtrar por agente deja sólo sus tareas', (tester) async {
    await _pinta(tester, await _estadoCon(_json));

    await tester.tap(find.text('codex').first);
    await tester.pumpAndSettle();

    expect(find.text('migración de la tabla de sesiones'), findsOneWidget);
    expect(find.text('vistas de tareas y agentes'), findsNothing);
    expect(find.text('contrato de la API'), findsNothing);
    expect(find.text('1 de 4'), findsOneWidget);
  });

  testWidgets('filtrar por estado deja sólo las tareas en ese estado', (tester) async {
    await _pinta(tester, await _estadoCon(_json));

    await tester.tap(find.text('entregada').first);
    await tester.pumpAndSettle();

    expect(find.text('contrato de la API'), findsOneWidget);
    expect(find.text('vistas de tareas y agentes'), findsNothing);
    expect(find.text('1 de 4'), findsOneWidget);
  });

  testWidgets('los dos filtros se combinan y se pueden quitar', (tester) async {
    await _pinta(tester, await _estadoCon(_json));

    await tester.tap(find.text('cc').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('integrada').first);
    await tester.pumpAndSettle();

    expect(find.text('primera vista: inicio'), findsOneWidget);
    expect(find.text('vistas de tareas y agentes'), findsNothing);
    expect(find.text('1 de 4'), findsOneWidget);

    await tester.tap(find.text('Quitar filtros').first);
    await tester.pumpAndSettle();

    expect(find.text('4 total'), findsOneWidget);
    expect(find.text('vistas de tareas y agentes'), findsOneWidget);
  });

  testWidgets('un cruce sin resultados culpa al filtro, no al tablero', (tester) async {
    await _pinta(tester, await _estadoCon(_json));

    await tester.tap(find.text('chat').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('abierta').first);
    await tester.pumpAndSettle();

    expect(find.text('Ninguna tarea cumple el filtro.'), findsOneWidget);
    // El vacío de `TablaTareas` diría que no hay tareas abiertas, y eso aquí
    // sería mentira: las hay, pero no de este agente.
    expect(find.text('No hay tareas abiertas.'), findsNothing);
    expect(find.text('0 de 4'), findsOneWidget);
  });

  testWidgets('sólo se ofrecen los estados que existen en la pizarra', (tester) async {
    await _pinta(tester, await _estadoCon(_json));

    expect(find.text('abierta'), findsWidgets);
    expect(find.text('esperando'), findsWidgets);
    // Nadie tiene una tarea en un estado que el tablero no contiene: no hay
    // chip para él.
    expect(find.text('desconocido'), findsNothing);
  });

  testWidgets('un tablero vacío no es un error ni un filtro fallido', (tester) async {
    await _pinta(
      tester,
      await _estadoCon(
        jsonEncode({
          'board': {'tasks': []},
          'ledger': {'agents': []},
        }),
      ),
    );

    expect(find.text('No hay tareas abiertas.'), findsOneWidget);
    expect(find.text('0 total'), findsOneWidget);
  });

  testWidgets('sin servicio se ve el fallo, no una tabla vacía', (tester) async {
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
    expect(find.textContaining('scripts/dev.fish'), findsOneWidget);
  });

  // Las dos vistas dejan de ser destinos apagados en la barra lateral: si se
  // implementan pero nadie quita su `fase`, siguen sin poder abrirse.
  testWidgets('Tareas y Agentes se abren desde la barra lateral', (tester) async {
    tester.view.physicalSize = const Size(1600, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: await _estadoCon(_json),
        child: MaterialApp(theme: TemaDuo.oscuro(), home: const MarcoApp()),
      ),
    );

    await tester.tap(find.text('Tareas'));
    await tester.pumpAndSettle();
    expect(find.text('Centro de control'), findsNothing);
    expect(find.text('4 total'), findsOneWidget);

    await tester.tap(find.text('Agentes').first);
    await tester.pumpAndSettle();
    expect(find.text('Claude Code'), findsOneWidget);
    expect(find.text('alias: codex'), findsOneWidget);
  });
}
