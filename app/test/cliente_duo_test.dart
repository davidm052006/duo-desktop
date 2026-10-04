import 'dart:convert';
import 'dart:io';

import 'package:duo_desktop/src/config.dart';
import 'package:duo_desktop/src/datos/cliente_duo.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _config = ConfigDuo(puerto: 5132, token: 'secreto');

ClienteDuo _cliente(Future<http.Response> Function(http.Request) responde) =>
    ClienteDuo(config: _config, transporte: MockClient(responde));

String _error(String codigo) => jsonEncode({
  'error': {'code': codigo, 'message': 'da igual el texto'},
});

void main() {
  test('manda el token como Bearer, que es lo que fija el contrato', () async {
    String? cabecera;
    final cliente = _cliente((p) async {
      cabecera = p.headers['Authorization'];
      return http.Response(
        jsonEncode({
          'board': {'tasks': []},
          'ledger': {'agents': []},
        }),
        200,
      );
    });

    await cliente.tablero();
    expect(cabecera, 'Bearer secreto');
  });

  test('pega a 127.0.0.1 y a ningún otro sitio', () async {
    Uri? pedida;
    final cliente = _cliente((p) async {
      pedida = p.url;
      return http.Response(
        jsonEncode({
          'board': {'tasks': []},
          'ledger': {'agents': []},
        }),
        200,
      );
    });

    await cliente.tablero();
    expect(pedida!.host, '127.0.0.1');
    expect(pedida!.port, 5132);
    expect(pedida!.path, '/board');
  });

  test('una pizarra válida sin tareas es un 200, no un error', () async {
    final cliente = _cliente(
      (_) async => http.Response(
        jsonEncode({
          'board': {'tasks': []},
          'ledger': {
            'agents': [
              {'agent': 'cc', 'points': 0, 'tasks': 0, 'last': null},
            ],
          },
        }),
        200,
      ),
    );

    final tablero = await cliente.tablero();
    expect(tablero.tareas, isEmpty);
    expect(tablero.agentes, hasLength(1));
  });

  group('códigos de error del contrato', () {
    for (final (status, codigo) in [
      (401, 'unauthorized'),
      (404, 'board_not_found'),
      (422, 'invalid_board'),
      (500, 'board_read_failed'),
    ]) {
      test('$status llega a la UI como $codigo', () async {
        final cliente = _cliente(
          (_) async => http.Response(_error(codigo), status),
        );
        await expectLater(
          cliente.tablero(),
          throwsA(isA<FalloDuo>().having((e) => e.codigo, 'codigo', codigo)),
        );
      });
    }

    test('un error sin envoltura no deja a la UI sin código', () async {
      final cliente = _cliente((_) async => http.Response('vaya', 503));
      await expectLater(
        cliente.tablero(),
        throwsA(isA<FalloDuo>().having((e) => e.codigo, 'codigo', 'http_503')),
      );
    });
  });

  test('servicio caído: un código propio, no una excepción cruda', () async {
    final cliente = _cliente(
      (_) async => throw const SocketException('nada escuchando'),
    );
    await expectLater(
      cliente.tablero(),
      throwsA(
        isA<FalloDuo>().having(
          (e) => e.codigo,
          'codigo',
          'service_unreachable',
        ),
      ),
    );
  });

  test('un 200 que no cumple el contrato se reporta como tal', () async {
    final cliente = _cliente((_) async => http.Response('{"board":{}}', 200));
    await expectLater(
      cliente.tablero(),
      throwsA(
        isA<FalloDuo>().having((e) => e.codigo, 'codigo', 'contrato_roto'),
      ),
    );
  });

  test(
    'capacidades locales usa el endpoint protegido y no inventa proveedores web',
    () async {
      Uri? pedida;
      String? autorizacion;
      final cliente = _cliente((request) async {
        pedida = request.url;
        autorizacion = request.headers['Authorization'];
        return http.Response(
          jsonEncode({
            'agents': [
              {
                'provider': 'codex',
                'available': true,
                'executable': '/usr/bin/codex',
              },
              {
                'provider': 'claude',
                'available': true,
                'executable': '/usr/bin/claude',
              },
              {'provider': 'gemini', 'available': false, 'executable': null},
            ],
          }),
          200,
        );
      });

      final capacidades = await cliente.capacidadesAgentes();

      expect(pedida!.path, '/agents/capabilities');
      expect(autorizacion, 'Bearer secreto');
      expect(capacidades.map((item) => item.provider), [
        'codex',
        'claude',
        'gemini',
      ]);
      expect(capacidades[0].disponible, isTrue);
      expect(capacidades[2].disponible, isFalse);
    },
  );
}
