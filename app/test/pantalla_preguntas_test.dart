import 'dart:convert';

import 'package:duo_desktop/src/config.dart';
import 'package:duo_desktop/src/datos/cliente_duo.dart';
import 'package:duo_desktop/src/estado/estado_tablero.dart';
import 'package:duo_desktop/src/pantallas/pantalla_preguntas.dart';
import 'package:duo_desktop/src/tema/tema.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

const _config = ConfigDuo(puerto: 5132, token: 'secreto');

Future<EstadoTablero> _estadoCon(
  Map<String, dynamic> datos, {
  int codigo = 200,
}) async {
  final estado = EstadoTablero(
    cliente: ClienteDuo(
      config: _config,
      transporte: MockClient(
        (_) async => http.Response(jsonEncode(datos), codigo),
      ),
    ),
  );
  await estado.refresca();
  return estado;
}

Widget _app(EstadoTablero estado) => ChangeNotifierProvider.value(
  value: estado,
  child: MaterialApp(theme: TemaDuo.oscuro(), home: const PantallaPreguntas()),
);

Map<String, dynamic> _tablero(List<Map<String, dynamic>> tareas) => {
  'board': {'tasks': tareas},
  'ledger': {'agents': []},
};

void main() {
  testWidgets('muestra solo las tareas esperando y no inventa su pregunta', (
    tester,
  ) async {
    final estado = await _estadoCon(
      _tablero([
        {
          'id': 'T-008',
          'title': 'decidir el nombre de la vista',
          'owner': 'codex',
          'branch': 'codex/t-008',
          'status': 'esperando',
          'opened': '2026-10-01',
        },
        {
          'id': 'T-007',
          'title': 'una tarea que sigue abierta',
          'owner': 'chat',
          'branch': 'chat/t-007',
          'status': 'abierta',
          'opened': '2026-10-01',
        },
      ]),
    );

    await tester.pumpWidget(_app(estado));

    expect(find.text('T-008'), findsOneWidget);
    expect(find.text('decidir el nombre de la vista'), findsOneWidget);
    expect(find.text('codex'), findsOneWidget);
    expect(find.text('esperando'), findsOneWidget);
    expect(
      find.text('El texto de la pregunta no viene en /board.'),
      findsOneWidget,
    );
    expect(find.text('una tarea que sigue abierta'), findsNothing);
  });

  testWidgets('Responder revela duo ask sin ejecutar una acción', (
    tester,
  ) async {
    final estado = await _estadoCon(
      _tablero([
        {
          'id': 'T-008',
          'title': 'decidir el nombre de la vista',
          'owner': 'codex',
          'branch': 'codex/t-008',
          'status': 'esperando',
          'opened': '2026-10-01',
        },
      ]),
    );
    await tester.pumpWidget(_app(estado));

    await tester.tap(find.text('Responder'));
    await tester.pumpAndSettle();

    expect(find.text('Responder desde Duo'), findsOneWidget);
    expect(find.text('duo ask'), findsOneWidget);
  });

  testWidgets('sin tareas esperando muestra un estado vacío', (tester) async {
    final estado = await _estadoCon(_tablero([]));
    await tester.pumpWidget(_app(estado));

    expect(find.text('SIN PREGUNTAS PENDIENTES'), findsOneWidget);
    expect(
      find.text('Ningún agente está esperando una respuesta.'),
      findsOneWidget,
    );
  });
}
