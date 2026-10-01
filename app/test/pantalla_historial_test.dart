import 'dart:convert';

import 'package:duo_desktop/src/config.dart';
import 'package:duo_desktop/src/datos/cliente_duo.dart';
import 'package:duo_desktop/src/estado/estado_tablero.dart';
import 'package:duo_desktop/src/pantallas/pantalla_historial.dart';
import 'package:duo_desktop/src/tema/tema.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

const _config = ConfigDuo(puerto: 5132, token: 'secreto');

Future<EstadoTablero> _estadoCon(Map<String, dynamic> datos) async {
  final estado = EstadoTablero(
    cliente: ClienteDuo(
      config: _config,
      transporte: MockClient(
        (_) async => http.Response(jsonEncode(datos), 200),
      ),
    ),
  );
  await estado.refresca();
  return estado;
}

Widget _app(EstadoTablero estado) => ChangeNotifierProvider.value(
  value: estado,
  child: MaterialApp(theme: TemaDuo.oscuro(), home: const PantallaHistorial()),
);

Map<String, dynamic> _tablero(List<Map<String, dynamic>> tareas) => {
  'board': {'tasks': tareas},
  'ledger': {'agents': []},
};

void main() {
  testWidgets(
    'agrupa las tareas por fecha de apertura y muestra agente y estado',
    (tester) async {
      final estado = await _estadoCon(
        _tablero([
          {
            'id': 'T-006',
            'title': 'vista de inicio',
            'owner': 'cc',
            'branch': 'cc/t-006',
            'status': 'integrada',
            'opened': '2026-09-30',
          },
          {
            'id': 'T-008',
            'title': 'vistas de preguntas e historial',
            'owner': 'codex',
            'branch': 'codex/t-008',
            'status': 'abierta',
            'opened': '2026-10-01',
          },
        ]),
      );
      await tester.pumpWidget(_app(estado));

      expect(find.text('vistas de preguntas e historial'), findsOneWidget);
      expect(find.text('codex'), findsOneWidget);
      expect(find.text('abierta'), findsOneWidget);
      expect(find.text('vista de inicio'), findsOneWidget);
      expect(find.text('cc'), findsOneWidget);
      expect(find.text('integrada'), findsOneWidget);
      expect(
        find.text(
          'La línea de tiempo usa la fecha de apertura de las tareas en /board. El servicio todavía no entrega eventos ni cambios de estado.',
        ),
        findsOneWidget,
      );

      expect(
        tester.getTopLeft(find.text('2026-10-01')).dy,
        lessThan(tester.getTopLeft(find.text('2026-09-30')).dy),
      );
    },
  );

  testWidgets('sin tareas muestra un estado vacío honesto', (tester) async {
    final estado = await _estadoCon(_tablero([]));
    await tester.pumpWidget(_app(estado));

    expect(find.text('No hay tareas registradas en /board.'), findsOneWidget);
    expect(
      find.text(
        'Los eventos detallados llegarán cuando el servicio los exponga.',
      ),
      findsOneWidget,
    );
  });
}
