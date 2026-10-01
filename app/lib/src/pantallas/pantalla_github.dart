import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../config.dart';
import '../tema/paleta.dart';
import '../widgets/tarjeta.dart';

class PantallaGitHub extends StatefulWidget {
  const PantallaGitHub({super.key});

  @override
  State<PantallaGitHub> createState() => _PantallaGitHubState();
}

class _PantallaGitHubState extends State<PantallaGitHub> {
  bool _cargando = true;
  String? _mensaje;
  List<_Rama> _ramas = const [];
  List<_PullRequest> _prs = const [];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _mensaje = null;
    });

    final config = ConfigDuo.desdeEntorno;
    try {
      final respuesta = await http.get(
        config.ruta('/github'),
        headers: {
          'Authorization': 'Bearer ${config.token}',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 5));

      if (!mounted) return;

      if (respuesta.statusCode == 404 || respuesta.statusCode == 501) {
        setState(() {
          _cargando = false;
          _ramas = const [];
          _prs = const [];
          _mensaje = 'GET /github todavía no está disponible en el servicio local.';
        });
        return;
      }

      if (respuesta.statusCode != 200) {
        setState(() {
          _cargando = false;
          _ramas = const [];
          _prs = const [];
          _mensaje = 'El servicio respondió HTTP ${respuesta.statusCode} al consultar /github.';
        });
        return;
      }

      final json = jsonDecode(respuesta.body);
      if (json is! Map<String, dynamic>) {
        throw const FormatException('respuesta no es un objeto JSON');
      }

      final ramasRaw = json['branches'];
      final prsRaw = json['pullRequests'] ?? json['pull_requests'] ?? json['prs'];

      final ramas = ramasRaw is List
          ? ramasRaw.whereType<Map>().map((e) => _Rama.desde(Map<String, dynamic>.from(e))).toList()
          : <_Rama>[];

      final prs = prsRaw is List
          ? prsRaw.whereType<Map>().map((e) => _PullRequest.desde(Map<String, dynamic>.from(e))).toList()
          : <_PullRequest>[];

      setState(() {
        _cargando = false;
        _ramas = ramas;
        _prs = prs;
        if (ramas.isEmpty && prs.isEmpty) {
          _mensaje = 'El endpoint respondió correctamente, pero no hay ramas ni pull requests para mostrar.';
        }
      });
    } on TimeoutException {
      _fallo('El servicio tardó demasiado en responder a GET /github.');
    } on SocketException {
      _fallo('El servicio local no está disponible.');
    } on http.ClientException {
      _fallo('No fue posible conectar con el servicio local.');
    } on FormatException catch (e) {
      _fallo('La respuesta de GET /github no tiene el formato esperado: ${e.message}.');
    } on Object catch (e) {
      _fallo('No fue posible leer la información de GitHub: $e');
    }
  }

  void _fallo(String mensaje) {
    if (!mounted) return;
    setState(() {
      _cargando = false;
      _ramas = const [];
      _prs = const [];
      _mensaje = mensaje;
    });
  }

  @override
  Widget build(BuildContext context) {
    final paleta = context.paleta;
    final textos = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 36),
      children: [
        Row(
          children: [
            Text('GitHub', style: textos.headlineSmall?.copyWith(fontSize: 26)),
            const SizedBox(width: 12),
            Insignia('GET /github', tono: paleta.acentoAlt, mono: true),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(
                'Ramas de agentes y pull requests del repositorio activo.',
                style: textos.bodySmall?.copyWith(color: paleta.tintaSecundaria),
              ),
            ),
            OutlinedButton.icon(
              onPressed: _cargando ? null : _cargar,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Actualizar'),
            ),
          ],
        ),
        const SizedBox(height: 24),
        if (_cargando)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        else ...[
          if (_mensaje != null) ...[
            _EstadoVacio(mensaje: _mensaje!),
            const SizedBox(height: 18),
          ],
          LayoutBuilder(
            builder: (context, caja) {
              final dosColumnas = caja.maxWidth >= 980;
              final ramas = _PanelRamas(ramas: _ramas);
              final prs = _PanelPrs(prs: _prs);
              if (dosColumnas) {
                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: ramas),
                      const SizedBox(width: 18),
                      Expanded(child: prs),
                    ],
                  ),
                );
              }
              return Column(
                children: [
                  ramas,
                  const SizedBox(height: 18),
                  prs,
                ],
              );
            },
          ),
        ],
      ],
    );
  }
}

class _EstadoVacio extends StatelessWidget {
  const _EstadoVacio({required this.mensaje});

  final String mensaje;

  @override
  Widget build(BuildContext context) {
    final paleta = context.paleta;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: paleta.acentoAlt.withValues(alpha: 0.06),
        border: Border.all(color: paleta.acentoAlt.withValues(alpha: 0.22)),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 17, color: paleta.acentoAlt),
          const SizedBox(width: 10),
          Expanded(child: Text(mensaje, style: Theme.of(context).textTheme.bodySmall)),
        ],
      ),
    );
  }
}

class _PanelRamas extends StatelessWidget {
  const _PanelRamas({required this.ramas});

  final List<_Rama> ramas;

  @override
  Widget build(BuildContext context) {
    final paleta = context.paleta;
    return Tarjeta(
      titulo: 'Ramas por agente',
      icono: Icons.account_tree_outlined,
      sufijo: Text('${ramas.length}', style: Theme.of(context).textTheme.titleMedium),
      hijo: ramas.isEmpty
          ? Text(
              'No hay ramas devueltas por GET /github.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: paleta.tintaTenue),
            )
          : Column(
              children: [
                for (final rama in ramas)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Container(width: 8, height: 8, color: paleta.serieDe(rama.agente)),
                        const SizedBox(width: 10),
                        SizedBox(width: 58, child: Mono(rama.agente, peso: FontWeight.w700)),
                        const SizedBox(width: 8),
                        Expanded(child: Mono(rama.nombre, color: paleta.tintaSecundaria)),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

class _PanelPrs extends StatelessWidget {
  const _PanelPrs({required this.prs});

  final List<_PullRequest> prs;

  @override
  Widget build(BuildContext context) {
    final paleta = context.paleta;
    return Tarjeta(
      titulo: 'Pull requests',
      icono: Icons.merge_outlined,
      sufijo: Text('${prs.length}', style: Theme.of(context).textTheme.titleMedium),
      hijo: prs.isEmpty
          ? Text(
              'No hay pull requests devueltos por GET /github.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: paleta.tintaTenue),
            )
          : Column(
              children: [
                for (final pr in prs)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Mono('#${pr.numero}', color: paleta.acentoAlt, peso: FontWeight.w700),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(pr.titulo, style: Theme.of(context).textTheme.bodyMedium),
                              const SizedBox(height: 4),
                              Mono(pr.rama, color: paleta.tintaTenue),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Insignia(pr.estado, tono: paleta.tintaSecundaria),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

class _Rama {
  const _Rama({required this.nombre, required this.agente});

  final String nombre;
  final String agente;

  factory _Rama.desde(Map<String, dynamic> json) {
    final nombre = (json['name'] ?? json['branch'] ?? '').toString();
    final agente = (json['agent'] ?? json['owner'] ?? _agenteDesdeRama(nombre)).toString();
    return _Rama(nombre: nombre, agente: agente.isEmpty ? '—' : agente);
  }

  static String _agenteDesdeRama(String rama) {
    if (rama.startsWith('chat/')) return 'chat';
    if (rama.startsWith('codex/')) return 'codex';
    if (rama.startsWith('cc/')) return 'cc';
    return '';
  }
}

class _PullRequest {
  const _PullRequest({
    required this.numero,
    required this.titulo,
    required this.estado,
    required this.rama,
  });

  final String numero;
  final String titulo;
  final String estado;
  final String rama;

  factory _PullRequest.desde(Map<String, dynamic> json) => _PullRequest(
        numero: (json['number'] ?? json['id'] ?? '?').toString(),
        titulo: (json['title'] ?? 'Pull request sin título').toString(),
        estado: (json['state'] ?? json['status'] ?? 'desconocido').toString(),
        rama: (json['head'] ?? json['branch'] ?? json['headBranch'] ?? '').toString(),
      );
}
