import 'dart:convert';

import 'package:duo_desktop/src/config.dart';
import 'package:duo_desktop/src/datos/cliente_duo.dart';
import 'package:duo_desktop/src/estado/estado_tablero.dart';
import 'package:duo_desktop/src/pantallas/marco_app.dart';
import 'package:duo_desktop/src/tema/tema.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

const _config = ConfigDuo(puerto: 5132, token: 'secreto');

final _json = jsonEncode({
  'project': {'name': 'duo-desktop', 'repo': '/home/david/dev/duo-desktop', 'board': '/pizarra'},
  'board': {
    'tasks': [
      {
        'id': 'T-006',
        'title': 'primera vista: inicio',
        'owner': 'cc',
        'branch': 'cc/t-006-inicio',
        'status': 'abierta',
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

/// Una ventana de escritorio de verdad: el centro de control reparte por ancho.
Future<void> _pinta(WidgetTester tester, EstadoTablero estado) async {
  tester.view.physicalSize = const Size(1600, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: estado,
      child: MaterialApp(theme: TemaDuo.oscuro(), home: const MarcoApp()),
    ),
  );
}

void main() {
  testWidgets('Inicio es lo primero que se ve', (tester) async {
    await _pinta(tester, await _estadoCon(_json));

    expect(find.text('Centro de control'), findsOneWidget);
    expect(find.text('DUO-DESKTOP'), findsOneWidget);
    // La ruta sale dos veces a propósito: en la barra de marca (qué repo tiene
    // abierto la app) y bajo el título (de dónde salen estos datos).
    expect(find.text('/home/david/dev/duo-desktop'), findsNWidgets(2));
  });

  testWidgets('el estado de cada agente sale del tablero', (tester) async {
    await _pinta(tester, await _estadoCon(_json));

    // cc tiene una tarea abierta; codex está parado por una pregunta; chat no
    // tiene nada vivo (su única tarea está integrada).
    expect(find.text('trabajando'), findsWidgets);
    expect(find.text('esperando decisión'), findsWidgets);
    expect(find.text('disponible'), findsWidgets);
    expect(find.text('Ninguna tarea activa'), findsOneWidget);
  });

  testWidgets('las preguntas pendientes se cuentan y se atribuyen', (tester) async {
    await _pinta(tester, await _estadoCon(_json));

    expect(find.text('1 pendiente(s)'), findsWidgets);
    expect(find.text('migración de la tabla de sesiones'), findsWidgets);
  });

  testWidgets('la carga dice que cuenta tareas y nada más', (tester) async {
    await _pinta(tester, await _estadoCon(_json));

    expect(find.textContaining('sin estimación de recursos ni de tokens'), findsOneWidget);
    expect(find.textContaining('tareas sin cerrar (total: 2)'), findsOneWidget);
  });

  testWidgets('el botón de nueva tarea abre el formulario', (tester) async {
    await _pinta(tester, await _estadoCon(_json));

    // Dejó de estar marcado como pendiente cuando T-016 lo implementó.
    expect(find.text('Nueva tarea · Fase 2'), findsNothing);

    await tester.tap(find.textContaining('Nueva tarea').first);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(Dialog), findsOneWidget);
  });

  testWidgets('todos los destinos del menú se pueden abrir', (tester) async {
    await _pinta(tester, await _estadoCon(_json));

    // Ya no queda ninguna sección por construir: si alguien añade un destino
    // nuevo sin su pantalla, este test lo caza.
    for (final d in [...destinosTrabajo, ...destinosPreferencias]) {
      expect(d.listo, isTrue, reason: '${d.nombre} sigue marcado con fase');
    }
  });

  testWidgets('el Tablero sigue siendo navegable desde la barra lateral', (tester) async {
    await _pinta(tester, await _estadoCon(_json));

    await tester.tap(find.text('Tablero'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Centro de control'), findsNothing);
    expect(find.text('contrato de la API'), findsWidgets);
  });

  testWidgets('sin servicio se ve el fallo, no un centro de control vacío', (tester) async {
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
    expect(find.text('Servicio local sin responder'), findsOneWidget);
  });

  testWidgets('board_not_found se convierte en configuración inicial', (tester) async {
    final estado = await _estadoCon(
      jsonEncode({
        'error': {
          'code': 'board_not_found',
          'message': 'No se encontró una pizarra de duo en el proyecto activo.',
        },
      }),
      codigo: 404,
    );

    expect(estado.sinProyectoLocal, isTrue);
    expect(estado.servicioLocalResponde, isTrue);

    await _pinta(tester, estado);

    expect(find.text('Duo está listo'), findsOneWidget);
    expect(
      find.textContaining('Todavía no has vinculado un proyecto local'),
      findsOneWidget,
    );
    expect(find.text('Ir a Proyectos'), findsOneWidget);
    expect(find.text('board_not_found'), findsNothing);
    expect(
      find.text('Servicio conectado · configura un proyecto'),
      findsOneWidget,
    );
  });

  testWidgets('un tablero vacío se muestra a cero, sin inventar carga', (tester) async {
    await _pinta(
      tester,
      await _estadoCon(
        jsonEncode({
          'board': {'tasks': []},
          'ledger': {'agents': []},
        }),
      ),
    );

    expect(find.text('Nadie tiene trabajo abierto.'), findsOneWidget);
    expect(find.text('El tablero está vacío.'), findsOneWidget);
  });
}
