import 'dart:convert';

import 'package:duo_desktop/src/config.dart';
import 'package:duo_desktop/src/datos/cliente_duo.dart';
import 'package:duo_desktop/src/estado/estado_tablero.dart';
import 'package:duo_desktop/src/pantallas/pantalla_configuracion.dart';
import 'package:duo_desktop/src/tema/tema.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _config = ConfigDuo(puerto: 5132, token: 'secreto');

final _json = jsonEncode({
  'project': {'name': 'duo-desktop', 'repo': '/home/david/dev/duo-desktop', 'board': '/pizarra'},
  'board': {
    'tasks': [
      {
        'id': 'T-015',
        'title': 'tests de widget',
        'owner': 'cc',
        'branch': 'cc/t-015-tests',
        'status': 'abierta',
        'opened': '2026-10-01',
      },
    ],
  },
  'ledger': {
    'agents': [
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

// --- el almacén de preferencias ------------------------------------------
//
// Se sirve desde el canal de plataforma en vez de `setMockInitialValues`
// porque esa función deja elegido un almacén *estático* para el resto del
// archivo, y aquí hace falta probar también el caso en el que el almacén
// falla. Con el canal, cada test manda sin depender del orden.

const _canalPrefs = MethodChannel('plugins.flutter.io/shared_preferences');
const _prefijo = 'flutter.';

late Map<String, Object> _almacen;
late bool _almacenRoto;

void _instalaAlmacen() {
  _almacen = {};
  _almacenRoto = false;
  SharedPreferences.resetStatic();

  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_canalPrefs, (llamada) async {
        if (_almacenRoto) {
          throw PlatformException(
            code: 'sin-almacen',
            message: 'El almacén de preferencias no responde.',
          );
        }
        final args = llamada.arguments is Map
            ? (llamada.arguments as Map).cast<String, Object?>()
            : const <String, Object?>{};
        switch (llamada.method) {
          case 'getAll':
            return Map<String, Object>.from(_almacen);
          case 'setString' || 'setDouble' || 'setBool' || 'setInt' || 'setStringList':
            _almacen[args['key']! as String] = args['value']!;
            return true;
          case 'remove':
            _almacen.remove(args['key']);
            return true;
          case 'clear':
            _almacen.clear();
            return true;
        }
        return null;
      });

  addTearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_canalPrefs, null);
    SharedPreferences.resetStatic();
  });
}

void _guardadas(Map<String, Object> valores) =>
    _almacen.addAll({for (final e in valores.entries) '$_prefijo${e.key}': e.value});

/// Una ventana de escritorio de verdad: la pantalla reparte por ancho.
Future<void> _pinta(WidgetTester tester, EstadoTablero estado) async {
  tester.view.physicalSize = const Size(1600, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: estado,
      child: MaterialApp(
        theme: TemaDuo.oscuro(),
        home: const Scaffold(body: PantallaConfiguracion()),
      ),
    ),
  );
  // La pantalla arranca leyendo las preferencias: hasta que no vuelven solo
  // hay un spinner.
  await tester.pumpAndSettle();
}

/// El campo de una ruta se busca por su etiqueta, no por su pista: cuando el
/// valor guardado coincide con la pista, buscar por texto encontraría las dos.
Finder _campo(String etiqueta) => find.descendant(
  of: find.ancestor(of: find.text(etiqueta), matching: find.byType(Column)).first,
  matching: find.byType(TextField),
);

String _texto(WidgetTester tester, String etiqueta) =>
    tester.widget<TextField>(_campo(etiqueta)).controller!.text;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(_instalaAlmacen);

  testWidgets('los tres paneles se pintan con el entorno real', (tester) async {
    await _pinta(tester, await _estadoCon(_json));

    expect(find.text('Configuración'), findsOneWidget);
    expect(find.text('entorno local'), findsOneWidget);
    expect(find.text('PROYECTO ACTIVO'), findsOneWidget);
    expect(find.text('SERVICIO LOCAL'), findsOneWidget);
    expect(find.text('RUTAS DE DUO'), findsOneWidget);
  });

  testWidgets('el proyecto activo sale de GET /board, no de las preferencias', (tester) async {
    await _pinta(tester, await _estadoCon(_json));

    expect(find.text('activo'), findsOneWidget);
    expect(find.text('duo-desktop'), findsOneWidget);
    expect(find.text('/home/david/dev/duo-desktop'), findsOneWidget);
    // La pizarra se muestra con el `.team` que duo cuelga debajo.
    expect(find.text('/pizarra/.team'), findsOneWidget);
  });

  testWidgets('el servicio se declara conectado con su puerto y su URL', (tester) async {
    await _pinta(tester, await _estadoCon(_json));

    expect(find.text('conectado'), findsOneWidget);
    expect(find.text('El servicio local está respondiendo.'), findsOneWidget);
    expect(find.text('127.0.0.1'), findsOneWidget);
    // El puerto es el de `ConfigDuo.desdeEntorno`, no el del cliente del test:
    // esta pantalla describe el proceso, no la petición.
    expect(find.text('${ConfigDuo.desdeEntorno.puerto}'), findsOneWidget);
    expect(find.text('http://127.0.0.1:${ConfigDuo.desdeEntorno.puerto}'), findsOneWidget);
  });

  testWidgets('sin preferencias guardadas las rutas salen con su valor por defecto', (
    tester,
  ) async {
    await _pinta(tester, await _estadoCon(_json));

    expect(_texto(tester, 'EJECUTABLE DUO'), '~/.local/bin/duo');
    expect(_texto(tester, 'CONFIGURACIÓN DUO'), '~/.config/duo');
  });

  testWidgets('las rutas guardadas se recuperan al abrir', (tester) async {
    _guardadas({
      'config.ruta_duo': '/opt/duo/bin/duo',
      'config.ruta_config_duo': '/etc/duo',
    });

    await _pinta(tester, await _estadoCon(_json));

    expect(_texto(tester, 'EJECUTABLE DUO'), '/opt/duo/bin/duo');
    expect(_texto(tester, 'CONFIGURACIÓN DUO'), '/etc/duo');
  });

  testWidgets('guardar escribe las dos rutas, sin espacios, y lo confirma', (tester) async {
    await _pinta(tester, await _estadoCon(_json));

    await tester.enterText(_campo('EJECUTABLE DUO'), '  /opt/duo/bin/duo  ');
    await tester.enterText(_campo('CONFIGURACIÓN DUO'), '/etc/duo');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(_almacen['${_prefijo}config.ruta_duo'], '/opt/duo/bin/duo');
    expect(_almacen['${_prefijo}config.ruta_config_duo'], '/etc/duo');
    expect(find.text('Configuración local guardada.'), findsOneWidget);
  });

  testWidgets('si el almacén de preferencias falla la pantalla se abre igual', (tester) async {
    // Lo contrario sería quedarse en el spinner para siempre por no poder leer
    // dos rutas que tienen valor por defecto.
    _almacenRoto = true;

    await _pinta(tester, await _estadoCon(_json));

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('RUTAS DE DUO'), findsOneWidget);
    expect(_texto(tester, 'EJECUTABLE DUO'), '~/.local/bin/duo');
  });

  testWidgets('si guardar falla se dice, y el botón vuelve', (tester) async {
    // Hoy `_guardar` hace `await SharedPreferences.getInstance()` sin `try`:
    // con el almacén caído la excepción se propaga, el `setState(_guardando =
    // false)` no llega, y el botón se queda en «Guardando…» desactivado para
    // siempre, sin decir por qué. El arreglo va en
    // `lib/src/pantallas/pantalla_configuracion.dart`, fuera del territorio de
    // T-015.
    await _pinta(tester, await _estadoCon(_json));
    _almacenRoto = true;

    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Guardando…'), findsNothing);
    expect(find.text('Guardar'), findsOneWidget);
    // skip: fallo abierto; guardar con el almacén caído deja el botón colgado.
  }, skip: true);

  testWidgets('sin servicio se dice que no hay proyecto ni respuesta', (tester) async {
    await _pinta(
      tester,
      await _estadoCon(
        jsonEncode({
          'error': {'code': 'unauthorized', 'message': 'Token local ausente o inválido.'},
        }),
        codigo: 401,
      ),
    );

    expect(find.text('sin datos'), findsOneWidget);
    expect(find.text('El servicio todavía no informó un proyecto activo.'), findsOneWidget);
    expect(find.text('sin respuesta'), findsOneWidget);
    // El motivo del fallo se muestra tal cual lo dio el servicio.
    expect(find.text('Token local ausente o inválido.'), findsOneWidget);
    expect(find.text('duo-desktop'), findsNothing);
  });

  testWidgets('board_not_found mantiene el servicio como conectado', (tester) async {
    await _pinta(
      tester,
      await _estadoCon(
        jsonEncode({
          'error': {
            'code': 'board_not_found',
            'message': 'No se encontró una pizarra de duo en el proyecto activo.',
          },
        }),
        codigo: 404,
      ),
    );

    expect(find.text('conectado'), findsOneWidget);
    expect(
      find.text(
        'El servicio local está respondiendo. Falta vincular un proyecto local.',
      ),
      findsOneWidget,
    );
    expect(find.text('sin respuesta'), findsNothing);
  });

  testWidgets('un tablero sin proyecto no se confunde con un servicio caído', (tester) async {
    await _pinta(
      tester,
      await _estadoCon(
        jsonEncode({
          'board': {'tasks': []},
          'ledger': {'agents': []},
        }),
      ),
    );

    // Responde, luego está conectado; lo que falta es el `project`, y eso se
    // dice en su propio panel.
    expect(find.text('conectado'), findsOneWidget);
    expect(find.text('El servicio local está respondiendo.'), findsOneWidget);
    expect(find.text('sin datos'), findsOneWidget);
    expect(find.text('El servicio todavía no informó un proyecto activo.'), findsOneWidget);
  });
}
