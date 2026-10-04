import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../datos/cliente_duo.dart';
import '../datos/cliente_cloud.dart';
import '../tema/paleta.dart';
import '../widgets/tarjeta.dart';

class PantallaProyectoCloud extends StatefulWidget {
  const PantallaProyectoCloud({
    super.key,
    required this.proyecto,
    required this.volver,
    this.cloud,
  });

  final ProyectoCloud proyecto;
  final VoidCallback volver;
  final ClienteCloud? cloud;

  @override
  State<PantallaProyectoCloud> createState() => _PantallaProyectoCloudState();
}

class _PantallaProyectoCloudState extends State<PantallaProyectoCloud>
    with SingleTickerProviderStateMixin {
  late final ClienteCloud _cloud;
  late final bool _administraCloud;
  late final TabController _tabs;
  late Future<List<MiembroCloud>> _miembros;
  late Future<List<TareaCloud>> _tareas;

  @override
  void initState() {
    super.initState();
    _administraCloud = widget.cloud == null;
    _cloud = widget.cloud ?? ClienteCloud();
    _tabs = TabController(length: 3, vsync: this);
    _recargar();
  }

  @override
  void dispose() {
    _tabs.dispose();
    if (_administraCloud) {
      _cloud.cierra();
    }
    super.dispose();
  }

  void _recargar() {
    _miembros = _cloud.miembros(widget.proyecto.id);
    _tareas = _cloud.tareas(widget.proyecto.id);
  }

  Future<void> _invitar() async {
    final invitacion = await showDialog<InvitacionCloud>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _DialogInvitar(
        cloud: _cloud,
        projectId: widget.proyecto.id,
      ),
    );
    if (invitacion == null || !mounted) return;

    await showDialog<void>(
      context: context,
      builder: (_) => _DialogTokenInvitacion(invitacion: invitacion),
    );
    setState(_recargar);
  }

  Future<void> _crearTarea(List<MiembroCloud> miembros) async {
    final creada = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _DialogTarea(
        cloud: _cloud,
        projectId: widget.proyecto.id,
        ramaObjetivo: widget.proyecto.ramaObjetivo,
        miembros: miembros,
      ),
    );
    if (creada == true && mounted) setState(_recargar);
  }

  Future<void> _editarPullRequest(TareaCloud tarea) async {
    final actualizado = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _DialogPullRequest(
        cloud: _cloud,
        projectId: widget.proyecto.id,
        tarea: tarea,
        ramaObjetivoProyecto: widget.proyecto.ramaObjetivo,
        esOwner: widget.proyecto.rol == 'owner',
      ),
    );
    if (actualizado == true && mounted) setState(_recargar);
  }

  @override
  Widget build(BuildContext context) {
    final paleta = context.paleta;
    final textos = Theme.of(context).textTheme;
    final esOwner = widget.proyecto.rol == 'owner';
    final puedeEditar =
        widget.proyecto.rol == 'owner' || widget.proyecto.rol == 'editor';

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 22, 28, 0),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Volver a proyectos',
                onPressed: widget.volver,
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          widget.proyecto.nombre,
                          style: textos.headlineSmall?.copyWith(
                            fontSize: 25,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Insignia(
                          widget.proyecto.rol.toUpperCase(),
                          tono: esOwner
                              ? paleta.acento
                              : puedeEditar
                                  ? const Color(0xFF9D5CFF)
                                  : paleta.acentoAlt,
                          mono: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Flexible(
                          child: Mono(
                            widget.proyecto.repositorio,
                            color: paleta.tintaSecundaria,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Insignia(
                          '→ ${widget.proyecto.ramaObjetivo}',
                          tono: paleta.acentoAlt,
                          mono: true,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Actualizar',
                onPressed: () => setState(_recargar),
                icon: const Icon(Icons.sync),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Container(
            decoration: BoxDecoration(
              color: paleta.panel,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: paleta.acentoAlt.withValues(alpha: .16),
              ),
            ),
            child: TabBar(
              controller: _tabs,
              tabs: const [
                Tab(icon: Icon(Icons.group_outlined), text: 'Miembros'),
                Tab(icon: Icon(Icons.task_alt_outlined), text: 'Tareas'),
                Tab(icon: Icon(Icons.rate_review_outlined), text: 'Revisiones'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              _VistaMiembros(
                carga: _miembros,
                esOwner: esOwner,
                invitar: _invitar,
              ),
              FutureBuilder<List<MiembroCloud>>(
                future: _miembros,
                builder: (context, miembrosSnap) => _VistaTareas(
                  carga: _tareas,
                  proyecto: widget.proyecto,
                  cloud: _cloud,
                  puedeEditar: puedeEditar,
                  crear: miembrosSnap.hasData
                      ? () => _crearTarea(miembrosSnap.data!)
                      : null,
                  editarPullRequest: puedeEditar ? _editarPullRequest : null,
                  alCambiarCloud: () {
                    if (mounted) setState(_recargar);
                  },
                ),
              ),
              _VistaRevisiones(
                carga: _tareas,
                editarPullRequest: puedeEditar ? _editarPullRequest : null,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _VistaMiembros extends StatelessWidget {
  const _VistaMiembros({
    required this.carga,
    required this.esOwner,
    required this.invitar,
  });

  final Future<List<MiembroCloud>> carga;
  final bool esOwner;
  final VoidCallback invitar;

  @override
  Widget build(BuildContext context) => FutureBuilder<List<MiembroCloud>>(
        future: carga,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            if (snapshot.hasError) return _ErrorPanel(snapshot.error.toString());
            return const Center(child: CircularProgressIndicator(strokeWidth: 2));
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(28, 8, 28, 36),
            children: [
              Row(
                children: [
                  Text('Equipo', style: Theme.of(context).textTheme.titleMedium),
                  const Spacer(),
                  if (esOwner)
                    FilledButton.icon(
                      onPressed: invitar,
                      icon: const Icon(Icons.person_add_alt_1, size: 17),
                      label: const Text('Invitar'),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              for (final miembro in snapshot.data!)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Tarjeta(
                    titulo: miembro.nombre?.trim().isNotEmpty == true
                        ? miembro.nombre!
                        : miembro.email,
                    icono: Icons.person_outline,
                    sufijo: Insignia(
                      miembro.rol.toUpperCase(),
                      tono: _tonoRol(context, miembro.rol),
                      mono: true,
                    ),
                    hijo: Mono(
                      miembro.email,
                      color: context.paleta.tintaSecundaria,
                    ),
                  ),
                ),
            ],
          );
        },
      );
}

class _VistaTareas extends StatelessWidget {
  const _VistaTareas({
    required this.carga,
    required this.proyecto,
    required this.cloud,
    required this.puedeEditar,
    required this.crear,
    required this.editarPullRequest,
    required this.alCambiarCloud,
  });

  final Future<List<TareaCloud>> carga;
  final ProyectoCloud proyecto;
  final ClienteCloud cloud;
  final bool puedeEditar;
  final VoidCallback? crear;
  final ValueChanged<TareaCloud>? editarPullRequest;
  final VoidCallback alCambiarCloud;

  @override
  Widget build(BuildContext context) => FutureBuilder<List<TareaCloud>>(
        future: carga,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            if (snapshot.hasError) return _ErrorPanel(snapshot.error.toString());
            return const Center(child: CircularProgressIndicator(strokeWidth: 2));
          }

          final tareas = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.fromLTRB(28, 8, 28, 36),
            children: [
              Row(
                children: [
                  Text(
                    'Tareas compartidas',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const Spacer(),
                  if (puedeEditar)
                    FilledButton.icon(
                      onPressed: crear,
                      icon: const Icon(Icons.add_task, size: 17),
                      label: const Text('Nueva tarea'),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              if (tareas.isEmpty)
                const _VacioTexto(
                  icono: Icons.task_alt_outlined,
                  texto: 'Todavía no hay tareas cloud en este proyecto.',
                )
              else
                for (final tarea in tareas)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _TarjetaTarea(
                      tarea: tarea,
                      proyecto: proyecto,
                      cloud: cloud,
                      alCambiarCloud: alCambiarCloud,
                      editarPullRequest: editarPullRequest == null
                          ? null
                          : () => editarPullRequest!(tarea),
                    ),
                  ),
            ],
          );
        },
      );
}

class _VistaRevisiones extends StatelessWidget {
  const _VistaRevisiones({
    required this.carga,
    required this.editarPullRequest,
  });

  final Future<List<TareaCloud>> carga;
  final ValueChanged<TareaCloud>? editarPullRequest;

  @override
  Widget build(BuildContext context) => FutureBuilder<List<TareaCloud>>(
        future: carga,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            if (snapshot.hasError) return _ErrorPanel(snapshot.error.toString());
            return const Center(child: CircularProgressIndicator(strokeWidth: 2));
          }

          final revisiones =
              snapshot.data!.where((t) => t.pullRequest != null).toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(28, 8, 28, 36),
            children: [
              Text(
                'Pull requests',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 14),
              if (revisiones.isEmpty)
                const _VacioTexto(
                  icono: Icons.rate_review_outlined,
                  texto: 'No hay pull requests asociados a tareas.',
                )
              else
                for (final tarea in revisiones)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _TarjetaRevision(
                      tarea: tarea,
                      editarPullRequest: editarPullRequest == null
                          ? null
                          : () => editarPullRequest!(tarea),
                    ),
                  ),
            ],
          );
        },
      );
}

class _TarjetaTarea extends StatelessWidget {
  const _TarjetaTarea({
    required this.tarea,
    required this.proyecto,
    required this.cloud,
    required this.alCambiarCloud,
    this.editarPullRequest,
  });

  final TareaCloud tarea;
  final ProyectoCloud proyecto;
  final ClienteCloud cloud;
  final VoidCallback alCambiarCloud;
  final VoidCallback? editarPullRequest;

  @override
  Widget build(BuildContext context) {
    final paleta = context.paleta;
    return Tarjeta(
      titulo: '${tarea.externalId} · ${tarea.titulo}',
      icono: Icons.task_alt_outlined,
      sufijo: Insignia(
        tarea.estado.toUpperCase(),
        tono: _tonoEstado(context, tarea.estado),
        mono: true,
      ),
      hijo: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              Insignia(
                tarea.assignedEmail ?? 'sin asignar',
                tono: paleta.tintaSecundaria,
              ),
              Insignia(
                tarea.workProvider,
                tono: const Color(0xFF9D5CFF),
                mono: true,
              ),
              Insignia(tarea.rama, tono: paleta.acentoAlt, mono: true),
              if (tarea.pullRequest != null)
                Insignia(
                  'PR #${tarea.pullRequest!.numero}',
                  tono: paleta.acento,
                  mono: true,
                ),
              if (editarPullRequest != null)
                ActionChip(
                  avatar: const Icon(Icons.merge_type, size: 16),
                  label: Text(
                    tarea.pullRequest == null ? 'Registrar PR' : 'Actualizar PR',
                  ),
                  onPressed: editarPullRequest,
                ),
            ],
          ),
          const SizedBox(height: 14),
          PanelTrabajoLocal(
            proyecto: proyecto,
            tarea: tarea,
            cloud: cloud,
            alCambiarCloud: alCambiarCloud,
          ),
        ],
      ),
    );
  }
}

class _TarjetaRevision extends StatelessWidget {
  const _TarjetaRevision({required this.tarea, this.editarPullRequest});
  final TareaCloud tarea;
  final VoidCallback? editarPullRequest;

  @override
  Widget build(BuildContext context) {
    final pr = tarea.pullRequest!;
    return Tarjeta(
      titulo: '${tarea.externalId} · PR #${pr.numero}',
      icono: Icons.merge_type,
      sufijo: Insignia(
        tarea.estado == 'finalized' ? 'MERGED' : 'IN REVIEW',
        tono: tarea.estado == 'finalized'
            ? context.paleta.bien
            : context.paleta.acento,
        mono: true,
      ),
      hijo: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tarea.titulo),
          const SizedBox(height: 10),
          Mono('${pr.ramaOrigen} → ${pr.ramaObjetivo}'),
          if (pr.estadoRevision != null) ...[
            const SizedBox(height: 8),
            Insignia(pr.estadoRevision!, tono: context.paleta.acentoAlt),
          ],
          if (editarPullRequest != null) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: editarPullRequest,
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: const Text('Actualizar PR'),
            ),
          ],
        ],
      ),
    );
  }
}

class _DialogInvitar extends StatefulWidget {
  const _DialogInvitar({required this.cloud, required this.projectId});

  final ClienteCloud cloud;
  final String projectId;

  @override
  State<_DialogInvitar> createState() => _DialogInvitarState();
}

class _DialogInvitarState extends State<_DialogInvitar> {
  final _email = TextEditingController();
  String _rol = 'editor';
  bool _enviando = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    if (_email.text.trim().isEmpty || _enviando) return;
    setState(() {
      _enviando = true;
      _error = null;
    });

    try {
      final invitacion = await widget.cloud.invitar(
        projectId: widget.projectId,
        email: _email.text.trim(),
        rol: _rol,
      );
      if (mounted) Navigator.of(context).pop(invitacion);
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _enviando = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        backgroundColor: context.paleta.panel,
        title: const Text('Invitar compañero'),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _email,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _rol,
                decoration: const InputDecoration(labelText: 'Rol'),
                items: const [
                  DropdownMenuItem(value: 'editor', child: Text('Editor')),
                  DropdownMenuItem(value: 'viewer', child: Text('Viewer')),
                ],
                onChanged: _enviando
                    ? null
                    : (value) {
                        if (value != null) setState(() => _rol = value);
                      },
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(color: context.paleta.critico),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _enviando ? null : () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: _enviando ? null : _enviar,
            child: Text(_enviando ? 'Creando…' : 'Crear invitación'),
          ),
        ],
      );
}

class _DialogTokenInvitacion extends StatelessWidget {
  const _DialogTokenInvitacion({required this.invitacion});
  final InvitacionCloud invitacion;

  @override
  Widget build(BuildContext context) => AlertDialog(
        backgroundColor: context.paleta.panel,
        title: const Text('Invitación creada'),
        content: SizedBox(
          width: 540,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${invitacion.email} · ${invitacion.rol}'),
              const SizedBox(height: 12),
              Text(
                'Este token se muestra una sola vez. Compártelo con el invitado.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              SelectableText(
                invitacion.token,
                style: const TextStyle(fontFamily: 'monospace'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: invitacion.token));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Token copiado')),
                );
              }
            },
            icon: const Icon(Icons.copy),
            label: const Text('Copiar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Listo'),
          ),
        ],
      );
}

class _DialogTarea extends StatefulWidget {
  const _DialogTarea({
    required this.cloud,
    required this.projectId,
    required this.ramaObjetivo,
    required this.miembros,
  });

  final ClienteCloud cloud;
  final String projectId;
  final String ramaObjetivo;
  final List<MiembroCloud> miembros;

  @override
  State<_DialogTarea> createState() => _DialogTareaState();
}

class _DialogTareaState extends State<_DialogTarea> {
  final _id = TextEditingController();
  final _titulo = TextEditingController();
  final _rama = TextEditingController();
  final _duo = ClienteDuo();
  String? _asignado;
  String _provider = 'chatgpt';
  bool _enviando = false;
  String? _error;
  late final Future<List<CapacidadAgenteLocal>> _capacidades;

  @override
  void initState() {
    super.initState();
    _capacidades = _duo.capacidadesAgentes();
  }

  @override
  void dispose() {
    _id.dispose();
    _titulo.dispose();
    _rama.dispose();
    _duo.cierra();
    super.dispose();
  }

  Widget _disponibilidadLocal() {
    if (_provider == 'chatgpt' || _provider == 'grok') {
      return const Text('Proveedor web: se abre en el chat CEF.');
    }
    return FutureBuilder<List<CapacidadAgenteLocal>>(
      future: _capacidades,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Text('Comprobando disponibilidad en este dispositivo…');
        }
        if (snapshot.hasError) {
          return Text(
            'No se pudo comprobar la disponibilidad en este dispositivo.',
            style: TextStyle(color: context.paleta.aviso),
          );
        }
        final capacidad = (snapshot.data ?? const <CapacidadAgenteLocal>[])
            .where((item) => item.provider == _provider)
            .firstOrNull;
        final disponible = capacidad?.disponible == true;
        return Text(
          disponible
              ? 'Disponible en este dispositivo'
              : 'No detectado en este dispositivo',
          style: TextStyle(
            color: disponible ? context.paleta.bien : context.paleta.tintaTenue,
          ),
        );
      },
    );
  }

  Future<void> _crear() async {
    if (_id.text.trim().isEmpty ||
        _titulo.text.trim().isEmpty ||
        _rama.text.trim().isEmpty ||
        _enviando) {
      return;
    }

    setState(() {
      _enviando = true;
      _error = null;
    });

    try {
      await widget.cloud.upsertTarea(
        projectId: widget.projectId,
        externalId: _id.text.trim(),
        titulo: _titulo.text.trim(),
        ownerAgent: _provider,
        estado: 'pending',
        rama: _rama.text.trim(),
        assignedUserId: _asignado,
        workProvider: _provider,
      );
      if (mounted) Navigator.pop(context, true);
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _enviando = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        backgroundColor: context.paleta.panel,
        title: const Text('Nueva tarea compartida'),
        content: SizedBox(
          width: 580,
          child: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  controller: _id,
                  decoration: const InputDecoration(
                    labelText: 'ID',
                    hintText: 'T-052',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _titulo,
                  decoration: const InputDecoration(labelText: 'Título'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  initialValue: _asignado,
                  decoration: const InputDecoration(labelText: 'Asignar a'),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Sin asignar'),
                    ),
                    for (final m in widget.miembros)
                      DropdownMenuItem<String?>(
                        value: m.id,
                        child: Text(m.email),
                      ),
                  ],
                  onChanged: (value) => setState(() => _asignado = value),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _provider,
                  decoration: const InputDecoration(labelText: 'Proveedor'),
                  items: const [
                    DropdownMenuItem(
                      value: 'chatgpt',
                      child: Text('ChatGPT Web'),
                    ),
                    DropdownMenuItem(
                      value: 'grok',
                      child: Text('Grok Web'),
                    ),
                    DropdownMenuItem(value: 'codex', child: Text('Codex')),
                    DropdownMenuItem(
                      value: 'claude',
                      child: Text('Claude Code'),
                    ),
                    DropdownMenuItem(value: 'gemini', child: Text('Gemini')),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _provider = value);
                  },
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: _disponibilidadLocal(),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _rama,
                  decoration: InputDecoration(
                    labelText: 'Rama de trabajo',
                    hintText: 'feature/T-052-descripcion',
                    helperText: 'PR final → ${widget.ramaObjetivo}',
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: TextStyle(color: context.paleta.critico),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _enviando ? null : () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            onPressed: _enviando ? null : _crear,
            icon: const Icon(Icons.add_task, size: 16),
            label: Text(_enviando ? 'Creando…' : 'Crear tarea'),
          ),
        ],
      );
}

class _DialogPullRequest extends StatefulWidget {
  const _DialogPullRequest({
    required this.cloud,
    required this.projectId,
    required this.tarea,
    required this.ramaObjetivoProyecto,
    required this.esOwner,
  });

  final ClienteCloud cloud;
  final String projectId;
  final TareaCloud tarea;
  final String ramaObjetivoProyecto;
  final bool esOwner;

  @override
  State<_DialogPullRequest> createState() => _DialogPullRequestState();
}

class _DialogPullRequestState extends State<_DialogPullRequest> {
  late final TextEditingController _numero;
  late final TextEditingController _url;
  late final TextEditingController _origen;
  late final TextEditingController _destino;
  final _mergedBy = TextEditingController();
  String _estado = 'open';
  String _revision = 'approved';
  bool _confirmarMerge = false;
  bool _enviando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final pr = widget.tarea.pullRequest;
    _numero = TextEditingController(text: pr?.numero.toString() ?? '');
    _url = TextEditingController(text: pr?.url ?? '');
    _origen = TextEditingController(text: pr?.ramaOrigen ?? widget.tarea.rama);
    _destino = TextEditingController(
      text: pr?.ramaObjetivo ?? widget.ramaObjetivoProyecto,
    );
    _estado = pr?.estado.isNotEmpty == true ? pr!.estado : 'open';
    _revision = pr?.estadoRevision?.isNotEmpty == true
        ? pr!.estadoRevision!
        : 'approved';
  }

  @override
  void dispose() {
    _numero.dispose();
    _url.dispose();
    _origen.dispose();
    _destino.dispose();
    _mergedBy.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final numero = int.tryParse(_numero.text.trim());
    if (numero == null ||
        _url.text.trim().isEmpty ||
        _origen.text.trim().isEmpty ||
        _destino.text.trim().isEmpty ||
        _enviando) {
      return;
    }
    if (_confirmarMerge && _mergedBy.text.trim().isEmpty) {
      setState(() => _error = 'Indica quién confirmó el merge.');
      return;
    }

    setState(() {
      _enviando = true;
      _error = null;
    });
    try {
      await widget.cloud.upsertPullRequest(
        projectId: widget.projectId,
        externalId: widget.tarea.externalId,
        githubNumber: numero,
        url: _url.text.trim(),
        sourceBranch: _origen.text.trim(),
        targetBranch: _destino.text.trim(),
        state: _estado,
        reviewState: _revision,
        mergedAt: _confirmarMerge ? DateTime.now() : null,
        mergedByLogin: _confirmarMerge ? _mergedBy.text.trim() : null,
      );
      if (mounted) {
        Navigator.pop(context, true);
      }
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _enviando = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        backgroundColor: context.paleta.panel,
        title: Text(widget.tarea.pullRequest == null ? 'Registrar PR' : 'Actualizar PR'),
        content: SizedBox(
          width: 580,
          child: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  controller: _numero,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Número de PR'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _url,
                  decoration: const InputDecoration(labelText: 'URL'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _origen,
                  decoration: const InputDecoration(labelText: 'Rama origen'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _destino,
                  decoration: InputDecoration(
                    labelText: 'Rama destino',
                    helperText: 'Finaliza solo si coincide con ${widget.ramaObjetivoProyecto}.',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _estado,
                  decoration: const InputDecoration(labelText: 'Estado PR'),
                  items: const [
                    DropdownMenuItem(value: 'open', child: Text('open')),
                    DropdownMenuItem(value: 'closed', child: Text('closed')),
                    DropdownMenuItem(value: 'merged', child: Text('merged')),
                  ],
                  onChanged: _enviando
                      ? null
                      : (value) => setState(() => _estado = value ?? 'open'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _revision,
                  decoration: const InputDecoration(labelText: 'Revisión'),
                  items: const [
                    DropdownMenuItem(value: 'pending', child: Text('pending')),
                    DropdownMenuItem(value: 'approved', child: Text('approved')),
                    DropdownMenuItem(value: 'changes_requested', child: Text('changes_requested')),
                  ],
                  onChanged: _enviando
                      ? null
                      : (value) => setState(() => _revision = value ?? 'pending'),
                ),
                if (widget.esOwner) ...[
                  const SizedBox(height: 12),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Confirmar merge'),
                    subtitle: const Text('Solo owner; registra fecha y autor del merge.'),
                    value: _confirmarMerge,
                    onChanged: _enviando
                        ? null
                        : (value) => setState(() => _confirmarMerge = value),
                  ),
                  if (_confirmarMerge)
                    TextField(
                      controller: _mergedBy,
                      decoration: const InputDecoration(labelText: 'Merged by login'),
                    ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: TextStyle(color: context.paleta.critico)),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _enviando ? null : () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            onPressed: _enviando ? null : _guardar,
            icon: const Icon(Icons.save_outlined, size: 16),
            label: Text(_enviando ? 'Guardando…' : 'Guardar PR'),
          ),
        ],
      );
}

class _VacioTexto extends StatelessWidget {
  const _VacioTexto({required this.icono, required this.texto});
  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Column(
          children: [
            Icon(icono, size: 40, color: context.paleta.tintaTenue),
            const SizedBox(height: 12),
            Text(texto, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      );
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel(this.texto);
  final String texto;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(28),
        child: Tarjeta(
          titulo: 'Error Cloud',
          icono: Icons.error_outline,
          hijo: Text(texto),
        ),
      );
}

Color _tonoRol(BuildContext context, String rol) => switch (rol) {
      'owner' => context.paleta.acento,
      'editor' => const Color(0xFF9D5CFF),
      _ => context.paleta.acentoAlt,
    };

Color _tonoEstado(BuildContext context, String estado) => switch (estado) {
      'finalized' => context.paleta.bien,
      'in_review' => context.paleta.acento,
      'in_progress' => context.paleta.acentoAlt,
      'waiting' => context.paleta.aviso,
      _ => context.paleta.tintaSecundaria,
    };
