import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

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
  late Future<List<CapacidadAgenteLocal>> _capacidades;
  Timer? _ciTimer;
  String? _ultimoFalloCi;
  bool _ciConsultando = false;

  @override
  void initState() {
    super.initState();
    _usuario = widget.cloud.usuarioActual();
    _capacidades = _duo.capacidadesAgentes().catchError(
      (_) => const <CapacidadAgenteLocal>[],
    );
    _cargarRepo();
    _programarSeguimientoCi();
  }

  @override
  void dispose() {
    _ciTimer?.cancel();
    _duo.cierra();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant PanelTrabajoLocal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tarea.pullRequest?.numero != widget.tarea.pullRequest?.numero ||
        oldWidget.tarea.estado != widget.tarea.estado) {
      _programarSeguimientoCi();
    }
  }

  void _programarSeguimientoCi() {
    _ciTimer?.cancel();
    if (widget.proyecto.rol != 'owner' ||
        widget.tarea.estado != 'in_review' ||
        widget.tarea.pullRequest == null) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _comprobarCiYFinalizar());
    _ciTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _comprobarCiYFinalizar(),
    );
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
      await widget.cloud.iniciarTarea(
        projectId: widget.proyecto.id,
        externalId: widget.tarea.externalId,
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

  String _promptFallback(WorkspaceLocal ws) => '''
${_contexto(ws)}

No tienes acceso directo al workspace desde este chat. Resuelve la tarea y
devuelve SOLO un parche unified diff aplicable con `git apply`.
Debe incluir todos los cambios necesarios y no debe incluir explicaciones
fuera del parche. No incluyas secretos ni credenciales.
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
    final ws = await _asegurarWorkspace();

    if (provider == 'chatgpt' || provider == 'grok') {
      await Clipboard.setData(ClipboardData(text: _promptFallback(ws)));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Prompt copiado. Abre ${provider == 'chatgpt' ? 'ChatGPT' : 'Grok'} en Chats.',
            ),
          ),
        );
      }
      return;
    }

    final capacidades = await _capacidades;
    final disponible = capacidades.any(
      (capacidad) => capacidad.provider == provider && capacidad.disponible,
    );
    if (!disponible) {
      await Clipboard.setData(ClipboardData(text: _promptFallback(ws)));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Ese agente no está instalado. Copié un prompt para usarlo en un chat.',
            ),
          ),
        );
      }
      return;
    }

    await _accion(() async {
      await _duo.lanzarAgenteLocal(
        workspaceId: ws.id,
        provider: provider,
      );
    });
  }

  Future<void> _recogerResultado() async {
    final data = await Clipboard.getData('text/plain');
    final resultado = data?.text?.trim() ?? '';
    if (resultado.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('El portapapeles está vacío.')),
        );
      }
      return;
    }

    if (!mounted) return;
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (_) => _DialogConfirmarResultado(resultado: resultado),
    );
    if (confirmado != true || !mounted) return;

    final key = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _DialogGeminiKey(),
    );
    if (key == null || key.trim().isEmpty || !mounted) return;

    await _accion(() async {
      final revision = await _revisarConGemini(key.trim(), resultado);
      if (!revision.aprobado) {
        if (mounted) {
          await showDialog<void>(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('Gemini pidió correcciones'),
              content: SelectableText(revision.detalle),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cerrar'),
                ),
              ],
            ),
          );
        }
        return;
      }

      final ws = await _asegurarWorkspace();
      _estado = await _duo.aplicarParcheWorkspace(
        workspaceId: ws.id,
        patch: resultado,
      );
      final archivos = _estado!.archivos;
      if (archivos.isEmpty) {
        throw const FalloDuo(
          'empty_patch',
          'El parche fue aceptado pero no produjo cambios.',
        );
      }

      await _duo.commitWorkspace(
        workspaceId: ws.id,
        archivos: archivos,
        mensaje: 'feat(${widget.tarea.externalId}): ${widget.tarea.titulo}',
      );
      await _duo.pushWorkspace(ws.id);
      final pr = await _duo.crearOEncontrarPullRequest(
        workspaceId: ws.id,
        titulo: '${widget.tarea.externalId}: ${widget.tarea.titulo}',
        cuerpo: 'Resultado recogido y revisado por Duo para ${widget.tarea.externalId}.',
      );
      await _sincronizarPr(pr);
      await widget.cloud.entregarTarea(
        projectId: widget.proyecto.id,
        externalId: widget.tarea.externalId,
        resultado: resultado,
      );
      widget.alCambiarCloud();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Resultado aprobado. PR #${pr.numero} creado.')),
        );
      }
    });
  }

  Future<_RevisionGemini> _revisarConGemini(String apiKey, String resultado) async {
    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-lite:generateContent',
    );
    final prompt = '''
Revisa rápidamente este resultado para una tarea de software.

Proyecto: ${widget.proyecto.nombre}
Tarea: ${widget.tarea.externalId} - ${widget.tarea.titulo}
Rama objetivo: ${widget.proyecto.ramaObjetivo}

El resultado debe ser un unified diff coherente, limitado a la tarea y sin
secretos. Responde en la primera línea exactamente APROBADO o RECHAZADO.
Después explica brevemente el motivo.

RESULTADO:
$resultado
''';

    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'x-goog-api-key': apiKey,
      },
      body: jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': prompt}
            ]
          }
        ],
        'generationConfig': {
          'temperature': 0.1,
          'maxOutputTokens': 300,
        },
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw FalloDuo(
        'gemini_review_failed',
        'Gemini respondió ${response.statusCode}. Revisa la clave y su cuota.',
      );
    }

    final decoded = jsonDecode(response.body);
    final candidates = decoded is Map<String, dynamic> ? decoded['candidates'] : null;
    final first = candidates is List && candidates.isNotEmpty ? candidates.first : null;
    final content = first is Map ? first['content'] : null;
    final parts = content is Map ? content['parts'] : null;
    final text = parts is List && parts.isNotEmpty && parts.first is Map
        ? '${(parts.first as Map)['text'] ?? ''}'.trim()
        : '';
    if (text.isEmpty) {
      throw const FalloDuo(
        'gemini_review_empty',
        'Gemini no devolvió una revisión utilizable.',
      );
    }
    return _RevisionGemini(
      text.toUpperCase().startsWith('APROBADO'),
      text,
    );
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

  Future<void> _comprobarCiYFinalizar() async {
    if (_ciConsultando ||
        widget.proyecto.rol != 'owner' ||
        widget.tarea.estado != 'in_review' ||
        widget.tarea.pullRequest == null) {
      return;
    }

    _ciConsultando = true;
    try {
      final ws = await _asegurarWorkspace();
      final pr = widget.tarea.pullRequest!;
      final ci = await _duo.estadoCiPullRequest(
        workspaceId: ws.id,
        numero: pr.numero,
      );

      if (ci.estado == 'pending') return;

      if (ci.estado == 'failed') {
        final log = ci.logFallo ?? 'CI falló sin log disponible.';
        if (mounted) setState(() => _ultimoFalloCi = log);
        await widget.cloud.publicarEvento(
          projectId: widget.proyecto.id,
          externalTaskId: widget.tarea.externalId,
          tipo: 'ci_failed',
          agente: widget.tarea.workProvider,
          payloadJson: jsonEncode({
            'runId': ci.runId,
            'url': ci.url,
            'log': log,
          }),
        );
        widget.alCambiarCloud();
        return;
      }

      if (ci.estado == 'passed') {
        final merged = await _duo.mergePullRequest(
          workspaceId: ws.id,
          numero: pr.numero,
        );
        await widget.cloud.upsertPullRequest(
          projectId: widget.proyecto.id,
          externalId: widget.tarea.externalId,
          githubNumber: merged.numero,
          url: merged.url,
          sourceBranch: merged.origen,
          targetBranch: merged.destino,
          state: merged.estado.toLowerCase(),
          reviewState: 'approved',
          mergedAt: merged.mergedAt,
          mergedByLogin: 'duo-desktop',
        );
        _ciTimer?.cancel();
        widget.alCambiarCloud();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('CI aprobado: PR fusionado y tarea completada.'),
            ),
          );
        }
      }
    } on Object catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      _ciConsultando = false;
    }
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
          final esOwner = widget.proyecto.rol == 'owner';
          if (!propia && !esOwner) {
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
                FutureBuilder<List<CapacidadAgenteLocal>>(
                  future: _capacidades,
                  builder: (context, caps) {
                    final provider = widget.tarea.workProvider;
                    final web = provider == 'chatgpt' || provider == 'grok';
                    final disponible = web ||
                        (caps.data ?? const <CapacidadAgenteLocal>[]).any(
                          (x) => x.provider == provider && x.disponible,
                        );
                    return Text(
                      disponible
                          ? 'Agente asignado disponible en este equipo.'
                          : 'Agente asignado no detectado: Duo usará un prompt para chat.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: disponible
                                ? context.paleta.bien
                                : context.paleta.aviso,
                          ),
                    );
                  },
                ),
                const SizedBox(height: 10),
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
                      label: Text(esLocal ? 'Abrir agente / fallback chat' : 'Prompt para chat'),
                    ),
                    FilledButton.icon(
                      onPressed: _ocupado ? null : _recogerResultado,
                      icon: const Icon(Icons.content_paste_go_outlined, size: 16),
                      label: const Text('Recoger resultado'),
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
                if (_ultimoFalloCi != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    'CI falló. La tarea sigue en revisión:',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: context.paleta.critico),
                  ),
                  const SizedBox(height: 6),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 220),
                    child: SingleChildScrollView(
                      child: SelectableText(
                        _ultimoFalloCi!,
                        style: const TextStyle(fontFamily: 'monospace'),
                      ),
                    ),
                  ),
                ],
                if (esOwner &&
                    widget.tarea.estado == 'in_review' &&
                    widget.tarea.pullRequest != null) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _ciConsultando ? null : _comprobarCiYFinalizar,
                    icon: const Icon(Icons.fact_check_outlined, size: 16),
                    label: const Text('Comprobar CI ahora'),
                  ),
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

class _RevisionGemini {
  const _RevisionGemini(this.aprobado, this.detalle);
  final bool aprobado;
  final String detalle;
}

class _DialogConfirmarResultado extends StatelessWidget {
  const _DialogConfirmarResultado({required this.resultado});
  final String resultado;

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Confirmar resultado recogido'),
        content: SizedBox(
          width: 760,
          height: 520,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Duo leerá este contenido del portapapeles, lo revisará con Gemini y, '
                'si se aprueba, intentará aplicarlo como unified diff.',
              ),
              const SizedBox(height: 12),
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: context.paleta.rejilla),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(12),
                    child: SelectableText(
                      resultado,
                      style: const TextStyle(fontFamily: 'monospace'),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmar y revisar'),
          ),
        ],
      );
}

class _DialogGeminiKey extends StatefulWidget {
  const _DialogGeminiKey();

  @override
  State<_DialogGeminiKey> createState() => _DialogGeminiKeyState();
}

class _DialogGeminiKeyState extends State<_DialogGeminiKey> {
  final _key = TextEditingController();

  @override
  void dispose() {
    _key.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Revisión rápida con Gemini'),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Pega tu clave de Gemini API. Duo la usa solo para esta revisión '
                'y no la guarda.',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _key,
                obscureText: true,
                autocorrect: false,
                enableSuggestions: false,
                decoration: const InputDecoration(labelText: 'Gemini API key'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, _key.text.trim()),
            child: const Text('Revisar'),
          ),
        ],
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
