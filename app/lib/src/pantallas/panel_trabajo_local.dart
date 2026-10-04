import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../datos/cliente_cloud.dart';
import '../datos/cliente_duo.dart';
import '../tema/paleta.dart';
import '../widgets/tarjeta.dart';
import 'fondo_video_config.dart';

class PanelTrabajoLocal extends StatefulWidget {
  const PanelTrabajoLocal({
    super.key,
    required this.proyecto,
    required this.tarea,
    required this.cloud,
    required this.alCambiarCloud,
  });

  final ProyectoCloud proyecto;
  final TareaCloud tarea;
  final ClienteCloud cloud;
  final VoidCallback alCambiarCloud;

  @override
  State<PanelTrabajoLocal> createState() => _PanelTrabajoLocalState();
}

class _PanelTrabajoLocalState extends State<PanelTrabajoLocal> {
  final _duo = ClienteDuo();
  WorkspaceLocal? _workspace;
  EstadoWorkspaceLocal? _estado;
  String? _repoLocal;
  String? _error;
  bool _ocupado = false;
  late Future<UsuarioCloudActual> _usuario;

  @override
  void initState() {
    super.initState();
    _usuario = widget.cloud.usuarioActual();
    _cargarRepo();
  }

  @override
  void dispose() {
    _duo.cierra();
    super.dispose();
  }

  Future<void> _cargarRepo() async {
    try {
      final path = await _duo.repositorioLocal(widget.proyecto.id);
      if (mounted) setState(() => _repoLocal = path);
    } on Object {
      // La tarea sigue usable aunque el servicio local aún no esté disponible.
    }
  }

  Future<void> _configurarRepo() async {
    final path = await FondoVideoConfig.elegirCarpeta(context);
    if (path == null || !mounted) return;
    await _accion(() async {
      await _duo.configurarRepositorioLocal(
        projectId: widget.proyecto.id,
        projectSlug: widget.proyecto.slug,
        repositoryFullName: widget.proyecto.repositorio,
        repositoryPath: path,
      );
      _repoLocal = path;
    });
  }

  Future<WorkspaceLocal> _asegurarWorkspace() async {
    final existente = _workspace;
    if (existente != null) return existente;

    final workspace = await _duo.prepararWorkspace(
      projectId: widget.proyecto.id,
      externalId: widget.tarea.externalId,
      taskTitle: widget.tarea.titulo,
      targetBranch: widget.proyecto.ramaObjetivo,
      provider: widget.tarea.workProvider,
    );
    _workspace = workspace;

    if (widget.tarea.estado == 'pending') {
      await widget.cloud.upsertTarea(
        projectId: widget.proyecto.id,
        externalId: widget.tarea.externalId,
        titulo: widget.tarea.titulo,
        ownerAgent: widget.tarea.ownerAgent,
        estado: 'in_progress',
        rama: workspace.rama,
        assignedUserId: widget.tarea.assignedUserId,
        workProvider: widget.tarea.workProvider,
      );
      widget.alCambiarCloud();
    }

    return workspace;
  }

  Future<void> _preparar() async {
    await _accion(() async {
      final ws = await _asegurarWorkspace();
      _estado = await _duo.estadoWorkspace(ws.id);
    });
  }

  Future<void> _actualizarEstado() async {
    await _accion(() async {
      final ws = await _asegurarWorkspace();
      _estado = await _duo.estadoWorkspace(ws.id);
    });
  }

  String _contexto(WorkspaceLocal ws) => '''
Proyecto: ${widget.proyecto.nombre}
Repositorio: ${widget.proyecto.repositorio}
Tarea: ${widget.tarea.externalId}
Título: ${widget.tarea.titulo}
Provider: ${widget.tarea.workProvider}
Branch: ${ws.rama}
Target: ${widget.proyecto.ramaObjetivo}
Workspace: ${ws.worktree}

Trabaja únicamente dentro de este workspace.
No hagas merge.
No hagas force-push.
No modifiques credenciales.
''';

  Future<void> _copiarContexto() async {
    await _accion(() async {
      final ws = await _asegurarWorkspace();
      await Clipboard.setData(ClipboardData(text: _contexto(ws)));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Contexto de tarea copiado')),
        );
      }
    });
  }

  Future<void> _abrirAgente() async {
    final provider = widget.tarea.workProvider;
    if (provider == 'chatgpt' || provider == 'grok') {
      await _copiarContexto();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Contexto copiado. Abre ${provider == 'chatgpt' ? 'ChatGPT' : 'Grok'} en Chats.',
            ),
          ),
        );
      }
      return;
    }

    await _accion(() async {
      final ws = await _asegurarWorkspace();
      await _duo.lanzarAgenteLocal(
        workspaceId: ws.id,
        provider: provider,
      );
    });
  }

  Future<void> _commit() async {
    await _actualizarEstado();
    if (!mounted || _estado == null) return;
    if (_estado!.archivos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay cambios para commit.')),
      );
      return;
    }

    final resultado = await showDialog<_CommitSeleccion>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _DialogCommit(
        tarea: widget.tarea,
        archivos: _estado!.archivos,
      ),
    );
    if (resultado == null) return;

    await _accion(() async {
      final ws = await _asegurarWorkspace();
      await _duo.commitWorkspace(
        workspaceId: ws.id,
        archivos: resultado.archivos,
        mensaje: resultado.mensaje,
      );
      _estado = await _duo.estadoWorkspace(ws.id);
    });
  }

  Future<void> _push() async {
    await _accion(() async {
      final ws = await _asegurarWorkspace();
      await _duo.pushWorkspace(ws.id);
      _estado = await _duo.estadoWorkspace(ws.id);
    });
  }

  Future<void> _crearPr() async {
    await _accion(() async {
      final ws = await _asegurarWorkspace();
      final pr = await _duo.crearOEncontrarPullRequest(
        workspaceId: ws.id,
        titulo: '${widget.tarea.externalId}: ${widget.tarea.titulo}',
        cuerpo: 'Trabajo preparado desde Duo Desktop para ${widget.tarea.externalId}.',
      );
      await _sincronizarPr(pr);
    });
  }

  Future<void> _sincronizarPrReal() async {
    final existente = widget.tarea.pullRequest;
    if (existente == null) {
      await _crearPr();
      return;
    }

    await _accion(() async {
      final ws = await _asegurarWorkspace();
      final pr = await _duo.estadoPullRequest(
        workspaceId: ws.id,
        numero: existente.numero,
      );
      await _sincronizarPr(pr);
    });
  }

  Future<void> _sincronizarPr(PullRequestLocal pr) async {
    await widget.cloud.upsertPullRequest(
      projectId: widget.proyecto.id,
      externalId: widget.tarea.externalId,
      githubNumber: pr.numero,
      url: pr.url,
      sourceBranch: pr.origen,
      targetBranch: pr.destino,
      state: pr.estado.toLowerCase(),
      reviewState: widget.tarea.pullRequest?.estadoRevision,
      mergedAt: pr.mergedAt,
      mergedByLogin: null,
    );
    widget.alCambiarCloud();
  }

  Future<void> _accion(Future<void> Function() fn) async {
    if (_ocupado) return;
    setState(() {
      _ocupado = true;
      _error = null;
    });
    try {
      await fn();
    } on Object catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<UsuarioCloudActual>(
        future: _usuario,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            if (snapshot.hasError) {
              return Text(
                'No se pudo comprobar la identidad Cloud.',
                style: TextStyle(color: context.paleta.aviso),
              );
            }
            return const LinearProgressIndicator(minHeight: 2);
          }

          final propia = widget.tarea.assignedUserId != null &&
              widget.tarea.assignedUserId == snapshot.data!.id;
          if (!propia) {
            return Text(
              widget.tarea.assignedUserId == null
                  ? 'Tarea sin asignar: acciones locales deshabilitadas.'
                  : 'Asignada a otro miembro: solo lectura local.',
              style: Theme.of(context).textTheme.bodySmall,
            );
          }

          final ws = _workspace;
          final estado = _estado;
          final esLocal = const {'codex', 'claude', 'gemini'}
              .contains(widget.tarea.workProvider);

          return Tarjeta(
            titulo: 'Workspace local',
            icono: Icons.terminal_outlined,
            sufijo: ws == null
                ? Insignia('SIN PREPARAR', tono: context.paleta.aviso)
                : Insignia(ws.rama, tono: context.paleta.acentoAlt, mono: true),
            hijo: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_repoLocal != null)
                  Mono(_repoLocal!, color: context.paleta.tintaSecundaria)
                else
                  Text(
                    'Configura qué copia local corresponde a este proyecto.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _ocupado ? null : _configurarRepo,
                      icon: const Icon(Icons.folder_open, size: 16),
                      label: const Text('Configurar repo'),
                    ),
                    FilledButton.icon(
                      onPressed: _ocupado ? null : _preparar,
                      icon: const Icon(Icons.account_tree_outlined, size: 16),
                      label: const Text('Preparar trabajo'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _ocupado ? null : _copiarContexto,
                      icon: const Icon(Icons.copy, size: 16),
                      label: const Text('Copiar contexto'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _ocupado ? null : _abrirAgente,
                      icon: Icon(
                        esLocal ? Icons.terminal : Icons.chat_bubble_outline,
                        size: 16,
                      ),
                      label: Text(esLocal ? 'Abrir agente' : 'Contexto para chat'),
                    ),
                  ],
                ),
                if (ws != null) ...[
                  const SizedBox(height: 12),
                  Mono(ws.worktree, color: context.paleta.tintaTenue),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _ocupado ? null : _actualizarEstado,
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text('Cambios'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _ocupado ? null : _commit,
                        icon: const Icon(Icons.commit, size: 16),
                        label: const Text('Commit'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _ocupado ? null : _push,
                        icon: const Icon(Icons.cloud_upload_outlined, size: 16),
                        label: const Text('Push'),
                      ),
                      FilledButton.icon(
                        onPressed: _ocupado ? null : _crearPr,
                        icon: const Icon(Icons.merge_type, size: 16),
                        label: Text(
                          widget.tarea.pullRequest == null ? 'Crear PR' : 'Ver/usar PR',
                        ),
                      ),
                      if (widget.tarea.pullRequest != null)
                        OutlinedButton.icon(
                          onPressed: _ocupado ? null : _sincronizarPrReal,
                          icon: const Icon(Icons.sync, size: 16),
                          label: const Text('Sincronizar GitHub'),
                        ),
                    ],
                  ),
                ],
                if (estado != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    estado.dirty
                        ? '${estado.archivos.length} archivo(s) cambiado(s) · ↑${estado.ahead} ↓${estado.behind}'
                        : 'Workspace limpio · ↑${estado.ahead} ↓${estado.behind}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (estado.archivos.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    for (final archivo in estado.archivos.take(8))
                      Mono(archivo, color: context.paleta.tintaSecundaria),
                  ],
                ],
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: context.paleta.critico),
                  ),
                ],
              ],
            ),
          );
        },
      );
}

class _CommitSeleccion {
  const _CommitSeleccion(this.archivos, this.mensaje);
  final List<String> archivos;
  final String mensaje;
}

class _DialogCommit extends StatefulWidget {
  const _DialogCommit({
    required this.tarea,
    required this.archivos,
  });

  final TareaCloud tarea;
  final List<String> archivos;

  @override
  State<_DialogCommit> createState() => _DialogCommitState();
}

class _DialogCommitState extends State<_DialogCommit> {
  late final TextEditingController _mensaje;
  final Set<String> _seleccionados = {};

  @override
  void initState() {
    super.initState();
    _mensaje = TextEditingController(
      text: 'feat(${widget.tarea.externalId}): ${widget.tarea.titulo}',
    );
  }

  @override
  void dispose() {
    _mensaje.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        backgroundColor: context.paleta.panel,
        title: const Text('Commit explícito'),
        content: SizedBox(
          width: 620,
          height: 480,
          child: Column(
            children: [
              TextField(
                controller: _mensaje,
                decoration: const InputDecoration(labelText: 'Mensaje'),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView(
                  children: [
                    for (final archivo in widget.archivos)
                      CheckboxListTile(
                        value: _seleccionados.contains(archivo),
                        title: Mono(archivo),
                        onChanged: (value) => setState(() {
                          if (value == true) {
                            _seleccionados.add(archivo);
                          } else {
                            _seleccionados.remove(archivo);
                          }
                        }),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            onPressed: _seleccionados.isEmpty || _mensaje.text.trim().isEmpty
                ? null
                : () => Navigator.pop(
                      context,
                      _CommitSeleccion(
                        _seleccionados.toList(growable: false),
                        _mensaje.text.trim(),
                      ),
                    ),
            icon: const Icon(Icons.commit, size: 16),
            label: const Text('Commit'),
          ),
        ],
      );
}
