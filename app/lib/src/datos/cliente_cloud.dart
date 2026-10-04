import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config_cloud.dart';

class FalloCloud implements Exception {
  const FalloCloud(this.mensaje, {this.codigo});

  final String mensaje;
  final int? codigo;

  @override
  String toString() => mensaje;
}

class ProyectoCloud {
  const ProyectoCloud({
    required this.id,
    required this.nombre,
    required this.slug,
    required this.repositorio,
    required this.ramaObjetivo,
    required this.rol,
  });

  final String id;
  final String nombre;
  final String slug;
  final String repositorio;
  final String ramaObjetivo;
  final String rol;

  factory ProyectoCloud.desdeJson(Map<String, dynamic> json) => ProyectoCloud(
        id: '${json['projectId'] ?? json['id'] ?? ''}',
        nombre: '${json['name'] ?? ''}',
        slug: '${json['slug'] ?? ''}',
        repositorio: '${json['repositoryFullName'] ?? ''}',
        ramaObjetivo: '${json['targetBranch'] ?? 'develop'}',
        rol: '${json['role'] ?? 'viewer'}',
      );
}

class ClienteCloud {
  ClienteCloud({http.Client? cliente}) : _cliente = cliente ?? http.Client();

  final http.Client _cliente;

  String _token() {
    final token = Supabase.instance.client.auth.currentSession?.accessToken;
    if (token == null || token.isEmpty) {
      throw const FalloCloud('La sesión de Supabase no está disponible.');
    }
    return token;
  }

  Future<http.Response> _enviar(
    String metodo,
    String path, {
    Object? cuerpo,
  }) async {
    final request = http.Request(metodo, ConfigCloud.endpoint(path))
      ..headers['Authorization'] = 'Bearer ${_token()}'
      ..headers['Accept'] = 'application/json';

    if (cuerpo != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(cuerpo);
    }

    final streamed = await _cliente.send(request);
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response;
    }

    String mensaje = 'Duo Cloud respondió ${response.statusCode}.';
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final error = decoded['error'];
        if (error is Map<String, dynamic> && error['message'] != null) {
          mensaje = '${error['message']}';
        }
      }
    } on Object {
      // Mantiene el mensaje HTTP genérico si el cuerpo no es JSON.
    }

    throw FalloCloud(mensaje, codigo: response.statusCode);
  }

  Future<List<ProyectoCloud>> proyectos() async {
    final response = await _enviar('GET', '/api/projects');
    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw const FalloCloud('Respuesta inválida al cargar proyectos.');
    }

    return decoded
        .whereType<Map<String, dynamic>>()
        .map(ProyectoCloud.desdeJson)
        .toList(growable: false);
  }

  Future<ProyectoCloud> crearProyecto({
    required String nombre,
    required String slug,
    required String repositorio,
    String ramaObjetivo = 'develop',
  }) async {
    final response = await _enviar(
      'POST',
      '/api/projects',
      cuerpo: {
        'name': nombre,
        'slug': slug,
        'repositoryFullName': repositorio,
        'targetBranch': ramaObjetivo,
      },
    );

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FalloCloud('Respuesta inválida al crear el proyecto.');
    }

    return ProyectoCloud.desdeJson(decoded);
  }

  void cierra() => _cliente.close();
}
