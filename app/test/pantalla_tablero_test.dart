import 'dart:convert';
import 'dart:io';

import 'package:duo_desktop/src/config.dart';
import 'package:duo_desktop/src/datos/cliente_duo.dart';
import 'package:duo_desktop/src/estado/estado_tablero.dart';
import 'package:duo_desktop/src/pantallas/pantalla_tablero.dart';
import 'package:duo_desktop/src/tema/tema.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

const _config = ConfigDuo(puerto: 5132, token: 'secreto');

final _tablero = jsonEncode({
  'project': {'name': 'duo-desktop', 'repo': '/repo', 'board': '/pizarra'},
  'board': {
    'tasks': [
      {
        'id': 'T-005',
        'title': 'informe de avance',
        'owner': 'cc',
        'branch': 'cc/t-005-informe',
        'status': 'abierta',
        'opened': '2026-09-30',
      },
      {
        'id': 'T-002',
        'title': 'contrato de la API',
        'owner': 'chat',
        'branch': 'chat/t-002-contrato',
        'status': 'entregada',
        'opened': '2026-09-30',
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

/// El estado listo para pintar, sin sondeo: un `Timer.periodic` dejaría el test
/// con relojes pendientes.
Future<EstadoTablero> _estadoCon(
  Future<http.Response> Function(http.Request) responde,
) async {
  final estado = EstadoTablero(
    cliente: ClienteDuo(config: _config, transporte: MockClient(responde)),
  );
  await estado.refresca();
  return estado;
}

Widget _app(EstadoTablero estado) => ChangeNotifierProvider.value(
  value: estado,
  child: MaterialApp(theme: TemaDuo.claro(), home: const PantallaTablero()),
);

void main() {
  testWidgets('pinta las tareas en el orden del tablero', (tester) async {
    final estado = await _estadoCon((_) async => http.Response(_tablero, 200));
    await tester.pumpWidget(_app(estado));

    expect(find.text('T-005'), findsOneWidget);
    expect(find.text('informe de avance'), findsOneWidget);
    expect(find.text('T-002'), findsOneWidget);

    double posY(String t) => tester.getTopLeft(find.text(t)).dy;
    expect(posY('T-005'), lessThan(posY('T-002')));
  });

  testWidgets('cada estado se nombra, no solo se colorea', (tester) async {
    final estado = await _estadoCon((_) async => http.Response(_tablero, 200));
    await tester.pumpWidget(_app(estado));

    expect(find.text('abierta'), findsOneWidget);
    expect(find.text('entregada'), findsOneWidget);
  });

  testWidgets('organiza las tareas en las cuatro columnas del Kanban', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final estado = await _estadoCon((_) async => http.Response(_tablero, 200));
    await tester.pumpWidget(_app(estado));

    expect(find.text('EN ESPERA'), findsOneWidget);
    expect(find.text('EN PROGRESO'), findsOneWidget);
    expect(find.text('NECESITA DECISIÓN'), findsOneWidget);
    expect(find.text('FINALIZADAS'), findsOneWidget);
    expect(find.text('INSPECTOR DE TAREA'), findsOneWidget);
  });

  testWidgets('cada barra de carga lleva su cifra escrita al lado', (
    tester,
  ) async {
    final estado = await _estadoCon((_) async => http.Response(_tablero, 200));
    await tester.pumpWidget(_app(estado));

    expect(find.text('2 pts · 2 tareas'), findsOneWidget);
    expect(find.text('1 pts · 1 tarea'), findsOneWidget);
    expect(find.text('0 pts · 0 tareas'), findsOneWidget);
    // El agente sin actividad lo dice con palabras, no con una barra a cero.
    expect(find.text('sin actividad'), findsOneWidget);
  });

  testWidgets('un tablero vacío no es un error', (tester) async {
    final estado = await _estadoCon(
      (_) async => http.Response(
        jsonEncode({
          'board': {'tasks': []},
          'ledger': {'agents': []},
        }),
        200,
      ),
    );
    await tester.pumpWidget(_app(estado));

    expect(find.text('No hay tareas abiertas.'), findsOneWidget);
  });

  testWidgets('el 401 explica que el token no cuadra', (tester) async {
    final estado = await _estadoCon(
      (_) async => http.Response(
        jsonEncode({
          'error': {
            'code': 'unauthorized',
            'message': 'Token local ausente o inválido.',
          },
        }),
        401,
      ),
    );
    await tester.pumpWidget(_app(estado));

    expect(find.text('unauthorized'), findsOneWidget);
    expect(find.textContaining('scripts/dev.fish'), findsOneWidget);
  });

  testWidgets('un fallo tras haber cargado no borra lo que ya se veía', (
    tester,
  ) async {
    var falla = false;
    final estado = EstadoTablero(
      cliente: ClienteDuo(
        config: _config,
        transporte: MockClient((_) async {
          if (falla) throw const SocketException('se cayó');
          return http.Response(_tablero, 200);
        }),
      ),
    );

    await estado.refresca();
    await tester.pumpWidget(_app(estado));
    expect(find.text('T-005'), findsOneWidget);

    falla = true;
    await estado.refresca();
    await tester.pump();

    expect(
      find.text('T-005'),
      findsOneWidget,
      reason: 'los datos siguen en pantalla',
    );
    expect(
      find.text('sin conexión'),
      findsOneWidget,
      reason: 'pero avisados de que están viejos',
    );
  });
}
