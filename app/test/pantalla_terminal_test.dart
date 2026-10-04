import 'dart:convert';

import 'package:duo_desktop/src/config.dart';
import 'package:duo_desktop/src/datos/cliente_duo.dart';
import 'package:duo_desktop/src/estado/estado_tablero.dart';
import 'package:duo_desktop/src/modelos/evento_duo.dart';
import 'package:duo_desktop/src/pantallas/pantalla_terminal.dart';
import 'package:duo_desktop/src/tema/tema.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

const _config = ConfigDuo(puerto: 5132, token: 'secreto');

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

Future<void> _pinta(
  WidgetTester tester, {
  required EstadoTablero estado,
  Size tamano = const Size(1600, 1200),
  ThemeData? tema,
}) async {
  tester.view.physicalSize = tamano;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  addTearDown(estado.dispose);

  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: estado,
      child: MaterialApp(
        theme: tema ?? TemaDuo.oscuro(),
        home: const Scaffold(body: PantallaTerminal()),
      ),
    ),
  );
}

void main() {
  testWidgets(
    'muestra salida en vivo y reconexión cuando /events no está conectado',
    (tester) async {
      final estado = await _estadoCon(
        jsonEncode({
          'board': {'tasks': []},
          'ledger': {'agents': []},
        }),
      );

      await _pinta(tester, estado: estado);

      expect(find.text('Salida en vivo'), findsOneWidget);
      expect(find.text('RECONECTANDO'), findsOneWidget);
    expect(find.text('SALIDA DE AGENTES'), findsOneWidget);
      expect(find.text('0 bloque(s)'), findsOneWidget);
      expect(
        find.textContaining('Esperando reconexión con /events'),
        findsOneWidget,
      );
      expect(find.textContaining('Fase 5'), findsOneWidget);
    },
  );

  testWidgets('muestra taskId, agente y texto de la salida recibida', (
    tester,
  ) async {
    final estado = await _estadoCon(
      jsonEncode({
        'board': {'tasks': []},
        'ledger': {'agents': []},
      }),
    );
    estado
      ..eventosConectados = true
      ..salidas.add(
        SalidaAgente(
          tareaId: 'T-031',
          agente: 'codex',
          texto: 'La sesión terminó correctamente.',
          recibida: DateTime(2026),
        ),
      );

    await _pinta(tester, estado: estado);

    expect(find.text('EN VIVO'), findsOneWidget);
    expect(find.text('1 bloque(s)'), findsOneWidget);
    expect(find.text('[codex]'), findsOneWidget);
    expect(find.text('T-031'), findsOneWidget);
    expect(find.text('La sesión terminó correctamente.'), findsOneWidget);
  });

  testWidgets('limpiar salida no altera el tablero', (tester) async {
    final estado = await _estadoCon(
      jsonEncode({
        'board': {'tasks': []},
        'ledger': {'agents': []},
      }),
    );
    final tableroInicial = estado.tablero;
    estado.salidas.add(
      SalidaAgente(
        tareaId: 'T-032',
        agente: 'claude',
        texto: 'Salida temporal.',
        recibida: DateTime(2026),
      ),
    );

    await _pinta(tester, estado: estado);
    await tester.tap(find.text('Limpiar'));
    await tester.pump();

    expect(estado.salidas, isEmpty);
    expect(identical(estado.tablero, tableroInicial), isTrue);
  });

  testWidgets('en una ventana estrecha y clara no desborda', (tester) async {
    final estado = await _estadoCon(
      jsonEncode({
        'board': {'tasks': []},
        'ledger': {'agents': []},
      }),
    );

    await _pinta(
      tester,
      estado: estado,
      tamano: const Size(760, 900),
      tema: TemaDuo.claro(),
    );

    expect(find.text('Salida en vivo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
