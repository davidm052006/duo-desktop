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

/// Las peticiones que la pantalla hizo a `/questions`, para comprobar qué
/// manda y a dónde.
class _Espia {
  final List<http.Request> peticiones = [];
}

Widget _app(
  EstadoTablero estado, {
  required Future<http.Response> Function(http.Request) responde,
  _Espia? espia,
}) => ChangeNotifierProvider.value(
  value: estado,
  child: MaterialApp(
    theme: TemaDuo.oscuro(),
    home: PantallaPreguntas(
      config: _config,
      transporte: MockClient((peticion) {
        espia?.peticiones.add(peticion);
        return responde(peticion);
      }),
    ),
  ),
);

/// `GET /questions` no está montado en el servicio: ASP.NET contesta 404 sin
/// cuerpo de error.
Future<http.Response> _sinEndpoint(http.Request _) async =>
    http.Response('', 404);

Map<String, dynamic> _tablero(List<Map<String, dynamic>> tareas) => {
  'board': {'tasks': tareas},
  'ledger': {'agents': []},
};

final _tareaEsperando = {
  'id': 'T-008',
  'title': 'decidir el nombre de la vista',
  'owner': 'codex',
  'branch': 'codex/t-008',
  'status': 'esperando',
  'opened': '2026-10-01',
};

void main() {
  testWidgets('muestra el texto real que entrega GET /questions', (
    tester,
  ) async {
    final estado = await _estadoCon(_tablero([_tareaEsperando]));

    await tester.pumpWidget(
      _app(
        estado,
        responde: (_) async => http.Response(
          jsonEncode({
            'questions': [
              {
                'id': 'T-008',
                'text': '¿La vista se llama Preguntas o Bandeja?',
                'owner': 'codex',
                'opened': '2026-10-01',
                'status': 'esperando',
                'options': ['Preguntas', 'Bandeja'],
              },
            ],
          }),
          200,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('T-008'), findsOneWidget);
    expect(find.text('¿La vista se llama Preguntas o Bandeja?'), findsOneWidget);
    expect(find.text('· Bandeja'), findsOneWidget);
    expect(find.text('1 PREGUNTA PENDIENTE'), findsOneWidget);
    // El título de la tarea sale de /board, no de la pregunta: aquí no aparece.
    expect(find.text('decidir el nombre de la vista'), findsNothing);
  });

  testWidgets('acepta la lista en la raíz y descarta lo que no tiene id', (
    tester,
  ) async {
    final estado = await _estadoCon(_tablero([]));

    await tester.pumpWidget(
      _app(
        estado,
        responde: (_) async => http.Response(
          jsonEncode([
            {'id': 'T-009', 'question': 'tengo dos opciones, ¿cuál?'},
            {'text': 'una pregunta sin identificador'},
          ]),
          200,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1 PREGUNTA PENDIENTE'), findsOneWidget);
    expect(find.text('tengo dos opciones, ¿cuál?'), findsOneWidget);
    expect(find.text('una pregunta sin identificador'), findsNothing);
  });

  testWidgets('sin GET /questions degrada a las tareas esperando de /board', (
    tester,
  ) async {
    final estado = await _estadoCon(
      _tablero([
        _tareaEsperando,
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

    await tester.pumpWidget(_app(estado, responde: _sinEndpoint));
    await tester.pumpAndSettle();

    expect(find.text('T-008'), findsOneWidget);
    expect(find.text('decidir el nombre de la vista'), findsOneWidget);
    expect(find.text('codex'), findsOneWidget);
    expect(
      find.text('El texto de la pregunta no viene en /board.'),
      findsOneWidget,
    );
    expect(
      find.textContaining('GET /questions todavía no existe'),
      findsOneWidget,
    );
    expect(find.text('una tarea que sigue abierta'), findsNothing);
  });

  testWidgets('sin preguntas ni tareas esperando muestra el estado vacío', (
    tester,
  ) async {
    final estado = await _estadoCon(_tablero([]));

    await tester.pumpWidget(_app(estado, responde: _sinEndpoint));
    await tester.pumpAndSettle();

    expect(find.text('SIN PREGUNTAS PENDIENTES'), findsOneWidget);
    expect(
      find.text('Ningún agente está esperando una respuesta.'),
      findsOneWidget,
    );
  });

  testWidgets('un fallo de /questions se dice con su código y no borra /board', (
    tester,
  ) async {
    final estado = await _estadoCon(_tablero([_tareaEsperando]));

    await tester.pumpWidget(
      _app(
        estado,
        responde: (_) async => http.Response(
          jsonEncode({
            'error': {'code': 'unauthorized', 'message': 'Token inválido.'},
          }),
          401,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('unauthorized'), findsOneWidget);
    expect(find.textContaining('Token inválido.'), findsOneWidget);
    // Degrada, no rompe: la tarea esperando sigue en pantalla.
    expect(find.text('T-008'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
  });

  testWidgets('responder envía POST /questions/{id}/answer con el texto', (
    tester,
  ) async {
    final estado = await _estadoCon(_tablero([_tareaEsperando]));
    final espia = _Espia();

    await tester.pumpWidget(
      _app(
        estado,
        espia: espia,
        responde: (peticion) async => peticion.method == 'POST'
            ? http.Response('', 200)
            : http.Response('', 404),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Responder'));
    await tester.pumpAndSettle();

    expect(find.text('Responder a T-008'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), 'Llámala Preguntas');
    await tester.tap(find.text('Enviar respuesta'));
    await tester.pumpAndSettle();

    final enviada = espia.peticiones.singleWhere((p) => p.method == 'POST');
    expect(enviada.url.path, '/questions/T-008/answer');
    expect(jsonDecode(enviada.body), {'text': 'Llámala Preguntas'});
    expect(enviada.headers['Authorization'], 'Bearer secreto');

    // El diálogo se cierra y se avisa de que la respuesta salió.
    expect(find.text('Responder a T-008'), findsNothing);
    expect(find.text('Respuesta enviada a T-008.'), findsOneWidget);
  });

  testWidgets('una respuesta vacía no sale a la red', (tester) async {
    final estado = await _estadoCon(_tablero([_tareaEsperando]));
    final espia = _Espia();

    await tester.pumpWidget(
      _app(estado, espia: espia, responde: _sinEndpoint),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Responder'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enviar respuesta'));
    await tester.pumpAndSettle();

    expect(
      find.text('Escribe la respuesta: el servicio rechaza una vacía.'),
      findsOneWidget,
    );
    expect(espia.peticiones.where((p) => p.method == 'POST'), isEmpty);
    expect(find.text('Responder a T-008'), findsOneWidget);
  });

  testWidgets('si el POST falla, el diálogo se queda con el error y el texto', (
    tester,
  ) async {
    final estado = await _estadoCon(_tablero([_tareaEsperando]));

    await tester.pumpWidget(
      _app(
        estado,
        responde: (peticion) async => peticion.method == 'POST'
            ? http.Response(
                jsonEncode({
                  'error': {
                    'code': 'duo_command_failed',
                    'message': 'No se pudo enviar la respuesta al agente.',
                  },
                }),
                500,
              )
            : http.Response('', 404),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Responder'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'sigue con la opción A');
    await tester.tap(find.text('Enviar respuesta'));
    await tester.pumpAndSettle();

    expect(find.text('duo_command_failed'), findsOneWidget);
    expect(
      find.text('No se pudo enviar la respuesta al agente.'),
      findsOneWidget,
    );
    // No se pierde lo escrito ni se cierra el diálogo.
    expect(find.text('sigue con la opción A'), findsOneWidget);
    expect(find.text('Enviar respuesta'), findsOneWidget);
  });
}
