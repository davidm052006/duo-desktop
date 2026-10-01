import 'dart:convert';

import 'package:duo_desktop/src/config.dart';
import 'package:duo_desktop/src/datos/cliente_duo.dart';
import 'package:duo_desktop/src/estado/estado_tablero.dart';
import 'package:duo_desktop/src/pantallas/pantalla_agentes.dart';
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
        'id': 'T-007',
        'title': 'andamiaje de las vistas',
        'owner': 'cc',
        'branch': 'cc/t-007-andamiaje',
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
        'opened': '2026-09-28',
      },
    ],
  },
  'ledger': {
    'agents': [
      {'agent': 'chat', 'points': 2, 'tasks': 2, 'last': '2026-09-30'},
      {'agent': 'codex', 'points': 1, 'tasks': 1, 'last': '2026-09-28'},
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

/// Alto de sobra: las fichas se apilan y el test no debería pelearse con el
/// desplazamiento para ver la última.
Future<void> _pinta(WidgetTester tester, EstadoTablero estado) async {
  tester.view.physicalSize = const Size(1600, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: estado,
      child: MaterialApp(theme: TemaDuo.oscuro(), home: const Scaffold(body: PantallaAgentes())),
    ),
  );
}

void main() {
  testWidgets('una ficha por agente, con su nombre y su alias', (tester) async {
    await _pinta(tester, await _estadoCon(_json));

    expect(find.text('Agentes'), findsOneWidget);
    expect(find.text('Claude Code'), findsOneWidget);
    expect(find.text('Codex CLI'), findsOneWidget);
    expect(find.text('ChatGPT'), findsOneWidget);
    expect(find.text('alias: cc'), findsOneWidget);
    expect(find.text('alias: codex'), findsOneWidget);
    expect(find.text('alias: chat'), findsOneWidget);
  });

  testWidgets('la carga sale del tablero y el acumulado del ledger', (tester) async {
    await _pinta(tester, await _estadoCon(_json));

    // Tres tareas vivas en total: dos de cc, una de codex, ninguna de chat.
    expect(find.text('2 tarea(s) sin cerrar · 67% del total'), findsOneWidget);
    expect(find.text('1 tarea(s) sin cerrar · 33% del total'), findsOneWidget);
    expect(find.text('0 tarea(s) sin cerrar · 0% del total'), findsOneWidget);

    expect(
      find.text('Acumulado en el ledger: 2 pts · 2 tarea(s) contabilizada(s).'),
      findsOneWidget,
    );
    expect(
      find.text('Acumulado en el ledger: 0 pts · 0 tarea(s) contabilizada(s).'),
      findsOneWidget,
    );
  });

  testWidgets('la última actividad es la fecha del ledger, y se dice', (tester) async {
    await _pinta(tester, await _estadoCon(_json));

    expect(find.text('2026-09-30'), findsOneWidget);
    expect(find.text('2026-09-28'), findsOneWidget);
    // El agente sin nada contabilizado lo dice con palabras.
    expect(find.text('sin actividad registrada'), findsOneWidget);
    expect(find.textContaining('no su último evento en disco'), findsNWidgets(3));
  });

  testWidgets('cada ficha lista todas sus tareas abiertas, no sólo una', (tester) async {
    await _pinta(tester, await _estadoCon(_json));

    expect(find.text('vistas de tareas y agentes'), findsOneWidget);
    expect(find.text('andamiaje de las vistas'), findsOneWidget);
    expect(find.text('migración de la tabla de sesiones'), findsOneWidget);
    // La tarea de chat está integrada: no es trabajo abierto.
    expect(find.text('contrato de la API'), findsNothing);
    expect(find.text('Ninguna tarea activa'), findsOneWidget);
  });

  testWidgets('el estado de cada agente se escribe, no sólo se colorea', (tester) async {
    await _pinta(tester, await _estadoCon(_json));

    expect(find.text('trabajando'), findsOneWidget);
    expect(find.text('esperando decisión'), findsOneWidget);
    expect(find.text('disponible'), findsOneWidget);
  });

  testWidgets('un dueño que no está en el ledger sale igual, y se avisa', (tester) async {
    await _pinta(
      tester,
      await _estadoCon(
        jsonEncode({
          'board': {
            'tasks': [
              {
                'id': 'T-010',
                'title': 'tarea de un agente nuevo',
                'owner': 'nuevo',
                'branch': 'nuevo/t-010',
                'status': 'abierta',
                'opened': '2026-10-01',
              },
            ],
          },
          'ledger': {'agents': []},
        }),
      ),
    );

    // Alias desconocido: se muestra tal cual, sin inventarle un nombre humano.
    expect(find.text('nuevo'), findsOneWidget);
    expect(find.text('fuera del ledger'), findsOneWidget);
    expect(find.text('Sin acumulado: no figura en ledger.agents.'), findsOneWidget);
  });

  testWidgets('un tablero vacío se dice, no se inventa', (tester) async {
    await _pinta(
      tester,
      await _estadoCon(
        jsonEncode({
          'board': {'tasks': []},
          'ledger': {'agents': []},
        }),
      ),
    );

    expect(
      find.text('El ledger está vacío y ninguna tarea tiene dueño.'),
      findsOneWidget,
    );
  });

  testWidgets('sin servicio se ve el fallo, no fichas vacías', (tester) async {
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
}
