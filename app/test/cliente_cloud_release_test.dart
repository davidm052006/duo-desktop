import 'dart:convert';

import 'package:duo_desktop/src/datos/cliente_cloud.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

const _releaseConfigCheck = bool.fromEnvironment('RELEASE_CONFIG_CHECK');

void main() {
  test('crear proyecto usa el endpoint Cloud compilado y sesión Bearer', () async {
    if (!_releaseConfigCheck) return;

    final transport = _ClienteFalso();
    final cloud = ClienteCloud(
      cliente: transport,
      tokenProvider: () => 'session-de-prueba',
    );

    await cloud.crearProyecto(
      nombre: 'Proyecto de prueba',
      slug: 'proyecto-prueba',
      repositorio: 'duo/prueba',
    );

    final request = transport.request!;
    expect(request.method, 'POST');
    expect(request.url.path, '/api/projects');
    expect(request.url.scheme, 'https');
    expect(request.headers['authorization'], 'Bearer session-de-prueba');
    expect(
      jsonDecode((request as http.Request).body),
      {
        'name': 'Proyecto de prueba',
        'slug': 'proyecto-prueba',
        'repositoryFullName': 'duo/prueba',
        'targetBranch': 'develop',
      },
    );
  });
}

class _ClienteFalso extends http.BaseClient {
  http.BaseRequest? request;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest value) async {
    request = value;
    return http.StreamedResponse(
      Stream.value(utf8.encode(jsonEncode({
        'projectId': 'project-1',
        'name': 'Proyecto de prueba',
        'slug': 'proyecto-prueba',
        'repositoryFullName': 'duo/prueba',
        'targetBranch': 'develop',
        'role': 'owner',
      }))),
      201,
      headers: const {'content-type': 'application/json'},
    );
  }
}
