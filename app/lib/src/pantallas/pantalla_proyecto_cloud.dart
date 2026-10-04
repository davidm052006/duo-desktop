import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../datos/cliente_cloud.dart';
import '../tema/paleta.dart';
import '../widgets/tarjeta.dart';

class PantallaProyectoCloud extends StatefulWidget {
  const PantallaProyectoCloud({
    super.key,
    required this.proyecto,
    required this.volver,
  });

  final ProyectoCloud proyecto;
  final VoidCallback volver;

  @override
  State<PantallaProyectoCloud> createState() => _PantallaProyectoCloudState();
}

class _PantallaProyectoCloudState extends State<PantallaProyectoCloud>
    with SingleTickerProviderStateMixin {
  late final ClienteCloud _cloud;
  late final TabController _tabs;
  late Future<List<MiembroCloud>> _miembros;
  late Future<List<TareaCloud>> _tareas;

  @override
  void initState() {
    super.initState();
    _cloud = ClienteCloud();
    _tabs = TabController(length: 3, vsync: this);
    _recargar();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _cloud.cierra();
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
                  puedeEditar: puedeEditar,
                  crear: miembrosSnap.hasData
                      ? () => _crearTarea(miembrosSnap.data!)
                      : null,
                ),
              ),
              _VistaRevisiones(carga: _tareas),
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
    required this.puedeEditar,
    required this.crear,
  });

  final Future<List<TareaCloud>> carga;
  final bool puedeEditar;
  final VoidCallback? crear;

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
                    child: _TarjetaTarea(tarea: tarea),
                  ),
            ],
          );
        },
      );
}

class _VistaRevisiones extends StatelessWidget {
  const _VistaRevisiones({required this.carga});

  final Future<List<TareaCloud>> carga;

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
                    child: _TarjetaRevision(tarea: tarea),
                  ),
            ],
          );
        },
      );
}

class _TarjetaTarea extends StatelessWidget {
  const _TarjetaTarea({required this.tarea});
  final TareaCloud tarea;

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
      hijo: Wrap(
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
        ],
      ),
    );
  }
}

class _TarjetaRevision extends StatelessWidget {
  const _TarjetaRevision({required this.tarea});
  final TareaCloud tarea;

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
  String? _asignado;
  String _provider = 'chatgpt';
  bool _enviando = false;
  String? _error;

  @override
  void dispose() {
    _id.dispose();
    _titulo.dispose();
    _rama.dispose();
    super.dispose();
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
