import 'dart:convert';

import 'package:duo_desktop/src/config.dart';
import 'package:duo_desktop/src/datos/cliente_duo.dart';
import 'package:duo_desktop/src/estado/estado_tablero.dart';
import 'package:duo_desktop/src/pantallas/pantalla_terminal.dart';
import 'package:duo_desktop/src/tema/paleta.dart';
import 'package:duo_desktop/src/tema/tema.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

const _config = ConfigDuo(puerto: 5132, token: 'secreto');

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

/// Una ventana de escritorio de verdad: la consola ocupa alto fijo.
Future<void> _pinta(
  WidgetTester tester, {
  EstadoTablero? estado,
  Size tamano = const Size(1600, 1200),
  ThemeData? tema,
}) async {
  tester.view.physicalSize = tamano;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final pantalla = MaterialApp(
    theme: tema ?? TemaDuo.oscuro(),
    home: const Scaffold(body: PantallaTerminal()),
  );

  // Terminal no lee el tablero, pero se pinta dentro de la app igual que el
  // resto: el proveedor se monta cuando el test quiere comprobarlo.
  await tester.pumpWidget(
    estado == null
        ? pantalla
        : ChangeNotifierProvider.value(value: estado, child: pantalla),
  );
}

void main() {
  testWidgets('la consola dice que es una demo, no una sesión real', (tester) async {
    await _pinta(tester);

    expect(find.text('Terminal'), findsOneWidget);
    expect(find.text('DEMO'), findsOneWidget);
    expect(find.text('ejemplo'), findsOneWidget);
    expect(find.text('Fase 5'), findsOneWidget);
    expect(find.textContaining('no una sesión real'), findsOneWidget);
    expect(find.textContaining('PTY y streaming en vivo llegan en la Fase 5'), findsOneWidget);
  });

  testWidgets('la salida de ejemplo se pinta entera, línea a línea', (tester) async {
    await _pinta(tester);

    expect(find.text('SALIDA DE AGENTES'), findsOneWidget);
    expect(find.text('Leyendo el brief de la tarea…'), findsOneWidget);
    expect(find.text(r'$ dotnet test --no-restore'), findsOneWidget);
    expect(find.text('Passed! 26 tests completados.'), findsOneWidget);
    expect(
      find.text('Revisando cambios multiarchivo y estado del worktree…'),
      findsOneWidget,
    );
    expect(find.text('Entregable preparado para revisión cruzada.'), findsOneWidget);
  });

  testWidgets('cada línea lleva escrito de qué agente viene', (tester) async {
    await _pinta(tester);

    // El color de serie es refuerzo: el alias va siempre en texto.
    expect(find.text('[chat]'), findsNWidgets(2));
    expect(find.text('[codex]'), findsNWidgets(2));
    expect(find.text('[cc]'), findsOneWidget);
  });

  testWidgets('el alias usa el color de su agente, no uno cualquiera', (tester) async {
    await _pinta(tester);

    Color colorDe(String alias) =>
        tester.widget<Text>(find.text('[$alias]').first).style!.color!;

    expect(colorDe('chat'), PaletaDatos.oscuro.serieDe('chat'));
    expect(colorDe('codex'), PaletaDatos.oscuro.serieDe('codex'));
    expect(colorDe('cc'), PaletaDatos.oscuro.serieDe('cc'));
    // Tres agentes, tres colores distintos: si alguien recicla un slot, salta.
    expect({colorDe('chat'), colorDe('codex'), colorDe('cc')}, hasLength(3));
  });

  testWidgets('con el servicio caído la consola se pinta igual', (tester) async {
    // Terminal no depende de GET /board: no tiene estado vacío ni fallo propio.
    // Lo que sí hay que garantizar es que un servicio muerto no la deja en
    // blanco, porque es la vista donde se va a mirar qué pasó.
    await _pinta(
      tester,
      estado: await _estadoCon(
        jsonEncode({
          'error': {'code': 'unauthorized', 'message': 'Token local ausente o inválido.'},
        }),
        codigo: 401,
      ),
    );

    expect(find.text('Terminal'), findsOneWidget);
    expect(find.text('Leyendo el brief de la tarea…'), findsOneWidget);
    expect(find.text('unauthorized'), findsNothing);
  });

  testWidgets('con tablero vacío tampoco cambia: las líneas no salen de ahí', (tester) async {
    await _pinta(
      tester,
      estado: await _estadoCon(
        jsonEncode({
          'board': {'tasks': []},
          'ledger': {'agents': []},
        }),
      ),
    );

    expect(find.text('Passed! 26 tests completados.'), findsOneWidget);
  });

  testWidgets('en una ventana estrecha y en claro no desborda', (tester) async {
    // `pumpWidget` ya fallaría con un desborde de layout; aquí basta con que
    // siga estando la consola después de apretar el ancho.
    await _pinta(tester, tamano: const Size(760, 900), tema: TemaDuo.claro());

    expect(find.text('Terminal'), findsOneWidget);
    expect(find.text('SALIDA DE AGENTES'), findsOneWidget);
  });
}
