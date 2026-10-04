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

class MiembroCloud {
  const MiembroCloud({
    required this.id,
    required this.email,
    required this.nombre,
    required this.rol,
  });

  final String id;
  final String email;
  final String? nombre;
  final String rol;

  factory MiembroCloud.desdeJson(Map<String, dynamic> json) => MiembroCloud(
        id: '${json['userId'] ?? ''}',
        email: '${json['email'] ?? ''}',
        nombre: json['displayName'] == null ? null : '${json['displayName']}',
        rol: '${json['role'] ?? 'viewer'}',
      );
}

class PullRequestCloud {
  const PullRequestCloud({
    required this.numero,
    required this.url,
    required this.ramaOrigen,
    required this.ramaObjetivo,
    required this.estado,
    this.estadoRevision,
    this.mergedAt,
  });

  final int numero;
  final String url;
  final String ramaOrigen;
  final String ramaObjetivo;
  final String estado;
  final String? estadoRevision;
  final DateTime? mergedAt;

  factory PullRequestCloud.desdeJson(Map<String, dynamic> json) =>
      PullRequestCloud(
        numero: json['githubNumber'] as int? ?? 0,
        url: '${json['url'] ?? ''}',
        ramaOrigen: '${json['sourceBranch'] ?? ''}',
        ramaObjetivo: '${json['targetBranch'] ?? ''}',
        estado: '${json['state'] ?? ''}',
        estadoRevision: json['reviewState'] == null
            ? null
            : '${json['reviewState']}',
        mergedAt: DateTime.tryParse('${json['mergedAt'] ?? ''}'),
      );
}

class TareaCloud {
  const TareaCloud({
    required this.id,
    required this.externalId,
    required this.titulo,
    required this.ownerAgent,
    required this.estado,
    required this.rama,
    required this.assignedUserId,
    required this.assignedEmail,
    required this.workProvider,
    required this.pullRequest,
  });

  final String id;
  final String externalId;
  final String titulo;
  final String ownerAgent;
  final String estado;
  final String rama;
  final String? assignedUserId;
  final String? assignedEmail;
  final String workProvider;
  final PullRequestCloud? pullRequest;

  factory TareaCloud.desdeJson(Map<String, dynamic> json) => TareaCloud(
        id: '${json['id'] ?? ''}',
        externalId: '${json['externalId'] ?? ''}',
        titulo: '${json['title'] ?? ''}',
        ownerAgent: '${json['ownerAgent'] ?? ''}',
        estado: '${json['status'] ?? ''}',
        rama: '${json['branch'] ?? ''}',
        assignedUserId: json['assignedUserId'] == null
            ? null
            : '${json['assignedUserId']}',
        assignedEmail: json['assignedEmail'] == null
            ? null
            : '${json['assignedEmail']}',
        workProvider: '${json['workProvider'] ?? ''}',
        pullRequest: json['pullRequest'] is Map<String, dynamic>
            ? PullRequestCloud.desdeJson(
                json['pullRequest'] as Map<String, dynamic>,
              )
            : null,
      );
}

class InvitacionCloud {
  const InvitacionCloud({
    required this.token,
    required this.email,
    required this.rol,
    required this.expira,
  });

  final String token;
  final String email;
  final String rol;
  final DateTime? expira;
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

  Future<List<MiembroCloud>> miembros(String projectId) async {
    final response = await _enviar('GET', '/api/projects/$projectId/members');
    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw const FalloCloud('Respuesta inválida al cargar miembros.');
    }
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(MiembroCloud.desdeJson)
        .toList(growable: false);
  }

  Future<List<TareaCloud>> tareas(String projectId) async {
    final response = await _enviar('GET', '/api/projects/$projectId/tasks');
    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw const FalloCloud('Respuesta inválida al cargar tareas.');
    }
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(TareaCloud.desdeJson)
        .toList(growable: false);
  }

  Future<InvitacionCloud> invitar({
    required String projectId,
    required String email,
    required String rol,
  }) async {
    final response = await _enviar(
      'POST',
      '/api/projects/$projectId/invitations',
      cuerpo: {'email': email, 'role': rol},
    );
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FalloCloud('Respuesta inválida al crear invitación.');
    }
    return InvitacionCloud(
      token: '${decoded['inviteToken'] ?? ''}',
      email: '${decoded['email'] ?? email}',
      rol: '${decoded['role'] ?? rol}',
      expira: DateTime.tryParse('${decoded['expiresAt'] ?? ''}'),
    );
  }

  Future<void> aceptarInvitacion(String token) async {
    await _enviar('POST', '/api/invitations/${Uri.encodeComponent(token)}/accept');
  }

  Future<void> upsertTarea({
    required String projectId,
    required String externalId,
    required String titulo,
    required String ownerAgent,
    required String estado,
    required String rama,
    required String? assignedUserId,
    required String workProvider,
  }) async {
    await _enviar(
      'POST',
      '/api/projects/$projectId/tasks/upsert',
      cuerpo: {
        'externalId': externalId,
        'title': titulo,
        'ownerAgent': ownerAgent,
        'status': estado,
        'branch': rama,
        'assignedUserId': assignedUserId,
        'workProvider': workProvider,
      },
    );
  }

  Future<void> upsertPullRequest({
    required String projectId,
    required String externalId,
    required int githubNumber,
    required String url,
    required String sourceBranch,
    required String targetBranch,
    required String state,
    String? reviewState,
    DateTime? mergedAt,
    String? mergedByLogin,
  }) async {
    await _enviar(
      'POST',
      '/api/projects/$projectId/tasks/${Uri.encodeComponent(externalId)}/pull-request',
      cuerpo: {
        'githubNumber': githubNumber,
        'url': url,
        'sourceBranch': sourceBranch,
        'targetBranch': targetBranch,
        'state': state,
        'reviewState': reviewState,
        'mergedAt': mergedAt?.toUtc().toIso8601String(),
        'mergedByLogin': mergedByLogin,
      },
    );
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
