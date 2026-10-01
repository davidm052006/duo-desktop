import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../config.dart';
import '../datos/cliente_duo.dart';
import '../estado/estado_tablero.dart';
import '../modelos/tablero.dart';
import '../tema/paleta.dart';
import '../widgets/tarjeta.dart';

class PantallaGitHub extends StatefulWidget {
  const PantallaGitHub({super.key});

  @override
  State<PantallaGitHub> createState() => _PantallaGitHubState();
}

class _PantallaGitHubState extends State<PantallaGitHub> {
  final _cliente = ClienteDuo();

  bool _cargando = true;
  String? _mensaje;
  String? _errorAccion;
  String? _tareaEnAccion;
  List<_Rama> _ramas = const [];
  List<_PullRequest> _prs = const [];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _cliente.cierra();
    super.dispose();
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
        final cuerpo = _json(respuesta.body);
        final error = cuerpo?['error'] as Map<String, dynamic>?;
        setState(() {
          _cargando = false;
          _ramas = const [];
          _prs = const [];
          _mensaje = error?['message'] as String? ??
              'El servicio respondió HTTP ${respuesta.statusCode} al consultar /github.';
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
          ? ramasRaw
              .whereType<Map>()
              .map((e) => _Rama.desde(Map<String, dynamic>.from(e)))
              .toList()
          : <_Rama>[];

      final prs = prsRaw is List
          ? prsRaw
              .whereType<Map>()
              .map((e) => _PullRequest.desde(Map<String, dynamic>.from(e)))
              .toList()
          : <_PullRequest>[];

      setState(() {
        _cargando = false;
        _ramas = ramas;
        _prs = prs;
        if (ramas.isEmpty && prs.isEmpty) {
          _mensaje =
              'El endpoint respondió correctamente, pero no hay ramas ni pull requests para mostrar.';
        }
      });
    } on TimeoutException {
      _fallo('El servicio tardó demasiado en responder a GET /github.');
    } on SocketException {
      _fallo('El servicio local no está disponible.');
    } on http.ClientException {
      _fallo('No fue posible conectar con el servicio local.');
    } on FormatException catch (e) {
      _fallo(
        'La respuesta de GET /github no tiene el formato esperado: ${e.message}.',
      );
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

  Map<String, dynamic>? _json(String cuerpo) {
    try {
      final valor = jsonDecode(cuerpo);
      return valor is Map<String, dynamic> ? valor : null;
    } on Object {
      return null;
    }
  }

  Future<void> _publicar(Tarea tarea) async {
    final confirmado = await _confirmar(
      titulo: 'Publicar rama en GitHub',
      texto:
          'Se publicará la rama ${tarea.rama} asociada a ${tarea.id}. Esta operación modifica el remoto de GitHub.',
      accion: 'Publicar rama',
    );
    if (!confirmado || !mounted) return;

    await _ejecutarAccion(
      tarea: tarea,
      accion: () => _cliente.publicarRama(tarea.id),
      exito: 'Rama de ${tarea.id} publicada.',
    );
  }

  Future<void> _abrirPr(Tarea tarea) async {
    final confirmado = await _confirmar(
      titulo: 'Abrir pull request',
      texto:
          'Se solicitará abrir el pull request de ${tarea.id} desde ${tarea.rama}. Esta operación sale a GitHub.',
      accion: 'Abrir PR',
    );
    if (!confirmado || !mounted) return;

    await _ejecutarAccion(
      tarea: tarea,
      accion: () => _cliente.abrirPullRequest(tarea.id),
      exito: 'Pull request de ${tarea.id} solicitado.',
    );
  }

  Future<void> _ejecutarAccion({
    required Tarea tarea,
    required Future<void> Function() accion,
    required String exito,
  }) async {
    setState(() {
      _tareaEnAccion = tarea.id;
      _errorAccion = null;
    });

    try {
      await accion();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(exito)),
      );
      await _cargar();
    } on FalloDuo catch (e) {
      if (!mounted) return;
      setState(() {
        _errorAccion =
            '${e.mensaje}\n\nAlternativa manual: duo pr ${tarea.id}';
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _errorAccion =
            '$e\n\nAlternativa manual: duo pr ${tarea.id}';
      });
    } finally {
      if (mounted) setState(() => _tareaEnAccion = null);
    }
  }

  Future<bool> _confirmar({
    required String titulo,
    required String texto,
    required String accion,
  }) async {
    final resultado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(titulo),
        content: Text(texto),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(accion),
          ),
        ],
      ),
    );
    return resultado ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final paleta = context.paleta;
    final textos = Theme.of(context).textTheme;
    final tareas = context.watch<EstadoTablero>().tablero?.tareas ?? const <Tarea>[];

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
                'Ramas de agentes, pull requests y acciones explícitas sobre el remoto.',
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
        if (_errorAccion != null) ...[
          const SizedBox(height: 18),
          _ErrorAccion(mensaje: _errorAccion!),
        ],
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
              final ramas = _PanelRamas(
                ramas: _ramas,
                tareas: tareas,
                tareaEnAccion: _tareaEnAccion,
                alPublicar: _publicar,
                alAbrirPr: _abrirPr,
              );
              final prs = _PanelPrs(prs: _prs);
              if (dosColumnas) {
                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(flex: 3, child: ramas),
                      const SizedBox(width: 18),
                      Expanded(flex: 2, child: prs),
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

class _ErrorAccion extends StatelessWidget {
  const _ErrorAccion({required this.mensaje});

  final String mensaje;

  @override
  Widget build(BuildContext context) {
    final paleta = context.paleta;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: paleta.critico.withValues(alpha: .08),
        border: Border.all(color: paleta.critico.withValues(alpha: .35)),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, size: 17, color: paleta.critico),
          const SizedBox(width: 10),
          Expanded(
            child: SelectableText(
              mensaje,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
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
          Expanded(
            child: Text(
              mensaje,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _PanelRamas extends StatelessWidget {
  const _PanelRamas({
    required this.ramas,
    required this.tareas,
    required this.tareaEnAccion,
    required this.alPublicar,
    required this.alAbrirPr,
  });

  final List<_Rama> ramas;
  final List<Tarea> tareas;
  final String? tareaEnAccion;
  final ValueChanged<Tarea> alPublicar;
  final ValueChanged<Tarea> alAbrirPr;

  Tarea? _tareaDe(_Rama rama) {
    for (final tarea in tareas) {
      if (tarea.rama == rama.nombre) return tarea;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final paleta = context.paleta;
    return Tarjeta(
      titulo: 'Ramas por agente',
      icono: Icons.account_tree_outlined,
      sufijo: Text(
        '${ramas.length}',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      hijo: ramas.isEmpty
          ? Text(
              'No hay ramas devueltas por GET /github.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: paleta.tintaTenue),
            )
          : Column(
              children: [
                for (final rama in ramas) _RamaFila(
                  rama: rama,
                  tarea: _tareaDe(rama),
                  ocupada: _tareaDe(rama)?.id == tareaEnAccion,
                  alPublicar: alPublicar,
                  alAbrirPr: alAbrirPr,
                ),
              ],
            ),
    );
  }
}

class _RamaFila extends StatelessWidget {
  const _RamaFila({
    required this.rama,
    required this.tarea,
    required this.ocupada,
    required this.alPublicar,
    required this.alAbrirPr,
  });

  final _Rama rama;
  final Tarea? tarea;
  final bool ocupada;
  final ValueChanged<Tarea> alPublicar;
  final ValueChanged<Tarea> alAbrirPr;

  @override
  Widget build(BuildContext context) {
    final paleta = context.paleta;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: paleta.rejilla),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  color: paleta.serieDe(rama.agente),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 58,
                  child: Mono(rama.agente, peso: FontWeight.w700),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Mono(
                    rama.nombre,
                    color: paleta.tintaSecundaria,
                  ),
                ),
                if (tarea != null)
                  Insignia(tarea!.id, tono: paleta.acentoAlt, mono: true),
              ],
            ),
            if (tarea != null) ...[
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: ocupada ? null : () => alPublicar(tarea!),
                    icon: const Icon(Icons.cloud_upload_outlined, size: 16),
                    label: const Text('Publicar'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: ocupada ? null : () => alAbrirPr(tarea!),
                    icon: const Icon(Icons.merge_outlined, size: 16),
                    label: const Text('Abrir PR'),
                  ),
                ],
              ),
            ] else ...[
              const SizedBox(height: 8),
              Text(
                'No corresponde a una tarea visible de GET /board; acciones deshabilitadas.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: paleta.tintaTenue),
              ),
            ],
          ],
        ),
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
      sufijo: Text(
        '${prs.length}',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      hijo: prs.isEmpty
          ? Text(
              'No hay pull requests devueltos por GET /github.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: paleta.tintaTenue),
            )
          : Column(
              children: [
                for (final pr in prs)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Mono(
                          '#${pr.numero}',
                          color: paleta.acentoAlt,
                          peso: FontWeight.w700,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                pr.titulo,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 4),
                              Mono(pr.rama, color: paleta.tintaTenue),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Insignia(
                          pr.estado,
                          tono: paleta.tintaSecundaria,
                        ),
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
    final agente =
        (json['agent'] ?? json['owner'] ?? _agenteDesdeRama(nombre)).toString();
    return _Rama(
      nombre: nombre,
      agente: agente.isEmpty ? '—' : agente,
    );
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
        rama:
            (json['head'] ?? json['branch'] ?? json['headBranch'] ?? '').toString(),
      );
}
