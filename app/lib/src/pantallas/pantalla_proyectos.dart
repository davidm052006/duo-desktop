import 'package:flutter/material.dart';

import '../config_cloud.dart';
import '../datos/cliente_cloud.dart';
import '../tema/paleta.dart';
import '../widgets/tarjeta.dart';
import 'pantalla_proyecto_cloud.dart';

class PantallaProyectos extends StatefulWidget {
  const PantallaProyectos({super.key});

  @override
  State<PantallaProyectos> createState() => _PantallaProyectosState();
}

class _PantallaProyectosState extends State<PantallaProyectos> {
  late final ClienteCloud _cloud;
  late Future<List<ProyectoCloud>> _carga;
  ProyectoCloud? _abierto;

  @override
  void initState() {
    super.initState();
    _cloud = ClienteCloud();
    _carga = _leer();
  }

  @override
  void dispose() {
    _cloud.cierra();
    super.dispose();
  }

  Future<List<ProyectoCloud>> _leer() async {
    if (!ConfigCloud.configurado) return const [];
    return _cloud.proyectos();
  }

  void _refrescar() {
    setState(() => _carga = _leer());
  }

  Future<void> _nuevoProyecto() async {
    final creado = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _DialogNuevoProyecto(cloud: _cloud),
    );
    if (creado == true && mounted) _refrescar();
  }

  @override
  Widget build(BuildContext context) {
    if (_abierto != null) {
      return PantallaProyectoCloud(
        proyecto: _abierto!,
        volver: () => setState(() => _abierto = null),
      );
    }

    final paleta = context.paleta;
    final textos = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 36),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      ShaderMask(
                        shaderCallback: (rect) => const LinearGradient(
                          colors: [
                            Color(0xFF9D5CFF),
                            Color(0xFFFF63C3),
                            Color(0xFF63E6FF),
                          ],
                        ).createShader(rect),
                        child: const Icon(
                          Icons.account_tree_outlined,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Proyectos',
                        style: textos.headlineSmall?.copyWith(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Insignia('CLOUD', tono: paleta.acentoAlt, mono: true),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tus espacios colaborativos, miembros, tareas y revisiones.',
                    style: textos.bodySmall?.copyWith(
                      color: paleta.tintaSecundaria,
                    ),
                  ),
                ],
              ),
            ),
            OutlinedButton.icon(
              onPressed: _refrescar,
              icon: const Icon(Icons.sync, size: 16),
              label: const Text('Actualizar'),
            ),
            const SizedBox(width: 10),
            FilledButton.icon(
              onPressed: ConfigCloud.configurado ? _nuevoProyecto : null,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Nuevo proyecto'),
            ),
          ],
        ),
        const SizedBox(height: 24),
        if (!ConfigCloud.configurado)
          _CloudNoConfigurado()
        else
          FutureBuilder<List<ProyectoCloud>>(
            future: _carga,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const SizedBox(
                  height: 220,
                  child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              }

              if (snapshot.hasError) {
                return _PanelError(
                  mensaje: snapshot.error.toString(),
                  reintentar: _refrescar,
                );
              }

              final proyectos = snapshot.data ?? const <ProyectoCloud>[];
              if (proyectos.isEmpty) {
                return _Vacio(crear: _nuevoProyecto);
              }

              return LayoutBuilder(
                builder: (context, caja) {
                  final columnas = caja.maxWidth >= 1180
                      ? 3
                      : caja.maxWidth >= 760
                          ? 2
                          : 1;
                  const gap = 16.0;
                  final ancho =
                      (caja.maxWidth - gap * (columnas - 1)) / columnas;

                  return Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: [
                      for (final proyecto in proyectos)
                        SizedBox(
                          width: ancho,
                          child: _TarjetaProyecto(
                            proyecto: proyecto,
                            abrir: () => setState(() => _abierto = proyecto),
                          ),
                        ),
                    ],
                  );
                },
              );
            },
          ),
      ],
    );
  }
}

class _TarjetaProyecto extends StatelessWidget {
  const _TarjetaProyecto({
    required this.proyecto,
    required this.abrir,
  });

  final ProyectoCloud proyecto;
  final VoidCallback abrir;

  @override
  Widget build(BuildContext context) {
    final paleta = context.paleta;
    final textos = Theme.of(context).textTheme;
    final colorRol = switch (proyecto.rol) {
      'owner' => const Color(0xFFFF63C3),
      'editor' => const Color(0xFF9D5CFF),
      _ => const Color(0xFF63E6FF),
    };

    return Container(
      constraints: const BoxConstraints(minHeight: 190),
      decoration: BoxDecoration(
        color: paleta.panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorRol.withValues(alpha: .34),
        ),
        boxShadow: [
          BoxShadow(
            color: colorRol.withValues(alpha: .10),
            blurRadius: 24,
            spreadRadius: 1,
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: abrir,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      proyecto.nombre,
                      style: textos.titleMedium?.copyWith(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Insignia(
                    proyecto.rol.toUpperCase(),
                    tono: colorRol,
                    mono: true,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _DatoProyecto(
                icono: Icons.code,
                texto: proyecto.repositorio,
              ),
              const SizedBox(height: 10),
              _DatoProyecto(
                icono: Icons.fork_right_outlined,
                texto: proyecto.ramaObjetivo,
              ),
              const Spacer(),
              Divider(color: paleta.rejilla),
              const SizedBox(height: 8),
              Row(
                children: [
                  Mono(
                    proyecto.slug,
                    color: paleta.tintaTenue,
                  ),
                  const Spacer(),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 18,
                    color: paleta.acentoAlt,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DatoProyecto extends StatelessWidget {
  const _DatoProyecto({required this.icono, required this.texto});

  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icono, size: 15, color: context.paleta.tintaTenue),
          const SizedBox(width: 8),
          Expanded(
            child: Mono(
              texto.isEmpty ? 'sin configurar' : texto,
              color: context.paleta.tintaSecundaria,
            ),
          ),
        ],
      );
}

class _Vacio extends StatelessWidget {
  const _Vacio({required this.crear});

  final VoidCallback crear;

  @override
  Widget build(BuildContext context) => Tarjeta(
        titulo: 'Sin proyectos',
        icono: Icons.blur_on,
        hijo: Padding(
          padding: const EdgeInsets.symmetric(vertical: 34),
          child: Column(
            children: [
              const Icon(Icons.hub_outlined, size: 42),
              const SizedBox(height: 14),
              Text(
                'Crea tu primer proyecto colaborativo.',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Quedarás como owner y luego podrás invitar editores y viewers.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: crear,
                icon: const Icon(Icons.add),
                label: const Text('Crear proyecto'),
              ),
            ],
          ),
        ),
      );
}

class _CloudNoConfigurado extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Tarjeta(
        titulo: 'Duo Cloud',
        icono: Icons.cloud_off_outlined,
        sufijo: Insignia('FALTA URL', tono: context.paleta.aviso),
        hijo: Text(
          'Configura DUO_CLOUD_URL con --dart-define para conectar esta app '
          'con el backend colaborativo. El login de Supabase puede seguir '
          'funcionando aunque Cloud todavía no tenga URL.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
}

class _PanelError extends StatelessWidget {
  const _PanelError({required this.mensaje, required this.reintentar});

  final String mensaje;
  final VoidCallback reintentar;

  @override
  Widget build(BuildContext context) => Tarjeta(
        titulo: 'No se pudieron cargar los proyectos',
        icono: Icons.cloud_off_outlined,
        sufijo: Insignia('ERROR', tono: context.paleta.critico),
        hijo: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(mensaje, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: reintentar,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      );
}

class _DialogNuevoProyecto extends StatefulWidget {
  const _DialogNuevoProyecto({required this.cloud});

  final ClienteCloud cloud;

  @override
  State<_DialogNuevoProyecto> createState() => _DialogNuevoProyectoState();
}

class _DialogNuevoProyectoState extends State<_DialogNuevoProyecto> {
  final _form = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _slug = TextEditingController();
  final _repo = TextEditingController();
  final _rama = TextEditingController(text: 'develop');
  bool _enviando = false;
  String? _error;

  @override
  void dispose() {
    _nombre.dispose();
    _slug.dispose();
    _repo.dispose();
    _rama.dispose();
    super.dispose();
  }

  Future<void> _crear() async {
    if (!_form.currentState!.validate() || _enviando) return;

    setState(() {
      _enviando = true;
      _error = null;
    });

    try {
      await widget.cloud.crearProyecto(
        nombre: _nombre.text.trim(),
        slug: _slug.text.trim(),
        repositorio: _repo.text.trim(),
        ramaObjetivo: _rama.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _enviando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final paleta = context.paleta;

    return AlertDialog(
      backgroundColor: paleta.panel,
      surfaceTintColor: Colors.transparent,
      title: Row(
        children: [
          Icon(Icons.add_box_outlined, color: paleta.acentoAlt),
          const SizedBox(width: 10),
          const Text('Nuevo proyecto'),
        ],
      ),
      content: SizedBox(
        width: 580,
        child: Form(
          key: _form,
          child: SingleChildScrollView(
            child: Column(
              children: [
                _Campo(
                  controller: _nombre,
                  label: 'Nombre',
                  hint: 'SIHS',
                ),
                const SizedBox(height: 14),
                _Campo(
                  controller: _slug,
                  label: 'Slug',
                  hint: 'sihs',
                  validator: (value) {
                    final v = value?.trim() ?? '';
                    if (!RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$').hasMatch(v)) {
                      return 'Usa minúsculas, números y guiones.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                _Campo(
                  controller: _repo,
                  label: 'Repositorio GitHub',
                  hint: 'organizacion/sihs',
                  validator: (value) {
                    final v = value?.trim() ?? '';
                    if (!RegExp(r'^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$')
                        .hasMatch(v)) {
                      return 'Usa owner/repositorio.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                _Campo(
                  controller: _rama,
                  label: 'Rama objetivo',
                  hint: 'develop',
                ),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  Text(
                    _error!,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: paleta.critico),
                  ),
                ],
              ],
            ),
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
          icon: _enviando
              ? const SizedBox(
                  width: 15,
                  height: 15,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.rocket_launch_outlined, size: 16),
          label: Text(_enviando ? 'Creando…' : 'Crear'),
        ),
      ],
    );
  }
}

class _Campo extends StatelessWidget {
  const _Campo({
    required this.controller,
    required this.label,
    required this.hint,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) => TextFormField(
        controller: controller,
        validator: validator ??
            (value) => (value == null || value.trim().isEmpty)
                ? 'Campo obligatorio.'
                : null,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
        ),
      );
}
